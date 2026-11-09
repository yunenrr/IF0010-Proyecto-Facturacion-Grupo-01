USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_FACTURA_DETALLE_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_FACTURA_DETALLE_AUDITORIA_UPDATE
ON DBO.FACTURA_DETALLE
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'FACTURA_DETALLE'
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
        I.FACTURA_DETALLE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(CONCAT(
            'UPDATE factura_detalle ', I.FACTURA_DETALLE_ID, ': ',
            IIF(
                D.FACTURA_ID <> I.FACTURA_ID,
                CONCAT(
                    'factura_id ',
                    D.FACTURA_ID,
                    ' -> ',
                    I.FACTURA_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.ITEM_FACTURABLE_ID <> I.ITEM_FACTURABLE_ID,
                CONCAT(
                    'item_facturable_id ',
                    D.ITEM_FACTURABLE_ID,
                    ' -> ',
                    I.ITEM_FACTURABLE_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.NUMERO_LINEA <> I.NUMERO_LINEA,
                CONCAT(
                    'numero_linea ',
                    D.NUMERO_LINEA,
                    ' -> ',
                    I.NUMERO_LINEA,
                    '; '
                ),
                ''
            ),
            IIF(
                D.DESCRIPCION <> I.DESCRIPCION,
                CONCAT(
                    'descripcion ',
                    D.DESCRIPCION,
                    ' -> ',
                    I.DESCRIPCION,
                    '; '
                ),
                ''
            ),
            IIF(
                D.CANTIDAD <> I.CANTIDAD,
                CONCAT(
                    'cantidad ',
                    D.CANTIDAD,
                    ' -> ',
                    I.CANTIDAD,
                    '; '
                ),
                ''
            ),
            IIF(
                D.PRECIO_UNITARIO <> I.PRECIO_UNITARIO,
                CONCAT(
                    'precio_unitario ',
                    D.PRECIO_UNITARIO,
                    ' -> ',
                    I.PRECIO_UNITARIO,
                    '; '
                ),
                ''
            ),
            IIF(
                D.PORCENTAJE_IMPUESTO <> I.PORCENTAJE_IMPUESTO,
                CONCAT(
                    'porcentaje_impuesto ',
                    D.PORCENTAJE_IMPUESTO,
                    ' -> ',
                    I.PORCENTAJE_IMPUESTO,
                    '; '
                ),
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
                    'monto_total ',
                    D.MONTO_TOTAL,
                    ' -> ',
                    I.MONTO_TOTAL,
                    '; '
                ),
                ''
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.FACTURA_DETALLE_ID,
                D.FACTURA_ID,
                D.ITEM_FACTURABLE_ID,
                D.NUMERO_LINEA,
                D.DESCRIPCION,
                D.CANTIDAD,
                D.PRECIO_UNITARIO,
                D.PORCENTAJE_IMPUESTO,
                D.MONTO_SUBTOTAL,
                D.MONTO_DESCUENTO,
                D.MONTO_IMPUESTO,
                D.MONTO_TOTAL
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.FACTURA_DETALLE_ID,
                I.FACTURA_ID,
                I.ITEM_FACTURABLE_ID,
                I.NUMERO_LINEA,
                I.DESCRIPCION,
                I.CANTIDAD,
                I.PRECIO_UNITARIO,
                I.PORCENTAJE_IMPUESTO,
                I.MONTO_SUBTOTAL,
                I.MONTO_DESCUENTO,
                I.MONTO_IMPUESTO,
                I.MONTO_TOTAL
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.FACTURA_DETALLE_ID = D.FACTURA_DETALLE_ID
    WHERE
        D.FACTURA_ID <> I.FACTURA_ID
        OR D.ITEM_FACTURABLE_ID <> I.ITEM_FACTURABLE_ID
        OR D.NUMERO_LINEA <> I.NUMERO_LINEA
        OR D.DESCRIPCION <> I.DESCRIPCION
        OR D.CANTIDAD <> I.CANTIDAD
        OR D.PRECIO_UNITARIO <> I.PRECIO_UNITARIO
        OR D.PORCENTAJE_IMPUESTO <> I.PORCENTAJE_IMPUESTO
        OR D.MONTO_SUBTOTAL <> I.MONTO_SUBTOTAL
        OR D.MONTO_DESCUENTO <> I.MONTO_DESCUENTO
        OR D.MONTO_IMPUESTO <> I.MONTO_IMPUESTO
        OR D.MONTO_TOTAL <> I.MONTO_TOTAL;
END;
GO
