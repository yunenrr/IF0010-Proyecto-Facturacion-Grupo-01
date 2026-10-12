USE C21626;
GO

CREATE OR ALTER PROCEDURE dbo.sp_registrar_cliente
    @identificacion VARCHAR(20),
    @tipo_persona CHAR(1), -- 'F' para Físico, 'J' para Jurídico
    @correo VARCHAR(150),
    @telefono VARCHAR(20),
    @distrito_id INT,
    @otras_senas VARCHAR(250),
    -- Parámetros para cliente físico
    @nombre VARCHAR(50) = NULL,
    @apellido1 VARCHAR(50) = NULL,
    @apellido2 VARCHAR(50) = NULL,
    -- Parámetros para cliente jurídico
    @razon_social VARCHAR(150) = NULL,
    @nombre_comercial VARCHAR(150) = NULL,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Insertar en la tabla base cliente
        INSERT INTO dbo.cliente (
            identificacion,
            tipo_persona,
            correo,
            telefono,
            distrito_id,
            otras_senas
        )
        VALUES (
            @identificacion,
            @tipo_persona,
            @correo,
            @telefono,
            @distrito_id,
            @otras_senas
        );

        DECLARE @nuevo_cliente_id INT = SCOPE_IDENTITY();

        -- 2. Insertar en el subtipo correspondiente
        IF @tipo_persona = 'F'
        BEGIN
            INSERT INTO dbo.cliente_fisico (cliente_id, nombre, apellido1, apellido2)
            VALUES (@nuevo_cliente_id, @nombre, @apellido1, @apellido2);
        END
        ELSE IF @tipo_persona = 'J'
        BEGIN
            INSERT INTO dbo.cliente_juridico (cliente_id, razon_social, nombre_comercial)
            VALUES (@nuevo_cliente_id, @razon_social, @nombre_comercial);
        END

        COMMIT TRANSACTION;
        SET @codigo_error = 0;
        SET @mensaje_error = 'Cliente registrado exitosamente con ID: ' + CAST(@nuevo_cliente_id AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH
END;
GO
