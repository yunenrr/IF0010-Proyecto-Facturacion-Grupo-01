USE ProyectoFacturacion;
GO

CREATE TABLE dbo.empresaemisora (
    empresa_id INT IDENTITY (1, 1) NOT NULL,
    nombre_comercial VARCHAR(100) NOT NULL,
    razon_social VARCHAR(150) NOT NULL,
    cedula VARCHAR(20) NOT NULL,
    direccion VARCHAR(250) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL,
    fecha_creacion DATETIME2 NOT NULL,
    activa BIT NOT NULL,

    CONSTRAINT pk_empresaemisora
    PRIMARY KEY (empresa_id),

    CONSTRAINT uq_empresaemisora_cedula
    UNIQUE (cedula)
);
GO
