USE ProyectoFacturacion;
GO

CREATE TABLE dbo.provincia (
    provincia_id INT IDENTITY (1, 1) NOT NULL,
    codigo_hacienda CHAR(1) NOT NULL,
    nombre VARCHAR(100) NOT NULL,

    CONSTRAINT pk_provincia
    PRIMARY KEY (provincia_id),

    CONSTRAINT uq_provincia_codigo_hacienda
    UNIQUE (codigo_hacienda),

    CONSTRAINT uq_provincia_nombre
    UNIQUE (nombre)
);
GO
