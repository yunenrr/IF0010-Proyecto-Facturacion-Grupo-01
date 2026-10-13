USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_generar_productos;
GO

-- Carga masiva de productos con existencia hasta alcanzar @cantidad_objetivo
-- registros en total. Cada producto se registra primero en item_facturable
-- (codigo, descripcion, precio, impuesto, estado) y luego en
-- producto_con_existencia (stock), que comparte su identificador.
-- El stock inicial es amplio para que la carga masiva de facturas, que
-- descuenta existencias de las facturas no canceladas, no lo deje negativo.
CREATE PROCEDURE dbo.usp_generar_productos
    @cantidad_objetivo INT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @existentes INT;
    DECLARE @faltantes INT;
    DECLARE @ahora DATETIME2 = SYSDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @cantidad_objetivo IS NULL OR @cantidad_objetivo <= 0
        BEGIN
            THROW 50021, 'La cantidad objetivo debe ser mayor que cero.', 1;
        END

        SET @existentes = (SELECT COUNT(*) FROM dbo.producto_con_existencia);
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes > 0
        BEGIN
            SELECT
                n.seq,
                'PROD-' + RIGHT('000000' + CAST(n.seq AS VARCHAR(10)), 6) AS codigo_interno,
                CHOOSE(n.seq % 20 + 1,
                    'Arroz', 'Frijoles', 'Aceite', 'Azucar', 'Cafe', 'Leche',
                    'Harina', 'Pasta', 'Atun', 'Galletas', 'Jabon', 'Detergente',
                    'Shampoo', 'Papel higienico', 'Cuaderno', 'Lapicero',
                    'Bombillo', 'Cable', 'Baterias', 'Cereal')
                + ' '
                + CHOOSE(n.seq / 20 % 10 + 1,
                    'pequeno', 'mediano', 'grande', 'familiar', 'economico',
                    'premium', 'organico', 'light', 'extra', 'clasico')
                + ' marca '
                + CHOOSE(n.seq / 200 % 10 + 1,
                    'Alfa', 'Beta', 'Gama', 'Delta', 'Sigma', 'Omega', 'Zeta',
                    'Kappa', 'Lambda', 'Tauro')
                + ' ref ' + CAST(n.seq AS VARCHAR(10)) AS descripcion,
                CAST((50000 + CAST(n.seq AS BIGINT) * 7919 % 24950000) / 100.0 AS DECIMAL(18, 2)) AS precio_unitario,
                CAST(CHOOSE(n.seq % 6 + 1, 13.00, 13.00, 13.00, 4.00, 2.00, 0.00) AS DECIMAL(5, 2)) AS porcentaje_impuesto,
                CASE WHEN n.seq % 20 = 0 THEN 0 ELSE 1 END AS activo,
                DATEADD(DAY, -(n.seq * 17 % 900) - 1, @ahora) AS fecha_creacion,
                100000 + (n.seq * 31 % 50000) AS stock_actual
            INTO #nuevos
            FROM (
                SELECT TOP (@faltantes)
                    @existentes + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS seq
                FROM sys.all_objects AS a
                CROSS JOIN sys.all_objects AS b
                WHERE a.object_id IS NOT NULL
                    AND b.object_id IS NOT NULL
            ) AS n;

            INSERT INTO dbo.item_facturable (
                codigo_interno, descripcion, precio_unitario,
                porcentaje_impuesto, activo, fecha_creacion
            )
            SELECT
                codigo_interno, descripcion, precio_unitario,
                porcentaje_impuesto, activo, fecha_creacion
            FROM #nuevos
            ORDER BY seq;

            INSERT INTO dbo.producto_con_existencia (producto_con_existencia_id, stock_actual)
            SELECT i.item_facturable_id, n.stock_actual
            FROM #nuevos AS n
            INNER JOIN dbo.item_facturable AS i
                ON i.codigo_interno = n.codigo_interno;
        END

        COMMIT TRANSACTION;
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
