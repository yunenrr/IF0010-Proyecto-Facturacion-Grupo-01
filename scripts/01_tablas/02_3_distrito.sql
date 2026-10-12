USE C21626;
GO

CREATE TABLE dbo.distrito (
    distrito_id INT IDENTITY(1, 1) NOT NULL,
    canton_id INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    CONSTRAINT PK_distrito PRIMARY KEY (distrito_id),
    CONSTRAINT FK_distrito_canton FOREIGN KEY (canton_id) REFERENCES dbo.canton (canton_id)
);
GO
