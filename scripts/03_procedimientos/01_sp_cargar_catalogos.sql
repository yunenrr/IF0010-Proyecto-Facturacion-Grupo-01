CREATE OR ALTER PROCEDURE dbo.sp_cargar_catalogos
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Tipos de documento
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.tipodocumento
            WHERE codigo = 'FACTURA'
        )
        BEGIN
            INSERT INTO dbo.tipodocumento (
                codigo,
                descripcion
            )
            VALUES (
                'FACTURA',
                'Factura'
            );
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.tipodocumento
            WHERE codigo = 'TIQUETE'
        )
        BEGIN
            INSERT INTO dbo.tipodocumento (
                codigo,
                descripcion
            )
            VALUES (
                'TIQUETE',
                'Tiquete'
            );
        END;

        -- Monedas
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.moneda
            WHERE codigo = 'CRC'
        )
        BEGIN
            INSERT INTO dbo.moneda (
                codigo,
                simbolo,
                descripcion
            )
            VALUES (
                'CRC',
                'CRC',
                'Colon costarricense'
            );
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.moneda
            WHERE codigo = 'USD'
        )
        BEGIN
            INSERT INTO dbo.moneda (
                codigo,
                simbolo,
                descripcion
            )
            VALUES (
                'USD',
                '$',
                'Dolar estadounidense'
            );
        END;

        -- Estados de factura
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.estadofactura
            WHERE codigo = 'BORRADOR'
        )
        BEGIN
            INSERT INTO dbo.estadofactura (
                codigo,
                descripcion
            )
            VALUES (
                'BORRADOR',
                'Factura en borrador'
            );
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.estadofactura
            WHERE codigo = 'EMITIDA'
        )
        BEGIN
            INSERT INTO dbo.estadofactura (
                codigo,
                descripcion
            )
            VALUES (
                'EMITIDA',
                'Factura emitida'
            );
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.estadofactura
            WHERE codigo = 'PAGADA'
        )
        BEGIN
            INSERT INTO dbo.estadofactura (
                codigo,
                descripcion
            )
            VALUES (
                'PAGADA',
                'Factura pagada'
            );
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.estadofactura
            WHERE codigo = 'CANCELADA'
        )
        BEGIN
            INSERT INTO dbo.estadofactura (
                codigo,
                descripcion
            )
            VALUES (
                'CANCELADA',
                'Factura cancelada'
            );
        END;

        -- Unidades de medida
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.unidad_medida
            WHERE descripcion = 'UNIDAD'
        )
        BEGIN
            INSERT INTO dbo.unidad_medida (descripcion)
            VALUES ('UNIDAD');
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.unidad_medida
            WHERE descripcion = 'HORA'
        )
        BEGIN
            INSERT INTO dbo.unidad_medida (descripcion)
            VALUES ('HORA');
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.unidad_medida
            WHERE descripcion = 'DIA'
        )
        BEGIN
            INSERT INTO dbo.unidad_medida (descripcion)
            VALUES ('DIA');
        END;

        -- Tipos de operación
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.tipo_operacion
            WHERE descripcion = 'INSERT'
        )
        BEGIN
            INSERT INTO dbo.tipo_operacion (descripcion)
            VALUES ('INSERT');
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.tipo_operacion
            WHERE descripcion = 'UPDATE'
        )
        BEGIN
            INSERT INTO dbo.tipo_operacion (descripcion)
            VALUES ('UPDATE');
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.tipo_operacion
            WHERE descripcion = 'DELETE'
        )
        BEGIN
            INSERT INTO dbo.tipo_operacion (descripcion)
            VALUES ('DELETE');
        END;

        COMMIT TRANSACTION;

        SET @codigo_error = 0;
        SET @mensaje_error = 'Catalogos cargados correctamente';
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @codigo_error = ERROR_NUMBER();
        SET @mensaje_error = ERROR_MESSAGE();
    END CATCH;
END;
GO
