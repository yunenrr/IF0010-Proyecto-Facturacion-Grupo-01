USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_generar_facturas;
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
--     numero de segundos de 365 dias) y, ademas, se descartan las que ya existan.
--   * Estados (40 % EMITIDA, 40 % PAGADA, 10 % CANCELADA, 10 % BORRADOR),
--     monedas (80 % CRC, 20 % USD) y tipos de documento (2/3 FAC, 1/3 TIQ).
--   * Precio de linea = precio de lista (colones) / tipo_cambio.
--   * Linea: subtotal = cantidad * precio; total = subtotal - descuento +
--     impuesto, con impuesto = (subtotal - descuento) * % impuesto / 100.
--   * Los totales del encabezado son la suma exacta de sus lineas.
--   * Se descuenta stock de las facturas no canceladas (productos activos con stock suficiente: >= 50 000 o servicios).
-- Los indices secundarios se crean DESPUES de la carga (scripts/04_indices).
CREATE PROCEDURE dbo.usp_generar_facturas
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

    DECLARE @ahora DATETIME2 (0) = CAST(SYSDATETIME() AS DATETIME2 (0));
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
            THROW 50032, 'El tamano de lote debe estar entre 1 y 100000.', 1;
        END

        SELECT @id_fac = tipo_documento_id FROM dbo.tipodocumento WHERE codigo = 'FAC';
        SELECT @id_tiq = tipo_documento_id FROM dbo.tipodocumento WHERE codigo = 'TIQ';
        SELECT @id_crc = moneda_id FROM dbo.moneda WHERE codigo = 'CRC';
        SELECT @id_usd = moneda_id FROM dbo.moneda WHERE codigo = 'USD';
        SELECT @id_borrador = estado_factura_id FROM dbo.estadofactura WHERE codigo = 'BORRADOR';
        SELECT @id_emitida = estado_factura_id FROM dbo.estadofactura WHERE codigo = 'EMITIDA';
        SELECT @id_pagada = estado_factura_id FROM dbo.estadofactura WHERE codigo = 'PAGADA';
        SELECT @id_cancelada = estado_factura_id FROM dbo.estadofactura WHERE codigo = 'CANCELADA';

        IF @id_fac IS NULL OR @id_tiq IS NULL OR @id_crc IS NULL OR @id_usd IS NULL
            OR @id_borrador IS NULL OR @id_emitida IS NULL
            OR @id_pagada IS NULL OR @id_cancelada IS NULL
        BEGIN
            THROW 50033, 'Catalogos incompletos. Ejecute usp_cargar_catalogos primero.', 1;
        END

        -- Datos de referencia numerados para repartirlos entre las facturas
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY empresa_id) AS INT) AS rn,
            empresa_id
        INTO #empresas
        FROM dbo.empresaemisora
        WHERE activa = 1;

        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY cliente_id) AS INT) AS rn,
            cliente_id
        INTO #clientes
        FROM dbo.cliente;

        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY it.item_facturable_id) AS INT) AS rn,
            it.item_facturable_id,
            it.descripcion,
            it.precio_unitario,
            it.porcentaje_impuesto
        INTO #items
        FROM dbo.item_facturable AS it
        WHERE it.activo = 1
            AND (
                NOT EXISTS (
                    SELECT 1
                    FROM dbo.producto_con_existencia AS pe
                    WHERE pe.producto_con_existencia_id = it.item_facturable_id
                )
                OR EXISTS (
                    SELECT 1
                    FROM dbo.producto_con_existencia AS pe
                    WHERE pe.producto_con_existencia_id = it.item_facturable_id
                        AND pe.stock_actual >= 50000
                )
            );

        SET @n_empresas = (SELECT COUNT(*) FROM #empresas);
        SET @n_clientes = (SELECT COUNT(*) FROM #clientes);
        SET @n_items = (SELECT COUNT(*) FROM #items);

        IF @n_empresas = 0 OR @n_clientes = 0 OR @n_items < 5
        BEGIN
            THROW 50034, 'Faltan empresas activas, clientes o al menos 5 productos activos. Ejecute las cargas previas.', 1;
        END

        COMMIT TRANSACTION;

        SET @existentes = (SELECT COUNT_BIG(*) FROM dbo.factura);
        SET @base = ISNULL((SELECT MAX(factura_id) FROM dbo.factura), 0);

        WHILE @existentes < @cantidad_objetivo
        BEGIN
            IF @cantidad_objetivo - @existentes < @tamano_lote
            BEGIN
                SET @lote_actual = CAST(@cantidad_objetivo - @existentes AS INT);
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
                s.seq,
                DATEADD(SECOND, -CAST(s.seq * 7919 % 31536000 AS INT) - 1, @ahora) AS fecha_emision,
                CASE WHEN s.seq % 3 = 0 THEN @id_tiq ELSE @id_fac END AS tipo_documento_id,
                CASE WHEN s.seq % 3 = 0 THEN 'TIQ' ELSE 'FAC' END AS codigo_tipo,
                CASE WHEN s.seq % 5 = 0 THEN @id_usd ELSE @id_crc END AS moneda_id,
                CASE
                    WHEN s.seq % 5 = 0
                        THEN CAST(500 + (s.seq % 4001) / 100.0 AS DECIMAL(18, 4))
                    ELSE CAST(1 AS DECIMAL(18, 4))
                END AS tipo_cambio,
                CASE
                    WHEN s.seq / 5 % 20 < 8 THEN @id_emitida
                    WHEN s.seq / 5 % 20 < 16 THEN @id_pagada
                    WHEN s.seq / 5 % 20 < 18 THEN @id_cancelada
                    ELSE @id_borrador
                END AS estado_factura_id,
                e.empresa_id,
                cl.cliente_id,
                CAST('' AS VARCHAR(50)) AS numero_factura
            INTO #cab
            FROM (
                SELECT TOP (@lote_actual)
                    @base + @desplazamiento + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS seq
                FROM sys.all_objects AS a
                CROSS JOIN sys.all_objects AS b
                WHERE a.object_id IS NOT NULL
                    AND b.object_id IS NOT NULL
            ) AS s
            INNER JOIN #empresas AS e
                ON e.rn = (s.seq * 31) % @n_empresas + 1
            INNER JOIN #clientes AS cl
                ON cl.rn = (s.seq * 104729) % @n_clientes + 1;

            UPDATE #cab
            SET numero_factura =
                CONVERT(CHAR(8), fecha_emision, 112)
                + REPLACE(CONVERT(CHAR(8), fecha_emision, 108), ':', '')
                + '-' + codigo_tipo;

            -- Descarta las facturas cuyo identificador ya exista
            DELETE c
            FROM #cab AS c
            WHERE EXISTS (
                SELECT 1 FROM dbo.factura AS f WHERE f.numero_factura = c.numero_factura
            );

            CREATE UNIQUE CLUSTERED INDEX ix_tmp_cab ON #cab (seq);

            -- Lineas de detalle (3 a 5 por factura)
            SELECT
                c.seq,
                l.linea AS numero_linea,
                i.item_facturable_id,
                i.descripcion,
                CAST(1 + (c.seq * l.linea) % 10 AS DECIMAL(18, 2)) AS cantidad,
                CAST(ROUND(i.precio_unitario / c.tipo_cambio, 2) AS DECIMAL(18, 2)) AS precio_unitario,
                i.porcentaje_impuesto,
                CAST(0 AS DECIMAL(18, 2)) AS monto_subtotal,
                CAST(0 AS DECIMAL(18, 2)) AS monto_descuento,
                CAST(0 AS DECIMAL(18, 2)) AS monto_impuesto,
                CAST(0 AS DECIMAL(18, 2)) AS monto_total
            INTO #lin
            FROM #cab AS c
            INNER JOIN (VALUES (1), (2), (3), (4), (5)) AS l (linea)
                ON l.linea <= 3 + c.seq % 3
            INNER JOIN #items AS i
                ON i.rn = (c.seq * 13 + l.linea * 37) % @n_items + 1;

            UPDATE #lin
            SET monto_subtotal = CAST(ROUND(cantidad * precio_unitario, 2) AS DECIMAL(18, 2));

            UPDATE #lin
            SET monto_descuento = CASE
                WHEN (seq + numero_linea) % 5 = 0
                    THEN CAST(ROUND(monto_subtotal * 0.10, 2) AS DECIMAL(18, 2))
                ELSE CAST(0 AS DECIMAL(18, 2))
            END;

            UPDATE #lin
            SET monto_impuesto = CAST(
                ROUND((monto_subtotal - monto_descuento) * porcentaje_impuesto / 100.0, 2)
                AS DECIMAL(18, 2)
            );

            UPDATE #lin
            SET monto_total = monto_subtotal - monto_descuento + monto_impuesto;

            CREATE UNIQUE CLUSTERED INDEX ix_tmp_lin ON #lin (seq, numero_linea);

            -- Encabezados: los totales son la suma de sus lineas
            INSERT INTO dbo.factura (
                empresa_id, cliente_id, tipo_documento_id, moneda_id,
                estado_factura_id, numero_factura, fecha_emision, tipo_cambio,
                monto_subtotal, monto_descuento, monto_impuesto, monto_total,
                observaciones, fecha_creacion, fecha_modificacion
            )
            SELECT
                c.empresa_id, c.cliente_id, c.tipo_documento_id, c.moneda_id,
                c.estado_factura_id, c.numero_factura, c.fecha_emision, c.tipo_cambio,
                t.subtotal, t.descuento, t.impuesto, t.total,
                'Carga masiva consecutivo ' + CAST(c.seq AS VARCHAR(20)),
                c.fecha_emision, c.fecha_emision
            FROM #cab AS c
            INNER JOIN (
                SELECT
                    seq,
                    SUM(monto_subtotal) AS subtotal,
                    SUM(monto_descuento) AS descuento,
                    SUM(monto_impuesto) AS impuesto,
                    SUM(monto_total) AS total
                FROM #lin
                GROUP BY seq
            ) AS t
                ON t.seq = c.seq
            ORDER BY c.seq;

            -- Detalles
            INSERT INTO dbo.factura_detalle (
                factura_id, item_facturable_id, numero_linea, descripcion,
                cantidad, precio_unitario, porcentaje_impuesto,
                monto_subtotal, monto_descuento, monto_impuesto, monto_total
            )
            SELECT
                f.factura_id, l.item_facturable_id, l.numero_linea, l.descripcion,
                l.cantidad, l.precio_unitario, l.porcentaje_impuesto,
                l.monto_subtotal, l.monto_descuento, l.monto_impuesto, l.monto_total
            FROM #lin AS l
            INNER JOIN #cab AS c
                ON c.seq = l.seq
            INNER JOIN dbo.factura AS f
                ON f.numero_factura = c.numero_factura
            ORDER BY f.factura_id, l.numero_linea;

            -- Existencias: las facturas no canceladas descuentan stock
            UPDATE p
            SET p.stock_actual = p.stock_actual - CAST(s.unidades AS INT)
            FROM dbo.producto_con_existencia AS p
            INNER JOIN (
                SELECT l.item_facturable_id, SUM(l.cantidad) AS unidades
                FROM #lin AS l
                INNER JOIN #cab AS c
                    ON c.seq = l.seq
                WHERE c.estado_factura_id <> @id_cancelada
                GROUP BY l.item_facturable_id
            ) AS s
                ON s.item_facturable_id = p.producto_con_existencia_id;

            IF EXISTS (SELECT 1 FROM dbo.producto_con_existencia WHERE stock_actual < 0)
            BEGIN
                THROW 50035, 'El stock de un producto quedaria negativo. Se revierte el lote.', 1;
            END

            COMMIT TRANSACTION;

            SET @desplazamiento = @desplazamiento + @lote_actual;
            SET @existentes = (SELECT COUNT_BIG(*) FROM dbo.factura);
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
