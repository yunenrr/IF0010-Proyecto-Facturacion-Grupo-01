USE ProyectoFacturacion;
GO

CREATE TABLE dbo.unidad_medida (
    unidad_medida_id INT IDENTITY (1, 1) NOT NULL,
    descripcion VARCHAR(50) NOT NULL,

    CONSTRAINT pk_unidad_medida
    PRIMARY KEY (unidad_medida_id),

    CONSTRAINT uq_unidad_medida_descripcion
    UNIQUE (descripcion)
);
GO
