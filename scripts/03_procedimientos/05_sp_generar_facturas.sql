USE C21626;
GO

CREATE OR ALTER PROCEDURE dbo.sp_generar_facturas
    @cantidad_facturas INT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @contador INT = 1;
    DECLARE @fecha_actual DATETIME;
    DECLARE @tipo_doc_codigo VARCHAR(10);
    DECLARE @numero_factura VARCHAR(50);
    DECLARE @cliente_id INT;
    DECLARE @empresa_id INT;
    DECLARE @estado_id INT;
    DECLARE @moneda_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        WHILE @contador <= @cantidad_facturas
        BEGIN
            -- Simular fecha aleatoria en el último año y datos relacionados
            SET @fecha_actual = DATEADD(DAY, -CHECKSUM(NEWID()) % 365, GETDATE());
            
            -- Obtener un tipo de documento aleatorio de la base
            SELECT TOP 1 @tipo_doc_codigo = codigo FROM dbo.tipo_documento ORDER BY NEWID();
            SELECT TOP 1 @cliente_id = cliente_id FROM dbo.cliente ORDER BY NEWID();
            SELECT TOP 1 @empresa_id = empresa_id FROM dbo.empresa_emisora ORDER BY NEWID();
            SELECT TOP 1 @estado_id = estado_factura_id FROM dbo.estado_factura ORDER BY NEWID();
            SELECT TOP 1 @moneda_id = moneda_id FROM dbo.moneda ORDER BY NEWID();

            -- CONSTRUIR EL IDENTIFICADOR BAJO EL ESTÁNDAR: AAAAMMDDHHMMSS-TipoDocumento
            SET @numero_factura = 
                FORMAT(@fecha_actual, 'yyyyMMddHHmmss') + '-' + ISNULL(@tipo_doc_codigo, 'FE');

            -- Insertar la factura
            INSERT INTO dbo.factura (
                numero_factura,
                fecha_emision,
                cliente_id,
                empresa_id,
                estado_factura_id,
                moneda_id
            )
            VALUES (
                @numero_factura,
                @fecha_actual,
                @cliente_id,
                @empresa_id,
                @estado_id,
                @moneda_id
            );

            SET @contador = @contador + 1;
        END

        COMMIT TRANSACTION;
        SET @codigo_error = 0;
        SET @mensaje_error = 'Facturas generadas correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH
END;
GO
