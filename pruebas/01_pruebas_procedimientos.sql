/*
    PRUEBAS FUNCIONALES DE PROCEDIMIENTOS ALMACENADOS - IF0010

    Requisitos: haber ejecutado todos los scripts de scripts/ (tablas,
    procedimientos, datos e indices) en ese orden.
    Uso: ejecutar completo en SSMS (o con sqlcmd) sobre ProyectoFacturacion.
    Resultado: tabla final con PASS / FAIL por prueba y un resumen.

    NOTA: las pruebas dejan unos pocos registros de prueba (clientes, productos
    TEST-xxxx y facturas); no hay eliminaciones directas porque toda
    modificacion pasa por procedimientos. Cada ejecucion usa un identificador
    aleatorio, por lo que se puede repetir sin colisiones.

    Se puede ejecutar varias veces en la misma sesion: al inicio elimina sus
    propias tablas temporales (#resultados, #tot, #facs); no toca datos reales.
    ESTADO: las 44 pruebas fueron ejecutadas y aprobadas por el equipo en SQL
    Server 2022 sobre la version con auditoria.
*/
USE ProyectoFacturacion;
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS #resultados;
DROP TABLE IF EXISTS #tot;
DROP TABLE IF EXISTS #facs;

IF NOT EXISTS (SELECT 1 FROM dbo.distrito)
    OR NOT EXISTS (SELECT 1 FROM dbo.empresaemisora WHERE activa = 1)
BEGIN
    RAISERROR ('Faltan datos base. Ejecute primero los scripts de carga (03_datos).', 16, 1);
    RETURN;
END

CREATE TABLE #resultados (
    orden INT IDENTITY (1, 1) NOT NULL,
    prueba VARCHAR(120) NOT NULL,
    resultado VARCHAR(4) NOT NULL,
    detalle VARCHAR(300) NOT NULL
);

CREATE TABLE #tot (
    factura_id BIGINT,
    numero_factura VARCHAR(50),
    fecha_emision DATETIME2,
    empresa VARCHAR(100),
    cliente_identificacion VARCHAR(20),
    tipo_documento VARCHAR(10),
    moneda CHAR(3),
    estado VARCHAR(20),
    monto_subtotal DECIMAL(18, 2),
    monto_descuento DECIMAL(18, 2),
    monto_impuesto DECIMAL(18, 2),
    monto_total DECIMAL(18, 2),
    cantidad_lineas INT,
    total_lineas DECIMAL(38, 2)
);

CREATE TABLE #facs (
    factura_id BIGINT,
    numero_factura VARCHAR(50),
    fecha_emision DATETIME2,
    tipo_documento VARCHAR(10),
    moneda CHAR(3),
    estado VARCHAR(20),
    monto_subtotal DECIMAL(18, 2),
    monto_descuento DECIMAL(18, 2),
    monto_impuesto DECIMAL(18, 2),
    monto_total DECIMAL(18, 2)
);

DECLARE @run VARCHAR(8) = RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID()) % 100000000) AS VARCHAR(10)), 8);
DECLARE @cod INT;
DECLARE @msg VARCHAR(250);
DECLARE @distrito INT = (SELECT TOP (1) distrito_id FROM dbo.distrito ORDER BY distrito_id);
DECLARE @empresa INT = (SELECT TOP (1) empresa_id FROM dbo.empresaemisora WHERE activa = 1 ORDER BY empresa_id);
DECLARE @cliente_f INT;
DECLARE @cliente_j INT;
DECLARE @prod1 INT;
DECLARE @prod2 INT;
DECLARE @id_a BIGINT;
DECLARE @num_a VARCHAR(50);
DECLARE @id_usd BIGINT;
DECLARE @num_usd VARCHAR(50);
DECLARE @id_b BIGINT;
DECLARE @num_b VARCHAR(50);
DECLARE @id_c BIGINT;
DECLARE @num_c VARCHAR(50);
DECLARE @id_x BIGINT;
DECLARE @num_x VARCHAR(50);
DECLARE @ident_f VARCHAR(20) = '9' + @run;
DECLARE @ident_4 VARCHAR(20) = '8' + @run;
DECLARE @ident_5 VARCHAR(20) = '7' + @run;
DECLARE @id_xi INT;
DECLARE @antes INT;
DECLARE @antes2 INT;
DECLARE @antes3 INT;
DECLARE @stock1 INT;
DECLARE @ini DATETIME2;

-- ===================== CLIENTES =====================

-- T01 registrar cliente fisico
SET @antes = (SELECT COUNT(*) FROM dbo.cliente);
EXEC dbo.usp_registrar_cliente
    @tipo_persona = 'F', @identificacion = @ident_f,
    @correo = 'prueba@correo.example.cr', @telefono = '88880000',
    @distrito_id = @distrito, @otras_senas = 'Casa de prueba',
    @nombre = 'Prueba', @apellido1 = 'Uno', @apellido2 = 'Dos',
    @cliente_id = @cliente_f OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T01 registrar cliente fisico',
    CASE WHEN @cod = 0 AND @cliente_f > 0
        AND EXISTS (SELECT 1 FROM dbo.cliente_fisico WHERE cliente_id = @cliente_f)
        AND NOT EXISTS (SELECT 1 FROM dbo.cliente_juridico WHERE cliente_id = @cliente_f)
        AND (SELECT COUNT(*) FROM dbo.cliente) = @antes + 1 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T02 registrar cliente juridico
SET @antes = (SELECT COUNT(*) FROM dbo.cliente);
EXEC dbo.usp_registrar_cliente
    @tipo_persona = 'J', @identificacion = @run,
    @correo = 'contacto@empresaprueba.example.cr', @telefono = '22220000',
    @distrito_id = @distrito, @otras_senas = 'Oficina de prueba',
    @razon_social = 'Prueba Sociedad Anonima', @nombre_comercial = 'Prueba SA',
    @cliente_id = @cliente_j OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T02 registrar cliente juridico',
    CASE WHEN @cod = 0 AND @cliente_j > 0
        AND EXISTS (SELECT 1 FROM dbo.cliente_juridico WHERE cliente_id = @cliente_j)
        AND NOT EXISTS (SELECT 1 FROM dbo.cliente_fisico WHERE cliente_id = @cliente_j)
        AND (SELECT COUNT(*) FROM dbo.cliente) = @antes + 1 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T03 identificacion duplicada: error y sin registros nuevos
SET @antes = (SELECT COUNT(*) FROM dbo.cliente);
SET @antes2 = (SELECT COUNT(*) FROM dbo.cliente_fisico);
EXEC dbo.usp_registrar_cliente
    @tipo_persona = 'F', @identificacion = @ident_f,
    @correo = 'otro@correo.example.cr', @telefono = '88881111',
    @distrito_id = @distrito, @otras_senas = 'Otra casa',
    @nombre = 'Otro', @apellido1 = 'Uno', @apellido2 = 'Dos',
    @cliente_id = @id_xi OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T03 cliente duplicado rechazado sin registros parciales',
    CASE WHEN @cod = 50103 AND @id_xi = 0
        AND (SELECT COUNT(*) FROM dbo.cliente) = @antes
        AND (SELECT COUNT(*) FROM dbo.cliente_fisico) = @antes2 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T04 tipo de persona invalido
SET @antes = (SELECT COUNT(*) FROM dbo.cliente);
EXEC dbo.usp_registrar_cliente
    @tipo_persona = 'X', @identificacion = @ident_4,
    @correo = 'x@correo.example.cr', @telefono = '88882222',
    @distrito_id = @distrito, @otras_senas = 'Casa',
    @cliente_id = @id_xi OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T04 tipo de persona invalido',
    CASE WHEN @cod = 50101 AND (SELECT COUNT(*) FROM dbo.cliente) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T05 distrito inexistente
SET @antes = (SELECT COUNT(*) FROM dbo.cliente);
EXEC dbo.usp_registrar_cliente
    @tipo_persona = 'F', @identificacion = @ident_5,
    @correo = 'y@correo.example.cr', @telefono = '88883333',
    @distrito_id = -1, @otras_senas = 'Casa',
    @nombre = 'Prueba', @apellido1 = 'Uno', @apellido2 = 'Dos',
    @cliente_id = @id_xi OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T05 distrito inexistente rechazado',
    CASE WHEN @cod = 50107 AND (SELECT COUNT(*) FROM dbo.cliente) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T06 actualizar cliente (correo, telefono, direccion)
SET @ini = (SELECT fecha_registro FROM dbo.cliente WHERE cliente_id = @cliente_f);
EXEC dbo.usp_actualizar_cliente
    @cliente_id = @cliente_f, @correo = 'nuevo@correo.example.cr', @telefono = '70001111',
    @distrito_id = @distrito, @otras_senas = 'Direccion actualizada',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T06 actualizar cliente',
    CASE WHEN @cod = 0 AND EXISTS (
        SELECT 1 FROM dbo.cliente
        WHERE cliente_id = @cliente_f AND correo = 'nuevo@correo.example.cr'
            AND telefono = '70001111' AND otras_senas = 'Direccion actualizada'
            AND fecha_actualizacion >= fecha_registro
            AND fecha_registro = @ini) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T07 actualizar cliente inexistente
EXEC dbo.usp_actualizar_cliente
    @cliente_id = -1, @correo = 'a@b.cr', @telefono = '1', @distrito_id = @distrito,
    @otras_senas = 'x', @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT 'T07 actualizar cliente inexistente', CASE WHEN @cod = 50111 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T08 correo invalido: error y datos sin cambios
EXEC dbo.usp_actualizar_cliente
    @cliente_id = @cliente_f, @correo = 'sin-arroba', @telefono = '70002222',
    @distrito_id = @distrito, @otras_senas = 'No debe guardarse',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T08 correo invalido no modifica el cliente',
    CASE WHEN @cod = 50112 AND EXISTS (
        SELECT 1 FROM dbo.cliente
        WHERE cliente_id = @cliente_f AND telefono = '70001111'
            AND otras_senas = 'Direccion actualizada') THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- ===================== PRODUCTOS =====================

-- T09 registrar productos
EXEC dbo.usp_registrar_producto
    @codigo_interno = @run, @descripcion = 'Producto de prueba 1', @precio_unitario = 1000.00,
    @porcentaje_impuesto = 13.00, @stock_inicial = 10,
    @item_facturable_id = @prod1 OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T09 registrar producto con existencia',
    CASE WHEN @cod = 0 AND @prod1 > 0 AND EXISTS (
        SELECT 1 FROM dbo.producto_con_existencia
        WHERE producto_con_existencia_id = @prod1 AND stock_actual = 10) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

DECLARE @cod2 VARCHAR(30) = 'TEST2-' + @run;
EXEC dbo.usp_registrar_producto
    @codigo_interno = @cod2, @descripcion = 'Producto de prueba 2', @precio_unitario = 2000.00,
    @porcentaje_impuesto = 13.00, @stock_inicial = 1,
    @item_facturable_id = @prod2 OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;

-- T10 codigo duplicado
SET @antes = (SELECT COUNT(*) FROM dbo.item_facturable);
EXEC dbo.usp_registrar_producto
    @codigo_interno = @run, @descripcion = 'Duplicado', @precio_unitario = 500.00,
    @porcentaje_impuesto = 13.00, @stock_inicial = 1,
    @item_facturable_id = @id_xi OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T10 producto duplicado rechazado',
    CASE WHEN @cod = 50126 AND (SELECT COUNT(*) FROM dbo.item_facturable) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T11 precio negativo
SET @antes = (SELECT COUNT(*) FROM dbo.item_facturable);
SET @cod2 = 'NEG-' + @run;
EXEC dbo.usp_registrar_producto
    @codigo_interno = @cod2, @descripcion = 'Negativo', @precio_unitario = -5.00,
    @porcentaje_impuesto = 13.00, @stock_inicial = 1,
    @item_facturable_id = @id_xi OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T11 precio negativo rechazado',
    CASE WHEN @cod = 50123 AND (SELECT COUNT(*) FROM dbo.item_facturable) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T12 actualizar precio e impuesto del producto 1 (1500.00 y 4 %)
EXEC dbo.usp_actualizar_precio_item
    @item_facturable_id = @prod1, @precio_unitario = 1500.00, @porcentaje_impuesto = 4.00,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T12 actualizar precio e impuesto',
    CASE WHEN @cod = 0 AND EXISTS (
        SELECT 1 FROM dbo.item_facturable
        WHERE item_facturable_id = @prod1 AND precio_unitario = 1500.00
            AND porcentaje_impuesto = 4.00) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T13 precio negativo en actualizacion: sin cambios
EXEC dbo.usp_actualizar_precio_item
    @item_facturable_id = @prod1, @precio_unitario = -1.00, @porcentaje_impuesto = 4.00,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T13 actualizacion con precio negativo rechazada',
    CASE WHEN @cod = 50132 AND EXISTS (
        SELECT 1 FROM dbo.item_facturable
        WHERE item_facturable_id = @prod1 AND precio_unitario = 1500.00) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- ===================== FACTURAS =====================
-- Precios: producto 1 = 1500.00 (4 %), producto 2 = 2000.00 (13 %).

-- T14 registrar factura con 2 lineas, CRC
DECLARE @det_a dbo.tipo_detalle_factura;
INSERT INTO @det_a (item_facturable_id, cantidad, monto_descuento)
VALUES (@prod1, 2, 0), (@prod2, 1, 100.00);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC',
    @observaciones = 'Factura de prueba', @detalles = @det_a,
    @factura_id = @id_a OUTPUT, @numero_factura = @num_a OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
-- Esperado: subtotal 5000.00, descuento 100.00, impuesto 120.00 + 247.00 = 367.00, total 5267.00
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T14 registrar factura: encabezado y calculos',
    CASE WHEN @cod = 0 AND @id_a > 0 AND EXISTS (
        SELECT 1 FROM dbo.factura
        WHERE factura_id = @id_a AND numero_factura = @num_a
            AND monto_subtotal = 5000.00 AND monto_descuento = 100.00
            AND monto_impuesto = 367.00 AND monto_total = 5267.00) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg + ' numero=' + @num_a;

INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T15 factura: detalle consistente con encabezado y formula de linea',
    CASE WHEN (SELECT COUNT(*) FROM dbo.factura_detalle WHERE factura_id = @id_a) = 2
        AND (SELECT SUM(monto_total) FROM dbo.factura_detalle WHERE factura_id = @id_a) = 5267.00
        AND NOT EXISTS (
            SELECT 1 FROM dbo.factura_detalle
            WHERE factura_id = @id_a
                AND (monto_subtotal <> cantidad * precio_unitario
                    OR monto_total <> monto_subtotal - monto_descuento + monto_impuesto)) THEN 'PASS' ELSE 'FAIL' END,
    'lineas=' + CAST((SELECT COUNT(*) FROM dbo.factura_detalle WHERE factura_id = @id_a) AS VARCHAR(10));

INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T16 identificador AAAAMMDDHHMMSS-TipoDocumento',
    CASE WHEN @num_a LIKE REPLICATE('[0-9]', 14) + '-FAC' THEN 'PASS' ELSE 'FAIL' END,
    @num_a;

SET @stock1 = (SELECT stock_actual FROM dbo.producto_con_existencia WHERE producto_con_existencia_id = @prod1);
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T17 factura descuenta stock (prod1 10->8, prod2 1->0)',
    CASE WHEN @stock1 = 8 AND (SELECT stock_actual FROM dbo.producto_con_existencia
        WHERE producto_con_existencia_id = @prod2) = 0 THEN 'PASS' ELSE 'FAIL' END,
    'stock1=' + CAST(@stock1 AS VARCHAR(10));

-- T18 factura sin lineas: no debe existir encabezado huerfano
DECLARE @det_vacio dbo.tipo_detalle_factura;
SET @antes = (SELECT COUNT(*) FROM dbo.factura);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_vacio,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T18 factura sin lineas rechazada (sin encabezado huerfano)',
    CASE WHEN @cod = 50201 AND @id_x = 0 AND (SELECT COUNT(*) FROM dbo.factura) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T19 item inexistente en una linea: nada se guarda
DECLARE @det_malo dbo.tipo_detalle_factura;
INSERT INTO @det_malo (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, 1, 0), (-1, 1, 0);
SET @antes = (SELECT COUNT(*) FROM dbo.factura);
SET @antes2 = (SELECT COUNT(*) FROM dbo.factura_detalle);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_malo,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T19 linea con item inexistente: rollback completo',
    CASE WHEN @cod = 50210 AND (SELECT COUNT(*) FROM dbo.factura) = @antes
        AND (SELECT COUNT(*) FROM dbo.factura_detalle) = @antes2 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T20 stock insuficiente en la 2a linea: el descuento de stock de la 1a se revierte
DECLARE @det_stock dbo.tipo_detalle_factura;
INSERT INTO @det_stock (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, 1, 0), (@prod2, 1, 0);
SET @antes = (SELECT COUNT(*) FROM dbo.factura);
SET @antes2 = (SELECT COUNT(*) FROM dbo.factura_detalle);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_stock,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T20 stock insuficiente: rollback de encabezado, detalles y stock',
    CASE WHEN @cod = 50213 AND (SELECT COUNT(*) FROM dbo.factura) = @antes
        AND (SELECT COUNT(*) FROM dbo.factura_detalle) = @antes2
        AND (SELECT stock_actual FROM dbo.producto_con_existencia
            WHERE producto_con_existencia_id = @prod1) = 8 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T21 descuento mayor que el subtotal
DECLARE @det_desc dbo.tipo_detalle_factura;
INSERT INTO @det_desc (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, 1, 999999.00);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_desc,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT 'T21 descuento mayor que subtotal rechazado', CASE WHEN @cod = 50211 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T22 cantidad negativa (ningun monto puede ser negativo)
DECLARE @det_neg dbo.tipo_detalle_factura;
INSERT INTO @det_neg (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, -1, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_neg,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT 'T22 cantidad negativa rechazada', CASE WHEN @cod = 50209 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T23 tipo de cambio invalido para colones
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @tipo_cambio = 2.0000,
    @detalles = @det_desc,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT 'T23 tipo de cambio de colones distinto de 1 rechazado', CASE WHEN @cod = 50206 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T24 factura en dolares (tipo de cambio 500): precio 1500/500 = 3.00; impuesto 4 % = 0.12; total 3.12
DECLARE @det_usd dbo.tipo_detalle_factura;
INSERT INTO @det_usd (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, 1, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'TIQ', @codigo_moneda = 'USD', @tipo_cambio = 500.0000,
    @detalles = @det_usd,
    @factura_id = @id_usd OUTPUT, @numero_factura = @num_usd OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T24 factura en USD con tipo de cambio',
    CASE WHEN @cod = 0 AND @num_usd LIKE REPLICATE('[0-9]', 14) + '-TIQ' AND EXISTS (
        SELECT 1 FROM dbo.factura
        WHERE factura_id = @id_usd AND monto_subtotal = 3.00 AND monto_impuesto = 0.12
            AND monto_total = 3.12) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg + ' numero=' + @num_usd;

-- ===================== ESTADOS Y ELIMINACION =====================

-- T25 EMITIDA -> PAGADA
EXEC dbo.usp_cambiar_estado_factura
    @factura_id = @id_a, @codigo_estado_nuevo = 'PAGADA',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T25 cambiar estado EMITIDA a PAGADA',
    CASE WHEN @cod = 0 AND EXISTS (
        SELECT 1 FROM dbo.factura AS f
        INNER JOIN dbo.estadofactura AS e ON e.estado_factura_id = f.estado_factura_id
        WHERE f.factura_id = @id_a AND e.codigo = 'PAGADA') THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T26 transicion no permitida PAGADA -> EMITIDA
EXEC dbo.usp_cambiar_estado_factura
    @factura_id = @id_a, @codigo_estado_nuevo = 'EMITIDA',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T26 transicion de estado no permitida',
    CASE WHEN @cod = 50303 AND EXISTS (
        SELECT 1 FROM dbo.factura AS f
        INNER JOIN dbo.estadofactura AS e ON e.estado_factura_id = f.estado_factura_id
        WHERE f.factura_id = @id_a AND e.codigo = 'PAGADA') THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T27 cancelar una factura devuelve el stock (prod1: 8 -> 6 al facturar 2 -> 8 al cancelar)
DECLARE @det_b dbo.tipo_detalle_factura;
INSERT INTO @det_b (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, 2, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @codigo_estado = 'BORRADOR',
    @detalles = @det_b,
    @factura_id = @id_b OUTPUT, @numero_factura = @num_b OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
SET @antes = (SELECT stock_actual FROM dbo.producto_con_existencia WHERE producto_con_existencia_id = @prod1);
EXEC dbo.usp_cambiar_estado_factura
    @factura_id = @id_b, @codigo_estado_nuevo = 'CANCELADA',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
SET @antes2 = (SELECT stock_actual FROM dbo.producto_con_existencia WHERE producto_con_existencia_id = @prod1);
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T27 cancelar factura devuelve stock',
    CASE WHEN @cod = 0 AND @antes2 = @antes + 2 THEN 'PASS' ELSE 'FAIL' END,
    'stock antes=' + CAST(@antes AS VARCHAR(10)) + ' despues=' + CAST(@antes2 AS VARCHAR(10));

-- T28 eliminar factura en BORRADOR: desaparecen encabezado y detalles, stock devuelto
DECLARE @det_c dbo.tipo_detalle_factura;
INSERT INTO @det_c (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, 1, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @codigo_estado = 'BORRADOR',
    @detalles = @det_c,
    @factura_id = @id_c OUTPUT, @numero_factura = @num_c OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
SET @antes = (SELECT stock_actual FROM dbo.producto_con_existencia WHERE producto_con_existencia_id = @prod1);
EXEC dbo.usp_eliminar_factura
    @factura_id = @id_c, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T28 eliminar factura BORRADOR (encabezado + detalle + stock)',
    CASE WHEN @cod = 0
        AND NOT EXISTS (SELECT 1 FROM dbo.factura WHERE factura_id = @id_c)
        AND NOT EXISTS (SELECT 1 FROM dbo.factura_detalle WHERE factura_id = @id_c)
        AND (SELECT stock_actual FROM dbo.producto_con_existencia
            WHERE producto_con_existencia_id = @prod1) = @antes + 1 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T29 no se elimina una factura EMITIDA
EXEC dbo.usp_eliminar_factura
    @factura_id = @id_usd, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T29 factura EMITIDA no se puede eliminar',
    CASE WHEN @cod = 50312 AND EXISTS (SELECT 1 FROM dbo.factura WHERE factura_id = @id_usd)
        AND EXISTS (SELECT 1 FROM dbo.factura_detalle WHERE factura_id = @id_usd) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- ===================== CONSULTAS =====================

-- T30 totales por identificador de factura
INSERT INTO #tot EXEC dbo.usp_consultar_totales_factura
    @factura_id = @id_a, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T30 consultar totales por factura_id',
    CASE WHEN @cod = 0 AND EXISTS (
        SELECT 1 FROM #tot
        WHERE factura_id = @id_a AND monto_total = 5267.00 AND cantidad_lineas = 2
            AND total_lineas = 5267.00) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T31 totales por identificador de comprobante, midiendo el tiempo (< 1 s)
SET @ini = SYSDATETIME();
INSERT INTO #tot EXEC dbo.usp_consultar_totales_factura
    @numero_factura = @num_a, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T31 consultar totales por numero_factura en menos de 1 s',
    CASE WHEN @cod = 0 AND DATEDIFF(MILLISECOND, @ini, SYSDATETIME()) < 1000 THEN 'PASS' ELSE 'FAIL' END,
    'ms=' + CAST(DATEDIFF(MILLISECOND, @ini, SYSDATETIME()) AS VARCHAR(10));

-- T32 factura inexistente: identificador positivo (rango BIGINT) mayor que cualquier existente
DECLARE @factura_inexistente BIGINT = (SELECT ISNULL(MAX(factura_id), 0) + 1000000 FROM dbo.factura);
EXEC dbo.usp_consultar_totales_factura
    @factura_id = @factura_inexistente, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT 'T32 consultar totales de factura inexistente', CASE WHEN @cod = 50402 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T33 facturas por comprador (id): A (PAGADA), USD (EMITIDA), B (CANCELADA); C fue eliminada
INSERT INTO #facs EXEC dbo.usp_consultar_facturas_cliente
    @cliente_id = @cliente_f, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T33 consultar facturas por cliente_id',
    CASE WHEN @cod = 0 AND (SELECT COUNT(*) FROM #facs) = 3
        AND EXISTS (SELECT 1 FROM #facs WHERE factura_id = @id_a)
        AND EXISTS (SELECT 1 FROM #facs WHERE factura_id = @id_usd)
        AND EXISTS (SELECT 1 FROM #facs WHERE factura_id = @id_b) THEN 'PASS' ELSE 'FAIL' END,
    'filas=' + CAST((SELECT COUNT(*) FROM #facs) AS VARCHAR(10));

-- T34 facturas por comprador (identificacion)
SET @antes = (SELECT COUNT(*) FROM #facs);
INSERT INTO #facs EXEC dbo.usp_consultar_facturas_cliente
    @identificacion = @ident_f, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T34 consultar facturas por identificacion',
    CASE WHEN @cod = 0 AND (SELECT COUNT(*) FROM #facs) = @antes + 3 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T35 cliente inexistente: identificador positivo (rango INT) mayor que cualquier existente
DECLARE @cliente_inexistente INT = (SELECT ISNULL(MAX(cliente_id), 0) + 1000000 FROM dbo.cliente);
EXEC dbo.usp_consultar_facturas_cliente
    @cliente_id = @cliente_inexistente, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT 'T35 consultar facturas de cliente inexistente', CASE WHEN @cod = 50412 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T36 rendimiento: comprador con mas facturas en la carga masiva (< 1 s)
DECLARE @cliente_top INT = (
    SELECT TOP (1) cliente_id FROM dbo.factura GROUP BY cliente_id ORDER BY COUNT(*) DESC
);
SET @ini = SYSDATETIME();
INSERT INTO #facs EXEC dbo.usp_consultar_facturas_cliente
    @cliente_id = @cliente_top, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T36 consultar facturas del cliente con mas facturas en menos de 1 s',
    CASE WHEN @cod = 0 AND DATEDIFF(MILLISECOND, @ini, SYSDATETIME()) < 1000 THEN 'PASS' ELSE 'FAIL' END,
    'ms=' + CAST(DATEDIFF(MILLISECOND, @ini, SYSDATETIME()) AS VARCHAR(10));

-- ===================== CORRECCIONES DE REVISION =====================

-- T37 el tipo de tabla existe (creacion condicional valida)
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T37 existe el tipo dbo.tipo_detalle_factura',
    CASE WHEN TYPE_ID('dbo.tipo_detalle_factura') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    'tipo de tabla del parametro de lineas';

-- T38 auditoria no tiene FK hacia factura (el historial sobrevive al borrado)
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T38 auditoria sin FK hacia factura',
    CASE WHEN NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID('dbo.auditoria')
            AND referenced_object_id = OBJECT_ID('dbo.factura')) THEN 'PASS' ELSE 'FAIL' END,
    'fk_auditoria_factura eliminada';

-- T39 eliminar un BORRADOR conserva su historial de auditoria (generado por los triggers) y devuelve el stock
DECLARE @det_d dbo.tipo_detalle_factura;
INSERT INTO @det_d (item_facturable_id, cantidad, monto_descuento) VALUES (@prod1, 1, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @codigo_estado = 'BORRADOR',
    @detalles = @det_d,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
SET @antes = (SELECT stock_actual FROM dbo.producto_con_existencia WHERE producto_con_existencia_id = @prod1);
EXEC dbo.usp_eliminar_factura
    @factura_id = @id_x, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T39 eliminar BORRADOR auditado conserva el historial y devuelve stock',
    CASE WHEN @cod = 0
        AND NOT EXISTS (SELECT 1 FROM dbo.factura WHERE factura_id = @id_x)
        AND EXISTS (
            SELECT 1 FROM dbo.auditoria AS a
            INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
            INNER JOIN dbo.tipo_operacion AS op ON op.tipo_operacion_id = a.tipo_operacion_id
            WHERE en.nombre = 'FACTURA' AND a.registro_id = @id_x AND op.descripcion = 'DELETE')
        AND (SELECT stock_actual FROM dbo.producto_con_existencia
            WHERE producto_con_existencia_id = @prod1) = @antes + 1 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T40 cancelar dos veces: la segunda se rechaza y el stock no se devuelve de nuevo
SET @antes = (SELECT stock_actual FROM dbo.producto_con_existencia WHERE producto_con_existencia_id = @prod1);
EXEC dbo.usp_cambiar_estado_factura
    @factura_id = @id_b, @codigo_estado_nuevo = 'CANCELADA',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T40 cancelar una factura ya cancelada no duplica la devolucion de stock',
    CASE WHEN @cod = 50303 AND (SELECT stock_actual FROM dbo.producto_con_existencia
        WHERE producto_con_existencia_id = @prod1) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T41 eliminar dos veces: la segunda indica que la factura no existe y el stock no cambia
EXEC dbo.usp_eliminar_factura
    @factura_id = @id_x, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T41 eliminar dos veces la misma factura',
    CASE WHEN @cod = 50311 AND (SELECT stock_actual FROM dbo.producto_con_existencia
        WHERE producto_con_existencia_id = @prod1) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T42 lineas repetidas del mismo producto: se suma la cantidad antes de validar el stock
DECLARE @cod3 VARCHAR(30) = 'TEST3-' + @run;
DECLARE @prod3 INT;
EXEC dbo.usp_registrar_producto
    @codigo_interno = @cod3, @descripcion = 'Producto de prueba 3', @precio_unitario = 100.00,
    @porcentaje_impuesto = 13.00, @stock_inicial = 5,
    @item_facturable_id = @prod3 OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
DECLARE @det_e dbo.tipo_detalle_factura;
INSERT INTO @det_e (item_facturable_id, cantidad, monto_descuento) VALUES (@prod3, 3, 0), (@prod3, 3, 0);
SET @antes = (SELECT COUNT(*) FROM dbo.factura);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_e,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T42 dos lineas del mismo producto (3+3 con stock 5) se rechazan sin cambios',
    CASE WHEN @cod = 50213 AND (SELECT COUNT(*) FROM dbo.factura) = @antes
        AND (SELECT stock_actual FROM dbo.producto_con_existencia
            WHERE producto_con_existencia_id = @prod3) = 5 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T43 dos lineas del mismo producto (2+3 con stock 5): agotan el stock exactamente, nunca negativo
DECLARE @det_f dbo.tipo_detalle_factura;
INSERT INTO @det_f (item_facturable_id, cantidad, monto_descuento) VALUES (@prod3, 2, 0), (@prod3, 3, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cliente_f,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_f,
    @factura_id = @id_x OUTPUT, @numero_factura = @num_x OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T43 dos lineas del mismo producto (2+3 con stock 5) dejan stock 0',
    CASE WHEN @cod = 0 AND (SELECT stock_actual FROM dbo.producto_con_existencia
        WHERE producto_con_existencia_id = @prod3) = 0 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- T44 el identificador coincide con fecha_emision: AAAAMMDDHHMMSS-CodigoTipoDocumento
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'T44 identificador = fecha_emision (AAAAMMDDHHMMSS) + "-" + tipo de documento',
    CASE WHEN COUNT(*) = 4 AND SUM(
        CASE WHEN f.numero_factura = CONVERT(CHAR(8), f.fecha_emision, 112)
            + REPLACE(CONVERT(CHAR(8), f.fecha_emision, 108), ':', '') + '-' + t.codigo
            THEN 1 ELSE 0 END) = 4 THEN 'PASS' ELSE 'FAIL' END,
    'facturas revisadas=' + CAST(COUNT(*) AS VARCHAR(10))
FROM dbo.factura AS f
INNER JOIN dbo.tipodocumento AS t ON t.tipo_documento_id = f.tipo_documento_id
WHERE f.factura_id IN (@id_a, @id_usd, @id_b, @id_x);

-- ===================== RESULTADO =====================
SELECT orden, prueba, resultado, detalle
FROM #resultados
ORDER BY orden;

SELECT
    SUM(CASE WHEN resultado = 'PASS' THEN 1 ELSE 0 END) AS aprobadas,
    SUM(CASE WHEN resultado = 'FAIL' THEN 1 ELSE 0 END) AS fallidas
FROM #resultados;
GO
