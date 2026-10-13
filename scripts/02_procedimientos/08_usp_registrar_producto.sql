USE PROYECTOFACTURACION;
GO

DROP PROCEDURE IF EXISTS DBO.USP_REGISTRAR_PRODUCTO;
GO

-- Registra un producto con existencia: crea el item facturable del catalogo
-- (codigo, descripcion, precio de lista en colones, impuesto, activo, fecha)
-- y su registro de existencias, ambos en una sola transaccion.
-- Devuelve el identificador creado en @item_facturable_id.
CREATE PROCEDURE DBO.USP_REGISTRAR_PRODUCTO
    @codigo_interno VARCHAR(30),
    @descripcion VARCHAR(200),
    @precio_unitario DECIMAL(18, 2),
    @porcentaje_impuesto DECIMAL(5, 2),
    @stock_inicial INT,
    @item_facturable_id INT OUTPUT,
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @item_facturable_id = 0;
    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    BEGIN TRY
        BEGIN TRANSACTION;

        IF LEN(LTRIM(RTRIM(@codigo_interno))) = 0
            BEGIN
                THROW 50121, 'El codigo interno es obligatorio.', 1;
            END

        IF LEN(LTRIM(RTRIM(@descripcion))) = 0
            BEGIN
                THROW 50122, 'La descripcion es obligatoria.', 1;
            END

        IF @precio_unitario <= 0
            BEGIN
                THROW 50123, 'El precio unitario debe ser mayor que cero.', 1;
            END

        IF @porcentaje_impuesto < 0 OR @porcentaje_impuesto > 100
            BEGIN
                THROW 50124,
                'El porcentaje de impuesto debe estar entre 0 y 100.',
                1;
            END

        IF @stock_inicial < 0
            BEGIN
                THROW 50125, 'El stock inicial no puede ser negativo.', 1;
            END

        IF
            EXISTS (
                SELECT 1 FROM DBO.ITEM_FACTURABLE
                WHERE CODIGO_INTERNO = @codigo_interno
            )
            BEGIN
                THROW 50126, 'Ya existe un item con ese codigo interno.', 1;
            END

        INSERT INTO DBO.ITEM_FACTURABLE (
            CODIGO_INTERNO, DESCRIPCION, PRECIO_UNITARIO,
            PORCENTAJE_IMPUESTO, ACTIVO, FECHA_CREACION
        )
        VALUES (
            @codigo_interno, @descripcion, @precio_unitario,
            @porcentaje_impuesto, 1, SYSDATETIME()
        );

        SET @item_facturable_id = CAST(SCOPE_IDENTITY() AS INT);

        INSERT INTO DBO.PRODUCTO_CON_EXISTENCIA (
            PRODUCTO_CON_EXISTENCIA_ID, STOCK_ACTUAL
        )
        VALUES (@item_facturable_id, @stock_inicial);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END

        SET @item_facturable_id = 0;
        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = LEFT(ERROR_MESSAGE(), 250);
    END CATCH
END;
GO
