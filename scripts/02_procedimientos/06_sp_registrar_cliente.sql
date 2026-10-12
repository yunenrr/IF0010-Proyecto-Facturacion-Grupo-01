USE C21626;
GO

IF OBJECT_ID('dbo.sp_registrar_cliente', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_registrar_cliente;
GO

CREATE PROCEDURE dbo.sp_registrar_cliente
    @tipo_persona CHAR(1), -- 'F' para Físico, 'J' para Jurídico
    @identificacion VARCHAR(20),
    @nombre VARCHAR(50),
    @primer_apellido VARCHAR(50) = NULL,
    @segundo_apellido VARCHAR(50) = NULL,
    @razon_social VARCHAR(150) = NULL,
    @nombre_comercial VARCHAR(150) = NULL,
    @correo VARCHAR(100),
    @telefono VARCHAR(20),
    @id_provincia INT,
    @id_canton INT,
    @id_distrito INT,
    @detalles_direccion VARCHAR(250)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Insertar la dirección normalizada
        INSERT INTO dbo.cliente_direccion (id_provincia, id_canton, id_distrito, detalles)
        VALUES (@id_provincia, @id_canton, @id_distrito, @detalles_direccion);

        DECLARE @id_direccion INT = SCOPE_IDENTITY();

        -- 2. Insertar según el tipo de persona (Físico o Jurídico)
        IF @tipo_persona = 'F'
        BEGIN
            INSERT INTO dbo.cliente_fisico (cedula, nombre, primer_apellido, segundo_apellido, correo, telefono, id_direccion)
            VALUES (@identificacion, @nombre, @primer_apellido, @segundo_apellido, @correo, @telefono, @id_direccion);
        END
        ELSE IF @tipo_persona = 'J'
        BEGIN
            INSERT INTO dbo.cliente_juridico (cedula_juridica, razon_social, nombre_comercial, correo, telefono, id_direccion)
            VALUES (@identificacion, @razon_social, @nombre_comercial, @correo, @telefono, @id_direccion);
        }
        ELSE
        BEGIN
            RAISERROR('Tipo de persona inválido. Use F (Físico) o J (Jurídico).', 16, 1);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO
