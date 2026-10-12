USE C21626;
GO

CREATE TABLE dbo.canton (
    canton_id INT IDENTITY(1, 1) NOT NULL,
    provincia_id INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    CONSTRAINT PK_canton PRIMARY KEY (canton_id),
    CONSTRAINT FK_canton_provincia FOREIGN KEY (provincia_id) REFERENCES dbo.provincia (provincia_id)
);
GO
