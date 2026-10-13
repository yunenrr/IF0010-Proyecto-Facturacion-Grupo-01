USE ProyectoFacturacion;
GO

CREATE NONCLUSTERED INDEX ix_factura_empresa
    ON dbo.factura (empresa_id);
GO
