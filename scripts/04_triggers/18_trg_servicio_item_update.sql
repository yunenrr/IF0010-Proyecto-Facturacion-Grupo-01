USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_SERVICIO_ITEM_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_SERVICIO_ITEM_AUDITORIA_UPDATE
ON DBO.ITEM_FACTURABLE
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'SERVICIO'
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
        I.ITEM_FACTURABLE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(CONCAT(
            'UPDATE servicio ', I.ITEM_FACTURABLE_ID, ': ',
            IIF(
                D.CODIGO_INTERNO <> I.CODIGO_INTERNO,
                CONCAT(
                    'codigo_interno ',
                    D.CODIGO_INTERNO,
                    ' -> ',
                    I.CODIGO_INTERNO,
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
                D.ACTIVO <> I.ACTIVO,
                CONCAT(
                    'activo ',
                    D.ACTIVO,
                    ' -> ',
                    I.ACTIVO,
                    '; '
                ),
                ''
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.ITEM_FACTURABLE_ID,
                D.CODIGO_INTERNO,
                D.DESCRIPCION,
                D.PRECIO_UNITARIO,
                D.PORCENTAJE_IMPUESTO,
                D.ACTIVO,
                SV.UNIDAD_MEDIDA_ID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.ITEM_FACTURABLE_ID,
                I.CODIGO_INTERNO,
                I.DESCRIPCION,
                I.PRECIO_UNITARIO,
                I.PORCENTAJE_IMPUESTO,
                I.ACTIVO,
                SV.UNIDAD_MEDIDA_ID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.ITEM_FACTURABLE_ID = D.ITEM_FACTURABLE_ID
    INNER JOIN DBO.SERVICIO AS SV
        ON I.ITEM_FACTURABLE_ID = SV.SERVICIO_ID
    WHERE
        D.CODIGO_INTERNO <> I.CODIGO_INTERNO
        OR D.DESCRIPCION <> I.DESCRIPCION
        OR D.PRECIO_UNITARIO <> I.PRECIO_UNITARIO
        OR D.PORCENTAJE_IMPUESTO <> I.PORCENTAJE_IMPUESTO
        OR D.ACTIVO <> I.ACTIVO;
END;
GO
