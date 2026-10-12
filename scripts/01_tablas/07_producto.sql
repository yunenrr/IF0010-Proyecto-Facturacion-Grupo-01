USE C21626;
GO

CREATE TABLE dbo.producto_con_existencia (
    producto_con_existencia_id INT IDENTITY(1, 1) NOT NULL,
    codigo_producto VARCHAR(50) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    stock_actual INT NOT NULL,
    precio_unitario DECIMAL(18, 2) NOT NULL,
    porcentaje_impuesto DECIMAL(5, 2) NOT NULL,
    CONSTRAINT PK_producto_con_existencia PRIMARY KEY (producto_con_existencia_id),
    CONSTRAINT UQ_producto_codigo UNIQUE (codigo_producto)
);
GO
