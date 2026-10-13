USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_CONSULTAR_FACTURAS_CLIENTE;
GO

-- Consulta las facturas de un comprador, de la mas reciente a la mas antigua.
-- El comprador se identifica por @cliente_id (> 0) o por @identificacion.
-- No modifica datos. Usa ix_factura_cliente para responder en menos de un
-- segundo.
CREATE PROCEDURE DBO.USP_CONSULTAR_FACTURAS_CLIENTE
    @cliente_id INT = 0,
    @identificacion VARCHAR(20) = '',
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @id INT;

    BEGIN TRY
        IF @cliente_id > 0
            BEGIN
                SELECT @id = CLIENTE_ID
                FROM DBO.CLIENTE
                WHERE CLIENTE_ID = @cliente_id;
            END
        ELSE IF LEN(LTRIM(RTRIM(@identificacion))) > 0
            BEGIN
                SELECT @id = CLIENTE_ID
                FROM DBO.CLIENTE
                WHERE IDENTIFICACION = @identificacion;
            END
        ELSE
            BEGIN
                THROW 50411, 'Indique cliente_id o identificacion.', 1;
            END

        IF @id IS NULL
            BEGIN
                THROW 50412, 'El cliente indicado no existe.', 1;
            END

        SELECT
            F.FACTURA_ID,
            F.NUMERO_FACTURA,
            F.FECHA_EMISION,
            TD.CODIGO AS TIPO_DOCUMENTO,
            MO.CODIGO AS MONEDA,
            ES.CODIGO AS ESTADO,
            F.MONTO_SUBTOTAL,
            F.MONTO_DESCUENTO,
            F.MONTO_IMPUESTO,
            F.MONTO_TOTAL
        FROM DBO.FACTURA AS F
        INNER JOIN DBO.TIPODOCUMENTO AS TD
            ON F.TIPO_DOCUMENTO_ID = TD.TIPO_DOCUMENTO_ID
        INNER JOIN DBO.MONEDA AS MO
            ON F.MONEDA_ID = MO.MONEDA_ID
        INNER JOIN DBO.ESTADOFACTURA AS ES
            ON F.ESTADO_FACTURA_ID = ES.ESTADO_FACTURA_ID
        WHERE F.CLIENTE_ID = @id
        ORDER BY F.FECHA_EMISION DESC;
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
