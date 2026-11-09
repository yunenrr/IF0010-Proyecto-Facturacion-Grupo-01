USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_DIRECCION_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_DIRECCION_AUDITORIA_UPDATE
ON DBO.CLIENTE
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE_DIRECCION'
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
        I.CLIENTE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(CONCAT(
            'UPDATE direccion cliente ', I.CLIENTE_ID, ': ',
            IIF(
                D.DISTRITO_ID <> I.DISTRITO_ID,
                CONCAT(
                    'distrito_id ',
                    D.DISTRITO_ID,
                    ' -> ',
                    I.DISTRITO_ID,
                    '; '
                ),
                ''
            ),
            IIF(
                D.OTRAS_SENAS <> I.OTRAS_SENAS,
                CONCAT(
                    'otras_senas ',
                    D.OTRAS_SENAS,
                    ' -> ',
                    I.OTRAS_SENAS,
                    '; '
                ),
                ''
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.CLIENTE_ID,
                D.DISTRITO_ID,
                D.OTRAS_SENAS
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.CLIENTE_ID,
                I.DISTRITO_ID,
                I.OTRAS_SENAS
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.CLIENTE_ID = D.CLIENTE_ID
    WHERE
        D.DISTRITO_ID <> I.DISTRITO_ID
        OR D.OTRAS_SENAS <> I.OTRAS_SENAS;
END;
GO
