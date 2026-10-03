CREATE TABLE dbo.servicio (
    servicio_id INT NOT NULL,
    unidad_medida_id INT NOT NULL,

    CONSTRAINT pk_servicio
    PRIMARY KEY (servicio_id),

    CONSTRAINT fk_servicio_item_facturable
    FOREIGN KEY (servicio_id)
    REFERENCES dbo.item_facturable (item_facturable_id),

    CONSTRAINT fk_servicio_unidad_medida
    FOREIGN KEY (unidad_medida_id)
    REFERENCES dbo.unidad_medida (unidad_medida_id)
);
GO
