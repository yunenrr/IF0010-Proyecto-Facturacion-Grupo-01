CREATE TABLE dbo.moneda (
    moneda_id INT IDENTITY (1, 1) NOT NULL,
    codigo CHAR(3) NOT NULL,
    simbolo VARCHAR(10) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,

    CONSTRAINT pk_moneda
    PRIMARY KEY (moneda_id),

    CONSTRAINT uq_moneda_codigo
    UNIQUE (codigo)
);
GO
