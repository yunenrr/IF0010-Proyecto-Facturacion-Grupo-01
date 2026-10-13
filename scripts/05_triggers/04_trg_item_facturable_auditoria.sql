USE ProyectoFacturacion;
GO

-- Audita el precio de lista y el porcentaje de impuesto de productos y servicios.
-- Usuario: ORIGINAL_LOGIN() (login autenticado en SQL Server). Fecha: SYSDATETIME().
-- Se ejecuta dentro de la transaccion del cambio: si el cambio se revierte, la
-- fila de auditoria tambien. Opera por conjuntos (multiples filas por sentencia).

DROP TRIGGER IF EXISTS dbo.trg_item_facturable_auditoria_insert;
GO

CREATE TRIGGER dbo.trg_item_facturable_auditoria_insert
    ON dbo.item_facturable
    AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'ITEM_FACTURABLE'
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
        i.item_facturable_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('INSERT item_facturable ', i.item_facturable_id, ': ', 'codigo ', i.codigo_interno, ', precio ', i.precio_unitario, ', impuesto ', i.porcentaje_impuesto), 1000),
        N'{}',
        (SELECT i.item_facturable_id, i.codigo_interno, i.descripcion, i.precio_unitario, i.porcentaje_impuesto, i.activo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_item_facturable_auditoria_delete;
GO

CREATE TRIGGER dbo.trg_item_facturable_auditoria_delete
    ON dbo.item_facturable
    AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'ITEM_FACTURABLE'
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
        d.item_facturable_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('DELETE item_facturable ', d.item_facturable_id, ': ', 'codigo ', d.codigo_interno, ', precio ', d.precio_unitario, ', impuesto ', d.porcentaje_impuesto), 1000),
        (SELECT d.item_facturable_id, d.codigo_interno, d.descripcion, d.precio_unitario, d.porcentaje_impuesto, d.activo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        N'{}'
    FROM deleted AS d;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_item_facturable_auditoria_update;
GO

CREATE TRIGGER dbo.trg_item_facturable_auditoria_update
    ON dbo.item_facturable
    AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'ITEM_FACTURABLE'
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
        i.item_facturable_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('UPDATE item_facturable ', i.item_facturable_id, ': ',
        IIF(d.precio_unitario <> i.precio_unitario, CONCAT('precio_unitario ', d.precio_unitario, ' -> ', i.precio_unitario, '; '), ''),
        IIF(d.porcentaje_impuesto <> i.porcentaje_impuesto, CONCAT('porcentaje_impuesto ', d.porcentaje_impuesto, ' -> ', i.porcentaje_impuesto, '; '), '')), 1000),
        (SELECT d.item_facturable_id, d.codigo_interno, d.descripcion, d.precio_unitario, d.porcentaje_impuesto, d.activo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.item_facturable_id, i.codigo_interno, i.descripcion, i.precio_unitario, i.porcentaje_impuesto, i.activo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i
    INNER JOIN deleted AS d
        ON d.item_facturable_id = i.item_facturable_id
    WHERE d.precio_unitario <> i.precio_unitario OR d.porcentaje_impuesto <> i.porcentaje_impuesto;
END;
GO
