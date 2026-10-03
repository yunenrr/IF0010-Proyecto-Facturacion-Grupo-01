CREATE NONCLUSTERED INDEX ix_facturadetalle_producto
    ON dbo.factura_detalle (producto_id);
GO
