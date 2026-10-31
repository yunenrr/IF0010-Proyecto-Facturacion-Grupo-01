USE PROYECTOFACTURACION;
GO

-- Audita el precio de lista y el porcentaje de impuesto de productos y
-- servicios.
-- Usuario: ORIGINAL_LOGIN() (login autenticado en SQL Server). Fecha:
-- SYSDATETIME().
-- Se ejecuta dentro de la transaccion del cambio: si el cambio se revierte, la
-- fila de auditoria tambien. Opera por conjuntos (multiples filas por
-- sentencia).

DROP TRIGGER IF EXISTS DBO.TRG_ITEM_FACTURABLE_AUDITORIA_INSERT;
GO

CREATE TRIGGER DBO.TRG_ITEM_FACTURABLE_AUDITORIA_INSERT
ON DBO.ITEM_FACTURABLE
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'ITEM_FACTURABLE'
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
        I.ITEM_FACTURABLE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'INSERT item_facturable ',
                I.ITEM_FACTURABLE_ID,
                ': ',
                'codigo ',
                I.CODIGO_INTERNO,
                ', precio ',
                I.PRECIO_UNITARIO,
                ', impuesto ',
                I.PORCENTAJE_IMPUESTO
            ),
            1000
        ) AS DESCRIPCION,
        N'{}' AS DATOS_ANTERIORES,
        (
            SELECT
                I.ITEM_FACTURABLE_ID,
                I.CODIGO_INTERNO,
                I.DESCRIPCION,
                I.PRECIO_UNITARIO,
                I.PORCENTAJE_IMPUESTO,
                I.ACTIVO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_ITEM_FACTURABLE_AUDITORIA_DELETE;
GO

CREATE TRIGGER DBO.TRG_ITEM_FACTURABLE_AUDITORIA_DELETE
ON DBO.ITEM_FACTURABLE
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'ITEM_FACTURABLE'
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
        D.ITEM_FACTURABLE_ID,
        @operacion_id AS TIPO_OPERACION_ID,
        ORIGINAL_LOGIN() AS USUARIO,
        SYSDATETIME() AS FECHA_CAMBIO,
        LEFT(
            CONCAT(
                'DELETE item_facturable ',
                D.ITEM_FACTURABLE_ID,
                ': ',
                'codigo ',
                D.CODIGO_INTERNO,
                ', precio ',
                D.PRECIO_UNITARIO,
                ', impuesto ',
                D.PORCENTAJE_IMPUESTO
            ),
            1000
        ) AS DESCRIPCION,
        (
            SELECT
                D.ITEM_FACTURABLE_ID,
                D.CODIGO_INTERNO,
                D.DESCRIPCION,
                D.PRECIO_UNITARIO,
                D.PORCENTAJE_IMPUESTO,
                D.ACTIVO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        N'{}' AS DATOS_NUEVOS
    FROM DELETED AS D;
END;
GO

DROP TRIGGER IF EXISTS DBO.TRG_ITEM_FACTURABLE_AUDITORIA_UPDATE;
GO

CREATE TRIGGER DBO.TRG_ITEM_FACTURABLE_AUDITORIA_UPDATE
ON DBO.ITEM_FACTURABLE
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @entidad_id INT = (
        SELECT ENTIDAD_AUDITADA_ID
        FROM DBO.ENTIDAD_AUDITADA
        WHERE NOMBRE = 'ITEM_FACTURABLE'
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
            'UPDATE item_facturable ', I.ITEM_FACTURABLE_ID, ': ',
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
            )
        ), 1000) AS DESCRIPCION,
        (
            SELECT
                D.ITEM_FACTURABLE_ID,
                D.CODIGO_INTERNO,
                D.DESCRIPCION,
                D.PRECIO_UNITARIO,
                D.PORCENTAJE_IMPUESTO,
                D.ACTIVO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_ANTERIORES,
        (
            SELECT
                I.ITEM_FACTURABLE_ID,
                I.CODIGO_INTERNO,
                I.DESCRIPCION,
                I.PRECIO_UNITARIO,
                I.PORCENTAJE_IMPUESTO,
                I.ACTIVO
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS DATOS_NUEVOS
    FROM INSERTED AS I
    INNER JOIN DELETED AS D
        ON I.ITEM_FACTURABLE_ID = D.ITEM_FACTURABLE_ID
    WHERE
        D.PRECIO_UNITARIO <> I.PRECIO_UNITARIO
        OR D.PORCENTAJE_IMPUESTO <> I.PORCENTAJE_IMPUESTO;
END;
GO
