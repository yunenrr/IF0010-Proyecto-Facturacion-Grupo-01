CREATE TABLE dbo.cliente (
    cliente_id BIGINT IDENTITY (1, 1) NOT NULL,
    cedula VARCHAR(20) NOT NULL,
    tipo_cliente VARCHAR(10) NOT NULL,
    nombre VARCHAR(150) NULL,
    razon_social VARCHAR(150) NULL,
    direccion VARCHAR(250) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL,
    fecha_registro DATETIME2 NOT NULL
    CONSTRAINT df_cliente_fecharegistro
    DEFAULT SYSDATETIME(),
    fecha_ultima_actualizacion DATETIME2 NOT NULL
    CONSTRAINT df_cliente_fechaultimaactualizacion
    DEFAULT SYSDATETIME(),

    CONSTRAINT pk_cliente
    PRIMARY KEY (cliente_id),

    CONSTRAINT uq_cliente_cedula
    UNIQUE (cedula),

    CONSTRAINT ck_cliente_tipocliente
    CHECK (tipo_cliente IN ('FISICA', 'JURIDICA')),

    CONSTRAINT ck_cliente_nombre_razonsocial
    CHECK (
        (
            tipo_cliente = 'FISICA'
            AND nombre IS NOT NULL
            AND razon_social IS NULL
        )
        OR (
            tipo_cliente = 'JURIDICA'
            AND nombre IS NULL
            AND razon_social IS NOT NULL
        )
    )
);
GO
