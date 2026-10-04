USE C21626;
GO

DECLARE @code INT;
DECLARE @msg VARCHAR(250);

EXEC dbo.sp_generar_facturas
    @cantidad_objetivo = 500000,
    @tamano_lote = 25000,
    @codigo_error = @code OUTPUT,
    @mensaje_error = @msg OUTPUT;

SELECT
    @code AS CodigoError,
    @msg AS MensajeError;

-- Verificación de totales finales
SELECT COUNT(*) AS Total_Facturas FROM dbo.factura;
SELECT COUNT(*) AS Total_Detalles FROM dbo.detalle_facturable;
GO
