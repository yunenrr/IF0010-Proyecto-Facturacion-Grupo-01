USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_JURIDICO_AUDITORIA_INSERT;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_JURIDICO_AUDITORIA_INSERT
ON DBO.CLIENTE_JURIDICO
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE_JURIDICO'
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
        I.CLIENTE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'INSERT cliente_juridico ',
                I.CLIENTE_ID,
                ': ',
                'razon_social ',
                I.RAZON_SOCIAL,
                ', nombre_comercial ',
                I.NOMBRE_COMERCIAL
            ),
            1000
        ) AS DESCRIPCION,
        N'{}' AS DATOS_ANTERIORES,
        (
            SELECT
                I.CLIENTE_ID,
                I.RAZON_SOCIAL,
                I.NOMBRE_COMERCIAL
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_JURIDICO_AUDITORIA_DELETE;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_JURIDICO_AUDITORIA_DELETE
ON DBO.CLIENTE_JURIDICO
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE_JURIDICO'
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
        D.CLIENTE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'DELETE cliente_juridico ',
                D.CLIENTE_ID,
                ': ',
                'razon_social ',
                D.RAZON_SOCIAL,
                ', nombre_comercial ',
                D.NOMBRE_COMERCIAL
            ),
            1000
        ) AS DESCRIPCION,
        (
            SELECT
                D.CLIENTE_ID,
                D.RAZON_SOCIAL,
                D.NOMBRE_COMERCIAL
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_JURIDICO_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_JURIDICO_AUDITORIA_UPDATE
ON DBO.CLIENTE_JURIDICO
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE_JURIDICO'
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
            'UPDATE cliente_juridico ', I.CLIENTE_ID, ': ',
            IIF(
                D.RAZON_SOCIAL <> I.RAZON_SOCIAL,
                CONCAT(
                    'razon_social ',
                    D.RAZON_SOCIAL,
                    ' -> ',
                    I.RAZON_SOCIAL,
                    '; '
                ),
                ''
            ),
            IIF(
                D.NOMBRE_COMERCIAL <> I.NOMBRE_COMERCIAL,
                CONCAT(
                    'nombre_comercial ',
                    D.NOMBRE_COMERCIAL,
                    ' -> ',
                    I.NOMBRE_COMERCIAL,
                    '; '
                ),
                ''
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.CLIENTE_ID,
                D.RAZON_SOCIAL,
                D.NOMBRE_COMERCIAL
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.CLIENTE_ID,
                I.RAZON_SOCIAL,
                I.NOMBRE_COMERCIAL
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.CLIENTE_ID = D.CLIENTE_ID
    WHERE
        D.RAZON_SOCIAL <> I.RAZON_SOCIAL
        OR D.NOMBRE_COMERCIAL <> I.NOMBRE_COMERCIAL;
END;
GO
