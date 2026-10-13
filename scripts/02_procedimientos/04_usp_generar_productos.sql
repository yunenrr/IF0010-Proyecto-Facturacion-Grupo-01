USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_GENERAR_PRODUCTOS;
GO

-- Carga masiva de productos con existencia hasta alcanzar @cantidad_objetivo
-- registros en total. Cada producto se registra primero en item_facturable
-- (codigo, descripcion, precio, impuesto, estado) y luego en
-- producto_con_existencia (stock), que comparte su identificador.
-- El stock inicial es amplio para que la carga masiva de facturas, que
-- descuenta existencias de las facturas no canceladas, no lo deje negativo.
CREATE PROCEDURE DBO.USP_GENERAR_PRODUCTOS
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

        SET @existentes = (SELECT COUNT(*) FROM DBO.PRODUCTO_CON_EXISTENCIA);
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes > 0
            BEGIN
                SELECT
                    N.SEQ,
                    CAST(
                        (50000 + CAST(N.SEQ AS BIGINT) * 7919 % 24950000)
                        / 100.0 AS DECIMAL(18, 2)
                    ) AS PRECIO_UNITARIO,
                    CAST(
                        CHOOSE(
                            N.SEQ % 6 + 1, 13.00, 13.00, 13.00, 4.00, 2.00, 0.00
                        ) AS DECIMAL(5, 2)
                    ) AS PORCENTAJE_IMPUESTO,
                    'PROD-'
                    + RIGHT('000000' + CAST(N.SEQ AS VARCHAR(10)), 6)
                        AS CODIGO_INTERNO,
                    CHOOSE(
                        N.SEQ % 20 + 1,
                        'Arroz',
                        'Frijoles',
                        'Aceite',
                        'Azucar',
                        'Cafe',
                        'Leche',
                        'Harina',
                        'Pasta',
                        'Atun',
                        'Galletas',
                        'Jabon',
                        'Detergente',
                        'Shampoo', 'Papel higienico', 'Cuaderno', 'Lapicero',
                        'Bombillo', 'Cable', 'Baterias', 'Cereal'
                    )
                    + ' '
                    + CHOOSE(
                        N.SEQ / 20 % 10 + 1,
                        'pequeno', 'mediano', 'grande', 'familiar', 'economico',
                        'premium', 'organico', 'light', 'extra', 'clasico'
                    )
                    + ' marca '
                    + CHOOSE(
                        N.SEQ / 200 % 10 + 1,
                        'Alfa',
                        'Beta',
                        'Gama',
                        'Delta',
                        'Sigma',
                        'Omega',
                        'Zeta',
                        'Kappa', 'Lambda', 'Tauro'
                    )
                    + ' ref ' + CAST(N.SEQ AS VARCHAR(10)) AS DESCRIPCION,
                    CASE WHEN N.SEQ % 20 = 0 THEN 0 ELSE 1 END AS ACTIVO,
                    DATEADD(DAY, -(N.SEQ * 17 % 900) - 1, @ahora)
                        AS FECHA_CREACION,
                    100000 + (N.SEQ * 31 % 50000) AS STOCK_ACTUAL
                INTO #nuevos
                FROM (
                    SELECT TOP (@faltantes)
                        @existentes
                        + CAST(
                            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT
                        ) AS SEQ
                    FROM SYS.ALL_OBJECTS AS A
                    CROSS JOIN SYS.ALL_OBJECTS AS B
                    WHERE
                        A.OBJECT_ID IS NOT NULL
                        AND B.OBJECT_ID IS NOT NULL
                ) AS N;

                INSERT INTO DBO.ITEM_FACTURABLE (
                    CODIGO_INTERNO, DESCRIPCION, PRECIO_UNITARIO,
                    PORCENTAJE_IMPUESTO, ACTIVO, FECHA_CREACION
                )
                SELECT
                    CODIGO_INTERNO,
                    DESCRIPCION,
                    PRECIO_UNITARIO,
                    PORCENTAJE_IMPUESTO,
                    ACTIVO,
                    FECHA_CREACION
                FROM #nuevos
                ORDER BY SEQ;

                INSERT INTO DBO.PRODUCTO_CON_EXISTENCIA (
                    PRODUCTO_CON_EXISTENCIA_ID, STOCK_ACTUAL
                )
                SELECT
                    I.ITEM_FACTURABLE_ID,
                    N.STOCK_ACTUAL
                FROM #nuevos AS N
                INNER JOIN DBO.ITEM_FACTURABLE AS I
                    ON N.CODIGO_INTERNO = I.CODIGO_INTERNO;
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
