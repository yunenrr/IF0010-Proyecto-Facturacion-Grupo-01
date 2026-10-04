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
        DECLARE @total_clientes INT;
        DECLARE @total_items INT;
        DECLARE @ultima_secuencia INT;

        -- Validar que existan clientes e items cargados
        SELECT @total_clientes = COUNT(*) FROM dbo.cliente;
        SELECT @total_items = COUNT(*) FROM dbo.item_facturable;

        IF @total_clientes = 0 OR @total_items = 0
        BEGIN
            SET @codigo_error = 1;
            SET @mensaje_error = 'Error: Se requieren clientes e items facturables registrados previamente.';
            RETURN;
        END

        SELECT @existentes = COUNT(*) FROM dbo.factura;
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes <= 0
        BEGIN
            SET @codigo_error = 0;
            SET @mensaje_error = 'Ya existen ' + CAST(@existentes AS VARCHAR(10)) + ' o mas facturas en la base de datos.';
            RETURN;
        END

        -- Obtener el mayor correlativo numerico actual para evitar duplicados en numero_factura
        SELECT @ultima_secuencia = ISNULL(MAX(TRY_CAST(RIGHT(numero_factura, 8) AS INT)), 0) FROM dbo.factura;

        IF OBJECT_ID('tempdb..#NuevasFacturas') IS NOT NULL DROP TABLE #NuevasFacturas;
        CREATE TABLE #NuevasFacturas (
            factura_id INT PRIMARY KEY
        );

        WHILE @faltantes > 0
        BEGIN
            SET @lote_actual = CASE WHEN @faltantes < @tamano_lote THEN @faltantes ELSE @tamano_lote END;

            TRUNCATE TABLE #NuevasFacturas;

            BEGIN TRANSACTION;

            -- 1. Insertar encabezados de factura
            WITH
            L0 AS (SELECT 1 AS c FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) AS v(c)),
            L1 AS (SELECT 1 AS c FROM L0 AS a CROSS JOIN L0 AS b),
            L2 AS (SELECT 1 AS c FROM L1 AS a CROSS JOIN L1 AS b),
            L3 AS (SELECT 1 AS c FROM L2 AS a CROSS JOIN L2 AS b),
            Numbers AS (
                SELECT TOP (@lote_actual)
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
                FROM L3
            )
            INSERT INTO dbo.factura (
                cliente_id,
                numero_factura,
                fecha_emision,
                subtotal,
                impuesto,
                total,
                estado
            )
            OUTPUT inserted.factura_id INTO #NuevasFacturas(factura_id)
            SELECT
                c.cliente_id,
                'FAC-' + RIGHT('00000000' + CAST((@ultima_secuencia + num.n) AS VARCHAR(12)), 8) AS numero_factura,
                DATEADD(SECOND, -((@ultima_secuencia + num.n) % 31536000), SYSDATETIME()) AS fecha_emision,
                0.00 AS subtotal,
                0.00 AS impuesto,
                0.00 AS total,
                'PAGADA' AS estado
            FROM Numbers num
            INNER JOIN (
                SELECT cliente_id, ROW_NUMBER() OVER(ORDER BY cliente_id) AS rn
                FROM dbo.cliente
            ) c ON c.rn = (((@ultima_secuencia + num.n * 17) % @total_clientes) + 1);

            -- 2. Insertar detalles (de 3 a 5 lineas por factura)
            WITH Secuencia AS (
                SELECT 1 AS item_num UNION ALL
                SELECT 2 UNION ALL
                SELECT 3 UNION ALL
                SELECT 4 UNION ALL
                SELECT 5
            ),
            DetallesGenerados AS (
                SELECT
                    f.factura_id,
                    i.item_facturable_id,
                    ((f.factura_id * 3 + s.item_num * 7) % 10) + 1 AS cantidad,
                    i.precio_unitario,
                    i.porcentaje_impuesto
                FROM #NuevasFacturas f
                CROSS JOIN Secuencia s
                INNER JOIN (
                    SELECT item_facturable_id, precio_unitario, porcentaje_impuesto,
                           ROW_NUMBER() OVER(ORDER BY item_facturable_id) AS rn
                    FROM dbo.item_facturable
                ) i ON i.rn = (((f.factura_id * 11 + s.item_num * 13) % @total_items) + 1)
                WHERE s.item_num <= ((f.factura_id % 3) + 3)
            )
            INSERT INTO dbo.detalle_facturable (
                factura_id,
                item_facturable_id,
                cantidad,
                precio_unitario,
                porcentaje_impuesto,
                monto_impuesto,
                subtotal,
                total
            )
            SELECT
                factura_id,
                item_facturable_id,
                cantidad,
                precio_unitario,
                porcentaje_impuesto,
                CAST((cantidad * precio_unitario * (porcentaje_impuesto / 100.00)) AS DECIMAL(18,2)) AS monto_impuesto,
                CAST((cantidad * precio_unitario) AS DECIMAL(18,2)) AS subtotal,
                CAST((cantidad * precio_unitario * (1.00 + (porcentaje_impuesto / 100.00))) AS DECIMAL(18,2)) AS total
            FROM DetallesGenerados;

            -- 3. Actualizar totales acumulados en el encabezado
            UPDATE f
            SET f.subtotal = d.subtotal_sum,
                f.impuesto = d.impuesto_sum,
                f.total = d.total_sum
            FROM dbo.factura f
            INNER JOIN (
                SELECT
                    factura_id,
                    SUM(subtotal) AS subtotal_sum,
                    SUM(monto_impuesto) AS impuesto_sum,
                    SUM(total) AS total_sum
                FROM dbo.detalle_facturable
                WHERE factura_id IN (SELECT factura_id FROM #NuevasFacturas)
                GROUP BY factura_id
            ) d ON f.factura_id = d.factura_id;

            COMMIT TRANSACTION;

            SET @ultima_secuencia = @ultima_secuencia + @lote_actual;
            SET @existentes = @existentes + @lote_actual;
            SET @faltantes = @cantidad_objetivo - @existentes;
        END

        IF OBJECT_ID('tempdb..#NuevasFacturas') IS NOT NULL DROP TABLE #NuevasFacturas;

        SET @codigo_error = 0;
        SET @mensaje_error = 'Facturas generadas exitosamente. Total actual: ' + CAST(@existentes AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF OBJECT_ID('tempdb..#NuevasFacturas') IS NOT NULL DROP TABLE #NuevasFacturas;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH
END;
GO
