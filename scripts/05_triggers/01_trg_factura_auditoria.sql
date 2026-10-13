USE ProyectoFacturacion;
GO

-- Audita cambios de estado y de montos del encabezado del comprobante.
-- Usuario: ORIGINAL_LOGIN() (login autenticado en SQL Server). Fecha: SYSDATETIME().
-- Se ejecuta dentro de la transaccion del cambio: si el cambio se revierte, la
-- fila de auditoria tambien. Opera por conjuntos (multiples filas por sentencia).

DROP TRIGGER IF EXISTS dbo.trg_factura_auditoria_insert;
GO

CREATE TRIGGER dbo.trg_factura_auditoria_insert
    ON dbo.factura
    AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'FACTURA'
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
        i.factura_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('INSERT factura ', i.factura_id, ': ', 'numero ', i.numero_factura, ', estado ', e.codigo, ', total ', i.monto_total), 1000),
        N'{}',
        (SELECT i.factura_id, i.empresa_id, i.cliente_id, i.tipo_documento_id, i.moneda_id, i.estado_factura_id, i.numero_factura, i.fecha_emision, i.tipo_cambio, i.monto_subtotal, i.monto_descuento, i.monto_impuesto, i.monto_total, i.observaciones, e.codigo AS estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i
    INNER JOIN dbo.estadofactura AS e
        ON e.estado_factura_id = i.estado_factura_id;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_factura_auditoria_delete;
GO

CREATE TRIGGER dbo.trg_factura_auditoria_delete
    ON dbo.factura
    AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'FACTURA'
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
        d.factura_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('DELETE factura ', d.factura_id, ': ', 'numero ', d.numero_factura, ', estado ', e.codigo, ', total ', d.monto_total), 1000),
        (SELECT d.factura_id, d.empresa_id, d.cliente_id, d.tipo_documento_id, d.moneda_id, d.estado_factura_id, d.numero_factura, d.fecha_emision, d.tipo_cambio, d.monto_subtotal, d.monto_descuento, d.monto_impuesto, d.monto_total, d.observaciones, e.codigo AS estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        N'{}'
    FROM deleted AS d
    INNER JOIN dbo.estadofactura AS e
        ON e.estado_factura_id = d.estado_factura_id;
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_factura_auditoria_update;
GO

CREATE TRIGGER dbo.trg_factura_auditoria_update
    ON dbo.factura
    AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT entidad_auditada_id FROM dbo.entidad_auditada WHERE nombre = 'FACTURA'
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
        i.factura_id,
        @operacion_id,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        LEFT(CONCAT('UPDATE factura ', i.factura_id, ': ',
        IIF(d.estado_factura_id <> i.estado_factura_id, CONCAT('estado ', eo.codigo, ' -> ', en.codigo, '; '), ''),
        IIF(d.monto_subtotal <> i.monto_subtotal, CONCAT('monto_subtotal ', d.monto_subtotal, ' -> ', i.monto_subtotal, '; '), ''),
        IIF(d.monto_descuento <> i.monto_descuento, CONCAT('monto_descuento ', d.monto_descuento, ' -> ', i.monto_descuento, '; '), ''),
        IIF(d.monto_impuesto <> i.monto_impuesto, CONCAT('monto_impuesto ', d.monto_impuesto, ' -> ', i.monto_impuesto, '; '), ''),
        IIF(d.monto_total <> i.monto_total, CONCAT('monto_total ', d.monto_total, ' -> ', i.monto_total, '; '), '')), 1000),
        (SELECT d.factura_id, d.empresa_id, d.cliente_id, d.tipo_documento_id, d.moneda_id, d.estado_factura_id, d.numero_factura, d.fecha_emision, d.tipo_cambio, d.monto_subtotal, d.monto_descuento, d.monto_impuesto, d.monto_total, d.observaciones, eo.codigo AS estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.factura_id, i.empresa_id, i.cliente_id, i.tipo_documento_id, i.moneda_id, i.estado_factura_id, i.numero_factura, i.fecha_emision, i.tipo_cambio, i.monto_subtotal, i.monto_descuento, i.monto_impuesto, i.monto_total, i.observaciones, en.codigo AS estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i
    INNER JOIN deleted AS d
        ON d.factura_id = i.factura_id
    INNER JOIN dbo.estadofactura AS eo
        ON eo.estado_factura_id = d.estado_factura_id
    INNER JOIN dbo.estadofactura AS en
        ON en.estado_factura_id = i.estado_factura_id
    WHERE d.estado_factura_id <> i.estado_factura_id OR d.monto_subtotal <> i.monto_subtotal OR d.monto_descuento <> i.monto_descuento OR d.monto_impuesto <> i.monto_impuesto OR d.monto_total <> i.monto_total;
END;
GO
