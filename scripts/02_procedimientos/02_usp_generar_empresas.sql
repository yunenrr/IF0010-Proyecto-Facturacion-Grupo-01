USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_GENERAR_EMPRESAS;
GO

-- Carga masiva de empresas emisoras hasta alcanzar @cantidad_objetivo
-- registros en total. Es idempotente: solo inserta las empresas faltantes.
CREATE PROCEDURE DBO.USP_GENERAR_EMPRESAS
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

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @cantidad_objetivo IS NULL OR @cantidad_objetivo <= 0
            BEGIN
                THROW 50001, 'La cantidad objetivo debe ser mayor que cero.', 1;
            END

        SET @existentes = (SELECT COUNT(*) FROM DBO.EMPRESAEMISORA);
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes > 0
            BEGIN
                INSERT INTO DBO.EMPRESAEMISORA (
                    NOMBRE_COMERCIAL, RAZON_SOCIAL, CEDULA, DIRECCION, TELEFONO,
                    CORREO_ELECTRONICO, FECHA_CREACION, ACTIVA
                )
                SELECT
                    CHOOSE(
                        N.SEQ % 12 + 1,
                        'Soluciones', 'Servicios', 'Comercial', 'Distribuidora',
                        'Importadora', 'Tecnologias', 'Inversiones', 'Grupo',
                        'Corporacion', 'Suministros', 'Industrias', 'Logistica'
                    )
                    + ' '
                    + CHOOSE(
                        N.SEQ / 12 % 10 + 1,
                        'Atlantico',
                        'Caribe',
                        'Central',
                        'Pacifico',
                        'Tropical',
                        'Volcan',
                        'Montana',
                        'Costa Rica',
                        'Del Valle',
                        'Del Norte'
                    )
                    + ' ' + CAST(N.SEQ AS VARCHAR(10)) AS NOMBRE_COMERCIAL,
                    CHOOSE(
                        N.SEQ % 12 + 1,
                        'Soluciones', 'Servicios', 'Comercial', 'Distribuidora',
                        'Importadora', 'Tecnologias', 'Inversiones', 'Grupo',
                        'Corporacion', 'Suministros', 'Industrias', 'Logistica'
                    )
                    + ' '
                    + CHOOSE(
                        N.SEQ / 12 % 10 + 1,
                        'Atlantico',
                        'Caribe',
                        'Central',
                        'Pacifico',
                        'Tropical',
                        'Volcan',
                        'Montana',
                        'Costa Rica',
                        'Del Valle',
                        'Del Norte'
                    )
                    + ' ' + CAST(N.SEQ AS VARCHAR(10))
                    + ' Sociedad Anonima' AS RAZON_SOCIAL,
                    '3101'
                    + RIGHT('000000' + CAST(N.SEQ AS VARCHAR(10)), 6) AS CEDULA,
                    'Avenida ' + CAST(N.SEQ % 20 + 1 AS VARCHAR(5))
                    + ', calle ' + CAST(N.SEQ % 15 + 1 AS VARCHAR(5))
                    + ', edificio ' + CAST(N.SEQ AS VARCHAR(10)) AS DIRECCION,
                    '2'
                    + RIGHT(
                        '0000000'
                        + CAST(
                            CAST(N.SEQ AS BIGINT)
                            * 7919
                            % 10000000 AS VARCHAR(10)
                        ),
                        7
                    ) AS TELEFONO,
                    'facturacion'
                    + CAST(N.SEQ AS VARCHAR(10))
                    + '@empresa.example.cr' AS CORREO_ELECTRONICO,
                    DATEADD(
                        MINUTE, -(N.SEQ * 13 % 1440),
                        DATEADD(DAY, -(N.SEQ * 37 % 1000) - 30, SYSDATETIME())
                    ) AS FECHA_CREACION,
                    CASE WHEN N.SEQ % 10 = 0 THEN 0 ELSE 1 END AS ACTIVA
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
