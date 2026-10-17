USE PROYECTOFACTURACION;
GO

-- Audita la identificacion (cedula), el correo y el telefono del comprador.
-- Usuario: ORIGINAL_LOGIN() (login autenticado en SQL Server). Fecha:
-- SYSDATETIME().
-- Se ejecuta dentro de la transaccion del cambio: si el cambio se revierte, la
-- fila de auditoria tambien. Opera por conjuntos (multiples filas por
-- sentencia).

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_AUDITORIA_INSERT;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_AUDITORIA_INSERT
ON DBO.CLIENTE
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE'
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
                'INSERT cliente ',
                I.CLIENTE_ID,
                ': ',
                'identificacion ',
                I.IDENTIFICACION,
                ', correo ',
                I.CORREO,
                ', telefono ',
                I.TELEFONO
            ),
            1000
        ) AS DESCRIPCION,
        N'{}' AS DATOS_ANTERIORES,
        (
            SELECT
                I.CLIENTE_ID,
                I.IDENTIFICACION,
                I.CORREO,
                I.TELEFONO,
                I.DISTRITO_ID,
                I.OTRAS_SENAS
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_AUDITORIA_DELETE;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_AUDITORIA_DELETE
ON DBO.CLIENTE
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE'
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
                'DELETE cliente ',
                D.CLIENTE_ID,
                ': ',
                'identificacion ',
                D.IDENTIFICACION,
                ', correo ',
                D.CORREO,
                ', telefono ',
                D.TELEFONO
            ),
            1000
        ) AS DESCRIPCION,
        (
            SELECT
                D.CLIENTE_ID,
                D.IDENTIFICACION,
                D.CORREO,
                D.TELEFONO,
                D.DISTRITO_ID,
                D.OTRAS_SENAS
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_CLIENTE_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_CLIENTE_AUDITORIA_UPDATE
ON DBO.CLIENTE
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'CLIENTE'
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
            'UPDATE cliente ', I.CLIENTE_ID, ': ',
            IIF(
                D.IDENTIFICACION <> I.IDENTIFICACION,
                CONCAT(
                    'identificacion ',
                    D.IDENTIFICACION,
                    ' -> ',
                    I.IDENTIFICACION,
                    '; '
                ),
                ''
            ),
            IIF(
                D.CORREO <> I.CORREO,
                CONCAT('correo ', D.CORREO, ' -> ', I.CORREO, '; '),
                ''
            ),
            IIF(
                D.TELEFONO <> I.TELEFONO,
                CONCAT('telefono ', D.TELEFONO, ' -> ', I.TELEFONO, '; '),
                ''
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.CLIENTE_ID,
                D.IDENTIFICACION,
                D.CORREO,
                D.TELEFONO,
                D.DISTRITO_ID,
                D.OTRAS_SENAS
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.CLIENTE_ID,
                I.IDENTIFICACION,
                I.CORREO,
                I.TELEFONO,
                I.DISTRITO_ID,
                I.OTRAS_SENAS
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.CLIENTE_ID = D.CLIENTE_ID
    WHERE
        D.IDENTIFICACION <> I.IDENTIFICACION
        OR D.CORREO <> I.CORREO
        OR D.TELEFONO <> I.TELEFONO;
END;
GO
