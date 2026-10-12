DECLARE @codigo_error INT;
DECLARE @mensaje_error VARCHAR(4000);

EXEC dbo.usp_cargar_catalogos
    @codigo_error = @codigo_error OUTPUT,
    @mensaje_error = @mensaje_error OUTPUT;

SELECT
    @codigo_error AS codigo_error,
    @mensaje_error AS mensaje_error;
GO
