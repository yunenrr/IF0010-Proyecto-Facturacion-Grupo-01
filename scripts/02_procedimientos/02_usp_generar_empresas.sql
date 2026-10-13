USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_generar_empresas;
GO

-- Carga masiva de empresas emisoras hasta alcanzar @cantidad_objetivo
-- registros en total. Es idempotente: solo inserta las empresas faltantes.
CREATE PROCEDURE dbo.usp_generar_empresas
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

        SET @existentes = (SELECT COUNT(*) FROM dbo.empresaemisora);
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes > 0
        BEGIN
            INSERT INTO dbo.empresaemisora (
                nombre_comercial, razon_social, cedula, direccion, telefono,
                correo_electronico, fecha_creacion, activa
            )
            SELECT
                CHOOSE(n.seq % 12 + 1,
                    'Soluciones', 'Servicios', 'Comercial', 'Distribuidora',
                    'Importadora', 'Tecnologias', 'Inversiones', 'Grupo',
                    'Corporacion', 'Suministros', 'Industrias', 'Logistica')
                + ' '
                + CHOOSE(n.seq / 12 % 10 + 1,
                    'Atlantico', 'Caribe', 'Central', 'Pacifico', 'Tropical',
                    'Volcan', 'Montana', 'Costa Rica', 'Del Valle', 'Del Norte')
                + ' ' + CAST(n.seq AS VARCHAR(10)),
                CHOOSE(n.seq % 12 + 1,
                    'Soluciones', 'Servicios', 'Comercial', 'Distribuidora',
                    'Importadora', 'Tecnologias', 'Inversiones', 'Grupo',
                    'Corporacion', 'Suministros', 'Industrias', 'Logistica')
                + ' '
                + CHOOSE(n.seq / 12 % 10 + 1,
                    'Atlantico', 'Caribe', 'Central', 'Pacifico', 'Tropical',
                    'Volcan', 'Montana', 'Costa Rica', 'Del Valle', 'Del Norte')
                + ' ' + CAST(n.seq AS VARCHAR(10)) + ' Sociedad Anonima',
                '3101' + RIGHT('000000' + CAST(n.seq AS VARCHAR(10)), 6),
                'Avenida ' + CAST(n.seq % 20 + 1 AS VARCHAR(5))
                + ', calle ' + CAST(n.seq % 15 + 1 AS VARCHAR(5))
                + ', edificio ' + CAST(n.seq AS VARCHAR(10)),
                '2' + RIGHT('0000000' + CAST(CAST(n.seq AS BIGINT) * 7919 % 10000000 AS VARCHAR(10)), 7),
                'facturacion' + CAST(n.seq AS VARCHAR(10)) + '@empresa.example.cr',
                DATEADD(MINUTE, -(n.seq * 13 % 1440),
                    DATEADD(DAY, -(n.seq * 37 % 1000) - 30, SYSDATETIME())),
                CASE WHEN n.seq % 10 = 0 THEN 0 ELSE 1 END
            FROM (
                SELECT TOP (@faltantes)
                    @existentes + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS seq
                FROM sys.all_objects AS a
                CROSS JOIN sys.all_objects AS b
                WHERE a.object_id IS NOT NULL
                    AND b.object_id IS NOT NULL
            ) AS n;
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
