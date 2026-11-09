USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_FACTURA_DETALLE_AUDITORIA_DELETE;
GO

CREATE TRIGGER DBO.TRG_FACTURA_DETALLE_AUDITORIA_DELETE
ON DBO.FACTURA_DETALLE
AFTER DELETE
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
        D.FACTURA_DETALLE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'DELETE factura_detalle ',
                D.FACTURA_DETALLE_ID,
                ': ',
                'factura_id ',
                D.FACTURA_ID,
                ', item_facturable_id ',
                D.ITEM_FACTURABLE_ID,
                ', numero_linea ',
                D.NUMERO_LINEA,
                ', descripcion ',
                D.DESCRIPCION,
                ', cantidad ',
                D.CANTIDAD,
                ', precio_unitario ',
                D.PRECIO_UNITARIO,
                ', porcentaje_impuesto ',
                D.PORCENTAJE_IMPUESTO,
                ', monto_subtotal ',
                D.MONTO_SUBTOTAL,
                ', monto_descuento ',
                D.MONTO_DESCUENTO,
                ', monto_impuesto ',
                D.MONTO_IMPUESTO,
                ', monto_total ',
                D.MONTO_TOTAL
            ),
            1000
        ) AS DESCRIPCION,
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
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D;
END;
GO
