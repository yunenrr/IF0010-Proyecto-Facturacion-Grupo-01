USE ProyectoFacturacion;
GO

-- Audita lineas de detalle que modifican el calculo financiero de la factura.
-- Usuario: ORIGINAL_LOGIN() (login autenticado en SQL Server). Fecha: SYSDATETIME().
-- Se ejecuta dentro de la transaccion del cambio: si el cambio se revierte, la
-- fila de auditoria tambien. Opera por conjuntos (multiples filas por sentencia).

DROP TRIGGER IF EXISTS dbo.trg_factura_detalle_auditoria_insert;
GO

CREATE TRIGGER dbo.trg_factura_detalle_auditoria_insert
    ON dbo.factura_detalle
    AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'FACTURA_DETALLE'
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
        i.factura_detalle_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('INSERT factura_detalle ', i.factura_detalle_id, ': ', 'factura ', i.factura_id, ', linea ', i.numero_linea, ', cantidad ', i.cantidad, ', total ', i.monto_total), 1000),
        N'{}',
        (SELECT i.factura_detalle_id, i.factura_id, i.item_facturable_id, i.numero_linea, i.descripcion, i.cantidad, i.precio_unitario, i.porcentaje_impuesto, i.monto_subtotal, i.monto_descuento, i.monto_impuesto, i.monto_total FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_factura_detalle_auditoria_delete;
GO

CREATE TRIGGER dbo.trg_factura_detalle_auditoria_delete
    ON dbo.factura_detalle
    AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'FACTURA_DETALLE'
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
        d.factura_detalle_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('DELETE factura_detalle ', d.factura_detalle_id, ': ', 'factura ', d.factura_id, ', linea ', d.numero_linea, ', cantidad ', d.cantidad, ', total ', d.monto_total), 1000),
        (SELECT d.factura_detalle_id, d.factura_id, d.item_facturable_id, d.numero_linea, d.descripcion, d.cantidad, d.precio_unitario, d.porcentaje_impuesto, d.monto_subtotal, d.monto_descuento, d.monto_impuesto, d.monto_total FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        N'{}'
    FROM deleted AS d;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_factura_detalle_auditoria_update;
GO

CREATE TRIGGER dbo.trg_factura_detalle_auditoria_update
    ON dbo.factura_detalle
    AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'FACTURA_DETALLE'
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
        i.factura_detalle_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('UPDATE factura_detalle ', i.factura_detalle_id, ': ',
        IIF(d.item_facturable_id <> i.item_facturable_id, CONCAT('item_facturable_id ', d.item_facturable_id, ' -> ', i.item_facturable_id, '; '), ''),
        IIF(d.cantidad <> i.cantidad, CONCAT('cantidad ', d.cantidad, ' -> ', i.cantidad, '; '), ''),
        IIF(d.precio_unitario <> i.precio_unitario, CONCAT('precio_unitario ', d.precio_unitario, ' -> ', i.precio_unitario, '; '), ''),
        IIF(d.porcentaje_impuesto <> i.porcentaje_impuesto, CONCAT('porcentaje_impuesto ', d.porcentaje_impuesto, ' -> ', i.porcentaje_impuesto, '; '), ''),
        IIF(d.monto_subtotal <> i.monto_subtotal, CONCAT('monto_subtotal ', d.monto_subtotal, ' -> ', i.monto_subtotal, '; '), ''),
        IIF(d.monto_descuento <> i.monto_descuento, CONCAT('monto_descuento ', d.monto_descuento, ' -> ', i.monto_descuento, '; '), ''),
        IIF(d.monto_impuesto <> i.monto_impuesto, CONCAT('monto_impuesto ', d.monto_impuesto, ' -> ', i.monto_impuesto, '; '), ''),
        IIF(d.monto_total <> i.monto_total, CONCAT('monto_total ', d.monto_total, ' -> ', i.monto_total, '; '), '')), 1000),
        (SELECT d.factura_detalle_id, d.factura_id, d.item_facturable_id, d.numero_linea, d.descripcion, d.cantidad, d.precio_unitario, d.porcentaje_impuesto, d.monto_subtotal, d.monto_descuento, d.monto_impuesto, d.monto_total FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.factura_detalle_id, i.factura_id, i.item_facturable_id, i.numero_linea, i.descripcion, i.cantidad, i.precio_unitario, i.porcentaje_impuesto, i.monto_subtotal, i.monto_descuento, i.monto_impuesto, i.monto_total FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i
    INNER JOIN deleted AS d
        ON d.factura_detalle_id = i.factura_detalle_id
    WHERE d.item_facturable_id <> i.item_facturable_id OR d.cantidad <> i.cantidad OR d.precio_unitario <> i.precio_unitario OR d.porcentaje_impuesto <> i.porcentaje_impuesto OR d.monto_subtotal <> i.monto_subtotal OR d.monto_descuento <> i.monto_descuento OR d.monto_impuesto <> i.monto_impuesto OR d.monto_total <> i.monto_total;
END;
GO
