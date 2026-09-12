CREATE TABLE dbo.EmpresaEmisora (
    empresa_id INT IDENTITY(1,1) NOT NULL,
    nombre_comercial VARCHAR(100) NOT NULL,
    razon_social VARCHAR(150) NOT NULL,
    cedula VARCHAR(20) NOT NULL,
    direccion VARCHAR(250) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL,
    fecha_creacion DATETIME2 NOT NULL
        CONSTRAINT DF_EmpresaEmisora_FechaCreacion
        DEFAULT SYSDATETIME(),
    activa BIT NOT NULL
        CONSTRAINT DF_EmpresaEmisora_Activa
        DEFAULT 1,

    CONSTRAINT PK_EmpresaEmisora
        PRIMARY KEY (empresa_id),

    CONSTRAINT UQ_EmpresaEmisora_Cedula
        UNIQUE (cedula)
);
GO
