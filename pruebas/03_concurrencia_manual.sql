/*
    PRUEBA MANUAL DE CONCURRENCIA - IF0010

    Requiere dos sesiones de SSMS contra SQL Server. El equipo la aprobo en la
    version anterior (sin auditoria); no se ha repetido con la version definitiva.
    Objetivo: comprobar que dos facturas simultaneas sobre un producto con poco
    stock no lo dejan negativo y que la segunda espera o es rechazada.

    Preparacion (sesion 1 y 2 comparten esto; ejecutar una vez):
*/
USE ProyectoFacturacion;
GO

DECLARE @cod INT;
DECLARE @msg VARCHAR(250);
DECLARE @item INT;

EXEC dbo.usp_registrar_producto
    @codigo_interno = 'CONC-001', @descripcion = 'Producto de concurrencia',
    @precio_unitario = 100.00, @porcentaje_impuesto = 13.00, @stock_inicial = 1,
    @item_facturable_id = @item OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;

SELECT @item AS item_facturable_id, @cod AS codigo_error, @msg AS mensaje_error;
GO

/*
    Sesion 1 y sesion 2 (ejecutar el bloque siguiente casi al mismo tiempo,
    reemplazando @item por el id obtenido arriba y @empresa/@cliente por ids
    existentes):

        DECLARE @det dbo.tipo_detalle_factura;
        INSERT INTO @det VALUES (@item, 1, 0);
        EXEC dbo.usp_registrar_factura ... @detalles = @det ...;

    Resultado esperado: exactamente UNA sesion devuelve codigo_error = 0 y la
    otra 50213 (existencias insuficientes). Verificar despues:

        SELECT stock_actual FROM dbo.producto_con_existencia
        WHERE producto_con_existencia_id = <item>;   -- debe ser 0, nunca negativo
*/
