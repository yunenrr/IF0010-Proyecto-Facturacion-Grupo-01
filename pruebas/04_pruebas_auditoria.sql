/*
    PRUEBAS DE AUDITORIA - IF0010

    Requisitos: haber ejecutado TODOS los scripts de scripts/ (incluida la
    carpeta 05_triggers) y las cargas de 03_datos.
    Uso: ejecutar completo sobre ProyectoFacturacion. Resultado: tabla PASS/FAIL.

    Las pruebas cambian datos solo a traves de procedimientos almacenados. Las
    unicas excepciones son A12 (intento directo de UPDATE/DELETE sobre auditoria,
    que debe ser rechazado) y A14 (UPDATE directo multi-fila dentro de una
    transaccion que se revierte). Las filas de auditoria de las pruebas quedan en
    el historial (es inmutable); cada ejecucion usa un identificador aleatorio.

    Se puede ejecutar varias veces en la misma sesion (elimina #resultados y
    #hist al inicio).
    ESTADO: las 16 pruebas fueron ejecutadas y aprobadas por el equipo en SQL
    Server 2022.
*/
USE ProyectoFacturacion;
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS #resultados;
DROP TABLE IF EXISTS #hist;

IF NOT EXISTS (SELECT 1 FROM dbo.distrito)
    OR NOT EXISTS (SELECT 1 FROM dbo.empresaemisora WHERE activa = 1)
    OR OBJECT_ID('dbo.trg_factura_auditoria_insert', 'TR') IS NULL
BEGIN
    RAISERROR ('Faltan datos o triggers. Ejecute primero todos los scripts de scripts/.', 16, 1);
    RETURN;
END

CREATE TABLE #resultados (
    orden INT IDENTITY (1, 1) NOT NULL,
    prueba VARCHAR(140) NOT NULL,
    resultado VARCHAR(4) NOT NULL,
    detalle VARCHAR(300) NOT NULL
);

CREATE TABLE #hist (
    auditoria_id BIGINT,
    entidad VARCHAR(30),
    registro_id BIGINT,
    operacion VARCHAR(20),
    usuario NVARCHAR(128),
    fecha_cambio DATETIME2,
    descripcion NVARCHAR(1000),
    datos_anteriores NVARCHAR(MAX),
    datos_nuevos NVARCHAR(MAX)
);

DECLARE @run VARCHAR(8) = RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID()) % 100000000) AS VARCHAR(10)), 8);
DECLARE @cod INT;
DECLARE @msg VARCHAR(250);
DECLARE @distrito INT = (SELECT TOP (1) distrito_id FROM dbo.distrito ORDER BY distrito_id);
DECLARE @empresa INT = (SELECT TOP (1) empresa_id FROM dbo.empresaemisora WHERE activa = 1 ORDER BY empresa_id);
DECLARE @ident VARCHAR(20) = '6' + @run;
DECLARE @cli INT;
DECLARE @prod INT;
DECLARE @prod_corto INT;
DECLARE @cod_prod VARCHAR(30) = 'AUD-' + @run;
DECLARE @cod_prod2 VARCHAR(30) = 'AUD2-' + @run;
DECLARE @fac BIGINT;
DECLARE @num VARCHAR(50);
DECLARE @fac2 BIGINT;
DECLARE @num2 VARCHAR(50);
DECLARE @t0 DATETIME2 = SYSDATETIME();
DECLARE @antes INT;
DECLARE @antes2 INT;
DECLARE @err INT;

-- A01 triggers de auditoria presentes y habilitados (12 de datos + 1 de inmutabilidad)
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A01 existen y estan habilitados los triggers de auditoria',
    CASE WHEN COUNT(*) = 13 AND SUM(CAST(is_disabled AS INT)) = 0 THEN 'PASS' ELSE 'FAIL' END,
    'triggers=' + CAST(COUNT(*) AS VARCHAR(10))
FROM sys.triggers
WHERE name LIKE 'trg[_]%[_]auditoria[_]%' OR name = 'trg_auditoria_inmutable';

-- A02 catalogos de auditoria
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A02 catalogos: 4 entidades y 3 operaciones',
    CASE WHEN (SELECT COUNT(*) FROM dbo.entidad_auditada
            WHERE nombre IN ('FACTURA', 'FACTURA_DETALLE', 'CLIENTE', 'ITEM_FACTURABLE')) = 4
        AND (SELECT COUNT(*) FROM dbo.tipo_operacion
            WHERE descripcion IN ('INSERT', 'UPDATE', 'DELETE')) = 3 THEN 'PASS' ELSE 'FAIL' END,
    'entidad_auditada y tipo_operacion';

-- A03 registrar cliente: INSERT auditado con usuario/fecha automaticos
EXEC dbo.usp_registrar_cliente
    @tipo_persona = 'F', @identificacion = @ident,
    @correo = 'auditoria@correo.example.cr', @telefono = '88881111',
    @distrito_id = @distrito, @otras_senas = 'Casa auditoria',
    @nombre = 'Audit', @apellido1 = 'Uno', @apellido2 = 'Dos',
    @cliente_id = @cli OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A03 registrar cliente genera auditoria INSERT con usuario y fecha del motor',
    CASE WHEN @cod = 0 AND (
        SELECT COUNT(*)
        FROM dbo.auditoria AS a
        INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
        INNER JOIN dbo.tipo_operacion AS op ON op.tipo_operacion_id = a.tipo_operacion_id
        WHERE en.nombre = 'CLIENTE' AND a.registro_id = @cli AND op.descripcion = 'INSERT'
            AND a.usuario = ORIGINAL_LOGIN()
            AND a.fecha_cambio >= @t0 AND a.fecha_cambio <= SYSDATETIME()
            AND a.datos_anteriores = N'{}'
            AND JSON_VALUE(a.datos_nuevos, '$.identificacion') = @ident) = 1 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- A04 actualizar correo y telefono: UPDATE con valor anterior y nuevo
EXEC dbo.usp_actualizar_cliente
    @cliente_id = @cli, @correo = 'nuevo@correo.example.cr', @telefono = '22223333',
    @distrito_id = @distrito, @otras_senas = 'Casa auditoria',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A04 actualizar correo/telefono conserva valores anterior y nuevo',
    CASE WHEN @cod = 0 AND (
        SELECT COUNT(*)
        FROM dbo.auditoria AS a
        INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
        INNER JOIN dbo.tipo_operacion AS op ON op.tipo_operacion_id = a.tipo_operacion_id
        WHERE en.nombre = 'CLIENTE' AND a.registro_id = @cli AND op.descripcion = 'UPDATE'
            AND JSON_VALUE(a.datos_anteriores, '$.correo') = 'auditoria@correo.example.cr'
            AND JSON_VALUE(a.datos_nuevos, '$.correo') = 'nuevo@correo.example.cr'
            AND JSON_VALUE(a.datos_anteriores, '$.telefono') = '88881111'
            AND JSON_VALUE(a.datos_nuevos, '$.telefono') = '22223333'
            AND a.descripcion LIKE '%correo%' AND a.descripcion LIKE '%telefono%') = 1 THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- A05 cambiar solo la direccion (dato no auditado) no genera fila de auditoria
SET @antes = (SELECT COUNT(*) FROM dbo.auditoria AS a
    INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
    WHERE en.nombre = 'CLIENTE' AND a.registro_id = @cli);
EXEC dbo.usp_actualizar_cliente
    @cliente_id = @cli, @correo = 'nuevo@correo.example.cr', @telefono = '22223333',
    @distrito_id = @distrito, @otras_senas = 'Otra direccion',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A05 cambio solo de direccion no genera auditoria de cliente',
    CASE WHEN @cod = 0 AND (SELECT COUNT(*) FROM dbo.auditoria AS a
        INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
        WHERE en.nombre = 'CLIENTE' AND a.registro_id = @cli) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'filas antes=' + CAST(@antes AS VARCHAR(10));

-- A06 registrar producto y modificar precio/impuesto
EXEC dbo.usp_registrar_producto
    @codigo_interno = @cod_prod, @descripcion = 'Producto auditoria', @precio_unitario = 1000.00,
    @porcentaje_impuesto = 13.00, @stock_inicial = 10,
    @item_facturable_id = @prod OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A06a registrar producto genera auditoria INSERT de ITEM_FACTURABLE',
    CASE WHEN @cod = 0 AND EXISTS (
        SELECT 1 FROM dbo.auditoria AS a
        INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
        INNER JOIN dbo.tipo_operacion AS op ON op.tipo_operacion_id = a.tipo_operacion_id
        WHERE en.nombre = 'ITEM_FACTURABLE' AND a.registro_id = @prod AND op.descripcion = 'INSERT') THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

EXEC dbo.usp_actualizar_precio_item
    @item_facturable_id = @prod, @precio_unitario = 1500.00, @porcentaje_impuesto = 4.00,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A06b cambio de precio e impuesto conserva anterior y nuevo',
    CASE WHEN @cod = 0 AND EXISTS (
        SELECT 1 FROM dbo.auditoria AS a
        INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
        INNER JOIN dbo.tipo_operacion AS op ON op.tipo_operacion_id = a.tipo_operacion_id
        WHERE en.nombre = 'ITEM_FACTURABLE' AND a.registro_id = @prod AND op.descripcion = 'UPDATE'
            AND CAST(JSON_VALUE(a.datos_anteriores, '$.precio_unitario') AS DECIMAL(18, 2)) = 1000.00
            AND CAST(JSON_VALUE(a.datos_nuevos, '$.precio_unitario') AS DECIMAL(18, 2)) = 1500.00
            AND CAST(JSON_VALUE(a.datos_anteriores, '$.porcentaje_impuesto') AS DECIMAL(5, 2)) = 13.00
            AND CAST(JSON_VALUE(a.datos_nuevos, '$.porcentaje_impuesto') AS DECIMAL(5, 2)) = 4.00) THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- A07 registrar factura de 2 lineas: 1 INSERT de FACTURA + 2 INSERT de FACTURA_DETALLE
DECLARE @det_a dbo.tipo_detalle_factura;
INSERT INTO @det_a (item_facturable_id, cantidad, monto_descuento) VALUES (@prod, 2, 0), (@prod, 1, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cli,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @codigo_estado = 'BORRADOR',
    @detalles = @det_a,
    @factura_id = @fac OUTPUT, @numero_factura = @num OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT #hist EXEC dbo.usp_consultar_auditoria
    @factura_id = @fac, @codigo_error = @err OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A07 registrar factura audita encabezado (1) y lineas (2)',
    CASE WHEN @cod = 0 AND @err = 0
        AND (SELECT COUNT(*) FROM #hist WHERE entidad = 'FACTURA' AND operacion = 'INSERT') = 1
        AND (SELECT COUNT(*) FROM #hist WHERE entidad = 'FACTURA_DETALLE' AND operacion = 'INSERT') = 2
        AND (SELECT COUNT(*) FROM #hist WHERE usuario <> ORIGINAL_LOGIN()) = 0 THEN 'PASS' ELSE 'FAIL' END,
    'filas=' + CAST((SELECT COUNT(*) FROM #hist) AS VARCHAR(10)) + ' ' + @msg;

-- A08 cambio de estado: estado previo y nuevo
EXEC dbo.usp_cambiar_estado_factura
    @factura_id = @fac, @codigo_estado_nuevo = 'EMITIDA',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A08 cambio BORRADOR -> EMITIDA audita estado previo y nuevo',
    CASE WHEN @cod = 0 AND EXISTS (
        SELECT 1 FROM dbo.auditoria AS a
        INNER JOIN dbo.entidad_auditada AS en ON en.entidad_auditada_id = a.entidad_auditada_id
        INNER JOIN dbo.tipo_operacion AS op ON op.tipo_operacion_id = a.tipo_operacion_id
        WHERE en.nombre = 'FACTURA' AND a.registro_id = @fac AND op.descripcion = 'UPDATE'
            AND JSON_VALUE(a.datos_anteriores, '$.estado') = 'BORRADOR'
            AND JSON_VALUE(a.datos_nuevos, '$.estado') = 'EMITIDA'
            AND a.descripcion LIKE '%estado BORRADOR -> EMITIDA%') THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- A09 reversion de una transaccion externa: no queda auditoria ni cambio
SELECT @antes = COUNT(*) FROM dbo.auditoria;
BEGIN TRANSACTION;
EXEC dbo.usp_cambiar_estado_factura
    @factura_id = @fac, @codigo_estado_nuevo = 'PAGADA',
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
SET @antes2 = (SELECT COUNT(*) FROM dbo.auditoria);
ROLLBACK TRANSACTION;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A09 ROLLBACK revierte tambien la fila de auditoria',
    CASE WHEN @cod = 0 AND @antes2 = @antes + 1
        AND (SELECT COUNT(*) FROM dbo.auditoria) = @antes
        AND EXISTS (
            SELECT 1 FROM dbo.factura AS f
            INNER JOIN dbo.estadofactura AS e ON e.estado_factura_id = f.estado_factura_id
            WHERE f.factura_id = @fac AND e.codigo = 'EMITIDA') THEN 'PASS' ELSE 'FAIL' END,
    'dentro de la transaccion +1, tras ROLLBACK +0';

-- A10 operacion fallida (stock insuficiente) no deja auditoria
EXEC dbo.usp_registrar_producto
    @codigo_interno = @cod_prod2, @descripcion = 'Producto auditoria 2', @precio_unitario = 100.00,
    @porcentaje_impuesto = 13.00, @stock_inicial = 1,
    @item_facturable_id = @prod_corto OUTPUT, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
DECLARE @det_b dbo.tipo_detalle_factura;
INSERT INTO @det_b (item_facturable_id, cantidad, monto_descuento) VALUES (@prod, 1, 0), (@prod_corto, 5, 0);
SELECT @antes = COUNT(*) FROM dbo.auditoria;
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cli,
    @codigo_tipo_documento = 'FAC', @codigo_moneda = 'CRC', @detalles = @det_b,
    @factura_id = @fac2 OUTPUT, @numero_factura = @num2 OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A10 factura rechazada por stock no deja filas de auditoria',
    CASE WHEN @cod = 50213 AND (SELECT COUNT(*) FROM dbo.auditoria) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'codigo=' + CAST(@cod AS VARCHAR(10)) + ' ' + @msg;

-- A11 eliminar una factura BORRADOR conserva todo su historial
DECLARE @det_c dbo.tipo_detalle_factura;
INSERT INTO @det_c (item_facturable_id, cantidad, monto_descuento) VALUES (@prod, 1, 0);
EXEC dbo.usp_registrar_factura
    @empresa_id = @empresa, @cliente_id = @cli,
    @codigo_tipo_documento = 'TIQ', @codigo_moneda = 'CRC', @codigo_estado = 'BORRADOR',
    @detalles = @det_c,
    @factura_id = @fac2 OUTPUT, @numero_factura = @num2 OUTPUT,
    @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
EXEC dbo.usp_eliminar_factura
    @factura_id = @fac2, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
DELETE FROM #hist;
INSERT #hist EXEC dbo.usp_consultar_auditoria
    @factura_id = @fac2, @codigo_error = @err OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A11 eliminar factura BORRADOR: historial completo (INSERT y DELETE de encabezado y linea)',
    CASE WHEN @cod = 0 AND @err = 0
        AND NOT EXISTS (SELECT 1 FROM dbo.factura WHERE factura_id = @fac2)
        AND (SELECT COUNT(*) FROM #hist WHERE entidad = 'FACTURA' AND operacion = 'INSERT') = 1
        AND (SELECT COUNT(*) FROM #hist WHERE entidad = 'FACTURA' AND operacion = 'DELETE') = 1
        AND (SELECT COUNT(*) FROM #hist WHERE entidad = 'FACTURA_DETALLE' AND operacion = 'INSERT') = 1
        AND (SELECT COUNT(*) FROM #hist WHERE entidad = 'FACTURA_DETALLE' AND operacion = 'DELETE') = 1
        AND (SELECT COUNT(*) FROM #hist AS h WHERE h.entidad = 'FACTURA' AND h.operacion = 'DELETE'
            AND JSON_VALUE(h.datos_anteriores, '$.numero_factura') = @num2
            AND h.datos_nuevos = N'{}') = 1 THEN 'PASS' ELSE 'FAIL' END,
    'filas historial=' + CAST((SELECT COUNT(*) FROM #hist) AS VARCHAR(10)) + ' ' + @msg;

-- A12 el historial es inmutable: UPDATE y DELETE directos se rechazan
DECLARE @err_upd INT = 0;
DECLARE @err_del INT = 0;
DECLARE @aud_id BIGINT = (SELECT TOP (1) auditoria_id FROM dbo.auditoria ORDER BY auditoria_id);
DECLARE @desc_antes NVARCHAR(1000) = (SELECT descripcion FROM dbo.auditoria WHERE auditoria_id = @aud_id);
BEGIN TRY
    UPDATE dbo.auditoria SET descripcion = N'alterado' WHERE auditoria_id = @aud_id;
END TRY
BEGIN CATCH
    SET @err_upd = ERROR_NUMBER();
END CATCH
BEGIN TRY
    DELETE FROM dbo.auditoria WHERE auditoria_id = @aud_id;
END TRY
BEGIN CATCH
    SET @err_del = ERROR_NUMBER();
END CATCH
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A12 UPDATE y DELETE sobre auditoria rechazados (inmutable)',
    CASE WHEN @err_upd = 50502 AND @err_del = 50502
        AND (SELECT descripcion FROM dbo.auditoria WHERE auditoria_id = @aud_id) = @desc_antes THEN 'PASS' ELSE 'FAIL' END,
    'update=' + CAST(@err_upd AS VARCHAR(10)) + ' delete=' + CAST(@err_del AS VARCHAR(10));

-- A13 consultas de auditoria: filtro por entidad y validaciones
DELETE FROM #hist;
INSERT #hist EXEC dbo.usp_consultar_auditoria
    @nombre_entidad = 'CLIENTE', @registro_id = @cli, @codigo_error = @cod OUTPUT, @mensaje_error = @msg OUTPUT;
SET @antes = (SELECT COUNT(*) FROM #hist);
EXEC dbo.usp_consultar_auditoria
    @nombre_entidad = 'NO_EXISTE', @codigo_error = @err OUTPUT, @mensaje_error = @msg OUTPUT;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A13 consultar auditoria por entidad/registro y rechazar entidad inexistente',
    CASE WHEN @cod = 0 AND @antes = 2 AND @err = 50511
        AND (SELECT COUNT(*) FROM #hist WHERE operacion IN ('INSERT', 'UPDATE')) = 2 THEN 'PASS' ELSE 'FAIL' END,
    'filas cliente=' + CAST(@antes AS VARCHAR(10)) + ' codigo entidad invalida=' + CAST(@err AS VARCHAR(10));

-- A14 UPDATE multi-fila (por conjuntos): una fila de auditoria por fila afectada; se revierte
SELECT @antes = COUNT(*) FROM dbo.auditoria;
BEGIN TRANSACTION;
UPDATE dbo.item_facturable
SET precio_unitario = precio_unitario + 1
WHERE item_facturable_id IN (@prod, @prod_corto);
SET @antes2 = (SELECT COUNT(*) FROM dbo.auditoria);
ROLLBACK TRANSACTION;
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A14 trigger por conjuntos: 2 filas modificadas generan 2 filas de auditoria',
    CASE WHEN @antes2 = @antes + 2 AND (SELECT COUNT(*) FROM dbo.auditoria) = @antes THEN 'PASS' ELSE 'FAIL' END,
    'dentro de la transaccion +' + CAST(@antes2 - @antes AS VARCHAR(10));

-- A15 consistencia: toda fila tiene entidad y operacion validas y datos JSON
INSERT INTO #resultados (prueba, resultado, detalle)
SELECT
    'A15 filas de auditoria con JSON valido y descripcion no vacia',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    'invalidas=' + CAST(COUNT(*) AS VARCHAR(10))
FROM dbo.auditoria
WHERE ISJSON(datos_anteriores) = 0 OR ISJSON(datos_nuevos) = 0 OR LEN(descripcion) = 0;

-- ===================== RESULTADO =====================
SELECT orden, prueba, resultado, detalle
FROM #resultados
ORDER BY orden;

SELECT
    SUM(CASE WHEN resultado = 'PASS' THEN 1 ELSE 0 END) AS aprobadas,
    SUM(CASE WHEN resultado = 'FAIL' THEN 1 ELSE 0 END) AS fallidas
FROM #resultados;
GO
