USE ProyectoFacturacion;
GO

CREATE NONCLUSTERED INDEX ix_factura_cliente
    ON dbo.factura (cliente_id);
GO
