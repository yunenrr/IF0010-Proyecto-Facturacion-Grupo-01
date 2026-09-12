CREATE TABLE dbo.auditoria (
    auditoria_id BIGINT IDENTITY (1, 1) NOT NULL,
    nombre_tabla VARCHAR(100) NOT NULL,
    registro_id BIGINT NOT NULL,
    operacion VARCHAR(10) NOT NULL,

    valor_anterior VARCHAR(MAX) NULL,
    valor_nuevo VARCHAR(MAX) NULL,

    usuario_sql VARCHAR(128) NOT NULL
        CONSTRAINT df_auditoria_usuario
        DEFAULT SUSER_SNAME(),

    fecha_evento DATETIME2 NOT NULL
        CONSTRAINT df_auditoria_fechaevento
        DEFAULT SYSDATETIME(),

    descripcion VARCHAR(500) NULL,

    CONSTRAINT pk_auditoria
        PRIMARY KEY (auditoria_id),

    CONSTRAINT ck_auditoria_operacion
        CHECK (
            operacion IN ('INSERT', 'UPDATE', 'DELETE')
        )
);
GO
