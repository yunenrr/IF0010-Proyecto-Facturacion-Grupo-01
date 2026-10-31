USE PROYECTOFACTURACION;
GO

DECLARE @id VARCHAR(20) = (
    SELECT TOP (1) IDENTIFICACION
    FROM DBO.CLIENTE
    ORDER BY CLIENTE_ID
);
DECLARE @correo VARCHAR(150);
DECLARE @telefono VARCHAR(20);
DECLARE @orden INT = 1;
DECLARE @total INT;
DECLARE @usuario VARCHAR(30);
DECLARE @rol VARCHAR(30);
DECLARE @sql NVARCHAR(400);
DECLARE @params NVARCHAR(200) = CONCAT(
    N'@i VARCHAR(20), ',
    N'@c VARCHAR(150) OUTPUT, ',
    N'@t VARCHAR(20) OUTPUT'
);
DECLARE @usuarios TABLE (
    ORDEN INT IDENTITY (1, 1),
    USUARIO VARCHAR(30),
    ROL VARCHAR(30)
);
DECLARE @demo TABLE (
    ORDEN INT IDENTITY (1, 1),
    IDENTIFICACION VARCHAR(20),
    USUARIO VARCHAR(30),
    ROL VARCHAR(30),
    CORREO_VISTO VARCHAR(150),
    TELEFONO_VISTO VARCHAR(30)
);

SET @correo = NULL;
SET @telefono = NULL;
SELECT
    @correo = CORREO,
    @telefono = TELEFONO
FROM DBO.FN_CONSULTAR_CLIENTE(@id);
INSERT INTO @demo (IDENTIFICACION, USUARIO, ROL, CORREO_VISTO, TELEFONO_VISTO)
VALUES (
    @id, 'ADMINISTRADOR ACTUAL', 'db_owner',
    ISNULL(@correo, 'SIN DATOS'), ISNULL(@telefono, 'SIN DATOS')
);

INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_ADMIN', 'ROL_ADMINISTRATIVO');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_DBA', 'ROL_DBA');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_CAJERO', 'ROL_CAJERO');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_CONSULTA', 'ROL_CONSULTA');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_AUDITOR', 'ROL_AUDITOR');
INSERT INTO @usuarios (USUARIO, ROL) VALUES ('USR_SIN_ROL', '(ninguno)');

SET @total = (SELECT COUNT(*) FROM @usuarios);

WHILE @orden <= @total
    BEGIN
        SELECT
            @usuario = USUARIO,
            @rol = ROL
        FROM @usuarios
        WHERE ORDEN = @orden;

        SET @correo = NULL;
        SET @telefono = NULL;
        SET @sql = CONCAT(
            N'EXECUTE AS USER = ',
            QUOTENAME(@usuario, ''''),
            N'; SELECT @c = CORREO, @t = TELEFONO ',
            N'FROM DBO.FN_CONSULTAR_CLIENTE(@i); ',
            N'REVERT;'
        );

        BEGIN TRY
            EXEC SYS.SP_EXECUTESQL
                @sql,
                @params,
                @i = @id,
                @c = @correo OUTPUT,
                @t = @telefono OUTPUT;
        END TRY
        BEGIN CATCH
            SET @correo = NULL;
            SET @telefono = NULL;
        END CATCH

        INSERT INTO @demo (
            IDENTIFICACION, USUARIO, ROL, CORREO_VISTO, TELEFONO_VISTO
        )
        VALUES (
            @id, @usuario, @rol,
            ISNULL(@correo, 'SIN PERMISO'), ISNULL(@telefono, 'SIN PERMISO')
        );

        SET @orden = @orden + 1;
    END

SELECT
    IDENTIFICACION,
    USUARIO,
    ROL,
    CORREO_VISTO,
    TELEFONO_VISTO
FROM @demo
ORDER BY ORDEN;
GO
