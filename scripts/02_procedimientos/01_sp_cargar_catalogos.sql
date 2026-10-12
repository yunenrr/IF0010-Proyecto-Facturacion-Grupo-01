USE C21626;
GO

IF OBJECT_ID('dbo.sp_cargar_catalogos', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_cargar_catalogos;
GO

CREATE PROCEDURE dbo.sp_cargar_catalogos
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        
        IF EXISTS (SELECT * FROM sys.tables WHERE name = 'provincia') 
           AND NOT EXISTS (SELECT 1 FROM dbo.provincia)
        BEGIN
            INSERT INTO dbo.provincia (id_provincia, nombre)
            VALUES 
                (1, 'San José'),
                (2, 'Alajuela'),
                (3, 'Cartago'),
                (4, 'Heredia'),
                (5, 'Guanacaste'),
                (6, 'Puntarenas'),
                (7, 'Limón');
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
