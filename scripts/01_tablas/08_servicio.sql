CREATE TABLE dbo.servicio (
    servicio_id INT NOT NULL,
    codigo_interno VARCHAR(30) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,
    unidad_medida_id INT NOT NULL,
    activo BIT NOT NULL,
    fecha_creacion DATETIME2 NOT NULL,

    CONSTRAINT pk_servicio
    PRIMARY KEY (servicio_id),

    CONSTRAINT uq_servicio_codigo
    UNIQUE (codigo_interno),

    CONSTRAINT fk_servicio_item_facturable
    FOREIGN KEY (servicio_id)
    REFERENCES dbo.item_facturable (item_facturable_id),

    CONSTRAINT fk_servicio_unidad_medida
    FOREIGN KEY (unidad_medida_id)
    REFERENCES dbo.unidad_medida (unidad_medida_id)
);
GO

CREATE NONCLUSTERED INDEX ix_servicio_unidad_medida
ON dbo.servicio (unidad_medida_id);
GO
