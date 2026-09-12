CREATE TABLE dbo.tipodocumento (
    tipo_documento_id INT IDENTITY (1, 1) NOT NULL,
    codigo VARCHAR(10) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,

    CONSTRAINT pk_tipodocumento
        PRIMARY KEY (tipo_documento_id),

    CONSTRAINT uq_tipodocumento_codigo
        UNIQUE (codigo)
);
GO
