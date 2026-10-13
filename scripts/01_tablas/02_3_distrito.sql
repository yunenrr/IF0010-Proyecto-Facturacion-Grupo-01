USE ProyectoFacturacion;
GO

CREATE TABLE dbo.distrito (
    distrito_id INT IDENTITY (1, 1) NOT NULL,
    canton_id INT NOT NULL,
    codigo_hacienda CHAR(2) NOT NULL,
    nombre VARCHAR(100) NOT NULL,

    CONSTRAINT pk_distrito
    PRIMARY KEY (distrito_id),

    CONSTRAINT uq_distrito_canton_codigo
    UNIQUE (canton_id, codigo_hacienda),

    CONSTRAINT uq_distrito_canton_nombre
    UNIQUE (canton_id, nombre),

    CONSTRAINT fk_distrito_canton
    FOREIGN KEY (canton_id)
    REFERENCES dbo.canton (canton_id)
);
GO
