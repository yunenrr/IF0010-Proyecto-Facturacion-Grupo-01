USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_GENERAR_CLIENTES;
GO

-- Carga masiva de clientes hasta alcanzar @cantidad_objetivo registros en
-- total. Cada cliente se registra en dbo.cliente y en la subtabla que le
-- corresponde: cliente_fisico (90 %) o cliente_juridico (10 %). La direccion
-- se normaliza con distrito_id (provincia/canton/distrito) y otras_senas.
-- Requiere haber ejecutado usp_cargar_ubicaciones (distritos).
CREATE PROCEDURE DBO.USP_GENERAR_CLIENTES
    @cantidad_objetivo INT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @existentes INT;
    DECLARE @faltantes INT;
    DECLARE @total_distritos INT;
    DECLARE @ahora DATETIME2 = SYSDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @cantidad_objetivo IS NULL OR @cantidad_objetivo <= 0
            BEGIN
                THROW 50011, 'La cantidad objetivo debe ser mayor que cero.', 1;
            END

        SET @total_distritos = (SELECT COUNT(*) FROM DBO.DISTRITO);

        IF @total_distritos = 0
            BEGIN
                THROW 50012,
                'No hay distritos cargados. Ejecute usp_cargar_ubicaciones primero.', -- noqa: LT05
                1;
            END

        SET @existentes = (SELECT COUNT(*) FROM DBO.CLIENTE);
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes > 0
            BEGIN
            -- Distritos numerados para asignarlos de forma repartida
                SELECT
                    CAST(ROW_NUMBER() OVER (ORDER BY DISTRITO_ID) AS INT) AS RN,
                    DISTRITO_ID
                INTO #distritos
                FROM DBO.DISTRITO;

                -- Clientes por insertar (identificacion unica y datos de
                -- contacto)
                SELECT
                    N.SEQ,
                    D.DISTRITO_ID,
                    CASE WHEN N.SEQ % 10 = 0 THEN 1 ELSE 0 END AS ES_JURIDICO,
                    CASE
                        WHEN N.SEQ % 10 = 0
                            THEN
                                '3102'
                                + RIGHT(
                                    '000000' + CAST(N.SEQ AS VARCHAR(10)), 6
                                )
                        ELSE
                            '1'
                            + RIGHT('00000000' + CAST(N.SEQ AS VARCHAR(10)), 8)
                    END AS IDENTIFICACION,
                    'cliente'
                    + CAST(N.SEQ AS VARCHAR(10))
                    + '@correo.example.cr' AS CORREO,
                    '8'
                    + RIGHT(
                        '0000000'
                        + CAST(
                            CAST(N.SEQ AS BIGINT)
                            * 7919
                            % 10000000 AS VARCHAR(10)
                        ),
                        7
                    ) AS TELEFONO,
                    'Casa ' + CAST(N.SEQ AS VARCHAR(10)) + ', '
                    + CHOOSE(
                        N.SEQ % 8 + 1,
                        '200 metros norte de la iglesia',
                        '100 metros sur del parque',
                        '50 metros este de la escuela',
                        '300 metros oeste del Banco Nacional',
                        'frente a la plaza de deportes',
                        'costado norte del mercado',
                        'diagonal a la clinica',
                        '150 metros sur de la pulperia'
                    ) AS OTRAS_SENAS,
                    DATEADD(DAY, -(N.SEQ * 13 % 700) - 31, @ahora)
                        AS FECHA_REGISTRO,
                    DATEADD(
                        DAY, -(N.SEQ * 13 % 700) - 31 + (N.SEQ % 30), @ahora
                    ) AS FECHA_ACTUALIZACION,
                    CHOOSE(
                        N.SEQ * 7 % 20 + 1,
                        'Juan',
                        'Maria',
                        'Carlos',
                        'Ana',
                        'Luis',
                        'Sofia',
                        'Jose',
                        'Laura',
                        'Diego',
                        'Daniela',
                        'Andres',
                        'Valeria',
                        'Mario',
                        'Camila',
                        'Pablo',
                        'Fernanda',
                        'Jorge',
                        'Paola',
                        'Ricardo',
                        'Karla'
                    ) AS NOMBRE,
                    CHOOSE(
                        N.SEQ * 11 % 20 + 1,
                        'Rodriguez',
                        'Vargas',
                        'Jimenez',
                        'Mora',
                        'Solano',
                        'Araya',
                        'Gonzalez',
                        'Rojas',
                        'Quesada',
                        'Alvarado',
                        'Chaves',
                        'Castro',
                        'Salazar',
                        'Campos',
                        'Barrantes',
                        'Hernandez',
                        'Fernandez',
                        'Calderon', 'Navarro', 'Zamora'
                    ) AS APELLIDO1,
                    CHOOSE(
                        N.SEQ * 13 % 20 + 1,
                        'Perez',
                        'Lopez',
                        'Ramirez',
                        'Cordero',
                        'Segura',
                        'Brenes',
                        'Villalobos', 'Cespedes', 'Monge', 'Vindas', 'Madrigal',
                        'Carvajal',
                        'Umana',
                        'Esquivel',
                        'Arguedas',
                        'Sandi',
                        'Porras',
                        'Leiva', 'Ulate', 'Cruz'
                    ) AS APELLIDO2,
                    CHOOSE(
                        N.SEQ * 3 % 10 + 1,
                        'Comercial',
                        'Distribuidora',
                        'Servicios',
                        'Inversiones',
                        'Constructora',
                        'Importadora',
                        'Agricola',
                        'Transportes',
                        'Consultores', 'Tecnologias'
                    ) AS TIPO_NEGOCIO
                INTO #nuevos
                FROM (
                    SELECT TOP (@faltantes)
                        @existentes
                        + CAST(
                            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT
                        ) AS SEQ
                    FROM SYS.ALL_OBJECTS AS A
                    CROSS JOIN SYS.ALL_OBJECTS AS B
                    WHERE
                        A.OBJECT_ID IS NOT NULL
                        AND B.OBJECT_ID IS NOT NULL
                ) AS N
                INNER JOIN #distritos AS D
                    ON D.RN = N.SEQ % @total_distritos + 1;

                -- Supertipo
                INSERT INTO DBO.CLIENTE (
                    IDENTIFICACION, CORREO, TELEFONO, DISTRITO_ID, OTRAS_SENAS,
                    FECHA_REGISTRO, FECHA_ACTUALIZACION
                )
                SELECT
                    IDENTIFICACION,
                    CORREO,
                    TELEFONO,
                    DISTRITO_ID,
                    OTRAS_SENAS,
                    FECHA_REGISTRO,
                    FECHA_ACTUALIZACION
                FROM #nuevos
                ORDER BY SEQ;

                -- Subtipo: personas fisicas
                INSERT INTO DBO.CLIENTE_FISICO (
                    CLIENTE_ID, NOMBRE, APELLIDO1, APELLIDO2
                )
                SELECT
                    C.CLIENTE_ID,
                    N.NOMBRE,
                    N.APELLIDO1,
                    N.APELLIDO2
                FROM #nuevos AS N
                INNER JOIN DBO.CLIENTE AS C
                    ON N.IDENTIFICACION = C.IDENTIFICACION
                WHERE N.ES_JURIDICO = 0;

                -- Subtipo: personas juridicas
                INSERT INTO DBO.CLIENTE_JURIDICO (
                    CLIENTE_ID, RAZON_SOCIAL, NOMBRE_COMERCIAL
                )
                SELECT
                    C.CLIENTE_ID,
                    N.TIPO_NEGOCIO
                    + ' '
                    + N.APELLIDO1
                    + ' '
                    + CAST(N.SEQ AS VARCHAR(10))
                    + ' Sociedad Anonima' AS RAZON_SOCIAL,
                    N.TIPO_NEGOCIO
                    + ' '
                    + N.APELLIDO1
                    + ' '
                    + CAST(N.SEQ AS VARCHAR(10)) AS NOMBRE_COMERCIAL
                FROM #nuevos AS N
                INNER JOIN DBO.CLIENTE AS C
                    ON N.IDENTIFICACION = C.IDENTIFICACION
                WHERE N.ES_JURIDICO = 1;
            END

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
