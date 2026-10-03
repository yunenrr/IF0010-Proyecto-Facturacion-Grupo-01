CREATE TABLE dbo.factura_detalle (
    factura_detalle_id BIGINT IDENTITY (1, 1) NOT NULL,
    factura_id BIGINT NOT NULL,
    producto_id INT NULL,
    servicio_id INT NULL,
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

    CONSTRAINT fk_facturadetalle_producto
    FOREIGN KEY (producto_id)
    REFERENCES dbo.producto (producto_id),

    CONSTRAINT fk_facturadetalle_servicio
    FOREIGN KEY (servicio_id)
    REFERENCES dbo.servicio (servicio_id),

    CONSTRAINT ck_facturadetalle_cantidades
    CHECK (cantidad > 0 AND precio_unitario >= 0),

    CONSTRAINT ck_facturadetalle_producto_o_servicio
    CHECK (
        (producto_id IS NOT NULL AND servicio_id IS NULL)
        OR (servicio_id IS NOT NULL AND producto_id IS NULL)
    )
);
GO
