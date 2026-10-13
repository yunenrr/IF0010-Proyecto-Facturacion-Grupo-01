USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_consultar_auditoria;
GO

-- Consulta el historial de cambios, de lo mas reciente a lo mas antiguo.
-- Filtros opcionales (valor vacio / 0 = sin filtro):
--   @nombre_entidad: FACTURA, FACTURA_DETALLE, CLIENTE o ITEM_FACTURABLE
--   @registro_id:    clave primaria de la fila auditada (junto con la entidad)
--   @factura_id:     historial completo de una factura: su encabezado y sus
--                    lineas (el historial se conserva aunque la factura se elimine)
--   @desde / @hasta: rango de fecha_cambio (hasta exclusivo)
-- No modifica datos.
CREATE PROCEDURE dbo.usp_consultar_auditoria
    @nombre_entidad VARCHAR(30) = '',
    @registro_id BIGINT = 0,
    @factura_id BIGINT = 0,
    @desde DATETIME2 = '1900-01-01',
    @hasta DATETIME2 = '9999-12-31',
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    BEGIN TRY
        IF LEN(@nombre_entidad) > 0
            AND NOT EXISTS (SELECT 1 FROM dbo.entidad_auditada WHERE nombre = @nombre_entidad)
        BEGIN
            THROW 50511, 'La entidad indicada no se audita.', 1;
        END

        IF @desde > @hasta
        BEGIN
            THROW 50512, 'El rango de fechas es invalido.', 1;
        END

        SELECT
            a.auditoria_id,
            en.nombre AS entidad,
            a.registro_id,
            op.descripcion AS operacion,
            a.usuario,
            a.fecha_cambio,
            a.descripcion,
            a.datos_anteriores,
            a.datos_nuevos
        FROM dbo.auditoria AS a
        INNER JOIN dbo.entidad_auditada AS en
            ON en.entidad_auditada_id = a.entidad_auditada_id
        INNER JOIN dbo.tipo_operacion AS op
            ON op.tipo_operacion_id = a.tipo_operacion_id
        WHERE a.fecha_cambio >= @desde
            AND a.fecha_cambio < @hasta
            AND (LEN(@nombre_entidad) = 0 OR en.nombre = @nombre_entidad)
            AND (@registro_id = 0 OR a.registro_id = @registro_id)
            AND (
                @factura_id = 0
                OR (en.nombre = 'FACTURA' AND a.registro_id = @factura_id)
                OR (
                    en.nombre = 'FACTURA_DETALLE'
                    AND @factura_id = CAST(JSON_VALUE(
                        IIF(a.datos_nuevos = N'{}', a.datos_anteriores, a.datos_nuevos),
                        '$.factura_id') AS BIGINT)
                )
            )
        ORDER BY a.fecha_cambio DESC, a.auditoria_id DESC;
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
