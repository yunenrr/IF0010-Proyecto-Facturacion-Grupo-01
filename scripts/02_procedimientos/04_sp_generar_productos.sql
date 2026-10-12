USE C21626;
GO

IF OBJECT_ID('dbo.sp_generar_productos', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_generar_productos;
GO

CREATE PROCEDURE dbo.sp_generar_productos
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insertar productos iniciales de prueba si la tabla está vacía
        IF NOT EXISTS (SELECT 1 FROM dbo.producto_con_existencia)
        BEGIN
            INSERT INTO dbo.producto_con_existencia (codigo_producto, nombre, stock_actual, precio_unitario, porcentaje_impuesto)
            VALUES 
                ('PROD-001', 'Arroz 1kg', 100, 1500.00, 13.00),
                ('PROD-002', 'Frijoles 1kg', 80, 1200.00, 13.00),
                ('PROD-003', 'Aceite de Girasol 900ml', 50, 2500.00, 13.00),
                ('PROD-004', 'Azúcar 1kg', 120, 1100.00, 13.00),
                ('PROD-005', 'Café Molido 500g', 60, 3500.00, 13.00);
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
