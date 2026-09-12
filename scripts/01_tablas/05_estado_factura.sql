CREATE TABLE dbo.EstadoFactura (
    estado_factura_id INT IDENTITY(1,1) NOT NULL,
    codigo VARCHAR(20) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,

    CONSTRAINT PK_EstadoFactura
        PRIMARY KEY (estado_factura_id),

    CONSTRAINT UQ_EstadoFactura_Codigo
        UNIQUE (codigo)
);
GO
