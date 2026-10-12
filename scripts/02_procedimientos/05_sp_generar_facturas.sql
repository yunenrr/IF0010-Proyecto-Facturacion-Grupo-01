USE C21626;
GO

IF OBJECT_ID('dbo.sp_generar_facturas', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_generar_facturas;
GO

CREATE PROCEDURE dbo.sp_generar_facturas
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Generar factura de prueba si la tabla está vacía
        IF NOT EXISTS (SELECT 1 FROM dbo.factura)
        BEGIN
            -- 1. Insertar encabezado de factura de prueba
            INSERT INTO dbo.factura (fecha, cedula_cliente, total)
            VALUES (GETDATE(), '101110111', 1500.00);

            DECLARE @id_factura INT = SCOPE_IDENTITY();

            -- 2. Insertar detalle de la factura
            INSERT INTO dbo.detalle_factura (id_factura, codigo_producto, cantidad, precio_unitario, subtotal)
            VALUES (@id_factura, 'PROD-001', 1, 1500.00, 1500.00);

            -- 3. Actualizar el stock del producto afectado
            UPDATE dbo.producto_con_existencia
            SET stock_actual = stock_actual - 1
            WHERE codigo_producto = 'PROD-001';
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
