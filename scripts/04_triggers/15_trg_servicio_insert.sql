USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_SERVICIO_AUDITORIA_INSERT;
GO

CREATE TRIGGER DBO.TRG_SERVICIO_AUDITORIA_INSERT
ON DBO.SERVICIO
AFTER INSERT
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
        I.SERVICIO_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'INSERT servicio ',
                I.SERVICIO_ID,
                ': ',
                'unidad_medida_id ',
                I.UNIDAD_MEDIDA_ID,
                ', codigo ',
                IT.CODIGO_INTERNO
            ),
            1000
        ) AS DESCRIPCION,
        N'{}' AS DATOS_ANTERIORES,
        (
            SELECT
                I.SERVICIO_ID,
                I.UNIDAD_MEDIDA_ID,
                IT.CODIGO_INTERNO,
                IT.DESCRIPCION,
                IT.PRECIO_UNITARIO,
                IT.PORCENTAJE_IMPUESTO,
                IT.ACTIVO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DBO.ITEM_FACTURABLE AS IT
        ON I.SERVICIO_ID = IT.ITEM_FACTURABLE_ID;
END;
GO
