CREATE TABLE dbo.servicio (
    servicio_id INT IDENTITY (1, 1) NOT NULL,
    codigo_interno VARCHAR(30) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,
    unidad_medida VARCHAR(50) NOT NULL,
    activo BIT NOT NULL
    CONSTRAINT df_servicio_activo
    DEFAULT 1,
    fecha_creacion DATETIME2 NOT NULL
    CONSTRAINT df_servicio_fechacreacion
    DEFAULT SYSDATETIME(),

    CONSTRAINT pk_servicio
    PRIMARY KEY (servicio_id),

    CONSTRAINT uq_servicio_codigo
    UNIQUE (codigo_interno),

    CONSTRAINT ck_servicio_precio
    CHECK (precio_unitario >= 0),

    CONSTRAINT ck_servicio_impuesto
    CHECK (porcentaje_impuesto >= 0 AND porcentaje_impuesto <= 100)
);
GO
