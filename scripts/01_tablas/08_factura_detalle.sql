SET QUOTED_IDENTIFIER ON;
GO

CREATE TABLE dbo.facturadetalle (
    factura_detalle_id BIGINT IDENTITY (1, 1) NOT NULL,
    factura_id BIGINT NOT NULL,
    producto_servicio_id INT NOT NULL,

    numero_linea INT NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    cantidad DECIMAL(18, 2) NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,

    monto_descuento DECIMAL(18, 2) NOT NULL
    CONSTRAINT df_facturadetalle_descuento
    DEFAULT 0,

    monto_impuesto DECIMAL(18, 2) NOT NULL
    CONSTRAINT df_facturadetalle_impuesto
    DEFAULT 0,

    subtotal_linea AS
    CAST(cantidad * precio_unitario AS DECIMAL(18, 2)) PERSISTED,

    total_linea AS
    CAST(
        (cantidad * precio_unitario)
        - monto_descuento
        + monto_impuesto AS DECIMAL(18, 2)
    ) PERSISTED,

    CONSTRAINT pk_facturadetalle
    PRIMARY KEY (factura_detalle_id),

    CONSTRAINT fk_facturadetalle_factura
    FOREIGN KEY (factura_id)
    REFERENCES dbo.factura (factura_id),

    CONSTRAINT fk_facturadetalle_productoservicio
    FOREIGN KEY (producto_servicio_id)
    REFERENCES dbo.productoservicio (producto_servicio_id),

    CONSTRAINT uq_facturadetalle_linea
    UNIQUE (factura_id, numero_linea),

    CONSTRAINT ck_facturadetalle_numerolinea
    CHECK (numero_linea > 0),

    CONSTRAINT ck_facturadetalle_cantidad
    CHECK (cantidad > 0),

    CONSTRAINT ck_facturadetalle_precio
    CHECK (precio_unitario >= 0),

    CONSTRAINT ck_facturadetalle_impuestoporcentaje
    CHECK (porcentaje_impuesto >= 0 AND porcentaje_impuesto <= 100),

    CONSTRAINT ck_facturadetalle_descuento
    CHECK (monto_descuento >= 0),

    CONSTRAINT ck_facturadetalle_impuestomonto
    CHECK (monto_impuesto >= 0)
);
GO
