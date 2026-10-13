USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_consultar_facturas_cliente;
GO

-- Consulta las facturas de un comprador, de la mas reciente a la mas antigua.
-- El comprador se identifica por @cliente_id (> 0) o por @identificacion.
-- No modifica datos. Usa ix_factura_cliente para responder en menos de un
-- segundo.
CREATE PROCEDURE dbo.usp_consultar_facturas_cliente
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
            SELECT @id = cliente_id
            FROM dbo.cliente
            WHERE cliente_id = @cliente_id;
        END
        ELSE IF LEN(LTRIM(RTRIM(@identificacion))) > 0
        BEGIN
            SELECT @id = cliente_id
            FROM dbo.cliente
            WHERE identificacion = @identificacion;
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
            f.factura_id,
            f.numero_factura,
            f.fecha_emision,
            td.codigo AS tipo_documento,
            mo.codigo AS moneda,
            es.codigo AS estado,
            f.monto_subtotal,
            f.monto_descuento,
            f.monto_impuesto,
            f.monto_total
        FROM dbo.factura AS f
        INNER JOIN dbo.tipodocumento AS td
            ON td.tipo_documento_id = f.tipo_documento_id
        INNER JOIN dbo.moneda AS mo
            ON mo.moneda_id = f.moneda_id
        INNER JOIN dbo.estadofactura AS es
            ON es.estado_factura_id = f.estado_factura_id
        WHERE f.cliente_id = @id
        ORDER BY f.fecha_emision DESC;
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
