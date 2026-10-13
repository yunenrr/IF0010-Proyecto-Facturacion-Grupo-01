USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_registrar_factura;
GO

-- Registra una factura completa: encabezado + N lineas de detalle en una unica
-- transaccion. Garantiza que no existan encabezados sin detalle (se exige al
-- menos una linea) ni detalles sin encabezado.
--
-- @detalles (dbo.tipo_detalle_factura) trae por linea: item_facturable_id,
-- cantidad y monto_descuento (en la moneda de la factura). El precio unitario,
-- el porcentaje de impuesto y la descripcion se toman del catalogo.
--
-- Calculo financiero por linea:
--   precio_unitario = precio de lista (colones) / tipo_cambio
--   subtotal        = cantidad * precio_unitario
--   impuesto        = (subtotal - descuento) * porcentaje_impuesto / 100
--   total           = subtotal - descuento + impuesto
-- El encabezado acumula la suma de sus lineas. El identificador de comprobante
-- es AAAAMMDDHHMMSS-CodigoTipoDocumento; si ya existe uno igual se avanza la
-- fecha de emision un segundo hasta obtener uno libre.
-- Los productos con existencia descuentan stock; si no alcanza, la factura
-- completa se rechaza. Los montos negativos se rechazan.
CREATE PROCEDURE dbo.usp_registrar_factura
    @empresa_id INT,
    @cliente_id INT,
    @codigo_tipo_documento VARCHAR(10),
    @codigo_moneda CHAR(3),
    @tipo_cambio DECIMAL(18, 4) = 1,
    @codigo_estado VARCHAR(20) = 'EMITIDA',
    @observaciones VARCHAR(500) = '',
    @detalles dbo.tipo_detalle_factura READONLY,
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
    DECLARE @fecha DATETIME2 (0);
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
            THROW 50201, 'La factura debe tener al menos una linea de detalle.', 1;
        END

        SELECT
            @tipo_documento_id = tipo_documento_id,
            @codigo_tipo = codigo
        FROM dbo.tipodocumento
        WHERE codigo = @codigo_tipo_documento;

        IF @tipo_documento_id IS NULL
        BEGIN
            THROW 50202, 'El tipo de documento indicado no existe.', 1;
        END

        SELECT @moneda_id = moneda_id
        FROM dbo.moneda
        WHERE codigo = @codigo_moneda;

        IF @moneda_id IS NULL
        BEGIN
            THROW 50203, 'La moneda indicada no existe.', 1;
        END

        SELECT @estado_factura_id = estado_factura_id
        FROM dbo.estadofactura
        WHERE codigo = @codigo_estado
            AND codigo IN ('BORRADOR', 'EMITIDA');

        IF @estado_factura_id IS NULL
        BEGIN
            THROW 50204, 'Una factura nueva solo puede registrarse como BORRADOR o EMITIDA.', 1;
        END

        IF @tipo_cambio <= 0
        BEGIN
            THROW 50205, 'El tipo de cambio debe ser mayor que cero.', 1;
        END

        IF @codigo_moneda = 'CRC' AND @tipo_cambio <> 1
        BEGIN
            THROW 50206, 'El tipo de cambio del colon debe ser 1.', 1;
        END

        IF NOT EXISTS (
            SELECT 1 FROM dbo.empresaemisora WHERE empresa_id = @empresa_id AND activa = 1
        )
        BEGIN
            THROW 50207, 'La empresa emisora no existe o no esta activa.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE cliente_id = @cliente_id)
        BEGIN
            THROW 50208, 'El cliente comprador no existe.', 1;
        END

        IF EXISTS (SELECT 1 FROM @detalles WHERE cantidad <= 0 OR monto_descuento < 0)
        BEGIN
            THROW 50209, 'Las cantidades deben ser mayores que cero y los descuentos no pueden ser negativos.', 1;
        END

        IF EXISTS (
            SELECT 1
            FROM @detalles AS d
            WHERE NOT EXISTS (
                SELECT 1
                FROM dbo.item_facturable AS i
                WHERE i.item_facturable_id = d.item_facturable_id
                    AND i.activo = 1
            )
        )
        BEGIN
            THROW 50210, 'Alguna linea hace referencia a un item inexistente o inactivo.', 1;
        END

        -- Lineas calculadas con el precio e impuesto vigentes del catalogo
        SELECT
            CAST(ROW_NUMBER() OVER (
                ORDER BY d.item_facturable_id, d.cantidad, d.monto_descuento
            ) AS INT) AS numero_linea,
            d.item_facturable_id,
            i.descripcion,
            d.cantidad,
            CAST(ROUND(i.precio_unitario / @tipo_cambio, 2) AS DECIMAL(18, 2)) AS precio_unitario,
            i.porcentaje_impuesto,
            CAST(ROUND(d.cantidad * ROUND(i.precio_unitario / @tipo_cambio, 2), 2) AS DECIMAL(18, 2)) AS monto_subtotal,
            d.monto_descuento,
            CAST(0 AS DECIMAL(18, 2)) AS monto_impuesto,
            CAST(0 AS DECIMAL(18, 2)) AS monto_total
        INTO #lineas
        FROM @detalles AS d
        INNER JOIN dbo.item_facturable AS i
            ON i.item_facturable_id = d.item_facturable_id;

        IF EXISTS (SELECT 1 FROM #lineas WHERE monto_descuento > monto_subtotal)
        BEGIN
            THROW 50211, 'El descuento de una linea no puede superar su subtotal.', 1;
        END

        UPDATE #lineas
        SET monto_impuesto = CAST(
            ROUND((monto_subtotal - monto_descuento) * porcentaje_impuesto / 100.0, 2)
            AS DECIMAL(18, 2)
        );

        UPDATE #lineas
        SET monto_total = monto_subtotal - monto_descuento + monto_impuesto;

        -- Existencias: los productos con existencia se facturan en unidades enteras
        IF EXISTS (
            SELECT 1
            FROM #lineas AS l
            INNER JOIN dbo.producto_con_existencia AS p
                ON p.producto_con_existencia_id = l.item_facturable_id
            WHERE l.cantidad <> ROUND(l.cantidad, 0)
        )
        BEGIN
            THROW 50212, 'Los productos con existencia deben facturarse en unidades enteras.', 1;
        END

        -- Descuento de stock producto por producto en orden de id (evita
        -- interbloqueos entre facturas concurrentes). Cada UPDATE es atomico y
        -- solo descuenta si alcanza; si falla, el ROLLBACK revierte lo anterior.
        SET @item_actual = 0;

        WHILE 1 = 1
        BEGIN
            SELECT TOP (1)
                @item_actual = s.item_facturable_id,
                @unidades = s.unidades
            FROM (
                SELECT l.item_facturable_id, SUM(l.cantidad) AS unidades
                FROM #lineas AS l
                INNER JOIN dbo.producto_con_existencia AS p
                    ON p.producto_con_existencia_id = l.item_facturable_id
                GROUP BY l.item_facturable_id
            ) AS s
            WHERE s.item_facturable_id > @item_actual
            ORDER BY s.item_facturable_id;

            IF @@ROWCOUNT = 0
            BEGIN
                BREAK;
            END

            UPDATE dbo.producto_con_existencia
            SET stock_actual = stock_actual - CAST(@unidades AS INT)
            WHERE producto_con_existencia_id = @item_actual
                AND stock_actual >= @unidades;

            IF @@ROWCOUNT = 0
            BEGIN
                THROW 50213, 'Existencias insuficientes para completar la factura.', 1;
            END
        END

        -- Identificador de comprobante AAAAMMDDHHMMSS-TipoDocumento
        SET @fecha = CAST(SYSDATETIME() AS DATETIME2 (0));
        SET @numero = CONVERT(CHAR(8), @fecha, 112)
            + REPLACE(CONVERT(CHAR(8), @fecha, 108), ':', '')
            + '-' + @codigo_tipo;

        -- UPDLOCK + HOLDLOCK: bloquea el rango consultado hasta el COMMIT para que
        -- dos sesiones no tomen el mismo identificador (ademas del UNIQUE).
        WHILE EXISTS (
            SELECT 1 FROM dbo.factura WITH (UPDLOCK, HOLDLOCK)
            WHERE numero_factura = @numero
        )
        BEGIN
            SET @fecha = DATEADD(SECOND, 1, @fecha);
            SET @numero = CONVERT(CHAR(8), @fecha, 112)
                + REPLACE(CONVERT(CHAR(8), @fecha, 108), ':', '')
                + '-' + @codigo_tipo;
        END

        SELECT
            @subtotal = SUM(monto_subtotal),
            @descuento = SUM(monto_descuento),
            @impuesto = SUM(monto_impuesto),
            @total = SUM(monto_total)
        FROM #lineas;

        INSERT INTO dbo.factura (
            empresa_id, cliente_id, tipo_documento_id, moneda_id,
            estado_factura_id, numero_factura, fecha_emision, tipo_cambio,
            monto_subtotal, monto_descuento, monto_impuesto, monto_total,
            observaciones, fecha_creacion, fecha_modificacion
        )
        VALUES (
            @empresa_id, @cliente_id, @tipo_documento_id, @moneda_id,
            @estado_factura_id, @numero, @fecha, @tipo_cambio,
            @subtotal, @descuento, @impuesto, @total,
            @observaciones, SYSDATETIME(), SYSDATETIME()
        );

        SET @id_nuevo = CAST(SCOPE_IDENTITY() AS BIGINT);

        INSERT INTO dbo.factura_detalle (
            factura_id, item_facturable_id, numero_linea, descripcion,
            cantidad, precio_unitario, porcentaje_impuesto,
            monto_subtotal, monto_descuento, monto_impuesto, monto_total
        )
        SELECT
            @id_nuevo, item_facturable_id, numero_linea, descripcion,
            cantidad, precio_unitario, porcentaje_impuesto,
            monto_subtotal, monto_descuento, monto_impuesto, monto_total
        FROM #lineas
        ORDER BY numero_linea;

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
