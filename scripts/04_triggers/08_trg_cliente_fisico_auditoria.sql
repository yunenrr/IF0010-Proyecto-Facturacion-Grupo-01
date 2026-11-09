USE PROYECTOFACTURACION;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_FISICO_AUDITORIA_INSERT;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_FISICO_AUDITORIA_INSERT
ON DBO.CLIENTE_FISICO
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE_FISICO'
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
                'INSERT cliente_fisico ',
                I.CLIENTE_ID,
                ': ',
                'nombre ',
                I.NOMBRE,
                ', apellido1 ',
                I.APELLIDO1,
                ', apellido2 ',
                I.APELLIDO2
            ),
            1000
        ) AS DESCRIPCION,
        N'{}' AS DATOS_ANTERIORES,
        (
            SELECT
                I.CLIENTE_ID,
                I.NOMBRE,
                I.APELLIDO1,
                I.APELLIDO2
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_FISICO_AUDITORIA_DELETE;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_FISICO_AUDITORIA_DELETE
ON DBO.CLIENTE_FISICO
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE_FISICO'
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
                'DELETE cliente_fisico ',
                D.CLIENTE_ID,
                ': ',
                'nombre ',
                D.NOMBRE,
                ', apellido1 ',
                D.APELLIDO1,
                ', apellido2 ',
                D.APELLIDO2
            ),
            1000
        ) AS DESCRIPCION,
        (
            SELECT
                D.CLIENTE_ID,
                D.NOMBRE,
                D.APELLIDO1,
                D.APELLIDO2
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_FISICO_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_FISICO_AUDITORIA_UPDATE
ON DBO.CLIENTE_FISICO
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE_FISICO'
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
            'UPDATE cliente_fisico ', I.CLIENTE_ID, ': ',
            IIF(
                D.NOMBRE <> I.NOMBRE,
                CONCAT(
                    'nombre ',
                    D.NOMBRE,
                    ' -> ',
                    I.NOMBRE,
                    '; '
                ),
                ''
            ),
            IIF(
                D.APELLIDO1 <> I.APELLIDO1,
                CONCAT(
                    'apellido1 ',
                    D.APELLIDO1,
                    ' -> ',
                    I.APELLIDO1,
                    '; '
                ),
                ''
            ),
            IIF(
                D.APELLIDO2 <> I.APELLIDO2,
                CONCAT(
                    'apellido2 ',
                    D.APELLIDO2,
                    ' -> ',
                    I.APELLIDO2,
                    '; '
                ),
                ''
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.CLIENTE_ID,
                D.NOMBRE,
                D.APELLIDO1,
                D.APELLIDO2
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.CLIENTE_ID,
                I.NOMBRE,
                I.APELLIDO1,
                I.APELLIDO2
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.CLIENTE_ID = D.CLIENTE_ID
    WHERE
        D.NOMBRE <> I.NOMBRE
        OR D.APELLIDO1 <> I.APELLIDO1
        OR D.APELLIDO2 <> I.APELLIDO2;
END;
GO
