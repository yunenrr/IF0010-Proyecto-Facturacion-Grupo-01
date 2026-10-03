CREATE TABLE dbo.item_facturable (
    item_facturable_id INT IDENTITY (1, 1) NOT NULL,
    codigo_interno VARCHAR(30) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,
    activo BIT NOT NULL,
    fecha_creacion DATETIME2 NOT NULL,

    CONSTRAINT pk_itemfacturable
    PRIMARY KEY (item_facturable_id),

    CONSTRAINT uq_itemfacturable_codigo
    UNIQUE (codigo_interno)
);
GO
