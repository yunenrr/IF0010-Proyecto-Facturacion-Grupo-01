USE ProyectoFacturacion;
GO

-- Audita la identificacion (cedula), el correo y el telefono del comprador.
-- Usuario: ORIGINAL_LOGIN() (login autenticado en SQL Server). Fecha: SYSDATETIME().
-- Se ejecuta dentro de la transaccion del cambio: si el cambio se revierte, la
-- fila de auditoria tambien. Opera por conjuntos (multiples filas por sentencia).

DROP TRIGGER IF EXISTS dbo.trg_cliente_auditoria_insert;
GO

CREATE TRIGGER dbo.trg_cliente_auditoria_insert
    ON dbo.cliente
    AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'CLIENTE'
    );
    DECLARE @operacion_id INT = (
        SELECT tipo_operacion_id FROM dbo.tipo_operacion WHERE descripcion = 'INSERT'
    );

    IF @entidad_id IS NULL OR @operacion_id IS NULL
    BEGIN
        THROW 50501, 'Catalogos de auditoria incompletos: ejecute usp_cargar_catalogos.', 1;
    END

    INSERT INTO dbo.auditoria (
        entidad_auditada_id, registro_id, tipo_operacion_id, usuario, fecha_cambio,
        descripcion, datos_anteriores, datos_nuevos
    )
    SELECT
        @entidad_id,
        i.cliente_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('INSERT cliente ', i.cliente_id, ': ', 'identificacion ', i.identificacion, ', correo ', i.correo, ', telefono ', i.telefono), 1000),
        N'{}',
        (SELECT i.cliente_id, i.identificacion, i.correo, i.telefono, i.distrito_id, i.otras_senas FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_cliente_auditoria_delete;
GO

CREATE TRIGGER dbo.trg_cliente_auditoria_delete
    ON dbo.cliente
    AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'CLIENTE'
    );
    DECLARE @operacion_id INT = (
        SELECT tipo_operacion_id FROM dbo.tipo_operacion WHERE descripcion = 'DELETE'
    );

    IF @entidad_id IS NULL OR @operacion_id IS NULL
    BEGIN
        THROW 50501, 'Catalogos de auditoria incompletos: ejecute usp_cargar_catalogos.', 1;
    END

    INSERT INTO dbo.auditoria (
        entidad_auditada_id, registro_id, tipo_operacion_id, usuario, fecha_cambio,
        descripcion, datos_anteriores, datos_nuevos
    )
    SELECT
        @entidad_id,
        d.cliente_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('DELETE cliente ', d.cliente_id, ': ', 'identificacion ', d.identificacion, ', correo ', d.correo, ', telefono ', d.telefono), 1000),
        (SELECT d.cliente_id, d.identificacion, d.correo, d.telefono, d.distrito_id, d.otras_senas FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        N'{}'
    FROM deleted AS d;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_cliente_auditoria_update;
GO

CREATE TRIGGER dbo.trg_cliente_auditoria_update
    ON dbo.cliente
    AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'CLIENTE'
    );
    DECLARE @operacion_id INT = (
        SELECT tipo_operacion_id FROM dbo.tipo_operacion WHERE descripcion = 'UPDATE'
    );

    IF @entidad_id IS NULL OR @operacion_id IS NULL
    BEGIN
        THROW 50501, 'Catalogos de auditoria incompletos: ejecute usp_cargar_catalogos.', 1;
    END

    INSERT INTO dbo.auditoria (
        entidad_auditada_id, registro_id, tipo_operacion_id, usuario, fecha_cambio,
        descripcion, datos_anteriores, datos_nuevos
    )
    SELECT
        @entidad_id,
        i.cliente_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('UPDATE cliente ', i.cliente_id, ': ',
        IIF(d.identificacion <> i.identificacion, CONCAT('identificacion ', d.identificacion, ' -> ', i.identificacion, '; '), ''),
        IIF(d.correo <> i.correo, CONCAT('correo ', d.correo, ' -> ', i.correo, '; '), ''),
        IIF(d.telefono <> i.telefono, CONCAT('telefono ', d.telefono, ' -> ', i.telefono, '; '), '')), 1000),
        (SELECT d.cliente_id, d.identificacion, d.correo, d.telefono, d.distrito_id, d.otras_senas FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.cliente_id, i.identificacion, i.correo, i.telefono, i.distrito_id, i.otras_senas FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i
    INNER JOIN deleted AS d
        ON d.cliente_id = i.cliente_id
    WHERE d.identificacion <> i.identificacion OR d.correo <> i.correo OR d.telefono <> i.telefono;
END;
GO
