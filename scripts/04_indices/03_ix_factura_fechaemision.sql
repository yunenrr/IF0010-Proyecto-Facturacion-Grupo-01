USE ProyectoFacturacion;
GO

CREATE NONCLUSTERED INDEX ix_factura_fechaemision
    ON dbo.factura (fecha_emision);
GO
