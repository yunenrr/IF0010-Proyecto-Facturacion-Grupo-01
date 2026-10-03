CREATE TABLE dbo.factura (
    factura_id BIGINT IDENTITY (1, 1) NOT NULL,
    numero_factura VARCHAR(50) NOT NULL,
    cliente_id BIGINT NOT NULL,
    fecha_emision DATETIME2 NOT NULL,
    estado VARCHAR(20) NOT NULL,
    moneda VARCHAR(3) NOT NULL,
    tipo_cambio DECIMAL(18, 4) NOT NULL,
    monto_subtotal DECIMAL(18, 2) NOT NULL,
    monto_impuesto DECIMAL(18, 2) NOT NULL,
    monto_total DECIMAL(18, 2) NOT NULL,

    CONSTRAINT pk_factura
    PRIMARY KEY (factura_id),

    CONSTRAINT uq_factura_numero
    UNIQUE (numero_factura),

    CONSTRAINT fk_factura_cliente
    FOREIGN KEY (cliente_id)
    REFERENCES dbo.cliente (cliente_id)
);
GO
