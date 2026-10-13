USE ProyectoFacturacion;
GO

CREATE NONCLUSTERED INDEX ix_factura_estado
    ON dbo.factura (estado_factura_id);
GO
