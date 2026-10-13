USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_generar_clientes;
GO

-- Carga masiva de clientes hasta alcanzar @cantidad_objetivo registros en
-- total. Cada cliente se registra en dbo.cliente y en la subtabla que le
-- corresponde: cliente_fisico (90 %) o cliente_juridico (10 %). La direccion
-- se normaliza con distrito_id (provincia/canton/distrito) y otras_senas.
-- Requiere haber ejecutado usp_cargar_ubicaciones (distritos).
CREATE PROCEDURE dbo.usp_generar_clientes
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

        SET @total_distritos = (SELECT COUNT(*) FROM dbo.distrito);

        IF @total_distritos = 0
        BEGIN
            THROW 50012, 'No hay distritos cargados. Ejecute usp_cargar_ubicaciones primero.', 1;
        END

        SET @existentes = (SELECT COUNT(*) FROM dbo.cliente);
        SET @faltantes = @cantidad_objetivo - @existentes;

        IF @faltantes > 0
        BEGIN
            -- Distritos numerados para asignarlos de forma repartida
            SELECT
                CAST(ROW_NUMBER() OVER (ORDER BY distrito_id) AS INT) AS rn,
                distrito_id
            INTO #distritos
            FROM dbo.distrito;

            -- Clientes por insertar (identificacion unica y datos de contacto)
            SELECT
                n.seq,
                CASE WHEN n.seq % 10 = 0 THEN 1 ELSE 0 END AS es_juridico,
                CASE
                    WHEN n.seq % 10 = 0
                        THEN '3102' + RIGHT('000000' + CAST(n.seq AS VARCHAR(10)), 6)
                    ELSE '1' + RIGHT('00000000' + CAST(n.seq AS VARCHAR(10)), 8)
                END AS identificacion,
                'cliente' + CAST(n.seq AS VARCHAR(10)) + '@correo.example.cr' AS correo,
                '8' + RIGHT('0000000' + CAST(CAST(n.seq AS BIGINT) * 7919 % 10000000 AS VARCHAR(10)), 7) AS telefono,
                d.distrito_id,
                'Casa ' + CAST(n.seq AS VARCHAR(10)) + ', '
                + CHOOSE(n.seq % 8 + 1,
                    '200 metros norte de la iglesia',
                    '100 metros sur del parque',
                    '50 metros este de la escuela',
                    '300 metros oeste del Banco Nacional',
                    'frente a la plaza de deportes',
                    'costado norte del mercado',
                    'diagonal a la clinica',
                    '150 metros sur de la pulperia') AS otras_senas,
                DATEADD(DAY, -(n.seq * 13 % 700) - 31, @ahora) AS fecha_registro,
                DATEADD(DAY, -(n.seq * 13 % 700) - 31 + (n.seq % 30), @ahora) AS fecha_actualizacion,
                CHOOSE(n.seq * 7 % 20 + 1,
                    'Juan', 'Maria', 'Carlos', 'Ana', 'Luis', 'Sofia', 'Jose',
                    'Laura', 'Diego', 'Daniela', 'Andres', 'Valeria', 'Mario',
                    'Camila', 'Pablo', 'Fernanda', 'Jorge', 'Paola', 'Ricardo',
                    'Karla') AS nombre,
                CHOOSE(n.seq * 11 % 20 + 1,
                    'Rodriguez', 'Vargas', 'Jimenez', 'Mora', 'Solano', 'Araya',
                    'Gonzalez', 'Rojas', 'Quesada', 'Alvarado', 'Chaves', 'Castro',
                    'Salazar', 'Campos', 'Barrantes', 'Hernandez', 'Fernandez',
                    'Calderon', 'Navarro', 'Zamora') AS apellido1,
                CHOOSE(n.seq * 13 % 20 + 1,
                    'Perez', 'Lopez', 'Ramirez', 'Cordero', 'Segura', 'Brenes',
                    'Villalobos', 'Cespedes', 'Monge', 'Vindas', 'Madrigal',
                    'Carvajal', 'Umana', 'Esquivel', 'Arguedas', 'Sandi', 'Porras',
                    'Leiva', 'Ulate', 'Cruz') AS apellido2,
                CHOOSE(n.seq * 3 % 10 + 1,
                    'Comercial', 'Distribuidora', 'Servicios', 'Inversiones',
                    'Constructora', 'Importadora', 'Agricola', 'Transportes',
                    'Consultores', 'Tecnologias') AS tipo_negocio
            INTO #nuevos
            FROM (
                SELECT TOP (@faltantes)
                    @existentes + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS seq
                FROM sys.all_objects AS a
                CROSS JOIN sys.all_objects AS b
                WHERE a.object_id IS NOT NULL
                    AND b.object_id IS NOT NULL
            ) AS n
            INNER JOIN #distritos AS d
                ON d.rn = n.seq % @total_distritos + 1;

            -- Supertipo
            INSERT INTO dbo.cliente (
                identificacion, correo, telefono, distrito_id, otras_senas,
                fecha_registro, fecha_actualizacion
            )
            SELECT
                identificacion, correo, telefono, distrito_id, otras_senas,
                fecha_registro, fecha_actualizacion
            FROM #nuevos
            ORDER BY seq;

            -- Subtipo: personas fisicas
            INSERT INTO dbo.cliente_fisico (cliente_id, nombre, apellido1, apellido2)
            SELECT c.cliente_id, n.nombre, n.apellido1, n.apellido2
            FROM #nuevos AS n
            INNER JOIN dbo.cliente AS c
                ON c.identificacion = n.identificacion
            WHERE n.es_juridico = 0;

            -- Subtipo: personas juridicas
            INSERT INTO dbo.cliente_juridico (cliente_id, razon_social, nombre_comercial)
            SELECT
                c.cliente_id,
                n.tipo_negocio + ' ' + n.apellido1 + ' ' + CAST(n.seq AS VARCHAR(10)) + ' Sociedad Anonima',
                n.tipo_negocio + ' ' + n.apellido1 + ' ' + CAST(n.seq AS VARCHAR(10))
            FROM #nuevos AS n
            INNER JOIN dbo.cliente AS c
                ON c.identificacion = n.identificacion
            WHERE n.es_juridico = 1;
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
