CREATE TABLE dbo.producto (
    producto_id INT NOT NULL,
    existencia INT NOT NULL,

    CONSTRAINT pk_producto
    PRIMARY KEY (producto_id),

    CONSTRAINT fk_producto_itemfacturable
    FOREIGN KEY (producto_id)
    REFERENCES dbo.item_facturable (item_facturable_id)
);
GO
