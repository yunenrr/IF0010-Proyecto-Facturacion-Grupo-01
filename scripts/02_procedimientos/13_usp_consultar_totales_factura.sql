USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_consultar_totales_factura;
GO

-- Consulta los totales de una factura por su identificador (@factura_id > 0) o
-- por su identificador de comprobante (@numero_factura). Devuelve un conjunto
-- de resultados con los totales del encabezado y, para verificar la integridad,
-- la cantidad de lineas y la suma de los totales del detalle.
-- No modifica datos. Usa la clave primaria o el indice unico de numero_factura
-- y el indice ix_facturadetalle_factura para responder en menos de un segundo.
CREATE PROCEDURE dbo.usp_consultar_totales_factura
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
            SELECT @id = factura_id
            FROM dbo.factura
            WHERE factura_id = @factura_id;
        END
        ELSE IF LEN(LTRIM(RTRIM(@numero_factura))) > 0
        BEGIN
            SELECT @id = factura_id
            FROM dbo.factura
            WHERE numero_factura = @numero_factura;
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
            f.factura_id,
            f.numero_factura,
            f.fecha_emision,
            em.nombre_comercial AS empresa,
            cl.identificacion AS cliente_identificacion,
            td.codigo AS tipo_documento,
            mo.codigo AS moneda,
            es.codigo AS estado,
            f.monto_subtotal,
            f.monto_descuento,
            f.monto_impuesto,
            f.monto_total,
            dt.cantidad_lineas,
            dt.total_lineas
        FROM dbo.factura AS f
        INNER JOIN dbo.empresaemisora AS em
            ON em.empresa_id = f.empresa_id
        INNER JOIN dbo.cliente AS cl
            ON cl.cliente_id = f.cliente_id
        INNER JOIN dbo.tipodocumento AS td
            ON td.tipo_documento_id = f.tipo_documento_id
        INNER JOIN dbo.moneda AS mo
            ON mo.moneda_id = f.moneda_id
        INNER JOIN dbo.estadofactura AS es
            ON es.estado_factura_id = f.estado_factura_id
        CROSS APPLY (
            SELECT
                COUNT(*) AS cantidad_lineas,
                ISNULL(SUM(d.monto_total), 0) AS total_lineas
            FROM dbo.factura_detalle AS d
            WHERE d.factura_id = f.factura_id
        ) AS dt
        WHERE f.factura_id = @id;
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
