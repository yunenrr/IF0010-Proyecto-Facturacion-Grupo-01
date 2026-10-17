USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_GENERAR_FACTURAS;
GO

-- Carga masiva de facturas hasta alcanzar @cantidad_objetivo facturas en total,
-- procesadas en lotes de @tamano_lote facturas. Cada lote se ejecuta en su
-- propia transaccion: si un lote falla se revierte solo ese lote, los lotes
-- anteriores permanecen y al volver a ejecutar el procedimiento continua desde
-- donde quedo (es idempotente respecto a la cantidad objetivo).
--
-- Reglas de la carga:
--   * Cada factura tiene entre 3 y 5 lineas de detalle (3 + consecutivo % 3).
--   * numero_factura = AAAAMMDDHHMMSS-CodigoTipoDocumento, unico: cada factura
--     usa un segundo distinto dentro del ultimo ano (paso 7919, coprimo con el
--     numero de segundos de 365 dias) y, ademas, se descartan las que ya
-- existan.
--   * Estados (40 % EMITIDA, 40 % PAGADA, 10 % CANCELADA, 10 % BORRADOR),
--     monedas (80 % CRC, 20 % USD) y tipos de documento (2/3 FAC, 1/3 TIQ).
--   * Precio de linea = precio de lista (colones) / tipo_cambio.
--   * Linea: subtotal = cantidad * precio; total = subtotal - descuento +
--     impuesto, con impuesto = (subtotal - descuento) * % impuesto / 100.
--   * Los totales del encabezado son la suma exacta de sus lineas.
--   * Se descuenta stock de las facturas no canceladas (productos activos con
-- stock suficiente: >= 50 000 o servicios).
-- Los indices secundarios se crean DESPUES de la carga (scripts/04_indices).
CREATE PROCEDURE DBO.USP_GENERAR_FACTURAS
    @cantidad_objetivo INT,
    @tamano_lote INT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @ahora DATETIME2(0) = CAST(SYSDATETIME() AS DATETIME2(0));
    DECLARE @id_fac INT;
    DECLARE @id_tiq INT;
    DECLARE @id_crc INT;
    DECLARE @id_usd INT;
    DECLARE @id_borrador INT;
    DECLARE @id_emitida INT;
    DECLARE @id_pagada INT;
    DECLARE @id_cancelada INT;
    DECLARE @n_empresas INT;
    DECLARE @n_clientes INT;
    DECLARE @n_items INT;
    DECLARE @existentes BIGINT;
    DECLARE @base BIGINT;
    DECLARE @desplazamiento BIGINT = 0;
    DECLARE @lote_actual INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @cantidad_objetivo IS NULL OR @cantidad_objetivo <= 0
            BEGIN
                THROW 50031, 'La cantidad objetivo debe ser mayor que cero.', 1;
            END

        IF @tamano_lote IS NULL OR @tamano_lote < 1 OR @tamano_lote > 100000
            BEGIN
                THROW 50032,
                'El tamano de lote debe estar entre 1 y 100000.',
                1;
            END

        SELECT @id_fac = TIPO_DOCUMENTO_ID
        FROM DBO.TIPODOCUMENTO
        WHERE CODIGO = 'FAC';
        SELECT @id_tiq = TIPO_DOCUMENTO_ID
        FROM DBO.TIPODOCUMENTO
        WHERE CODIGO = 'TIQ';
        SELECT @id_crc = MONEDA_ID FROM DBO.MONEDA
        WHERE CODIGO = 'CRC';
        SELECT @id_usd = MONEDA_ID FROM DBO.MONEDA
        WHERE CODIGO = 'USD';
        SELECT @id_borrador = ESTADO_FACTURA_ID
        FROM DBO.ESTADOFACTURA
        WHERE CODIGO = 'BORRADOR';
        SELECT @id_emitida = ESTADO_FACTURA_ID
        FROM DBO.ESTADOFACTURA
        WHERE CODIGO = 'EMITIDA';
        SELECT @id_pagada = ESTADO_FACTURA_ID
        FROM DBO.ESTADOFACTURA
        WHERE CODIGO = 'PAGADA';
        SELECT @id_cancelada = ESTADO_FACTURA_ID
        FROM DBO.ESTADOFACTURA
        WHERE CODIGO = 'CANCELADA';

        IF
            @id_fac IS NULL
            OR @id_tiq IS NULL
            OR @id_crc IS NULL
            OR @id_usd IS NULL
            OR @id_borrador IS NULL OR @id_emitida IS NULL
            OR @id_pagada IS NULL OR @id_cancelada IS NULL
            BEGIN
                THROW 50033,
                'Catalogos incompletos. Ejecute usp_cargar_catalogos primero.',
                1;
            END

        -- Datos de referencia numerados para repartirlos entre las facturas
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY EMPRESA_ID) AS INT) AS RN,
            EMPRESA_ID
        INTO #empresas
        FROM DBO.EMPRESAEMISORA
        WHERE ACTIVA = 1;

        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY CLIENTE_ID) AS INT) AS RN,
            CLIENTE_ID
        INTO #clientes
        FROM DBO.CLIENTE;

        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY IT.ITEM_FACTURABLE_ID) AS INT)
                AS RN,
            IT.ITEM_FACTURABLE_ID,
            IT.DESCRIPCION,
            IT.PRECIO_UNITARIO,
            IT.PORCENTAJE_IMPUESTO
        INTO #items
        FROM DBO.ITEM_FACTURABLE AS IT
        WHERE
            IT.ACTIVO = 1
            AND (
                NOT EXISTS (
                    SELECT 1
                    FROM DBO.PRODUCTO_CON_EXISTENCIA AS PE
                    WHERE PE.PRODUCTO_CON_EXISTENCIA_ID = IT.ITEM_FACTURABLE_ID
                )
                OR EXISTS (
                    SELECT 1
                    FROM DBO.PRODUCTO_CON_EXISTENCIA AS PE
                    WHERE
                        PE.PRODUCTO_CON_EXISTENCIA_ID = IT.ITEM_FACTURABLE_ID
                        AND PE.STOCK_ACTUAL >= 50000
                )
            );

        SET @n_empresas = (SELECT COUNT(*) FROM #empresas);
        SET @n_clientes = (SELECT COUNT(*) FROM #clientes);
        SET @n_items = (SELECT COUNT(*) FROM #items);

        IF @n_empresas = 0 OR @n_clientes = 0 OR @n_items < 5
            BEGIN
                THROW 50034,
                'Faltan empresas activas, clientes o al menos 5 productos activos. Ejecute las cargas previas.', -- noqa: LT05
                1;
            END

        COMMIT TRANSACTION;

        SET @existentes = (SELECT COUNT_BIG(*) FROM DBO.FACTURA);
        SET @base = ISNULL((SELECT MAX(FACTURA_ID) FROM DBO.FACTURA), 0);

        WHILE @existentes < @cantidad_objetivo
            BEGIN
                IF @cantidad_objetivo - @existentes < @tamano_lote
                    BEGIN
                        SET
                            @lote_actual
                            = CAST(@cantidad_objetivo - @existentes AS INT);
                    END
                ELSE
                    BEGIN
                        SET @lote_actual = @tamano_lote;
                    END

                BEGIN TRANSACTION;

                DROP TABLE IF EXISTS #cab;
                DROP TABLE IF EXISTS #lin;

                -- Encabezados del lote
                SELECT
                    S.SEQ,
                    E.EMPRESA_ID,
                    CL.CLIENTE_ID,
                    CAST('' AS VARCHAR(50)) AS NUMERO_FACTURA,
                    DATEADD(
                        SECOND,
                        -CAST(S.SEQ * 7919 % 31536000 AS INT) - 1,
                        @ahora
                    ) AS FECHA_EMISION,
                    CASE WHEN S.SEQ % 3 = 0 THEN @id_tiq ELSE @id_fac END
                        AS TIPO_DOCUMENTO_ID,
                    CASE WHEN S.SEQ % 3 = 0 THEN 'TIQ' ELSE 'FAC' END
                        AS CODIGO_TIPO,
                    CASE WHEN S.SEQ % 5 = 0 THEN @id_usd ELSE @id_crc END
                        AS MONEDA_ID,
                    CASE
                        WHEN S.SEQ % 5 = 0
                            THEN
                                CAST(
                                    500
                                    + (S.SEQ % 4001) / 100.0 AS DECIMAL(18, 4)
                                )
                        ELSE CAST(1 AS DECIMAL(18, 4))
                    END AS TIPO_CAMBIO,
                    CASE
                        WHEN S.SEQ / 5 % 20 < 8 THEN @id_emitida
                        WHEN S.SEQ / 5 % 20 < 16 THEN @id_pagada
                        WHEN S.SEQ / 5 % 20 < 18 THEN @id_cancelada
                        ELSE @id_borrador
                    END AS ESTADO_FACTURA_ID
                INTO #cab
                FROM (
                    SELECT TOP (@lote_actual)
                        @base
                        + @desplazamiento
                        + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS SEQ
                    FROM SYS.ALL_OBJECTS AS A
                    CROSS JOIN SYS.ALL_OBJECTS AS B
                    WHERE
                        A.OBJECT_ID IS NOT NULL
                        AND B.OBJECT_ID IS NOT NULL
                ) AS S
                INNER JOIN #empresas AS E
                    ON E.RN = (S.SEQ * 31) % @n_empresas + 1
                INNER JOIN #clientes AS CL
                    ON CL.RN = (S.SEQ * 104729) % @n_clientes + 1;

                UPDATE #cab
                SET
                    NUMERO_FACTURA
                    = CONVERT(CHAR(8), FECHA_EMISION, 112)
                    + REPLACE(CONVERT(CHAR(8), FECHA_EMISION, 108), ':', '')
                    + '-' + CODIGO_TIPO;

                -- Descarta las facturas cuyo identificador ya exista
                DELETE C
                FROM #cab AS C
                WHERE EXISTS (
                    SELECT 1
                    FROM DBO.FACTURA AS F
                    WHERE F.NUMERO_FACTURA = C.NUMERO_FACTURA
                );

                CREATE UNIQUE CLUSTERED INDEX IX_TMP_CAB ON #cab (SEQ);

                -- Lineas de detalle (3 a 5 por factura)
                SELECT
                    C.SEQ,
                    L.LINEA AS NUMERO_LINEA,
                    I.ITEM_FACTURABLE_ID,
                    I.DESCRIPCION,
                    CAST(1 + (C.SEQ * L.LINEA) % 10 AS DECIMAL(18, 2))
                        AS CANTIDAD,
                    CAST(
                        ROUND(I.PRECIO_UNITARIO / C.TIPO_CAMBIO, 2) AS DECIMAL(
                            18, 2
                        )
                    ) AS PRECIO_UNITARIO,
                    I.PORCENTAJE_IMPUESTO,
                    CAST(0 AS DECIMAL(18, 2)) AS MONTO_SUBTOTAL,
                    CAST(0 AS DECIMAL(18, 2)) AS MONTO_DESCUENTO,
                    CAST(0 AS DECIMAL(18, 2)) AS MONTO_IMPUESTO,
                    CAST(0 AS DECIMAL(18, 2)) AS MONTO_TOTAL
                INTO #lin
                FROM #cab AS C
                INNER JOIN (VALUES (1), (2), (3), (4), (5)) AS L(LINEA)
                    ON L.LINEA <= 3 + C.SEQ % 3
                INNER JOIN #items AS I
                    ON I.RN = (C.SEQ * 13 + L.LINEA * 37) % @n_items + 1;

                UPDATE #lin
                SET
                    MONTO_SUBTOTAL
                    = CAST(
                        ROUND(CANTIDAD * PRECIO_UNITARIO, 2)
                        AS DECIMAL(18, 2)
                    );

                UPDATE #lin
                SET MONTO_DESCUENTO = CASE
                    WHEN (SEQ + NUMERO_LINEA) % 5 = 0
                        THEN
                            CAST(
                                ROUND(MONTO_SUBTOTAL * 0.10, 2) AS DECIMAL(
                                    18, 2
                                )
                            )
                    ELSE CAST(0 AS DECIMAL(18, 2))
                END;

                UPDATE #lin
                SET MONTO_IMPUESTO = CAST(
                    ROUND(
                        (MONTO_SUBTOTAL - MONTO_DESCUENTO)
                        * PORCENTAJE_IMPUESTO
                        / 100.0,
                        2
                    )
                    AS DECIMAL(18, 2)
                );

                UPDATE #lin
                SET
                    MONTO_TOTAL
                    = MONTO_SUBTOTAL - MONTO_DESCUENTO + MONTO_IMPUESTO;

                CREATE UNIQUE CLUSTERED INDEX IX_TMP_LIN
                    ON #lin (SEQ, NUMERO_LINEA);

                -- Encabezados: los totales son la suma de sus lineas
                WITH T AS (
                    SELECT
                        SEQ,
                        SUM(MONTO_SUBTOTAL) AS SUBTOTAL,
                        SUM(MONTO_DESCUENTO) AS DESCUENTO,
                        SUM(MONTO_IMPUESTO) AS IMPUESTO,
                        SUM(MONTO_TOTAL) AS TOTAL
                    FROM #lin
                    GROUP BY SEQ
                )

                INSERT INTO DBO.FACTURA (
                    EMPRESA_ID, CLIENTE_ID, TIPO_DOCUMENTO_ID, MONEDA_ID,
                    ESTADO_FACTURA_ID,
                    NUMERO_FACTURA,
                    FECHA_EMISION,
                    TIPO_CAMBIO,
                    MONTO_SUBTOTAL,
                    MONTO_DESCUENTO,
                    MONTO_IMPUESTO,
                    MONTO_TOTAL,
                    OBSERVACIONES, FECHA_CREACION, FECHA_MODIFICACION
                )
                SELECT
                    C.EMPRESA_ID,
                    C.CLIENTE_ID,
                    C.TIPO_DOCUMENTO_ID,
                    C.MONEDA_ID,
                    C.ESTADO_FACTURA_ID,
                    C.NUMERO_FACTURA,
                    C.FECHA_EMISION,
                    C.TIPO_CAMBIO,
                    T.SUBTOTAL,
                    T.DESCUENTO,
                    T.IMPUESTO,
                    T.TOTAL,
                    'Carga masiva consecutivo '
                    + CAST(C.SEQ AS VARCHAR(20)) AS OBSERVACIONES,
                    C.FECHA_EMISION AS FECHA_CREACION,
                    C.FECHA_EMISION AS FECHA_MODIFICACION
                FROM #cab AS C
                INNER JOIN T
                    ON C.SEQ = T.SEQ
                ORDER BY C.SEQ;

                -- Detalles
                INSERT INTO DBO.FACTURA_DETALLE (
                    FACTURA_ID, ITEM_FACTURABLE_ID, NUMERO_LINEA, DESCRIPCION,
                    CANTIDAD, PRECIO_UNITARIO, PORCENTAJE_IMPUESTO,
                    MONTO_SUBTOTAL, MONTO_DESCUENTO, MONTO_IMPUESTO, MONTO_TOTAL
                )
                SELECT
                    F.FACTURA_ID,
                    L.ITEM_FACTURABLE_ID,
                    L.NUMERO_LINEA,
                    L.DESCRIPCION,
                    L.CANTIDAD,
                    L.PRECIO_UNITARIO,
                    L.PORCENTAJE_IMPUESTO,
                    L.MONTO_SUBTOTAL,
                    L.MONTO_DESCUENTO,
                    L.MONTO_IMPUESTO,
                    L.MONTO_TOTAL
                FROM #lin AS L
                INNER JOIN #cab AS C
                    ON L.SEQ = C.SEQ
                INNER JOIN DBO.FACTURA AS F
                    ON C.NUMERO_FACTURA = F.NUMERO_FACTURA
                ORDER BY F.FACTURA_ID, L.NUMERO_LINEA;

                -- Existencias: las facturas no canceladas descuentan stock
                UPDATE P
                SET P.STOCK_ACTUAL = P.STOCK_ACTUAL - CAST(S.UNIDADES AS INT)
                FROM DBO.PRODUCTO_CON_EXISTENCIA AS P
                INNER JOIN (
                    SELECT
                        L.ITEM_FACTURABLE_ID,
                        SUM(L.CANTIDAD) AS UNIDADES
                    FROM #lin AS L
                    INNER JOIN #cab AS C
                        ON L.SEQ = C.SEQ
                    WHERE C.ESTADO_FACTURA_ID <> @id_cancelada
                    GROUP BY L.ITEM_FACTURABLE_ID
                ) AS S
                    ON P.PRODUCTO_CON_EXISTENCIA_ID = S.ITEM_FACTURABLE_ID;

                IF
                    EXISTS (
                        SELECT 1 FROM DBO.PRODUCTO_CON_EXISTENCIA
                        WHERE STOCK_ACTUAL < 0
                    )
                    BEGIN
                        THROW 50035,
                        'El stock de un producto quedaria negativo. Se revierte el lote.', -- noqa: LT05
                        1;
                    END

                COMMIT TRANSACTION;

                SET @desplazamiento = @desplazamiento + @lote_actual;
                SET @existentes = (SELECT COUNT_BIG(*) FROM DBO.FACTURA);
            END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = LEFT(ERROR_MESSAGE(), 250);
    END CATCH
END;
GO
