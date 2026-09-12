CREATE TABLE dbo.TipoDocumento (
    tipo_documento_id INT IDENTITY(1,1) NOT NULL,
    codigo VARCHAR(10) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,

    CONSTRAINT PK_TipoDocumento
        PRIMARY KEY (tipo_documento_id),

    CONSTRAINT UQ_TipoDocumento_Codigo
        UNIQUE (codigo)
);
GO
