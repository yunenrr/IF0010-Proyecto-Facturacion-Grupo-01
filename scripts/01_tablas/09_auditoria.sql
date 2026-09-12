CREATE TABLE dbo.Auditoria (
    auditoria_id BIGINT IDENTITY(1,1) NOT NULL,

    nombre_tabla VARCHAR(100) NOT NULL,
    registro_id BIGINT NOT NULL,
    operacion VARCHAR(10) NOT NULL,

    valor_anterior VARCHAR(MAX) NULL,
    valor_nuevo VARCHAR(MAX) NULL,

    usuario_sql VARCHAR(128) NOT NULL
        CONSTRAINT DF_Auditoria_Usuario
        DEFAULT SUSER_SNAME(),

    fecha_evento DATETIME2 NOT NULL
        CONSTRAINT DF_Auditoria_FechaEvento
        DEFAULT SYSDATETIME(),

    descripcion VARCHAR(500) NULL,

    CONSTRAINT PK_Auditoria
        PRIMARY KEY (auditoria_id),

    CONSTRAINT CK_Auditoria_Operacion
        CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO
