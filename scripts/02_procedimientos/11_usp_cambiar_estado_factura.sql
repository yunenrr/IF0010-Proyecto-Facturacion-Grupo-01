USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cambiar_estado_factura;
GO

-- Cambia el estado de una factura respetando su flujo de vida:
--   BORRADOR -> EMITIDA | CANCELADA
--   EMITIDA  -> PAGADA  | CANCELADA
-- PAGADA y CANCELADA son estados finales. Al cancelar se devuelven al stock las
-- unidades de los productos con existencia. Actualiza fecha_modificacion.
CREATE PROCEDURE dbo.usp_cambiar_estado_factura
    @factura_id BIGINT,
    @codigo_estado_nuevo VARCHAR(20),
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @estado_actual_id INT;
    DECLARE @codigo_actual VARCHAR(20);
    DECLARE @estado_nuevo_id INT;
    DECLARE @codigo_nuevo VARCHAR(20);
    DECLARE @item_actual INT;
    DECLARE @unidades DECIMAL(18, 2);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @estado_actual_id = f.estado_factura_id,
            @codigo_actual = e.codigo
        FROM dbo.factura AS f WITH (UPDLOCK, ROWLOCK)
        INNER JOIN dbo.estadofactura AS e
            ON e.estado_factura_id = f.estado_factura_id
        WHERE f.factura_id = @factura_id;

        IF @estado_actual_id IS NULL
        BEGIN
            THROW 50301, 'La factura indicada no existe.', 1;
        END

        SELECT
            @estado_nuevo_id = estado_factura_id,
            @codigo_nuevo = codigo
        FROM dbo.estadofactura
        WHERE codigo = @codigo_estado_nuevo;

        IF @estado_nuevo_id IS NULL
        BEGIN
            THROW 50302, 'El estado indicado no existe.', 1;
        END

        IF NOT (
            (@codigo_actual = 'BORRADOR' AND @codigo_nuevo IN ('EMITIDA', 'CANCELADA'))
            OR (@codigo_actual = 'EMITIDA' AND @codigo_nuevo IN ('PAGADA', 'CANCELADA'))
        )
        BEGIN
            THROW 50303, 'La transicion de estado solicitada no esta permitida.', 1;
        END

        IF @codigo_nuevo = 'CANCELADA'
        BEGIN
            -- Devolucion de stock producto por producto en orden de id (evita
            -- interbloqueos con facturas concurrentes).
            SET @item_actual = 0;

            WHILE 1 = 1
            BEGIN
                SELECT TOP (1)
                    @item_actual = s.item_facturable_id,
                    @unidades = s.unidades
                FROM (
                    SELECT d.item_facturable_id, SUM(d.cantidad) AS unidades
                    FROM dbo.factura_detalle AS d
                    INNER JOIN dbo.producto_con_existencia AS p
                        ON p.producto_con_existencia_id = d.item_facturable_id
                    WHERE d.factura_id = @factura_id
                    GROUP BY d.item_facturable_id
                ) AS s
                WHERE s.item_facturable_id > @item_actual
                ORDER BY s.item_facturable_id;

                IF @@ROWCOUNT = 0
                BEGIN
                    BREAK;
                END

                UPDATE dbo.producto_con_existencia
                SET stock_actual = stock_actual + CAST(@unidades AS INT)
                WHERE producto_con_existencia_id = @item_actual;
            END
        END

        UPDATE dbo.factura
        SET
            estado_factura_id = @estado_nuevo_id,
            fecha_modificacion = SYSDATETIME()
        WHERE factura_id = @factura_id;

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
