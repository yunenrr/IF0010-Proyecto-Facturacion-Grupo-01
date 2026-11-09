USE PROYECTOFACTURACION;
GO

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
                'empresa_id ',
                I.EMPRESA_ID,
                ', cliente_id ',
                I.CLIENTE_ID,
                ', tipo_documento_id ',
                I.TIPO_DOCUMENTO_ID,
                ', moneda_id ',
                I.MONEDA_ID,
                ', estado_factura_id ',
                I.ESTADO_FACTURA_ID,
                ', numero_factura ',
                I.NUMERO_FACTURA,
                ', fecha_emision ',
                I.FECHA_EMISION,
                ', tipo_cambio ',
                I.TIPO_CAMBIO,
                ', monto_subtotal ',
                I.MONTO_SUBTOTAL,
                ', monto_descuento ',
                I.MONTO_DESCUENTO,
                ', monto_impuesto ',
                I.MONTO_IMPUESTO,
                ', monto_total ',
                I.MONTO_TOTAL,
                ', observaciones ',
                I.OBSERVACIONES
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
                I.OBSERVACIONES
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I;
END;
GO
