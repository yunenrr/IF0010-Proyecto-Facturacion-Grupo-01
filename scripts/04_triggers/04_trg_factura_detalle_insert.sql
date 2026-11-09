USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_FACTURA_DETALLE_AUDITORIA_INSERT;
GO

CREATE TRIGGER DBO.TRG_FACTURA_DETALLE_AUDITORIA_INSERT
ON DBO.FACTURA_DETALLE
AFTER INSERT
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
        I.FACTURA_DETALLE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'INSERT factura_detalle ',
                I.FACTURA_DETALLE_ID,
                ': ',
                'factura_id ',
                I.FACTURA_ID,
                ', item_facturable_id ',
                I.ITEM_FACTURABLE_ID,
                ', numero_linea ',
                I.NUMERO_LINEA,
                ', descripcion ',
                I.DESCRIPCION,
                ', cantidad ',
                I.CANTIDAD,
                ', precio_unitario ',
                I.PRECIO_UNITARIO,
                ', porcentaje_impuesto ',
                I.PORCENTAJE_IMPUESTO,
                ', monto_subtotal ',
                I.MONTO_SUBTOTAL,
                ', monto_descuento ',
                I.MONTO_DESCUENTO,
                ', monto_impuesto ',
                I.MONTO_IMPUESTO,
                ', monto_total ',
                I.MONTO_TOTAL
            ),
            1000
        ) AS DESCRIPCION,
        N'{}' AS DATOS_ANTERIORES,
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
    FROM INSERTED AS I;
END;
GO
