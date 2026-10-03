CREATE TABLE dbo.factura_detalle (
    factura_detalle_id BIGINT IDENTITY (1, 1) NOT NULL,
    factura_id BIGINT NOT NULL,
    item_facturable_id INT NOT NULL,
    cantidad DECIMAL(18, 2) NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,
    monto_subtotal DECIMAL(18, 2) NOT NULL,
    monto_impuesto DECIMAL(18, 2) NOT NULL,
    monto_total DECIMAL(18, 2) NOT NULL,

    CONSTRAINT pk_factura_detalle
    PRIMARY KEY (factura_detalle_id),

    CONSTRAINT fk_facturadetalle_factura
    FOREIGN KEY (factura_id)
    REFERENCES dbo.factura (factura_id),

    CONSTRAINT fk_facturadetalle_itemfacturable
    FOREIGN KEY (item_facturable_id)
    REFERENCES dbo.item_facturable (item_facturable_id)
);
GO
