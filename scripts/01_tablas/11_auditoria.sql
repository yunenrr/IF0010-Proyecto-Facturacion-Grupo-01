CREATE TABLE dbo.auditoria (
    auditoria_id BIGINT IDENTITY (1, 1) NOT NULL,
    nombre_tabla VARCHAR(100) NOT NULL,
    tipo_operacion_id INT NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME2 NOT NULL,
    datos_anteriores NVARCHAR(MAX) NOT NULL,
    datos_nuevos NVARCHAR(MAX) NOT NULL,

    CONSTRAINT pk_auditoria
    PRIMARY KEY (auditoria_id),

    CONSTRAINT fk_auditoria_tipo_operacion
    FOREIGN KEY (tipo_operacion_id)
    REFERENCES dbo.tipo_operacion (tipo_operacion_id)
);
GO

CREATE NONCLUSTERED INDEX ix_auditoria_tipo_operacion
ON dbo.auditoria (tipo_operacion_id);
GO
