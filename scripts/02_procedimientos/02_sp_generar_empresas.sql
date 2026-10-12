USE C21626;
GO

IF OBJECT_ID('dbo.sp_generar_empresas', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_generar_empresas;
GO

CREATE PROCEDURE dbo.sp_generar_empresas
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insertar empresa emisor de prueba si la tabla está vacía
        IF NOT EXISTS (SELECT 1 FROM dbo.empresa)
        BEGIN
            INSERT INTO dbo.empresa (cedula_juridica, razon_social, nombre_comercial, correo, telefono, id_direccion)
            VALUES ('3101987654', 'Servicios Tecnológicos C21626 S.A.', 'Tech Solutions', 'facturacion@techsolutions.com', '4000-0000', 1);
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
