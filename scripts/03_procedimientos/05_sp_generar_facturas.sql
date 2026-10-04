CREATE OR ALTER PROCEDURE dbo.sp_generar_facturas
    @cantidad_objetivo INT = 500000,
    @tamano_lote INT = 25000,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @existentes INT;
        DECLARE @faltantes INT;
        DECLARE @lote_actual INT;
        DECLARE @secuencia_base BIGINT;
        DECLARE @ahora DATETIME2 = SYSDATETIME();

        DECLARE @total_clientes INT;
        DECLARE @total_empresas INT;
        DECLARE @total_items INT;

        DECLARE @tipo_factura_id INT;
        DECLARE @tipo_tiquete_id INT;

        DECLARE @moneda_crc_id INT;
        DECLARE @moneda_usd_id INT;

        DECLARE @estado_borrador_id INT;
        DECLARE @estado_emitida_id INT;
        DECLARE @estado_pagada_id INT;
        DECLARE @estado_cancelada_id INT;

        -- Obtener los IDs de los catálogos necesarios.
        SELECT @tipo_factura_id = tipo_documento_id
        FROM dbo.tipodocumento
        WHERE codigo = 'FACTURA';

        SELECT @tipo_tiquete_id = tipo_documento_id
        FROM dbo.tipodocumento
        WHERE codigo = 'TIQUETE';

        SELECT @moneda_crc_id = moneda_id
        FROM dbo.moneda
        WHERE codigo = 'CRC';

        SELECT @moneda_usd_id = moneda_id
        FROM dbo.moneda
        WHERE codigo = 'USD';

        SELECT @estado_borrador_id = estado_factura_id
        FROM dbo.estadofactura
        WHERE codigo = 'BORRADOR';

        SELECT @estado_emitida_id = estado_factura_id
        FROM dbo.estadofactura
        WHERE codigo = 'EMITIDA';

        SELECT @estado_pagada_id = estado_factura_id
        FROM dbo.estadofactura
        WHERE codigo = 'PAGADA';

        SELECT @estado_cancelada_id = estado_factura_id
        FROM dbo.estadofactura
        WHERE codigo = 'CANCELADA';

        -- Validar que existan datos maestros.
        SELECT @total_clientes = COUNT(*)
        FROM dbo.cliente;

        SELECT @total_empresas = COUNT(*)
        FROM dbo.empresaemisora;

        SELECT @total_items = COUNT(*)
        FROM dbo.item_facturable;

        IF @total_clientes = 0
            OR @total_empresas = 0
            OR @total_items = 0
        BEGIN
            SET @codigo_error = 1;
            SET @mensaje_error =
                'Se requieren clientes, empresas e items facturables.';

            RETURN;
        END;

        IF @tipo_factura_id IS NULL
            OR @tipo_tiquete_id IS NULL
            OR @moneda_crc_id IS NULL
            OR @moneda_usd_id IS NULL
            OR @estado_borrador_id IS NULL
            OR @estado_emitida_id IS NULL
            OR @estado_pagada_id IS NULL
            OR @estado_cancelada_id IS NULL
        BEGIN
            SET @codigo_error = 2;
            SET @mensaje_error =
                'Faltan registros requeridos en los catalogos.';

            RETURN;
        END;

        -- Determinar cuántas facturas faltan.
        SELECT @existentes = COUNT(*)
        FROM dbo.factura;

        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes <= 0
        BEGIN
            SET @codigo_error = 0;

            SET @mensaje_error =
                'Ya existen '
                + CAST(@existentes AS VARCHAR(10))
                + ' o mas facturas.';

            RETURN;
        END;

        SET @secuencia_base = @existentes;

        -- Mapear clientes a una numeración continua.
        CREATE TABLE #clientes (
            rn INT PRIMARY KEY,
            cliente_id BIGINT NOT NULL
        );

        INSERT INTO #clientes (
            rn,
            cliente_id
        )
        SELECT
            ROW_NUMBER() OVER (
                ORDER BY cliente_id
            ),
            cliente_id
        FROM dbo.cliente;

        -- Mapear empresas a una numeración continua.
        CREATE TABLE #empresas (
            rn INT PRIMARY KEY,
            empresa_id INT NOT NULL
        );

        INSERT INTO #empresas (
            rn,
            empresa_id
        )
        SELECT
            ROW_NUMBER() OVER (
                ORDER BY empresa_id
            ),
            empresa_id
        FROM dbo.empresaemisora;

        -- Mapear items facturables.
        CREATE TABLE #items (
            rn INT PRIMARY KEY,
            item_facturable_id INT NOT NULL,
            descripcion VARCHAR(200) NOT NULL,
            precio_unitario DECIMAL(18, 2) NOT NULL,
            porcentaje_impuesto DECIMAL(5, 2) NOT NULL
        );

        INSERT INTO #items (
            rn,
            item_facturable_id,
            descripcion,
            precio_unitario,
            porcentaje_impuesto
        )
        SELECT
            ROW_NUMBER() OVER (
                ORDER BY item_facturable_id
            ),
            item_facturable_id,
            descripcion,
            precio_unitario,
            porcentaje_impuesto
        FROM dbo.item_facturable;

        -- Guardar los IDs generados en cada lote.
        CREATE TABLE #nuevas_facturas (
            factura_id BIGINT PRIMARY KEY
        );

        -- Generar las facturas por lotes.
        WHILE @faltantes > 0
        BEGIN
            SET @lote_actual =
                CASE
                    WHEN @faltantes < @tamano_lote
                        THEN @faltantes
                    ELSE @tamano_lote
                END;

            TRUNCATE TABLE #nuevas_facturas;

            BEGIN TRANSACTION;

            -- Crear los encabezados.
            WITH
            l0 AS (
                SELECT v.c
                FROM (
                    VALUES
                        (1), (1), (1), (1), (1),
                        (1), (1), (1), (1), (1)
                ) AS v(c)
            ),

            l1 AS (
                SELECT
                    a.c + b.c - 1 AS c
                FROM l0 AS a
                CROSS JOIN l0 AS b
            ),

            l2 AS (
                SELECT
                    a.c + b.c - 1 AS c
                FROM l1 AS a
                CROSS JOIN l1 AS b
            ),

            l3 AS (
                SELECT
                    a.c + b.c - 1 AS c
                FROM l2 AS a
                CROSS JOIN l2 AS b
            ),

            numbers AS (
                SELECT TOP (@lote_actual)
                    ROW_NUMBER() OVER (
                        ORDER BY (SELECT NULL)
                    ) AS n
                FROM l3
            ),

            datos_factura AS (
                SELECT
                    n,

                    @secuencia_base + n AS secuencia,

                    DATEADD(
                        SECOND,
                        -((@secuencia_base + n) * 61),
                        @ahora
                    ) AS fecha_factura

                FROM numbers
            )

            INSERT INTO dbo.factura (
                empresa_id,
                cliente_id,
                tipo_documento_id,
                moneda_id,
                estado_factura_id,
                numero_factura,
                fecha_emision,
                tipo_cambio,
                monto_subtotal,
                monto_descuento,
                monto_impuesto,
                monto_total,
                observaciones,
                fecha_creacion,
                fecha_modificacion
            )

            OUTPUT
                inserted.factura_id
            INTO #nuevas_facturas (
                factura_id
            )

            SELECT
                e.empresa_id,

                c.cliente_id,

                CASE
                    WHEN d.secuencia % 2 = 0
                        THEN @tipo_factura_id
                    ELSE @tipo_tiquete_id
                END,

                CASE
                    WHEN d.secuencia % 3 = 0
                        THEN @moneda_usd_id
                    ELSE @moneda_crc_id
                END,

                CASE d.secuencia % 4
                    WHEN 0 THEN @estado_borrador_id
                    WHEN 1 THEN @estado_emitida_id
                    WHEN 2 THEN @estado_pagada_id
                    ELSE @estado_cancelada_id
                END,

                CONVERT(
                    CHAR(8),
                    d.fecha_factura,
                    112
                )
                + REPLACE(
                    CONVERT(
                        CHAR(8),
                        d.fecha_factura,
                        108
                    ),
                    ':',
                    ''
                )
                + '-'
                + CASE
                    WHEN d.secuencia % 2 = 0
                        THEN 'FACTURA'
                    ELSE 'TIQUETE'
                END,

                d.fecha_factura,

                CASE
                    WHEN d.secuencia % 3 = 0
                        THEN CAST(
                            500.0000
                            AS DECIMAL(18, 4)
                        )
                    ELSE CAST(
                        1.0000
                        AS DECIMAL(18, 4)
                    )
                END,

                0.00,
                0.00,
                0.00,
                0.00,

                'Carga masiva de datos de prueba',

                d.fecha_factura,

                d.fecha_factura

            FROM datos_factura AS d

            INNER JOIN #clientes AS c
                ON c.rn =
                    (
                        ((d.secuencia * 17 - 1)
                        % @total_clientes)
                        + 1
                    )

            INNER JOIN #empresas AS e
                ON e.rn =
                    (
                        ((d.secuencia - 1)
                        % @total_empresas)
                        + 1
                    );

            -- Crear entre tres y cinco detalles por factura.
            WITH lineas AS (
                SELECT 1 AS numero_linea
                UNION ALL
                SELECT 2
                UNION ALL
                SELECT 3
                UNION ALL
                SELECT 4
                UNION ALL
                SELECT 5
            ),

            datos_detalle AS (
                SELECT
                    f.factura_id,
                    l.numero_linea,
                    i.item_facturable_id,
                    i.descripcion,
                    i.precio_unitario,
                    i.porcentaje_impuesto,

                    CAST(
                        (
                            (
                                f.factura_id * 3
                                + l.numero_linea * 7
                            ) % 10
                        ) + 1
                        AS DECIMAL(18, 2)
                    ) AS cantidad,

                    CASE
                        WHEN
                            (
                                f.factura_id
                                + l.numero_linea
                            ) % 10 = 0
                            THEN CAST(
                                0.10
                                AS DECIMAL(5, 2)
                            )

                        WHEN
                            (
                                f.factura_id
                                + l.numero_linea
                            ) % 5 = 0
                            THEN CAST(
                                0.05
                                AS DECIMAL(5, 2)
                            )

                        ELSE CAST(
                            0.00
                            AS DECIMAL(5, 2)
                        )
                    END AS porcentaje_descuento

                FROM #nuevas_facturas AS f

                CROSS JOIN lineas AS l

                INNER JOIN #items AS i
                    ON i.rn =
                        (
                            (
                                (
                                    f.factura_id * 11
                                    + l.numero_linea * 13
                                    - 1
                                ) % @total_items
                            ) + 1
                        )

                WHERE l.numero_linea
                    <= (
                        (f.factura_id % 3)
                        + 3
                    )
            ),

            calculos AS (
                SELECT
                    factura_id,
                    item_facturable_id,
                    numero_linea,
                    descripcion,
                    cantidad,
                    precio_unitario,
                    porcentaje_impuesto,

                    CAST(
                        cantidad * precio_unitario
                        AS DECIMAL(18, 2)
                    ) AS monto_subtotal,

                    CAST(
                        (
                            cantidad
                            * precio_unitario
                        )
                        * porcentaje_descuento
                        AS DECIMAL(18, 2)
                    ) AS monto_descuento

                FROM datos_detalle
            ),

            calculos_impuesto AS (
                SELECT
                    factura_id,
                    item_facturable_id,
                    numero_linea,
                    descripcion,
                    cantidad,
                    precio_unitario,
                    porcentaje_impuesto,
                    monto_subtotal,
                    monto_descuento,

                    CAST(
                        (
                            monto_subtotal
                            - monto_descuento
                        )
                        * (
                            porcentaje_impuesto
                            / 100.00
                        )
                        AS DECIMAL(18, 2)
                    ) AS monto_impuesto

                FROM calculos
            )

            INSERT INTO dbo.factura_detalle (
                factura_id,
                item_facturable_id,
                numero_linea,
                descripcion,
                cantidad,
                precio_unitario,
                porcentaje_impuesto,
                monto_subtotal,
                monto_descuento,
                monto_impuesto,
                monto_total
            )

            SELECT
                factura_id,
                item_facturable_id,
                numero_linea,
                descripcion,
                cantidad,
                precio_unitario,
                porcentaje_impuesto,
                monto_subtotal,
                monto_descuento,
                monto_impuesto,

                CAST(
                    monto_subtotal
                    - monto_descuento
                    + monto_impuesto
                    AS DECIMAL(18, 2)
                )

            FROM calculos_impuesto;

            -- Calcular los totales finales del encabezado.
            UPDATE f
            SET
                f.monto_subtotal = d.subtotal,
                f.monto_descuento = d.descuento,
                f.monto_impuesto = d.impuesto,
                f.monto_total = d.total,
                f.fecha_modificacion = SYSDATETIME()

            FROM dbo.factura AS f

            INNER JOIN (
                SELECT
                    fd.factura_id,
                    SUM(fd.monto_subtotal) AS subtotal,
                    SUM(fd.monto_descuento) AS descuento,
                    SUM(fd.monto_impuesto) AS impuesto,
                    SUM(fd.monto_total) AS total

                FROM dbo.factura_detalle AS fd

                INNER JOIN #nuevas_facturas AS nf
                    ON nf.factura_id = fd.factura_id

                GROUP BY
                    fd.factura_id

            ) AS d
                ON d.factura_id = f.factura_id;

            COMMIT TRANSACTION;

            SET @secuencia_base =
                @secuencia_base + @lote_actual;

            SET @existentes =
                @existentes + @lote_actual;

            SET @faltantes =
                @cantidad_objetivo - @existentes;
        END;

        SET @codigo_error = 0;

        SET @mensaje_error =
            'Facturas generadas exitosamente. Total actual: '
            + CAST(@existentes AS VARCHAR(10));

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH;
END;
GO
