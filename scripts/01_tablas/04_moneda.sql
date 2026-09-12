CREATE TABLE dbo.Moneda (
    moneda_id INT IDENTITY(1,1) NOT NULL,
    codigo CHAR(3) NOT NULL,
    simbolo VARCHAR(10) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,

    CONSTRAINT PK_Moneda
        PRIMARY KEY (moneda_id),

    CONSTRAINT UQ_Moneda_Codigo
        UNIQUE (codigo)
);
GO
