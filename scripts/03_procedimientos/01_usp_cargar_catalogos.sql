USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_CARGAR_CATALOGOS;
GO

CREATE PROCEDURE DBO.USP_CARGAR_CATALOGOS
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO DBO.TIPODOCUMENTO (CODIGO, DESCRIPCION)
        SELECT
            V.CODIGO,
            V.DESCRIPCION
        FROM (
            VALUES
            ('FAC', 'Factura'),
            ('TIQ', 'Tiquete')
        ) AS V(CODIGO, DESCRIPCION)
        WHERE NOT EXISTS (
            SELECT 1 FROM DBO.TIPODOCUMENTO AS T
            WHERE T.CODIGO = V.CODIGO
        );

        INSERT INTO DBO.MONEDA (CODIGO, SIMBOLO, DESCRIPCION)
        SELECT
            V.CODIGO,
            V.SIMBOLO,
            V.DESCRIPCION
        FROM (
            VALUES
            ('CRC', '¢', 'Colon costarricense'),
            ('USD', '$', 'Dolar estadounidense')
        ) AS V(CODIGO, SIMBOLO, DESCRIPCION)
        WHERE NOT EXISTS (
            SELECT 1 FROM DBO.MONEDA AS M
            WHERE M.CODIGO = V.CODIGO
        );

        INSERT INTO DBO.ESTADOFACTURA (CODIGO, DESCRIPCION)
        SELECT
            V.CODIGO,
            V.DESCRIPCION
        FROM (
            VALUES
            ('BORRADOR', 'Factura en preparacion, aun no emitida'),
            ('EMITIDA', 'Factura emitida al cliente'),
            ('PAGADA', 'Factura cancelada por el cliente mediante pago'),
            ('CANCELADA', 'Factura anulada')
        ) AS V(CODIGO, DESCRIPCION)
        WHERE NOT EXISTS (
            SELECT 1 FROM DBO.ESTADOFACTURA AS E
            WHERE E.CODIGO = V.CODIGO
        );

        INSERT INTO DBO.UNIDAD_MEDIDA (DESCRIPCION)
        SELECT V.DESCRIPCION
        FROM (
            VALUES
            ('Unidad'),
            ('Kilogramo'),
            ('Litro'),
            ('Hora'),
            ('Servicio')
        ) AS V(DESCRIPCION)
        WHERE NOT EXISTS (
            SELECT 1
            FROM DBO.UNIDAD_MEDIDA AS U
            WHERE U.DESCRIPCION = V.DESCRIPCION
        );

        INSERT INTO DBO.TIPO_OPERACION (DESCRIPCION)
        SELECT V.DESCRIPCION
        FROM (
            VALUES
            ('INSERT'),
            ('UPDATE'),
            ('DELETE')
        ) AS V(DESCRIPCION)
        WHERE NOT EXISTS (
            SELECT 1
            FROM DBO.TIPO_OPERACION AS O
            WHERE O.DESCRIPCION = V.DESCRIPCION
        );

        INSERT INTO DBO.ENTIDAD_AUDITADA (NOMBRE)
        SELECT V.NOMBRE
        FROM (
            VALUES
            ('FACTURA'),
            ('FACTURA_DETALLE'),
            ('CLIENTE'),
            ('ITEM_FACTURABLE'),
            ('CLIENTE_FISICO'),
            ('CLIENTE_JURIDICO'),
            ('CLIENTE_DIRECCION'),
            ('PRODUCTO_CON_EXISTENCIA'),
            ('SERVICIO')
        ) AS V(NOMBRE)
        WHERE NOT EXISTS (
            SELECT 1 FROM DBO.ENTIDAD_AUDITADA AS E
            WHERE E.NOMBRE = V.NOMBRE
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = LEFT(ERROR_MESSAGE(), 250);
    END CATCH
END;
GO
