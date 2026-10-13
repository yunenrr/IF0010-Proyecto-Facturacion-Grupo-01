USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_CONSULTAR_TOTALES_FACTURA;
GO

-- Consulta los totales de una factura por su identificador (@factura_id > 0) o
-- por su identificador de comprobante (@numero_factura). Devuelve un conjunto
-- de resultados con los totales del encabezado y, para verificar la integridad,
-- la cantidad de lineas y la suma de los totales del detalle.
-- No modifica datos. Usa la clave primaria o el indice unico de numero_factura
-- y el indice ix_facturadetalle_factura para responder en menos de un segundo.
CREATE PROCEDURE DBO.USP_CONSULTAR_TOTALES_FACTURA
    @factura_id BIGINT = 0,
    @numero_factura VARCHAR(50) = '',
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @id BIGINT;

    BEGIN TRY
        IF @factura_id > 0
            BEGIN
                SELECT @id = FACTURA_ID
                FROM DBO.FACTURA
                WHERE FACTURA_ID = @factura_id;
            END
        ELSE IF LEN(LTRIM(RTRIM(@numero_factura))) > 0
            BEGIN
                SELECT @id = FACTURA_ID
                FROM DBO.FACTURA
                WHERE NUMERO_FACTURA = @numero_factura;
            END
        ELSE
            BEGIN
                THROW 50401, 'Indique factura_id o numero_factura.', 1;
            END

        IF @id IS NULL
            BEGIN
                THROW 50402, 'La factura indicada no existe.', 1;
            END

        SELECT
            F.FACTURA_ID,
            F.NUMERO_FACTURA,
            F.FECHA_EMISION,
            EM.NOMBRE_COMERCIAL AS EMPRESA,
            CL.IDENTIFICACION AS CLIENTE_IDENTIFICACION,
            TD.CODIGO AS TIPO_DOCUMENTO,
            MO.CODIGO AS MONEDA,
            ES.CODIGO AS ESTADO,
            F.MONTO_SUBTOTAL,
            F.MONTO_DESCUENTO,
            F.MONTO_IMPUESTO,
            F.MONTO_TOTAL,
            DT.CANTIDAD_LINEAS,
            DT.TOTAL_LINEAS
        FROM DBO.FACTURA AS F
        INNER JOIN DBO.EMPRESAEMISORA AS EM
            ON F.EMPRESA_ID = EM.EMPRESA_ID
        INNER JOIN DBO.CLIENTE AS CL
            ON F.CLIENTE_ID = CL.CLIENTE_ID
        INNER JOIN DBO.TIPODOCUMENTO AS TD
            ON F.TIPO_DOCUMENTO_ID = TD.TIPO_DOCUMENTO_ID
        INNER JOIN DBO.MONEDA AS MO
            ON F.MONEDA_ID = MO.MONEDA_ID
        INNER JOIN DBO.ESTADOFACTURA AS ES
            ON F.ESTADO_FACTURA_ID = ES.ESTADO_FACTURA_ID
        CROSS APPLY (
            SELECT
                COUNT(*) AS CANTIDAD_LINEAS,
                ISNULL(SUM(D.MONTO_TOTAL), 0) AS TOTAL_LINEAS
            FROM DBO.FACTURA_DETALLE AS D
            WHERE D.FACTURA_ID = F.FACTURA_ID
        ) AS DT
        WHERE F.FACTURA_ID = @id;
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
