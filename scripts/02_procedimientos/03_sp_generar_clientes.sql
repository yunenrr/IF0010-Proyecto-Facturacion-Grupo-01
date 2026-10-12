USE C21626;
GO

IF OBJECT_ID('dbo.sp_generar_clientes', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_generar_clientes;
GO

CREATE PROCEDURE dbo.sp_generar_clientes
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insertar clientes de prueba si las tablas están vacías
        IF NOT EXISTS (SELECT 1 FROM dbo.cliente_fisico) AND NOT EXISTS (SELECT 1 FROM dbo.cliente_juridico)
        BEGIN
            -- 1. Insertar dirección de prueba para cliente físico
            INSERT INTO dbo.cliente_direccion (id_provincia, id_canton, id_distrito, detalles)
            VALUES (1, 1, 1, 'San José, Centro');
            
            DECLARE @id_dir_fisico INT = SCOPE_IDENTITY();

            -- 2. Insertar cliente físico de prueba
            INSERT INTO dbo.cliente_fisico (cedula, nombre, primer_apellido, segundo_apellido, correo, telefono, id_direccion)
            VALUES ('101110111', 'Juan', 'Pérez', 'Gómez', 'juan.perez@email.com', '88888888', @id_dir_fisico);

            -- 3. Insertar dirección de prueba para cliente jurídico
            INSERT INTO dbo.cliente_direccion (id_provincia, id_canton, id_distrito, detalles)
            VALUES (2, 1, 1, 'Alajuela, Centro');
            
            DECLARE @id_dir_juridico INT = SCOPE_IDENTITY();

            -- 4. Insertar cliente jurídico de prueba
            INSERT INTO dbo.cliente_juridico (cedula_juridica, razon_social, nombre_comercial, correo, telefono, id_direccion)
            VALUES ('3101123456', 'Empresa Ejemplo S.A.', 'Ejemplo SA', 'contacto@ejemplo.com', '22222222', @id_dir_juridico);
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
