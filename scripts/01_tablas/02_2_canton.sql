USE ProyectoFacturacion;
GO

CREATE TABLE dbo.canton (
    canton_id INT IDENTITY (1, 1) NOT NULL,
    provincia_id INT NOT NULL,
    codigo_hacienda CHAR(2) NOT NULL,
    nombre VARCHAR(100) NOT NULL,

    CONSTRAINT pk_canton
    PRIMARY KEY (canton_id),

    CONSTRAINT uq_canton_provincia_codigo
    UNIQUE (provincia_id, codigo_hacienda),

    CONSTRAINT uq_canton_provincia_nombre
    UNIQUE (provincia_id, nombre),

    CONSTRAINT fk_canton_provincia
    FOREIGN KEY (provincia_id)
    REFERENCES dbo.provincia (provincia_id)
);
GO
