USE ProyectoFacturacion;
GO

CREATE TABLE dbo.producto_con_existencia (
    producto_con_existencia_id INT NOT NULL,
    stock_actual INT NOT NULL,

    CONSTRAINT pk_producto_con_existencia
    PRIMARY KEY (producto_con_existencia_id),

    CONSTRAINT fk_productoconexistencia_item_facturable
    FOREIGN KEY (producto_con_existencia_id)
    REFERENCES dbo.item_facturable (item_facturable_id)
);
GO
