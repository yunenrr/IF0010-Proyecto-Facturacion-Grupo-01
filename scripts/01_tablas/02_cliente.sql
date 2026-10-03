CREATE TABLE dbo.cliente (
    cliente_id BIGINT IDENTITY (1, 1) NOT NULL,
    cedula VARCHAR(20) NOT NULL,
    tipo_persona CHAR(1) NOT NULL,
    
    nombre VARCHAR(100) NULL,
    apellidos VARCHAR(150) NULL,
    razon_social VARCHAR(150) NULL,
    
    direccion VARCHAR(250) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL,
    fecha_registro DATETIME2 NOT NULL,
    fecha_ultima_actualizacion DATETIME2 NOT NULL,

    CONSTRAINT pk_cliente
    PRIMARY KEY (cliente_id),

    CONSTRAINT uq_cliente_cedula
    UNIQUE (cedula)
);
GO
