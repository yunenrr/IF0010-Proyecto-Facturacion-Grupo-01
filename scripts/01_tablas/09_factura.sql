CREATE TABLE dbo.factura (
    factura_id BIGINT IDENTITY (1, 1) NOT NULL,
    empresa_id INT NOT NULL,
    cliente_id BIGINT NOT NULL,
    tipo_documento_id INT NOT NULL,
    moneda_id INT NOT NULL,
    estado_factura_id INT NOT NULL,

    numero_factura VARCHAR(50) NOT NULL,
    fecha_emision DATETIME2 NOT NULL,
    tipo_cambio DECIMAL(18, 4) NOT NULL,

    monto_subtotal DECIMAL(18, 2) NOT NULL,
    monto_descuento DECIMAL(18, 2) NOT NULL,
    monto_impuesto DECIMAL(18, 2) NOT NULL,
    monto_total DECIMAL(18, 2) NOT NULL,

    observaciones VARCHAR(500) NOT NULL,
    fecha_creacion DATETIME2 NOT NULL,
    fecha_modificacion DATETIME2 NOT NULL,

    CONSTRAINT pk_factura
    PRIMARY KEY (factura_id),

    CONSTRAINT uq_factura_numero
    UNIQUE (numero_factura),

    CONSTRAINT fk_factura_empresaemisora
    FOREIGN KEY (empresa_id)
    REFERENCES dbo.empresaemisora (empresa_id),

    CONSTRAINT fk_factura_cliente
    FOREIGN KEY (cliente_id)
    REFERENCES dbo.cliente (cliente_id),

    CONSTRAINT fk_factura_tipodocumento
    FOREIGN KEY (tipo_documento_id)
    REFERENCES dbo.tipodocumento (tipo_documento_id),

    CONSTRAINT fk_factura_moneda
    FOREIGN KEY (moneda_id)
    REFERENCES dbo.moneda (moneda_id),

    CONSTRAINT fk_factura_estadofactura
    FOREIGN KEY (estado_factura_id)
    REFERENCES dbo.estadofactura (estado_factura_id)
);
GO
