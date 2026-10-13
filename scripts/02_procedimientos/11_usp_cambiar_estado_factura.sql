USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_CAMBIAR_ESTADO_FACTURA;
GO

-- Cambia el estado de una factura respetando su flujo de vida:
--   BORRADOR -> EMITIDA | CANCELADA
--   EMITIDA  -> PAGADA  | CANCELADA
-- PAGADA y CANCELADA son estados finales. Al cancelar se devuelven al stock las
-- unidades de los productos con existencia. Actualiza fecha_modificacion.
CREATE PROCEDURE DBO.USP_CAMBIAR_ESTADO_FACTURA
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
            @estado_actual_id = F.ESTADO_FACTURA_ID,
            @codigo_actual = E.CODIGO
        FROM DBO.FACTURA AS F WITH (UPDLOCK, ROWLOCK)
        INNER JOIN DBO.ESTADOFACTURA AS E
            ON F.ESTADO_FACTURA_ID = E.ESTADO_FACTURA_ID
        WHERE F.FACTURA_ID = @factura_id;

        IF @estado_actual_id IS NULL
            BEGIN
                THROW 50301, 'La factura indicada no existe.', 1;
            END

        SELECT
            @estado_nuevo_id = ESTADO_FACTURA_ID,
            @codigo_nuevo = CODIGO
        FROM DBO.ESTADOFACTURA
        WHERE CODIGO = @codigo_estado_nuevo;

        IF @estado_nuevo_id IS NULL
            BEGIN
                THROW 50302, 'El estado indicado no existe.', 1;
            END

        IF
            NOT (
                (
                    @codigo_actual = 'BORRADOR'
                    AND @codigo_nuevo IN ('EMITIDA', 'CANCELADA')
                )
                OR (
                    @codigo_actual = 'EMITIDA'
                    AND @codigo_nuevo IN ('PAGADA', 'CANCELADA')
                )
            )
            BEGIN
                THROW 50303,
                'La transicion de estado solicitada no esta permitida.',
                1;
            END

        IF @codigo_nuevo = 'CANCELADA'
            BEGIN
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
                                ON
                                    D.ITEM_FACTURABLE_ID
                                    = P.PRODUCTO_CON_EXISTENCIA_ID
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
            END

        UPDATE DBO.FACTURA
        SET
            ESTADO_FACTURA_ID = @estado_nuevo_id,
            FECHA_MODIFICACION = SYSDATETIME()
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
