USE ProyectoFacturacion;
GO

-- Historial de cambios (solo se agrega, nunca se modifica ni se borra: ver
-- trg_auditoria_inmutable). registro_id es la clave primaria de la fila
-- auditada dentro de la entidad indicada. No tiene FK hacia las tablas
-- auditadas a proposito: el historial debe sobrevivir al DELETE de la fila
-- (por ejemplo, de una factura). usuario y fecha_cambio los asignan los
-- triggers (ORIGINAL_LOGIN y SYSDATETIME), nunca el llamador.
CREATE TABLE dbo.auditoria (
    auditoria_id BIGINT IDENTITY (1, 1) NOT NULL,
    entidad_auditada_id INT NOT NULL,
    registro_id BIGINT NOT NULL,
    tipo_operacion_id INT NOT NULL,
    usuario NVARCHAR(128) NOT NULL,
    fecha_cambio DATETIME2 NOT NULL,
    descripcion NVARCHAR(1000) NOT NULL,
    datos_anteriores NVARCHAR(MAX) NOT NULL,
    datos_nuevos NVARCHAR(MAX) NOT NULL,

    CONSTRAINT pk_auditoria
    PRIMARY KEY (auditoria_id),

    CONSTRAINT fk_auditoria_entidad_auditada
    FOREIGN KEY (entidad_auditada_id)
    REFERENCES dbo.entidad_auditada (entidad_auditada_id),

    CONSTRAINT fk_auditoria_tipo_operacion
    FOREIGN KEY (tipo_operacion_id)
    REFERENCES dbo.tipo_operacion (tipo_operacion_id)
);
GO
