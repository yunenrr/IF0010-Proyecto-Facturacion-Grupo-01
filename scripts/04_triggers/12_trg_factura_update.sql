USE PROYECTOFACTURACION;
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
                D.EMPRESA_ID <> I.EMPRESA_ID,
                CONCAT(
                    'empresa_id ',
                    D.EMPRESA_ID,
                    ' -> ',
                    I.EMPRESA_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.CLIENTE_ID <> I.CLIENTE_ID,
                CONCAT(
                    'cliente_id ',
                    D.CLIENTE_ID,
                    ' -> ',
                    I.CLIENTE_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.TIPO_DOCUMENTO_ID <> I.TIPO_DOCUMENTO_ID,
                CONCAT(
                    'tipo_documento_id ',
                    D.TIPO_DOCUMENTO_ID,
                    ' -> ',
                    I.TIPO_DOCUMENTO_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.MONEDA_ID <> I.MONEDA_ID,
                CONCAT(
                    'moneda_id ',
                    D.MONEDA_ID,
                    ' -> ',
                    I.MONEDA_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.ESTADO_FACTURA_ID <> I.ESTADO_FACTURA_ID,
                CONCAT(
                    'estado_factura_id ',
                    D.ESTADO_FACTURA_ID,
                    ' -> ',
                    I.ESTADO_FACTURA_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.NUMERO_FACTURA <> I.NUMERO_FACTURA,
                CONCAT(
                    'numero_factura ',
                    D.NUMERO_FACTURA,
                    ' -> ',
                    I.NUMERO_FACTURA,
                    '; '
                ),
                ''
            ),
            IIF(
                D.FECHA_EMISION <> I.FECHA_EMISION,
                CONCAT(
                    'fecha_emision ',
                    D.FECHA_EMISION,
                    ' -> ',
                    I.FECHA_EMISION,
                    '; '
                ),
                ''
            ),
            IIF(
                D.TIPO_CAMBIO <> I.TIPO_CAMBIO,
                CONCAT(
                    'tipo_cambio ',
                    D.TIPO_CAMBIO,
                    ' -> ',
                    I.TIPO_CAMBIO,
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
            ),
            IIF(
                D.OBSERVACIONES <> I.OBSERVACIONES,
                CONCAT(
                    'observaciones ',
                    D.OBSERVACIONES,
                    ' -> ',
                    I.OBSERVACIONES,
                    '; '
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
                D.OBSERVACIONES
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
                I.OBSERVACIONES
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.FACTURA_ID = D.FACTURA_ID
    WHERE
        D.EMPRESA_ID <> I.EMPRESA_ID
        OR D.CLIENTE_ID <> I.CLIENTE_ID
        OR D.TIPO_DOCUMENTO_ID <> I.TIPO_DOCUMENTO_ID
        OR D.MONEDA_ID <> I.MONEDA_ID
        OR D.ESTADO_FACTURA_ID <> I.ESTADO_FACTURA_ID
        OR D.NUMERO_FACTURA <> I.NUMERO_FACTURA
        OR D.FECHA_EMISION <> I.FECHA_EMISION
        OR D.TIPO_CAMBIO <> I.TIPO_CAMBIO
        OR D.MONTO_SUBTOTAL <> I.MONTO_SUBTOTAL
        OR D.MONTO_DESCUENTO <> I.MONTO_DESCUENTO
        OR D.MONTO_IMPUESTO <> I.MONTO_IMPUESTO
        OR D.MONTO_TOTAL <> I.MONTO_TOTAL
        OR D.OBSERVACIONES <> I.OBSERVACIONES;
END;
GO
