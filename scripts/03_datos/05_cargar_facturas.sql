USE ProyectoFacturacion;
GO

DECLARE @codigo_error INT;
DECLARE @mensaje_error VARCHAR(250);

EXEC dbo.usp_generar_facturas
    @cantidad_objetivo = 500000,
    @tamano_lote = 25000,
    @codigo_error = @codigo_error OUTPUT,
    @mensaje_error = @mensaje_error OUTPUT;

SELECT
    @codigo_error AS codigo_error,
    @mensaje_error AS mensaje_error;

IF @codigo_error <> 0
BEGIN
    RAISERROR ('Fallo la carga de facturas: %s', 16, 1, @mensaje_error);
END
GO
