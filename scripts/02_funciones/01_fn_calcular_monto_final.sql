USE PROYECTOFACTURACION;
GO

DROP FUNCTION IF EXISTS DBO.FN_CALCULAR_MONTO_FINAL;
GO

-- Funcion escalar: devuelve el monto final a pagar de una factura
--   monto final = subtotal - descuentos + impuestos
-- usando las cifras consolidadas del encabezado (factura), que
-- usp_registrar_factura acumula como la suma exacta de sus lineas.
-- Devuelve NULL si la factura no existe (para distinguirla de una factura
-- con monto cero). No modifica datos.
-- Es de una sola consulta, por lo que SQL Server 2019+ la puede incorporar
-- ("inline") al plan de la consulta que la usa.
CREATE FUNCTION DBO.FN_CALCULAR_MONTO_FINAL (@factura_id BIGINT)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @monto_final DECIMAL(18, 2);

    SELECT
        @monto_final
        = F.MONTO_SUBTOTAL - F.MONTO_DESCUENTO + F.MONTO_IMPUESTO
    FROM DBO.FACTURA AS F
    WHERE F.FACTURA_ID = @factura_id;

    RETURN @monto_final;
END;
GO
