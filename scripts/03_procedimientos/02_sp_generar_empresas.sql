CREATE OR ALTER PROCEDURE dbo.sp_generar_empresas
    @cantidad_objetivo INT = 100,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @cantidad_actual INT;
        DECLARE @faltantes INT;
        DECLARE @insertadas INT = 0;
        DECLARE @i INT = 1;
        DECLARE @cedula VARCHAR(20);

        SELECT @cantidad_actual = COUNT(*)
        FROM dbo.empresaemisora;

        IF @cantidad_actual < @cantidad_objetivo
        BEGIN
            SET @faltantes = @cantidad_objetivo - @cantidad_actual;

            WHILE @insertadas < @faltantes
            BEGIN
                SET @cedula = CONCAT(
                    '3-101-',
                    RIGHT('000000' + CAST(@i AS VARCHAR(6)), 6)
                );

                IF NOT EXISTS (
                    SELECT 1
                    FROM dbo.empresaemisora
                    WHERE cedula = @cedula
                )
                BEGIN
                    INSERT INTO dbo.empresaemisora (
                        nombre_comercial,
                        razon_social,
                        cedula,
                        direccion,
                        telefono,
                        correo_electronico,
                        fecha_creacion,
                        activa
                    )
                    VALUES (
                        CONCAT('Empresa ', RIGHT('000' + CAST(@i AS VARCHAR(3)), 3)),
                        CONCAT(
                            'Empresa ',
                            RIGHT('000' + CAST(@i AS VARCHAR(3)), 3),
                            ' Sociedad Anonima'
                        ),
                        @cedula,
                        CONCAT('Direccion empresa ', @i),
                        CONCAT(
                            '2200',
                            RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4)
                        ),
                        CONCAT(
                            'empresa',
                            RIGHT('000' + CAST(@i AS VARCHAR(3)), 3),
                            '@ejemplo.com'
                        ),
                        DATEADD(
                            DAY,
                            -(@i % 365),
                            SYSDATETIME()
                        ),
                        1
                    );

                    SET @insertadas = @insertadas + 1;
                END;

                SET @i = @i + 1;
            END;
        END;

        COMMIT TRANSACTION;

        SET @codigo_error = 0;
        SET @mensaje_error = CONCAT(
            'Carga completada. Empresas existentes: ',
            (
                SELECT COUNT(*)
                FROM dbo.empresaemisora
            )
        );
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH;
END;
GO
