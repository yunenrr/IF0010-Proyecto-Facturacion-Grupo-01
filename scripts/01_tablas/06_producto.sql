CREATE TABLE dbo.producto (
    producto_id INT IDENTITY (1, 1) NOT NULL,
    codigo_interno VARCHAR(30) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,
    existencia INT NOT NULL
    CONSTRAINT df_producto_existencia
    DEFAULT 0,
    activo BIT NOT NULL
    CONSTRAINT df_producto_activo
    DEFAULT 1,
    fecha_creacion DATETIME2 NOT NULL
    CONSTRAINT df_producto_fechacreacion
    DEFAULT SYSDATETIME(),

    CONSTRAINT pk_producto
    PRIMARY KEY (producto_id),

    CONSTRAINT uq_producto_codigo
    UNIQUE (codigo_interno),

    CONSTRAINT ck_producto_precio
    CHECK (precio_unitario >= 0),

    CONSTRAINT ck_producto_impuesto
    CHECK (porcentaje_impuesto >= 0 AND porcentaje_impuesto <= 100),

    CONSTRAINT ck_producto_existencia
    CHECK (existencia >= 0)
);
GO
