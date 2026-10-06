DECLARE @codigo_error INT;
DECLARE @mensaje_error VARCHAR(4000);

EXEC dbo.usp_generar_empresas
    @cantidad_objetivo = 100,
    @codigo_error = @codigo_error OUTPUT,
    @mensaje_error = @mensaje_error OUTPUT;

SELECT
    @codigo_error AS codigo_error,
    @mensaje_error AS mensaje_error;
GO
