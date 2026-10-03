CREATE TABLE dbo.tipo_operacion (
    tipo_operacion_id INT IDENTITY (1, 1) NOT NULL,
    descripcion VARCHAR(20) NOT NULL,

    CONSTRAINT pk_tipo_operacion
    PRIMARY KEY (tipo_operacion_id),

    CONSTRAINT uq_tipo_operacion_descripcion
    UNIQUE (descripcion)
);
GO
