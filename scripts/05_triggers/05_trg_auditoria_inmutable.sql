USE PROYECTOFACTURACION;
GO

-- El historial es de solo agregar: ningun UPDATE ni DELETE sobre auditoria.
-- INSTEAD OF evita el cambio y avisa; la transaccion que lo intento se
-- revierte.
-- (TRUNCATE TABLE, DROP o DISABLE TRIGGER siguen requiriendo permisos de
-- administracion; no se conceden a usuarios de la aplicacion.)
DROP TRIGGER IF EXISTS DBO.TRG_AUDITORIA_INMUTABLE;
GO

CREATE TRIGGER DBO.TRG_AUDITORIA_INMUTABLE
ON DBO.AUDITORIA
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 50502,
    'La auditoria es inmutable: no se permite modificar ni eliminar su historial.', -- noqa: LT05
    1;
END;
GO
