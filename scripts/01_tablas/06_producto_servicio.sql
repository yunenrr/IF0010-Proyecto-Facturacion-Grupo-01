CREATE TABLE dbo.productoservicio (
    producto_servicio_id INT IDENTITY (1, 1) NOT NULL,
    codigo_interno VARCHAR(30) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,
    activo BIT NOT NULL
        CONSTRAINT df_productoservicio_activo
        DEFAULT 1,
    fecha_creacion DATETIME2 NOT NULL
        CONSTRAINT df_productoservicio_fechacreacion
        DEFAULT SYSDATETIME(),

    CONSTRAINT pk_productoservicio
        PRIMARY KEY (producto_servicio_id),

    CONSTRAINT uq_productoservicio_codigo
        UNIQUE (codigo_interno),

    CONSTRAINT ck_productoservicio_precio
        CHECK (precio_unitario >= 0),

    CONSTRAINT ck_productoservicio_impuesto
        CHECK (
            porcentaje_impuesto >= 0
            AND porcentaje_impuesto <= 100
        )
);
GO
