CREATE TABLE dbo.FacturaDetalle (
    factura_detalle_id BIGINT IDENTITY(1,1) NOT NULL,
    factura_id BIGINT NOT NULL,
    producto_servicio_id INT NOT NULL,

    numero_linea INT NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    cantidad DECIMAL(18,2) NOT NULL,
    precio_unitario DECIMAL(18,2) NOT NULL,
    porcentaje_impuesto DECIMAL(5,2) NOT NULL,

    monto_descuento DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_FacturaDetalle_Descuento
        DEFAULT 0,

    monto_impuesto DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_FacturaDetalle_Impuesto
        DEFAULT 0,

    subtotal_linea AS
        CAST(cantidad * precio_unitario AS DECIMAL(18,2)) PERSISTED,

    total_linea AS
        CAST(
            (cantidad * precio_unitario)
            - monto_descuento
            + monto_impuesto
            AS DECIMAL(18,2)
        ) PERSISTED,

    CONSTRAINT PK_FacturaDetalle
        PRIMARY KEY (factura_detalle_id),

    CONSTRAINT FK_FacturaDetalle_Factura
        FOREIGN KEY (factura_id)
        REFERENCES dbo.Factura(factura_id),

    CONSTRAINT FK_FacturaDetalle_ProductoServicio
        FOREIGN KEY (producto_servicio_id)
        REFERENCES dbo.ProductoServicio(producto_servicio_id),

    CONSTRAINT UQ_FacturaDetalle_Linea
        UNIQUE (factura_id, numero_linea),

    CONSTRAINT CK_FacturaDetalle_NumeroLinea
        CHECK (numero_linea > 0),

    CONSTRAINT CK_FacturaDetalle_Cantidad
        CHECK (cantidad > 0),

    CONSTRAINT CK_FacturaDetalle_Precio
        CHECK (precio_unitario >= 0),

    CONSTRAINT CK_FacturaDetalle_ImpuestoPorcentaje
        CHECK (porcentaje_impuesto >= 0 AND porcentaje_impuesto <= 100),

    CONSTRAINT CK_FacturaDetalle_Descuento
        CHECK (monto_descuento >= 0),

    CONSTRAINT CK_FacturaDetalle_ImpuestoMonto
        CHECK (monto_impuesto >= 0)
);
GO
