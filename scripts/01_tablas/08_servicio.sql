CREATE TABLE dbo.servicio (
    servicio_id INT NOT NULL,
    unidad_medida VARCHAR(50) NOT NULL,

    CONSTRAINT pk_servicio
    PRIMARY KEY (servicio_id),

    CONSTRAINT fk_servicio_itemfacturable
    FOREIGN KEY (servicio_id)
    REFERENCES dbo.item_facturable (item_facturable_id)
);
GO
