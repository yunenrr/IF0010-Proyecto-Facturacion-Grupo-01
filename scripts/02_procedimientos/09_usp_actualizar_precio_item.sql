USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_actualizar_precio_item;
GO

-- Modifica el precio de lista y el porcentaje de impuesto de un item
-- facturable (producto o servicio). No altera facturas ya emitidas: cada linea
-- conserva el precio e impuesto con que se facturo.
CREATE PROCEDURE dbo.usp_actualizar_precio_item
    @item_facturable_id INT,
    @precio_unitario DECIMAL(18, 2),
    @porcentaje_impuesto DECIMAL(5, 2),
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.item_facturable WHERE item_facturable_id = @item_facturable_id
        )
        BEGIN
            THROW 50131, 'El item facturable indicado no existe.', 1;
        END

        IF @precio_unitario <= 0
        BEGIN
            THROW 50132, 'El precio unitario debe ser mayor que cero.', 1;
        END

        IF @porcentaje_impuesto < 0 OR @porcentaje_impuesto > 100
        BEGIN
            THROW 50133, 'El porcentaje de impuesto debe estar entre 0 y 100.', 1;
        END

        UPDATE dbo.item_facturable
        SET
            precio_unitario = @precio_unitario,
            porcentaje_impuesto = @porcentaje_impuesto
        WHERE item_facturable_id = @item_facturable_id;

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
