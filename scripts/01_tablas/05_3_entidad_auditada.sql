USE ProyectoFacturacion;
GO

-- Catalogo de las entidades cuyos cambios se auditan (FACTURA, FACTURA_DETALLE,
-- CLIENTE, ITEM_FACTURABLE). Evita repetir el nombre de la entidad como texto
-- en cada fila de auditoria.
CREATE TABLE dbo.entidad_auditada (
    entidad_auditada_id INT IDENTITY (1, 1) NOT NULL,
    nombre VARCHAR(30) NOT NULL,

    CONSTRAINT pk_entidad_auditada
    PRIMARY KEY (entidad_auditada_id),

    CONSTRAINT uq_entidad_auditada_nombre
    UNIQUE (nombre)
);
GO
