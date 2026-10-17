USE PROYECTOFACTURACION;
GO

DECLARE @codigo_error INT;
DECLARE @mensaje_error VARCHAR(250);

EXEC DBO.USP_CARGAR_UBICACIONES
    @codigo_error = @codigo_error OUTPUT,
    @mensaje_error = @mensaje_error OUTPUT;

SELECT
    @codigo_error AS CODIGO_ERROR,
    @mensaje_error AS MENSAJE_ERROR;

IF @codigo_error <> 0
    BEGIN
        RAISERROR ('Fallo la carga de ubicaciones: %s', 16, 1, @mensaje_error);
    END
GO
