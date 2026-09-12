CREATE TABLE dbo.Cliente (
    cliente_id BIGINT IDENTITY(1,1) NOT NULL,
    cedula VARCHAR(20) NOT NULL,
    nombre_razon_social VARCHAR(150) NOT NULL,
    direccion VARCHAR(250) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL,
    fecha_registro DATETIME2 NOT NULL
        CONSTRAINT DF_Cliente_FechaRegistro
        DEFAULT SYSDATETIME(),
    fecha_ultima_actualizacion DATETIME2 NOT NULL
        CONSTRAINT DF_Cliente_FechaUltimaActualizacion
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Cliente
        PRIMARY KEY (cliente_id),

    CONSTRAINT UQ_Cliente_Cedula
        UNIQUE (cedula)
);
GO
