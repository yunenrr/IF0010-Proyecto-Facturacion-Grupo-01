USE PROYECTOFACTURACION;
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
                'empresa_id ',
                D.EMPRESA_ID,
                ', cliente_id ',
                D.CLIENTE_ID,
                ', tipo_documento_id ',
                D.TIPO_DOCUMENTO_ID,
                ', moneda_id ',
                D.MONEDA_ID,
                ', estado_factura_id ',
                D.ESTADO_FACTURA_ID,
                ', numero_factura ',
                D.NUMERO_FACTURA,
                ', fecha_emision ',
                D.FECHA_EMISION,
                ', tipo_cambio ',
                D.TIPO_CAMBIO,
                ', monto_subtotal ',
                D.MONTO_SUBTOTAL,
                ', monto_descuento ',
                D.MONTO_DESCUENTO,
                ', monto_impuesto ',
                D.MONTO_IMPUESTO,
                ', monto_total ',
                D.MONTO_TOTAL,
                ', observaciones ',
                D.OBSERVACIONES
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
                D.OBSERVACIONES
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D;
END;
GO
