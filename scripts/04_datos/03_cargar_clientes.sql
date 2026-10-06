DECLARE @codigo_error INT;
DECLARE @mensaje_error VARCHAR(250);

EXEC dbo.usp_generar_clientes
    @cantidad_objetivo = 50000,
    @codigo_error = @codigo_error OUTPUT,
    @mensaje_error = @mensaje_error OUTPUT;

SELECT
    @codigo_error AS codigo_error,
    @mensaje_error AS mensaje_error;
GO
