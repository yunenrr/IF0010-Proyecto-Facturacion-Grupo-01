USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_actualizar_cliente;
GO

-- Actualiza los datos de contacto del comprador: correo, telefono y direccion
-- (distrito normalizado + otras senas). Refresca fecha_actualizacion.
CREATE PROCEDURE dbo.usp_actualizar_cliente
    @cliente_id INT,
    @correo VARCHAR(150),
    @telefono VARCHAR(20),
    @distrito_id INT,
    @otras_senas VARCHAR(250),
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE cliente_id = @cliente_id)
        BEGIN
            THROW 50111, 'El cliente indicado no existe.', 1;
        END

        IF CHARINDEX('@', @correo) < 2
        BEGIN
            THROW 50112, 'El correo electronico no es valido.', 1;
        END

        IF LEN(LTRIM(RTRIM(@telefono))) = 0
        BEGIN
            THROW 50113, 'El telefono es obligatorio.', 1;
        END

        IF LEN(LTRIM(RTRIM(@otras_senas))) = 0
        BEGIN
            THROW 50114, 'Las otras senas de la direccion son obligatorias.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.distrito WHERE distrito_id = @distrito_id)
        BEGIN
            THROW 50115, 'El distrito indicado no existe.', 1;
        END

        UPDATE dbo.cliente
        SET
            correo = @correo,
            telefono = @telefono,
            distrito_id = @distrito_id,
            otras_senas = @otras_senas,
            fecha_actualizacion = SYSDATETIME()
        WHERE cliente_id = @cliente_id;

        COMMIT TRANSACTION;
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
