USE Proyecto-Facturacion-Grupo01;
GO

CREATE OR ALTER PROCEDURE dbo.sp_generar_productos
    @cantidad_objetivo INT = 1000,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @existentes INT;
        DECLARE @faltantes INT;

        SELECT @existentes = COUNT(*) FROM dbo.producto;
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes <= 0
        BEGIN
            SET @codigo_error = 0;
            SET @mensaje_error = 'Ya existen ' + CAST(@existentes AS VARCHAR(10)) + ' o mas productos en la base de datos.';
            RETURN;
        END

        BEGIN TRANSACTION;

        -- 1. Insertar en la tabla supertipo item_facturable
        WITH
        L0 AS (SELECT 1 AS c FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) AS v(c)),
        L1 AS (SELECT 1 AS c FROM L0 AS a CROSS JOIN L0 AS b),
        L2 AS (SELECT 1 AS c FROM L1 AS a CROSS JOIN L1 AS b),
        Numbers AS (
            SELECT TOP (@faltantes)
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM L2
        )
        INSERT INTO dbo.item_facturable (
            codigo_interno,
            descripcion,
            precio_unitario,
            porcentaje_impuesto,
            activo,
            fecha_creacion
        )
        SELECT
            'PROD-' + RIGHT('00000' + CAST((@existentes + n) AS VARCHAR(10)), 5) AS codigo_interno,
            'Producto ' + CHOOSE((n % 10) + 1, 'Electronico', 'Hogar', 'Oficina', 'Herramienta', 'Alimento', 'Limpieza', 'Jardineria', 'Deporte', 'Juguete', 'Automotriz') + ' ' + CAST((@existentes + n) AS VARCHAR(10)) AS descripcion,
            CAST(500.00 + ((n * 137) % 95000) AS DECIMAL(18,2)) AS precio_unitario,
            CHOOSE((n % 3) + 1, CAST(0.00 AS DECIMAL(5,2)), CAST(2.00 AS DECIMAL(5,2)), CAST(13.00 AS DECIMAL(5,2))) AS porcentaje_impuesto,
            1 AS activo,
            DATEADD(MINUTE, -(n % 525600), SYSDATETIME()) AS fecha_creacion
        FROM Numbers;

        -- 2. Insertar en la tabla subtipo producto relacionando por codigo_interno
        INSERT INTO dbo.producto (
            producto_id,
            existencia
        )
        SELECT
            i.item_facturable_id,
            ((CAST(RIGHT(i.codigo_interno, 5) AS INT) * 17) % 500) + 10 AS existencia
        FROM dbo.item_facturable i
        LEFT JOIN dbo.producto p ON i.item_facturable_id = p.producto_id
        WHERE p.producto_id IS NULL
          AND i.codigo_interno LIKE 'PROD-%';

        COMMIT TRANSACTION;

        SET @codigo_error = 0;
        SET @mensaje_error = 'Productos generados exitosamente. Total actual: ' + CAST((@existentes + @faltantes) AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH
END;
GO
