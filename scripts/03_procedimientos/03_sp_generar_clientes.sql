CREATE OR ALTER PROCEDURE dbo.sp_generar_clientes
    @cantidad_objetivo INT = 50000,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @existentes INT;
        DECLARE @faltantes INT;

        SELECT @existentes = COUNT(*)
        FROM dbo.cliente;

        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes <= 0
        BEGIN
            SET @codigo_error = 0;
            SET @mensaje_error =
                'Ya existen '
                + CAST(@existentes AS VARCHAR(10))
                + ' o mas clientes en la base de datos.';

            RETURN;
        END;

        BEGIN TRANSACTION;

        WITH
        l0 AS (
            SELECT v.c
            FROM (
                VALUES
                    (1), (1), (1), (1), (1),
                    (1), (1), (1), (1), (1)
            ) AS v(c)
        ),

        l1 AS (
            SELECT
                a.c + b.c - 1 AS c
            FROM l0 AS a
            CROSS JOIN l0 AS b
        ),

        l2 AS (
            SELECT
                a.c + b.c - 1 AS c
            FROM l1 AS a
            CROSS JOIN l1 AS b
        ),

        l3 AS (
            SELECT
                a.c + b.c - 1 AS c
            FROM l2 AS a
            CROSS JOIN l2 AS b
        ),

        numbers AS (
            SELECT TOP (@faltantes)
                ROW_NUMBER() OVER (
                    ORDER BY (SELECT NULL)
                ) AS n
            FROM l3
        ),

        generador AS (
            SELECT
                n,

                CAST(
                    100000000 + @existentes + n
                    AS VARCHAR(20)
                ) AS cedula,

                CHOOSE(
                    (n % 20) + 1,
                    'Carlos',
                    'Ana',
                    'Luis',
                    'Maria',
                    'Jose',
                    'Sofia',
                    'Juan',
                    'Laura',
                    'Diego',
                    'Lucia',
                    'Pedro',
                    'Elena',
                    'Jorge',
                    'Valeria',
                    'Gabriel',
                    'Camila',
                    'Fernando',
                    'Paula',
                    'Andres',
                    'Daniela'
                ) AS primer_nombre,

                CHOOSE(
                    ((n / 20) % 20) + 1,
                    'Rodriguez',
                    'Gonzalez',
                    'Lopez',
                    'Jimenez',
                    'Mora',
                    'Vargas',
                    'Castro',
                    'Sanchez',
                    'Rojas',
                    'Navarro',
                    'Solano',
                    'Alvarado',
                    'Araya',
                    'Chaves',
                    'Gomez',
                    'Fernandez',
                    'Garcia',
                    'Perez',
                    'Herrera',
                    'Soto'
                ) AS primer_apellido,

                CHOOSE(
                    ((n / 400) % 20) + 1,
                    'Mora',
                    'Vargas',
                    'Castro',
                    'Sanchez',
                    'Rojas',
                    'Navarro',
                    'Solano',
                    'Alvarado',
                    'Araya',
                    'Chaves',
                    'Gomez',
                    'Fernandez',
                    'Garcia',
                    'Perez',
                    'Herrera',
                    'Rodriguez',
                    'Gonzalez',
                    'Lopez',
                    'Jimenez',
                    'Soto'
                ) AS segundo_apellido,

                '8'
                + RIGHT(
                    '0000000'
                    + CAST(
                        (@existentes + n)
                        AS VARCHAR(10)
                    ),
                    7
                ) AS telefono,

                CHOOSE(
                    (n % 7) + 1,
                    'San Jose, Escazu, Centro',
                    'Cartago, Paraiso, Llanos de Santa Lucia',
                    'Alajuela, San Carlos, Ciudad Quesada',
                    'Heredia, Belen, San Antonio',
                    'Guanacaste, Liberia, Centro',
                    'Puntarenas, Esparza, Espiritu Santo',
                    'Limon, Pococi, Guapiles'
                ) AS direccion,

                DATEADD(
                    MINUTE,
                    -(n % 525600),
                    SYSDATETIME()
                ) AS fecha_reg

            FROM numbers
        )

        INSERT INTO dbo.cliente (
            cedula,
            nombre_razon_social,
            direccion,
            telefono,
            correo_electronico,
            fecha_registro,
            fecha_ultima_actualizacion
        )
        SELECT
            cedula,

            primer_nombre
                + ' '
                + primer_apellido
                + ' '
                + segundo_apellido,

            direccion,

            telefono,

            'cliente'
                + CAST(
                    (@existentes + n)
                    AS VARCHAR(10)
                )
                + '@correo.cr',

            fecha_reg,

            fecha_reg

        FROM generador;

        COMMIT TRANSACTION;

        SET @codigo_error = 0;

        SET @mensaje_error =
            'Clientes generados exitosamente. Total actual: '
            + CAST(
                (@existentes + @faltantes)
                AS VARCHAR(10)
            );

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH;
END;
GO
