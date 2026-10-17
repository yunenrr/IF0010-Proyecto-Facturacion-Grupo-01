USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_ELIMINAR_FACTURA;
GO

-- Elimina una factura en estado BORRADOR junto con todas sus lineas de detalle
-- (nunca queda un encabezado sin cuerpo ni un cuerpo sin encabezado). Las
-- facturas EMITIDA, PAGADA o CANCELADA no se eliminan: se cancelan con
-- usp_cambiar_estado_factura. Devuelve al stock las unidades de los productos
-- con existencia.
CREATE PROCEDURE DBO.USP_ELIMINAR_FACTURA
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

        SELECT @codigo_actual = E.CODIGO
        FROM DBO.FACTURA AS F WITH (UPDLOCK, ROWLOCK)
        INNER JOIN DBO.ESTADOFACTURA AS E
            ON F.ESTADO_FACTURA_ID = E.ESTADO_FACTURA_ID
        WHERE F.FACTURA_ID = @factura_id;

        IF @codigo_actual IS NULL
            BEGIN
                THROW 50311, 'La factura indicada no existe.', 1;
            END

        IF @codigo_actual <> 'BORRADOR'
            BEGIN
                THROW 50312,
                'Solo se pueden eliminar facturas en estado BORRADOR.',
                1;
            END

        -- Devolucion de stock producto por producto en orden de id (evita
        -- interbloqueos con facturas concurrentes).
        SET @item_actual = 0;

        WHILE 1 = 1
            BEGIN
                SELECT TOP (1)
                    @item_actual = S.ITEM_FACTURABLE_ID,
                    @unidades = S.UNIDADES
                FROM (
                    SELECT
                        D.ITEM_FACTURABLE_ID,
                        SUM(D.CANTIDAD) AS UNIDADES
                    FROM DBO.FACTURA_DETALLE AS D
                    INNER JOIN DBO.PRODUCTO_CON_EXISTENCIA AS P
                        ON D.ITEM_FACTURABLE_ID = P.PRODUCTO_CON_EXISTENCIA_ID
                    WHERE D.FACTURA_ID = @factura_id
                    GROUP BY D.ITEM_FACTURABLE_ID
                ) AS S
                WHERE S.ITEM_FACTURABLE_ID > @item_actual
                ORDER BY S.ITEM_FACTURABLE_ID;

                IF @@ROWCOUNT = 0
                    BEGIN
                        BREAK;
                    END

                UPDATE DBO.PRODUCTO_CON_EXISTENCIA
                SET STOCK_ACTUAL = STOCK_ACTUAL + CAST(@unidades AS INT)
                WHERE PRODUCTO_CON_EXISTENCIA_ID = @item_actual;
            END
        DELETE FROM DBO.FACTURA_DETALLE
        WHERE FACTURA_ID = @factura_id;

        DELETE FROM DBO.FACTURA
        WHERE FACTURA_ID = @factura_id;

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
