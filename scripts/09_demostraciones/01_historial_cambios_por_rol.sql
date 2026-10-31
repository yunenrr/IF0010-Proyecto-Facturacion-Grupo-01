USE PROYECTOFACTURACION;
GO

DECLARE @correo VARCHAR(150);
DECLARE @distrito INT;
DECLARE @senas VARCHAR(250);
DECLARE @telefono VARCHAR(20);
DECLARE @cod INT;
DECLARE @msg VARCHAR(250);
DECLARE @filas INT;
DECLARE @orden INT = 1;
DECLARE @total INT;
DECLARE @usuario VARCHAR(30);
DECLARE @rol VARCHAR(30);
DECLARE @sql NVARCHAR(300);
DECLARE @usuarios TABLE (
    ORDEN INT IDENTITY (1, 1),
    USUARIO VARCHAR(30),
    ROL VARCHAR(30)
);
DECLARE @demo TABLE (
    ORDEN INT IDENTITY (1, 1),
    USUARIO VARCHAR(30),
    ROL VARCHAR(30),
    FILAS_VISIBLES VARCHAR(30)
);

BEGIN TRANSACTION;

SELECT
    @correo = CORREO,
    @distrito = DISTRITO_ID,
    @senas = OTRAS_SENAS,
    @telefono = CASE
        WHEN TELEFONO = '88887777' THEN '88886666'
        ELSE '88887777'
    END
FROM DBO.CLIENTE
WHERE CLIENTE_ID = 1;

EXEC DBO.USP_ACTUALIZAR_CLIENTE
    @cliente_id = 1,
    @correo = @correo,
    @telefono = @telefono,
    @distrito_id = @distrito,
    @otras_senas = @senas,
    @codigo_error = @cod OUTPUT,
    @mensaje_error = @msg OUTPUT;

IF @cod <> 0
    BEGIN
        IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END

        RAISERROR ('No se pudo generar el cambio de prueba: %s', 16, 1, @msg);
        RETURN;
    END

SET @filas = (SELECT COUNT(*) FROM DBO.FN_CONSULTAR_HISTORIAL_CAMBIOS());
INSERT INTO @demo (USUARIO, ROL, FILAS_VISIBLES)
VALUES ('ADMINISTRADOR ACTUAL', 'db_owner', CAST(@filas AS VARCHAR(30)));

INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_AUDITOR', 'ROL_AUDITOR');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_DBA', 'ROL_DBA');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_ADMIN', 'ROL_ADMINISTRATIVO');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_CAJERO', 'ROL_CAJERO');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_CONSULTA', 'ROL_CONSULTA');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_SIN_ROL', '(ninguno)');

SET @total = (SELECT COUNT(*) FROM @usuarios);

WHILE @orden <= @total
    BEGIN
        SELECT
            @usuario = USUARIO,
            @rol = ROL
        FROM @usuarios
        WHERE ORDEN = @orden;

        SET @filas = NULL;
        SET @sql = CONCAT(
            N'EXECUTE AS USER = ',
            QUOTENAME(@usuario, ''''),
            N'; SELECT @f = COUNT(*) ',
            N'FROM DBO.FN_CONSULTAR_HISTORIAL_CAMBIOS(); ',
            N'REVERT;'
        );

        BEGIN TRY
            EXEC SYS.SP_EXECUTESQL
                @sql,
                N'@f INT OUTPUT',
                @f = @filas OUTPUT;
        END TRY
        BEGIN CATCH
            SET @filas = NULL;
        END CATCH

        INSERT INTO @demo (USUARIO, ROL, FILAS_VISIBLES)
        VALUES (
            @usuario, @rol,
            ISNULL(CAST(@filas AS VARCHAR(30)), 'SIN PERMISO')
        );

        SET @orden = @orden + 1;
    END

SELECT
    USUARIO,
    ROL,
    FILAS_VISIBLES
FROM @demo
ORDER BY ORDEN;

ROLLBACK TRANSACTION;
GO
