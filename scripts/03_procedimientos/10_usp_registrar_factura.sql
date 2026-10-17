USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_REGISTRAR_FACTURA;
GO

CREATE PROCEDURE DBO.USP_REGISTRAR_FACTURA
    @empresa_id INT,
    @cliente_id INT,
    @codigo_tipo_documento VARCHAR(10),
    @codigo_moneda CHAR(3),
    @tipo_cambio DECIMAL(18, 4) = 1,
    @codigo_estado VARCHAR(20) = 'EMITIDA',
    @observaciones VARCHAR(500) = '',
    @detalles dbo.TIPO_DETALLE_FACTURA READONLY,
    @factura_id BIGINT OUTPUT,
    @numero_factura VARCHAR(50) OUTPUT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @factura_id = 0;
    SET @numero_factura = '';
    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @tipo_documento_id INT;
    DECLARE @codigo_tipo VARCHAR(10);
    DECLARE @moneda_id INT;
    DECLARE @estado_factura_id INT;
    DECLARE @fecha DATETIME2(0);
    DECLARE @numero VARCHAR(50);
    DECLARE @subtotal DECIMAL(18, 2);
    DECLARE @descuento DECIMAL(18, 2);
    DECLARE @impuesto DECIMAL(18, 2);
    DECLARE @total DECIMAL(18, 2);
    DECLARE @id_nuevo BIGINT;
    DECLARE @item_actual INT;
    DECLARE @unidades DECIMAL(18, 2);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM @detalles)
            BEGIN
                THROW 50201,
                'La factura debe tener al menos una linea de detalle.',
                1;
            END

        SELECT
            @tipo_documento_id = TIPO_DOCUMENTO_ID,
            @codigo_tipo = CODIGO
        FROM DBO.TIPODOCUMENTO
        WHERE CODIGO = @codigo_tipo_documento;

        IF @tipo_documento_id IS NULL
            BEGIN
                THROW 50202, 'El tipo de documento indicado no existe.', 1;
            END

        SELECT @moneda_id = MONEDA_ID
        FROM DBO.MONEDA
        WHERE CODIGO = @codigo_moneda;

        IF @moneda_id IS NULL
            BEGIN
                THROW 50203, 'La moneda indicada no existe.', 1;
            END

        SELECT @estado_factura_id = ESTADO_FACTURA_ID
        FROM DBO.ESTADOFACTURA
        WHERE
            CODIGO = @codigo_estado
            AND CODIGO IN ('BORRADOR', 'EMITIDA');

        IF @estado_factura_id IS NULL
            BEGIN
                THROW 50204,
                'Una factura nueva solo puede registrarse como BORRADOR o EMITIDA.', -- noqa: LT05
                1;
            END

        IF @tipo_cambio <= 0
            BEGIN
                THROW 50205, 'El tipo de cambio debe ser mayor que cero.', 1;
            END

        IF @codigo_moneda = 'CRC' AND @tipo_cambio <> 1
            BEGIN
                THROW 50206, 'El tipo de cambio del colon debe ser 1.', 1;
            END

        IF
            NOT EXISTS (
                SELECT 1
                FROM DBO.EMPRESAEMISORA
                WHERE EMPRESA_ID = @empresa_id AND ACTIVA = 1
            )
            BEGIN
                THROW 50207,
                'La empresa emisora no existe o no esta activa.',
                1;
            END

        IF
            NOT EXISTS (
                SELECT 1 FROM DBO.CLIENTE
                WHERE CLIENTE_ID = @cliente_id
            )
            BEGIN
                THROW 50208, 'El cliente comprador no existe.', 1;
            END

        IF
            EXISTS (
                SELECT 1 FROM @detalles
                WHERE CANTIDAD <= 0 OR MONTO_DESCUENTO < 0
            )
            BEGIN
                THROW 50209,
                'Las cantidades deben ser mayores que cero y los descuentos no pueden ser negativos.', -- noqa: LT05
                1;
            END

        IF
            EXISTS (
                SELECT 1
                FROM @detalles AS D
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM DBO.ITEM_FACTURABLE AS I
                    WHERE
                        I.ITEM_FACTURABLE_ID = D.ITEM_FACTURABLE_ID
                        AND I.ACTIVO = 1
                )
            )
            BEGIN
                THROW 50210,
                'Alguna linea hace referencia a un item inexistente o inactivo.', -- noqa: LT05
                1;
            END

        SELECT
            CAST(ROW_NUMBER() OVER (
                ORDER BY D.ITEM_FACTURABLE_ID, D.CANTIDAD, D.MONTO_DESCUENTO
            ) AS INT) AS NUMERO_LINEA,
            D.ITEM_FACTURABLE_ID,
            I.DESCRIPCION,
            D.CANTIDAD,
            CAST(ROUND(I.PRECIO_UNITARIO / @tipo_cambio, 2) AS DECIMAL(18, 2))
                AS PRECIO_UNITARIO,
            I.PORCENTAJE_IMPUESTO,
            CAST(
                ROUND(
                    D.CANTIDAD * ROUND(I.PRECIO_UNITARIO / @tipo_cambio, 2), 2
                ) AS DECIMAL(18, 2)
            ) AS MONTO_SUBTOTAL,
            D.MONTO_DESCUENTO,
            CAST(0 AS DECIMAL(18, 2)) AS MONTO_IMPUESTO,
            CAST(0 AS DECIMAL(18, 2)) AS MONTO_TOTAL
        INTO #lineas
        FROM @detalles AS D
        INNER JOIN DBO.ITEM_FACTURABLE AS I
            ON D.ITEM_FACTURABLE_ID = I.ITEM_FACTURABLE_ID;

        IF
            EXISTS (
                SELECT 1 FROM #lineas
                WHERE MONTO_DESCUENTO > MONTO_SUBTOTAL
            )
            BEGIN
                THROW 50211,
                'El descuento de una linea no puede superar su subtotal.',
                1;
            END

        UPDATE #lineas
        SET MONTO_IMPUESTO = CAST(
            ROUND(
                (MONTO_SUBTOTAL - MONTO_DESCUENTO)
                * PORCENTAJE_IMPUESTO
                / 100.0,
                2
            )
            AS DECIMAL(18, 2)
        );

        UPDATE #lineas
        SET MONTO_TOTAL = MONTO_SUBTOTAL - MONTO_DESCUENTO + MONTO_IMPUESTO;

        IF
            EXISTS (
                SELECT 1
                FROM #lineas AS L
                INNER JOIN DBO.PRODUCTO_CON_EXISTENCIA AS P
                    ON L.ITEM_FACTURABLE_ID = P.PRODUCTO_CON_EXISTENCIA_ID
                WHERE L.CANTIDAD <> ROUND(L.CANTIDAD, 0)
            )
            BEGIN
                THROW 50212,
                'Los productos con existencia deben facturarse en unidades enteras.', -- noqa: LT05
                1;
            END

        SET @item_actual = 0;

        WHILE 1 = 1
            BEGIN
                SELECT TOP (1)
                    @item_actual = S.ITEM_FACTURABLE_ID,
                    @unidades = S.UNIDADES
                FROM (
                    SELECT
                        L.ITEM_FACTURABLE_ID,
                        SUM(L.CANTIDAD) AS UNIDADES
                    FROM #lineas AS L
                    INNER JOIN DBO.PRODUCTO_CON_EXISTENCIA AS P
                        ON L.ITEM_FACTURABLE_ID = P.PRODUCTO_CON_EXISTENCIA_ID
                    GROUP BY L.ITEM_FACTURABLE_ID
                ) AS S
                WHERE S.ITEM_FACTURABLE_ID > @item_actual
                ORDER BY S.ITEM_FACTURABLE_ID;

                IF @@ROWCOUNT = 0
                    BEGIN
                        BREAK;
                    END

                UPDATE DBO.PRODUCTO_CON_EXISTENCIA
                SET STOCK_ACTUAL = STOCK_ACTUAL - CAST(@unidades AS INT)
                WHERE
                    PRODUCTO_CON_EXISTENCIA_ID = @item_actual
                    AND STOCK_ACTUAL >= @unidades;

                IF @@ROWCOUNT = 0
                    BEGIN
                        THROW 50213,
                        'Existencias insuficientes para completar la factura.',
                        1;
                    END
            END

        SET @fecha = CAST(SYSDATETIME() AS DATETIME2(0));
        SET @numero = DBO.FN_GENERAR_CLAVE_COMPROBANTE(@fecha, @codigo_tipo);

        WHILE EXISTS (
            SELECT 1 FROM DBO.FACTURA WITH (UPDLOCK, HOLDLOCK)
            WHERE NUMERO_FACTURA = @numero
        )
            BEGIN
                SET @fecha = DATEADD(SECOND, 1, @fecha);
                SET
                    @numero = DBO.FN_GENERAR_CLAVE_COMPROBANTE(
                        @fecha, @codigo_tipo
                    );
            END

        SELECT
            @subtotal = SUM(MONTO_SUBTOTAL),
            @descuento = SUM(MONTO_DESCUENTO),
            @impuesto = SUM(MONTO_IMPUESTO),
            @total = SUM(MONTO_TOTAL)
        FROM #lineas;

        INSERT INTO DBO.FACTURA (
            EMPRESA_ID, CLIENTE_ID, TIPO_DOCUMENTO_ID, MONEDA_ID,
            ESTADO_FACTURA_ID, NUMERO_FACTURA, FECHA_EMISION, TIPO_CAMBIO,
            MONTO_SUBTOTAL, MONTO_DESCUENTO, MONTO_IMPUESTO, MONTO_TOTAL,
            OBSERVACIONES, FECHA_CREACION, FECHA_MODIFICACION
        )
        VALUES (
            @empresa_id, @cliente_id, @tipo_documento_id, @moneda_id,
            @estado_factura_id, @numero, @fecha, @tipo_cambio,
            @subtotal, @descuento, @impuesto, @total,
            @observaciones, SYSDATETIME(), SYSDATETIME()
        );

        SET @id_nuevo = CAST(SCOPE_IDENTITY() AS BIGINT);

        INSERT INTO DBO.FACTURA_DETALLE (
            FACTURA_ID, ITEM_FACTURABLE_ID, NUMERO_LINEA, DESCRIPCION,
            CANTIDAD, PRECIO_UNITARIO, PORCENTAJE_IMPUESTO,
            MONTO_SUBTOTAL, MONTO_DESCUENTO, MONTO_IMPUESTO, MONTO_TOTAL
        )
        SELECT
            @id_nuevo AS FACTURA_ID,
            ITEM_FACTURABLE_ID,
            NUMERO_LINEA,
            DESCRIPCION,
            CANTIDAD,
            PRECIO_UNITARIO,
            PORCENTAJE_IMPUESTO,
            MONTO_SUBTOTAL,
            MONTO_DESCUENTO,
            MONTO_IMPUESTO,
            MONTO_TOTAL
        FROM #lineas
        ORDER BY NUMERO_LINEA;

        COMMIT TRANSACTION;

        SET @factura_id = @id_nuevo;
        SET @numero_factura = @numero;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END

        SET @factura_id = 0;
        SET @numero_factura = '';
        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = LEFT(ERROR_MESSAGE(), 250);
    END CATCH
END;
GO
