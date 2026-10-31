USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_CONSULTAR_AUDITORIA;
GO

-- Consulta el historial de cambios, de lo mas reciente a lo mas antiguo.
-- Filtros opcionales (valor vacio / 0 = sin filtro):
--   @nombre_entidad: FACTURA, FACTURA_DETALLE, CLIENTE o ITEM_FACTURABLE
--   @registro_id:    clave primaria de la fila auditada (junto con la entidad)
--   @factura_id:     historial completo de una factura: su encabezado y sus
--                    lineas (el historial se conserva aunque la factura se
-- elimine)
--   @desde / @hasta: rango de fecha_cambio (hasta exclusivo)
-- No modifica datos.
CREATE PROCEDURE DBO.USP_CONSULTAR_AUDITORIA
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
        IF
            LEN(@nombre_entidad) > 0
            AND NOT EXISTS (
                SELECT 1 FROM DBO.ENTIDAD_AUDITADA
                WHERE NOMBRE = @nombre_entidad
            )
            BEGIN
                THROW 50511, 'La entidad indicada no se audita.', 1;
            END

        IF @desde > @hasta
            BEGIN
                THROW 50512, 'El rango de fechas es invalido.', 1;
            END

        SELECT
            A.AUDITORIA_ID,
            EN.NOMBRE AS ENTIDAD,
            A.REGISTRO_ID,
            OP.DESCRIPCION AS OPERACION,
            A.USUARIO,
            A.FECHA_CAMBIO,
            A.DESCRIPCION,
            A.DATOS_ANTERIORES,
            A.DATOS_NUEVOS
        FROM DBO.AUDITORIA AS A
        INNER JOIN DBO.ENTIDAD_AUDITADA AS EN
            ON A.ENTIDAD_AUDITADA_ID = EN.ENTIDAD_AUDITADA_ID
        INNER JOIN DBO.TIPO_OPERACION AS OP
            ON A.TIPO_OPERACION_ID = OP.TIPO_OPERACION_ID
        WHERE
            A.FECHA_CAMBIO >= @desde
            AND A.FECHA_CAMBIO < @hasta
            AND (LEN(@nombre_entidad) = 0 OR EN.NOMBRE = @nombre_entidad)
            AND (@registro_id = 0 OR A.REGISTRO_ID = @registro_id)
            AND (
                @factura_id = 0
                OR (EN.NOMBRE = 'FACTURA' AND A.REGISTRO_ID = @factura_id)
                OR (
                    EN.NOMBRE = 'FACTURA_DETALLE'
                    AND @factura_id = CAST(JSON_VALUE(
                        IIF(
                            A.DATOS_NUEVOS = N'{}',
                            A.DATOS_ANTERIORES,
                            A.DATOS_NUEVOS
                        ),
                        '$.factura_id'
                    ) AS BIGINT)
                )
            )
        ORDER BY A.FECHA_CAMBIO DESC, A.AUDITORIA_ID DESC;
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
