USE ProyectoFacturacion;
GO

-- Tipo de tabla que recibe usp_registrar_factura con las lineas de la factura.
-- El precio unitario, el impuesto y la descripcion se toman del catalogo
-- (item_facturable); el llamador solo indica producto, cantidad y descuento.
-- CREATE TYPE no puede ir dentro de un bloque IF junto a otras sentencias del
-- lote: se ejecuta como SQL dinamico para que la creacion condicional sea valida.
IF TYPE_ID('dbo.tipo_detalle_factura') IS NULL
BEGIN
    EXEC (N'CREATE TYPE dbo.tipo_detalle_factura AS TABLE (
        item_facturable_id INT NOT NULL,
        cantidad DECIMAL(18, 2) NOT NULL,
        monto_descuento DECIMAL(18, 2) NOT NULL
    )');
END
GO
