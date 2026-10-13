USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_eliminar_factura;
GO

-- Elimina una factura en estado BORRADOR junto con todas sus lineas de detalle
-- (nunca queda un encabezado sin cuerpo ni un cuerpo sin encabezado). Las
-- facturas EMITIDA, PAGADA o CANCELADA no se eliminan: se cancelan con
-- usp_cambiar_estado_factura. Devuelve al stock las unidades de los productos
-- con existencia.
CREATE PROCEDURE dbo.usp_eliminar_factura
    @factura_id BIGINT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    DECLARE @codigo_actual VARCHAR(20);
    DECLARE @item_actual INT;
    DECLARE @unidades DECIMAL(18, 2);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @codigo_actual = e.codigo
        FROM dbo.factura AS f WITH (UPDLOCK, ROWLOCK)
        INNER JOIN dbo.estadofactura AS e
            ON e.estado_factura_id = f.estado_factura_id
        WHERE f.factura_id = @factura_id;

        IF @codigo_actual IS NULL
        BEGIN
            THROW 50311, 'La factura indicada no existe.', 1;
        END

        IF @codigo_actual <> 'BORRADOR'
        BEGIN
            THROW 50312, 'Solo se pueden eliminar facturas en estado BORRADOR.', 1;
        END

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
        DELETE FROM dbo.factura_detalle
        WHERE factura_id = @factura_id;

        DELETE FROM dbo.factura
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
