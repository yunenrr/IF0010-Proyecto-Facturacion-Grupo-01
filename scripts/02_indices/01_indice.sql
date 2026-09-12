CREATE NONCLUSTERED INDEX ix_factura_cliente
    ON dbo.factura (cliente_id);
GO

CREATE NONCLUSTERED INDEX ix_factura_empresa
    ON dbo.factura (empresa_id);
GO

CREATE NONCLUSTERED INDEX ix_factura_fechaemision
    ON dbo.factura (fecha_emision);
GO

CREATE NONCLUSTERED INDEX ix_factura_estado
    ON dbo.factura (estado_factura_id);
GO

CREATE NONCLUSTERED INDEX ix_factura_moneda
    ON dbo.factura (moneda_id);
GO

CREATE NONCLUSTERED INDEX ix_facturadetalle_productoservicio
    ON dbo.facturadetalle (producto_servicio_id);
GO
