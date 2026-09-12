CREATE NONCLUSTERED INDEX IX_Factura_Cliente
ON dbo.Factura (cliente_id);
GO

CREATE NONCLUSTERED INDEX IX_Factura_Empresa
ON dbo.Factura (empresa_id);
GO

CREATE NONCLUSTERED INDEX IX_Factura_FechaEmision
ON dbo.Factura (fecha_emision);
GO

CREATE NONCLUSTERED INDEX IX_Factura_Estado
ON dbo.Factura (estado_factura_id);
GO

CREATE NONCLUSTERED INDEX IX_Factura_Moneda
ON dbo.Factura (moneda_id);
GO

CREATE NONCLUSTERED INDEX IX_FacturaDetalle_ProductoServicio
ON dbo.FacturaDetalle (producto_servicio_id);
GO
