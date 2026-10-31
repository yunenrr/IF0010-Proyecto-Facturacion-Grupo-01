USE PROYECTOFACTURACION;
GO

-- Audita cambios de estado y de montos del encabezado del comprobante.
-- Usuario: ORIGINAL_LOGIN() (login autenticado en SQL Server). Fecha:
-- SYSDATETIME().
-- Se ejecuta dentro de la transaccion del cambio: si el cambio se revierte, la
-- fila de auditoria tambien. Opera por conjuntos (multiples filas por
-- sentencia).

DROP TRIGGER IF EXISTS DBO.TRG_FACTURA_AUDITORIA_INSERT;
GO

CREATE TRIGGER DBO.TRG_FACTURA_AUDITORIA_INSERT
ON DBO.FACTURA
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'FACTURA'
    );
    DECLARE @operacion_id INT = (
        SELECT TIPO_OPERACION_ID
        FROM DBO.TIPO_OPERACION
        WHERE DESCRIPCION = 'INSERT'
    );

    IF @entidad_id IS NULL OR @operacion_id IS NULL
        BEGIN
            THROW 50501,
            'Catalogos de auditoria incompletos: ejecute usp_cargar_catalogos.',
            1;
        END

    INSERT INTO DBO.AUDITORIA (
        ENTIDAD_AUDITADA_ID,
        REGISTRO_ID,
        TIPO_OPERACION_ID,
        USUARIO,
        FECHA_CAMBIO,
        DESCRIPCION, DATOS_ANTERIORES, DATOS_NUEVOS
    )
    SELECT
        @entidad_id AS ENTIDAD_AUDITADA_ID,
        I.FACTURA_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'INSERT factura ',
                I.FACTURA_ID,
                ': ',
                'numero ',
                I.NUMERO_FACTURA,
                ', estado ',
                E.CODIGO,
                ', total ',
                I.MONTO_TOTAL
            ),
            1000
        ) AS DESCRIPCION,
        N'{}' AS DATOS_ANTERIORES,
        (
            SELECT
                I.FACTURA_ID,
                I.EMPRESA_ID,
                I.CLIENTE_ID,
                I.TIPO_DOCUMENTO_ID,
                I.MONEDA_ID,
                I.ESTADO_FACTURA_ID,
                I.NUMERO_FACTURA,
                I.FECHA_EMISION,
                I.TIPO_CAMBIO,
                I.MONTO_SUBTOTAL,
                I.MONTO_DESCUENTO,
                I.MONTO_IMPUESTO,
                I.MONTO_TOTAL,
                I.OBSERVACIONES,
                E.CODIGO AS ESTADO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DBO.ESTADOFACTURA AS E
        ON I.ESTADO_FACTURA_ID = E.ESTADO_FACTURA_ID;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_FACTURA_AUDITORIA_DELETE;
GO

CREATE TRIGGER DBO.TRG_FACTURA_AUDITORIA_DELETE
ON DBO.FACTURA
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'FACTURA'
    );
    DECLARE @operacion_id INT = (
        SELECT TIPO_OPERACION_ID
        FROM DBO.TIPO_OPERACION
        WHERE DESCRIPCION = 'DELETE'
    );

    IF @entidad_id IS NULL OR @operacion_id IS NULL
        BEGIN
            THROW 50501,
            'Catalogos de auditoria incompletos: ejecute usp_cargar_catalogos.',
            1;
        END

    INSERT INTO DBO.AUDITORIA (
        ENTIDAD_AUDITADA_ID,
        REGISTRO_ID,
        TIPO_OPERACION_ID,
        USUARIO,
        FECHA_CAMBIO,
        DESCRIPCION, DATOS_ANTERIORES, DATOS_NUEVOS
    )
    SELECT
        @entidad_id AS ENTIDAD_AUDITADA_ID,
        D.FACTURA_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'DELETE factura ',
                D.FACTURA_ID,
                ': ',
                'numero ',
                D.NUMERO_FACTURA,
                ', estado ',
                E.CODIGO,
                ', total ',
                D.MONTO_TOTAL
            ),
            1000
        ) AS DESCRIPCION,
        (
            SELECT
                D.FACTURA_ID,
                D.EMPRESA_ID,
                D.CLIENTE_ID,
                D.TIPO_DOCUMENTO_ID,
                D.MONEDA_ID,
                D.ESTADO_FACTURA_ID,
                D.NUMERO_FACTURA,
                D.FECHA_EMISION,
                D.TIPO_CAMBIO,
                D.MONTO_SUBTOTAL,
                D.MONTO_DESCUENTO,
                D.MONTO_IMPUESTO,
                D.MONTO_TOTAL,
                D.OBSERVACIONES,
                E.CODIGO AS ESTADO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D
    INNER JOIN DBO.ESTADOFACTURA AS E
        ON D.ESTADO_FACTURA_ID = E.ESTADO_FACTURA_ID;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_FACTURA_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_FACTURA_AUDITORIA_UPDATE
ON DBO.FACTURA
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'FACTURA'
    );
    DECLARE @operacion_id INT = (
        SELECT TIPO_OPERACION_ID
        FROM DBO.TIPO_OPERACION
        WHERE DESCRIPCION = 'UPDATE'
    );

    IF @entidad_id IS NULL OR @operacion_id IS NULL
        BEGIN
            THROW 50501,
            'Catalogos de auditoria incompletos: ejecute usp_cargar_catalogos.',
            1;
        END

    INSERT INTO DBO.AUDITORIA (
        ENTIDAD_AUDITADA_ID,
        REGISTRO_ID,
        TIPO_OPERACION_ID,
        USUARIO,
        FECHA_CAMBIO,
        DESCRIPCION, DATOS_ANTERIORES, DATOS_NUEVOS
    )
    SELECT
        @entidad_id AS ENTIDAD_AUDITADA_ID,
        I.FACTURA_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(CONCAT(
            'UPDATE factura ', I.FACTURA_ID, ': ',
            IIF(
                D.ESTADO_FACTURA_ID <> I.ESTADO_FACTURA_ID,
                CONCAT('estado ', EO.CODIGO, ' -> ', EN.CODIGO, '; '),
                ''
            ),
            IIF(
                D.MONTO_SUBTOTAL <> I.MONTO_SUBTOTAL,
                CONCAT(
                    'monto_subtotal ',
                    D.MONTO_SUBTOTAL,
                    ' -> ',
                    I.MONTO_SUBTOTAL,
                    '; '
                ),
                ''
            ),
            IIF(
                D.MONTO_DESCUENTO <> I.MONTO_DESCUENTO,
                CONCAT(
                    'monto_descuento ',
                    D.MONTO_DESCUENTO,
                    ' -> ',
                    I.MONTO_DESCUENTO,
                    '; '
                ),
                ''
            ),
            IIF(
                D.MONTO_IMPUESTO <> I.MONTO_IMPUESTO,
                CONCAT(
                    'monto_impuesto ',
                    D.MONTO_IMPUESTO,
                    ' -> ',
                    I.MONTO_IMPUESTO,
                    '; '
                ),
                ''
            ),
            IIF(
                D.MONTO_TOTAL <> I.MONTO_TOTAL,
                CONCAT(
                    'monto_total ', D.MONTO_TOTAL, ' -> ', I.MONTO_TOTAL, '; '
                ),
                ''
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.FACTURA_ID,
                D.EMPRESA_ID,
                D.CLIENTE_ID,
                D.TIPO_DOCUMENTO_ID,
                D.MONEDA_ID,
                D.ESTADO_FACTURA_ID,
                D.NUMERO_FACTURA,
                D.FECHA_EMISION,
                D.TIPO_CAMBIO,
                D.MONTO_SUBTOTAL,
                D.MONTO_DESCUENTO,
                D.MONTO_IMPUESTO,
                D.MONTO_TOTAL,
                D.OBSERVACIONES,
                EO.CODIGO AS ESTADO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.FACTURA_ID,
                I.EMPRESA_ID,
                I.CLIENTE_ID,
                I.TIPO_DOCUMENTO_ID,
                I.MONEDA_ID,
                I.ESTADO_FACTURA_ID,
                I.NUMERO_FACTURA,
                I.FECHA_EMISION,
                I.TIPO_CAMBIO,
                I.MONTO_SUBTOTAL,
                I.MONTO_DESCUENTO,
                I.MONTO_IMPUESTO,
                I.MONTO_TOTAL,
                I.OBSERVACIONES,
                EN.CODIGO AS ESTADO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.FACTURA_ID = D.FACTURA_ID
    INNER JOIN DBO.ESTADOFACTURA AS EO
        ON D.ESTADO_FACTURA_ID = EO.ESTADO_FACTURA_ID
    INNER JOIN DBO.ESTADOFACTURA AS EN
        ON I.ESTADO_FACTURA_ID = EN.ESTADO_FACTURA_ID
    WHERE
        D.ESTADO_FACTURA_ID <> I.ESTADO_FACTURA_ID
        OR D.MONTO_SUBTOTAL <> I.MONTO_SUBTOTAL
        OR D.MONTO_DESCUENTO <> I.MONTO_DESCUENTO
        OR D.MONTO_IMPUESTO <> I.MONTO_IMPUESTO
        OR D.MONTO_TOTAL <> I.MONTO_TOTAL;
END;
GO
