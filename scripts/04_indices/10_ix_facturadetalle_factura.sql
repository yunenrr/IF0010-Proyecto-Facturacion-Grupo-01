USE ProyectoFacturacion;
GO

CREATE NONCLUSTERED INDEX ix_facturadetalle_factura
    ON dbo.factura_detalle (factura_id)
    INCLUDE (numero_linea, monto_subtotal, monto_descuento, monto_impuesto, monto_total);
GO
