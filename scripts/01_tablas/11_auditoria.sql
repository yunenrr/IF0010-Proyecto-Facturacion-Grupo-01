CREATE TABLE dbo.auditoria (
    auditoria_id BIGINT IDENTITY (1, 1) NOT NULL,
    factura_id BIGINT NOT NULL,
    operacion VARCHAR(10) NOT NULL,
    valor_anterior VARCHAR(MAX) NOT NULL,
    valor_nuevo VARCHAR(MAX) NOT NULL,
    usuario VARCHAR(128) NOT NULL,
    fecha_cambio DATETIME2 NOT NULL,
    descripcion VARCHAR(500) NOT NULL,

    CONSTRAINT pk_auditoria
    PRIMARY KEY (auditoria_id),

    CONSTRAINT fk_auditoria_factura
    FOREIGN KEY (factura_id)
    REFERENCES dbo.factura (factura_id)
);
GO
