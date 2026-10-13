USE ProyectoFacturacion;
GO

DROP PROCEDURE IF EXISTS dbo.usp_cargar_catalogos;
GO

-- Carga idempotente de los catalogos del sistema: tipos de documento, monedas,
-- estados de factura, unidades de medida, tipos de operacion y entidades auditadas.
-- Las ubicaciones (provincia / canton / distrito) las carga
-- usp_cargar_ubicaciones.
CREATE PROCEDURE dbo.usp_cargar_catalogos
    @codigo_error INT OUTPUT,
    @mensaje_error VARCHAR(250) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @codigo_error = 0;
    SET @mensaje_error = 'OK';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Tipos de documento
        INSERT INTO dbo.tipodocumento (codigo, descripcion)
        SELECT v.codigo, v.descripcion
        FROM (VALUES
            ('FAC', 'Factura'),
            ('TIQ', 'Tiquete')
        ) AS v (codigo, descripcion)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.tipodocumento AS t WHERE t.codigo = v.codigo
        );

        -- Monedas
        INSERT INTO dbo.moneda (codigo, simbolo, descripcion)
        SELECT v.codigo, v.simbolo, v.descripcion
        FROM (VALUES
            ('CRC', '¢', 'Colon costarricense'),
            ('USD', '$', 'Dolar estadounidense')
        ) AS v (codigo, simbolo, descripcion)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.moneda AS m WHERE m.codigo = v.codigo
        );

        -- Estados de factura
        INSERT INTO dbo.estadofactura (codigo, descripcion)
        SELECT v.codigo, v.descripcion
        FROM (VALUES
            ('BORRADOR', 'Factura en preparacion, aun no emitida'),
            ('EMITIDA', 'Factura emitida al cliente'),
            ('PAGADA', 'Factura cancelada por el cliente mediante pago'),
            ('CANCELADA', 'Factura anulada')
        ) AS v (codigo, descripcion)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.estadofactura AS e WHERE e.codigo = v.codigo
        );

        -- Unidades de medida
        INSERT INTO dbo.unidad_medida (descripcion)
        SELECT v.descripcion
        FROM (VALUES
            ('Unidad'),
            ('Kilogramo'),
            ('Litro'),
            ('Hora'),
            ('Servicio')
        ) AS v (descripcion)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.unidad_medida AS u WHERE u.descripcion = v.descripcion
        );

        -- Tipos de operacion de auditoria
        INSERT INTO dbo.tipo_operacion (descripcion)
        SELECT v.descripcion
        FROM (VALUES
            ('INSERT'),
            ('UPDATE'),
            ('DELETE')
        ) AS v (descripcion)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.tipo_operacion AS o WHERE o.descripcion = v.descripcion
        );

        -- Entidades que se auditan
        INSERT INTO dbo.entidad_auditada (nombre)
        SELECT v.nombre
        FROM (VALUES
            ('FACTURA'),
            ('FACTURA_DETALLE'),
            ('CLIENTE'),
            ('ITEM_FACTURABLE')
        ) AS v (nombre)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.entidad_auditada AS e WHERE e.nombre = v.nombre
        );

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
