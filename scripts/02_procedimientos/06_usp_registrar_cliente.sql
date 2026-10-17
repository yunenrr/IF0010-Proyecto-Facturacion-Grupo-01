USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_REGISTRAR_CLIENTE;
GO

-- Registra un cliente (comprador). @tipo_persona = 'F' (persona fisica) o
-- 'J' (persona juridica). El cliente se guarda en dbo.cliente y en la subtabla
-- que corresponde (cliente_fisico o cliente_juridico) dentro de una unica
-- transaccion: si algo falla no queda ningun registro parcial.
-- La direccion se normaliza con @distrito_id (provincia/canton/distrito) y
-- @otras_senas. Devuelve el identificador creado en @cliente_id.
CREATE PROCEDURE DBO.USP_REGISTRAR_CLIENTE
    @tipo_persona CHAR(1),
    @identificacion VARCHAR(20),
    @correo VARCHAR(150),
    @telefono VARCHAR(20),
    @distrito_id INT,
    @otras_senas VARCHAR(250),
    @nombre VARCHAR(50) = '',
    @apellido1 VARCHAR(50) = '',
    @apellido2 VARCHAR(50) = '',
    @razon_social VARCHAR(150) = '',
    @nombre_comercial VARCHAR(150) = '',
    @cliente_id INT OUTPUT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @cliente_id = 0;
    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @ahora DATETIME2 = SYSDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @tipo_persona NOT IN ('F', 'J')
            BEGIN
                THROW 50101,
                'Tipo de persona invalido. Use F (fisica) o J (juridica).',
                1;
            END

        IF LEN(LTRIM(RTRIM(@identificacion))) = 0
            BEGIN
                THROW 50102, 'La identificacion es obligatoria.', 1;
            END

        IF
            EXISTS (
                SELECT 1 FROM DBO.CLIENTE
                WHERE IDENTIFICACION = @identificacion
            )
            BEGIN
                THROW 50103, 'Ya existe un cliente con esa identificacion.', 1;
            END

        IF CHARINDEX('@', @correo) < 2
            BEGIN
                THROW 50104, 'El correo electronico no es valido.', 1;
            END

        IF LEN(LTRIM(RTRIM(@telefono))) = 0
            BEGIN
                THROW 50105, 'El telefono es obligatorio.', 1;
            END

        IF LEN(LTRIM(RTRIM(@otras_senas))) = 0
            BEGIN
                THROW 50106,
                'Las otras senas de la direccion son obligatorias.',
                1;
            END

        IF
            NOT EXISTS (
                SELECT 1 FROM DBO.DISTRITO
                WHERE DISTRITO_ID = @distrito_id
            )
            BEGIN
                THROW 50107, 'El distrito indicado no existe.', 1;
            END

        IF
            @tipo_persona = 'F'
            AND (
                LEN(LTRIM(RTRIM(@nombre))) = 0
                OR LEN(LTRIM(RTRIM(@apellido1))) = 0
                OR LEN(LTRIM(RTRIM(@apellido2))) = 0
            )
            BEGIN
                THROW 50108,
                'Una persona fisica requiere nombre y dos apellidos.',
                1;
            END

        IF
            @tipo_persona = 'J'
            AND (
                LEN(LTRIM(RTRIM(@razon_social))) = 0
                OR LEN(LTRIM(RTRIM(@nombre_comercial))) = 0
            )
            BEGIN
                THROW 50109,
                'Una persona juridica requiere razon social y nombre comercial.', -- noqa: LT05
                1;
            END

        INSERT INTO DBO.CLIENTE (
            IDENTIFICACION, CORREO, TELEFONO, DISTRITO_ID, OTRAS_SENAS,
            FECHA_REGISTRO, FECHA_ACTUALIZACION
        )
        VALUES (
            @identificacion, @correo, @telefono, @distrito_id, @otras_senas,
            @ahora, @ahora
        );

        SET @cliente_id = CAST(SCOPE_IDENTITY() AS INT);

        IF @tipo_persona = 'F'
            BEGIN
                INSERT INTO DBO.CLIENTE_FISICO (
                    CLIENTE_ID, NOMBRE, APELLIDO1, APELLIDO2
                )
                VALUES (@cliente_id, @nombre, @apellido1, @apellido2);
            END
        ELSE
            BEGIN
                INSERT INTO DBO.CLIENTE_JURIDICO (
                    CLIENTE_ID, RAZON_SOCIAL, NOMBRE_COMERCIAL
                )
                VALUES (@cliente_id, @razon_social, @nombre_comercial);
            END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END

        SET @cliente_id = 0;
        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = LEFT(ERROR_MESSAGE(), 250);
    END CATCH
END;
GO
