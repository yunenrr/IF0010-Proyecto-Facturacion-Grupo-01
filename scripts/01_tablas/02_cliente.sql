USE C21626;
GO

CREATE TABLE dbo.cliente (
    cliente_id INT IDENTITY(1, 1) NOT NULL,
    identificacion VARCHAR(20) NOT NULL,
    tipo_persona CHAR(1) NOT NULL,
    correo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    distrito_id INT NOT NULL,
    otras_senas VARCHAR(250) NOT NULL,
    CONSTRAINT PK_cliente PRIMARY KEY (cliente_id),
    CONSTRAINT UQ_cliente_identificacion UNIQUE (identificacion),
    CONSTRAINT FK_cliente_distrito FOREIGN KEY (distrito_id) REFERENCES dbo.distrito (distrito_id)
);
GO

CREATE TABLE dbo.cliente_fisico (
    cliente_id INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    apellido1 VARCHAR(50) NOT NULL,
    apellido2 VARCHAR(50) NOT NULL,
    CONSTRAINT PK_cliente_fisico PRIMARY KEY (cliente_id),
    CONSTRAINT FK_clientefisico_cliente FOREIGN KEY (cliente_id) REFERENCES dbo.cliente (cliente_id)
);
GO

CREATE TABLE dbo.cliente_juridico (
    cliente_id INT NOT NULL,
    razon_social VARCHAR(150) NOT NULL,
    nombre_comercial VARCHAR(150) NOT NULL,
    CONSTRAINT PK_cliente_juridico PRIMARY KEY (cliente_id),
    CONSTRAINT FK_clientejuridico_cliente FOREIGN KEY (cliente_id) REFERENCES dbo.cliente (cliente_id)
);
GO
