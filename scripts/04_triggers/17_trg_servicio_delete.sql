USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_SERVICIO_AUDITORIA_DELETE;
GO

CREATE TRIGGER DBO.TRG_SERVICIO_AUDITORIA_DELETE
ON DBO.SERVICIO
AFTER DELETE
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
        D.SERVICIO_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'DELETE servicio ',
                D.SERVICIO_ID,
                ': ',
                'unidad_medida_id ',
                D.UNIDAD_MEDIDA_ID,
                ', codigo ',
                IT.CODIGO_INTERNO
            ),
            1000
        ) AS DESCRIPCION,
        (
            SELECT
                D.SERVICIO_ID,
                D.UNIDAD_MEDIDA_ID,
                IT.CODIGO_INTERNO,
                IT.DESCRIPCION,
                IT.PRECIO_UNITARIO,
                IT.PORCENTAJE_IMPUESTO,
                IT.ACTIVO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D
    INNER JOIN DBO.ITEM_FACTURABLE AS IT
        ON D.SERVICIO_ID = IT.ITEM_FACTURABLE_ID;
END;
GO
