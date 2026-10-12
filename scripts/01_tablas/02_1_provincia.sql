USE C21626;
GO

CREATE TABLE dbo.provincia (
    provincia_id INT IDENTITY(1, 1) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    CONSTRAINT PK_provincia PRIMARY KEY (provincia_id),
    CONSTRAINT UQ_provincia_nombre UNIQUE (nombre)
);
GO
