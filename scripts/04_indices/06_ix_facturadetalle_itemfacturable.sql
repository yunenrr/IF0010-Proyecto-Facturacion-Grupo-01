USE ProyectoFacturacion;
GO

CREATE NONCLUSTERED INDEX ix_facturadetalle_itemfacturable
    ON dbo.factura_detalle (item_facturable_id);
GO
