USE PROYECTOFACTURACION;
GO

-- Historial de cambios (solo se agrega, nunca se modifica ni se borra: ver
-- trg_auditoria_inmutable). registro_id es la clave primaria de la fila
-- auditada dentro de la entidad indicada. No tiene FK hacia las tablas
-- auditadas a proposito: el historial debe sobrevivir al DELETE de la fila
-- (por ejemplo, de una factura). usuario y fecha_cambio los asignan los
-- triggers (ORIGINAL_LOGIN y SYSDATETIME), nunca el llamador.
CREATE TABLE DBO.AUDITORIA (
    AUDITORIA_ID BIGINT IDENTITY (1, 1) NOT NULL,
    ENTIDAD_AUDITADA_ID INT NOT NULL,
    REGISTRO_ID BIGINT NOT NULL,
    TIPO_OPERACION_ID INT NOT NULL,
    USUARIO NVARCHAR(128) NOT NULL,
    FECHA_CAMBIO DATETIME2 NOT NULL,
    DESCRIPCION NVARCHAR(1000) NOT NULL,
    DATOS_ANTERIORES NVARCHAR(MAX) NOT NULL,
    DATOS_NUEVOS NVARCHAR(MAX) NOT NULL,

    CONSTRAINT PK_AUDITORIA
    PRIMARY KEY (AUDITORIA_ID),

    CONSTRAINT FK_AUDITORIA_ENTIDAD_AUDITADA
    FOREIGN KEY (ENTIDAD_AUDITADA_ID)
    REFERENCES DBO.ENTIDAD_AUDITADA (ENTIDAD_AUDITADA_ID),

    CONSTRAINT FK_AUDITORIA_TIPO_OPERACION
    FOREIGN KEY (TIPO_OPERACION_ID)
    REFERENCES DBO.TIPO_OPERACION (TIPO_OPERACION_ID)
);
GO
