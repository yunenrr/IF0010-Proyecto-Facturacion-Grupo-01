USE ProyectoFacturacion;
GO

CREATE TABLE dbo.estadofactura (
    estado_factura_id INT IDENTITY (1, 1) NOT NULL,
    codigo VARCHAR(20) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,

    CONSTRAINT pk_estadofactura
    PRIMARY KEY (estado_factura_id),

    CONSTRAINT uq_estadofactura_codigo
    UNIQUE (codigo)
);
GO
