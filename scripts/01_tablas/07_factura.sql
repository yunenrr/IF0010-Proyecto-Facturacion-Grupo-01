CREATE TABLE dbo.Factura (
    factura_id BIGINT IDENTITY(1,1) NOT NULL,
    empresa_id INT NOT NULL,
    cliente_id BIGINT NOT NULL,
    tipo_documento_id INT NOT NULL,
    moneda_id INT NOT NULL,
    estado_factura_id INT NOT NULL,

    comprobante VARCHAR(40) NOT NULL,
    fecha_emision DATETIME2 NOT NULL,

    subtotal DECIMAL(18,2) NOT NULL,
    total_descuentos DECIMAL(18,2) NOT NULL,
    total_impuestos DECIMAL(18,2) NOT NULL,
    total_final DECIMAL(18,2) NOT NULL,

    observaciones VARCHAR(500) NULL,

    fecha_creacion DATETIME2 NOT NULL
        CONSTRAINT DF_Factura_FechaCreacion
        DEFAULT SYSDATETIME(),

    fecha_modificacion DATETIME2 NOT NULL
        CONSTRAINT DF_Factura_FechaModificacion
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Factura
        PRIMARY KEY (factura_id),

    CONSTRAINT UQ_Factura_Comprobante
        UNIQUE (comprobante),

    CONSTRAINT FK_Factura_EmpresaEmisora
        FOREIGN KEY (empresa_id)
        REFERENCES dbo.EmpresaEmisora(empresa_id),

    CONSTRAINT FK_Factura_Cliente
        FOREIGN KEY (cliente_id)
        REFERENCES dbo.Cliente(cliente_id),

    CONSTRAINT FK_Factura_TipoDocumento
        FOREIGN KEY (tipo_documento_id)
        REFERENCES dbo.TipoDocumento(tipo_documento_id),

    CONSTRAINT FK_Factura_Moneda
        FOREIGN KEY (moneda_id)
        REFERENCES dbo.Moneda(moneda_id),

    CONSTRAINT FK_Factura_EstadoFactura
        FOREIGN KEY (estado_factura_id)
        REFERENCES dbo.EstadoFactura(estado_factura_id),

    CONSTRAINT CK_Factura_Subtotal
        CHECK (subtotal >= 0),

    CONSTRAINT CK_Factura_Descuentos
        CHECK (total_descuentos >= 0),

    CONSTRAINT CK_Factura_Impuestos
        CHECK (total_impuestos >= 0),

    CONSTRAINT CK_Factura_Total
        CHECK (total_final >= 0)
);
GO
