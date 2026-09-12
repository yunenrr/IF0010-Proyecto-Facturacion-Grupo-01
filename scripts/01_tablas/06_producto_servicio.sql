CREATE TABLE dbo.ProductoServicio (
    producto_servicio_id INT IDENTITY(1,1) NOT NULL,
    codigo_interno VARCHAR(30) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    precio_unitario DECIMAL(18,2) NOT NULL,
    porcentaje_impuesto DECIMAL(5,2) NOT NULL,
    activo BIT NOT NULL
        CONSTRAINT DF_ProductoServicio_Activo
        DEFAULT 1,
    fecha_creacion DATETIME2 NOT NULL
        CONSTRAINT DF_ProductoServicio_FechaCreacion
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_ProductoServicio
        PRIMARY KEY (producto_servicio_id),

    CONSTRAINT UQ_ProductoServicio_Codigo
        UNIQUE (codigo_interno),

    CONSTRAINT CK_ProductoServicio_Precio
        CHECK (precio_unitario >= 0),

    CONSTRAINT CK_ProductoServicio_Impuesto
        CHECK (porcentaje_impuesto >= 0 AND porcentaje_impuesto <= 100)
);
GO
