CREATE TABLE dbo.factura (
    factura_id BIGINT IDENTITY (1, 1) NOT NULL,
    empresa_id INT NOT NULL,
    cliente_id BIGINT NOT NULL,
    tipo_documento_id INT NOT NULL,
    moneda_id INT NOT NULL,
    estado_factura_id INT NOT NULL,

    comprobante VARCHAR(40) NOT NULL,
    fecha_emision DATETIME2 NOT NULL,

    subtotal DECIMAL(18, 2) NOT NULL,
    total_descuentos DECIMAL(18, 2) NOT NULL,
    total_impuestos DECIMAL(18, 2) NOT NULL,
    total_final DECIMAL(18, 2) NOT NULL,

    observaciones VARCHAR(500) NULL,

    fecha_creacion DATETIME2 NOT NULL
        CONSTRAINT df_factura_fechacreacion
        DEFAULT SYSDATETIME(),

    fecha_modificacion DATETIME2 NOT NULL
        CONSTRAINT df_factura_fechamodificacion
        DEFAULT SYSDATETIME(),

    CONSTRAINT pk_factura
        PRIMARY KEY (factura_id),

    CONSTRAINT uq_factura_comprobante
        UNIQUE (comprobante),

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
        REFERENCES dbo.estadofactura (estado_factura_id),

    CONSTRAINT ck_factura_subtotal
        CHECK (subtotal >= 0),

    CONSTRAINT ck_factura_descuentos
        CHECK (total_descuentos >= 0),

    CONSTRAINT ck_factura_impuestos
        CHECK (total_impuestos >= 0),

    CONSTRAINT ck_factura_total
        CHECK (total_final >= 0)
);
GO
