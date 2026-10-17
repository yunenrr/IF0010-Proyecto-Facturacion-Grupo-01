/*
    VALIDACION DE CARGAS MASIVAS Y REGLAS DE LA RUBRICA - IF0010

    Requisitos: haber ejecutado scripts/ completo (tablas, procedimientos,
    datos e indices). Ejecutar de inmediato despues de la carga.
    Solo hace consultas (SELECT); no modifica datos.

    Se puede ejecutar varias veces en la misma sesion (elimina #validacion al
    inicio).
    ESTADO: aprobada por el equipo en SQL Server 2022 sobre la version anterior
    (sin auditoria). Los criterios de ubicaciones, identificador contra fecha y
    triggers se agregaron despues y la carga completa de la version definitiva
    aun no se ha validado de principio a fin.
*/
USE ProyectoFacturacion;
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS #validacion;

CREATE TABLE #validacion (
    orden INT IDENTITY (1, 1) NOT NULL,
    criterio VARCHAR(140) NOT NULL,
    resultado VARCHAR(4) NOT NULL,
    valor VARCHAR(100) NOT NULL
);

DECLARE @n BIGINT;
DECLARE @m BIGINT;

-- ===================== CANTIDADES MINIMAS =====================
SET @n = (SELECT COUNT_BIG(*) FROM dbo.empresaemisora);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Empresas >= 100', CASE WHEN @n >= 100 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

SET @n = (SELECT COUNT_BIG(*) FROM dbo.cliente);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Clientes >= 50.000', CASE WHEN @n >= 50000 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

SET @n = (SELECT COUNT_BIG(*) FROM dbo.producto_con_existencia);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Productos >= 1.000', CASE WHEN @n >= 1000 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

SET @n = (SELECT COUNT_BIG(*) FROM dbo.factura);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Facturas >= 500.000', CASE WHEN @n >= 500000 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

SET @n = (SELECT COUNT_BIG(*) FROM dbo.factura_detalle);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Detalles >= 1.500.000', CASE WHEN @n >= 1500000 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

-- ===================== FACTURAS =====================
-- Entre 3 y 5 lineas por factura de la carga masiva
SELECT
    @n = MIN(t.lineas),
    @m = MAX(t.lineas)
FROM (
    SELECT COUNT(*) AS lineas
    FROM dbo.factura_detalle AS d
    INNER JOIN dbo.factura AS f ON f.factura_id = d.factura_id
    WHERE f.observaciones LIKE 'Carga masiva%'
    GROUP BY d.factura_id
) AS t;
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Carga masiva: entre 3 y 5 detalles por factura',
    CASE WHEN @n >= 3 AND @m <= 5 THEN 'PASS' ELSE 'FAIL' END,
    'min=' + CAST(@n AS VARCHAR(10)) + ' max=' + CAST(@m AS VARCHAR(10));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.factura AS f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.factura_detalle AS d WHERE d.factura_id = f.factura_id)
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Ninguna factura sin detalle', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.factura
    WHERE numero_factura NOT LIKE REPLICATE('[0-9]', 14) + '-%'
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Formato AAAAMMDDHHMMSS-TipoDocumento en todas las facturas',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'incorrectas=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.factura AS f
    INNER JOIN dbo.tipodocumento AS t ON t.tipo_documento_id = f.tipo_documento_id
    WHERE f.numero_factura NOT LIKE '%-' + t.codigo
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'El sufijo del identificador coincide con el tipo de documento',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'incorrectas=' + CAST(@n AS VARCHAR(20));

SET @n = (SELECT COUNT_BIG(DISTINCT numero_factura) FROM dbo.factura);
SET @m = (SELECT COUNT_BIG(*) FROM dbo.factura);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Identificadores de comprobante unicos', CASE WHEN @n = @m THEN 'PASS' ELSE 'FAIL' END,
    CAST(@n AS VARCHAR(20)) + ' / ' + CAST(@m AS VARCHAR(20));

SET @n = (SELECT COUNT(DISTINCT estado_factura_id) FROM dbo.factura);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Variedad de estados (4)', CASE WHEN @n >= 4 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

SET @n = (SELECT COUNT(DISTINCT moneda_id) FROM dbo.factura);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Variedad de monedas (>= 2)', CASE WHEN @n >= 2 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

SELECT
    @n = DATEDIFF(DAY, MIN(fecha_emision), MAX(fecha_emision)),
    @m = SUM(CASE WHEN fecha_emision > SYSDATETIME() THEN 1 ELSE 0 END)
FROM dbo.factura
WHERE observaciones LIKE 'Carga masiva%';
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Fechas distribuidas en el ultimo ano (rango 300-366 dias, ninguna futura)',
    CASE WHEN @n BETWEEN 300 AND 366 AND @m = 0 THEN 'PASS' ELSE 'FAIL' END,
    'dias=' + CAST(@n AS VARCHAR(10)) + ' futuras=' + CAST(@m AS VARCHAR(10));

-- ===================== INTEGRIDAD FINANCIERA =====================
SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.factura AS f
    INNER JOIN (
        SELECT
            factura_id,
            SUM(monto_subtotal) AS subtotal,
            SUM(monto_descuento) AS descuento,
            SUM(monto_impuesto) AS impuesto,
            SUM(monto_total) AS total
        FROM dbo.factura_detalle
        GROUP BY factura_id
    ) AS t ON t.factura_id = f.factura_id
    WHERE f.monto_subtotal <> t.subtotal OR f.monto_descuento <> t.descuento
        OR f.monto_impuesto <> t.impuesto OR f.monto_total <> t.total
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Totales del encabezado = suma de sus lineas', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    'descuadradas=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.factura_detalle
    WHERE monto_total <> monto_subtotal - monto_descuento + monto_impuesto
        OR ABS(monto_subtotal - cantidad * precio_unitario) > 0.005
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Formula de linea: subtotal = cantidad*precio; total = subtotal-descuento+impuesto',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'incorrectas=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.factura
    WHERE monto_subtotal < 0 OR monto_descuento < 0 OR monto_impuesto < 0 OR monto_total < 0
);
SET @m = (
    SELECT COUNT_BIG(*)
    FROM dbo.factura_detalle
    WHERE cantidad < 0 OR precio_unitario < 0 OR monto_subtotal < 0
        OR monto_descuento < 0 OR monto_impuesto < 0 OR monto_total < 0
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Ningun monto negativo (facturas y detalles)', CASE WHEN @n = 0 AND @m = 0 THEN 'PASS' ELSE 'FAIL' END,
    'facturas=' + CAST(@n AS VARCHAR(20)) + ' detalles=' + CAST(@m AS VARCHAR(20));

SET @n = (SELECT COUNT_BIG(*) FROM dbo.producto_con_existencia WHERE stock_actual < 0);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Ningun stock negativo', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, CAST(@n AS VARCHAR(20));

-- ===================== CLIENTES NORMALIZADOS =====================
SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.cliente AS c
    WHERE (SELECT COUNT(*) FROM dbo.cliente_fisico AS f WHERE f.cliente_id = c.cliente_id)
        + (SELECT COUNT(*) FROM dbo.cliente_juridico AS j WHERE j.cliente_id = c.cliente_id) <> 1
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Cada cliente es exactamente fisico o juridico', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    'incorrectos=' + CAST(@n AS VARCHAR(20));

SET @n = (SELECT COUNT_BIG(*) FROM dbo.cliente_juridico);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Existen clientes fisicos y juridicos',
    CASE WHEN @n > 0 AND (SELECT COUNT_BIG(*) FROM dbo.cliente_fisico) > 0 THEN 'PASS' ELSE 'FAIL' END,
    'juridicos=' + CAST(@n AS VARCHAR(20));

-- ===================== UBICACIONES (HACIENDA) =====================
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Ubicaciones: 7 provincias, 81 cantones, 475 distritos',
    CASE WHEN (SELECT COUNT(*) FROM dbo.provincia) = 7
        AND (SELECT COUNT(*) FROM dbo.canton) = 81
        AND (SELECT COUNT(*) FROM dbo.distrito) = 475 THEN 'PASS' ELSE 'FAIL' END,
    CAST((SELECT COUNT(*) FROM dbo.provincia) AS VARCHAR(10)) + '/'
    + CAST((SELECT COUNT(*) FROM dbo.canton) AS VARCHAR(10)) + '/'
    + CAST((SELECT COUNT(*) FROM dbo.distrito) AS VARCHAR(10));

SET @n = (
    (SELECT COUNT_BIG(*) FROM dbo.provincia
        WHERE LEN(codigo_hacienda) <> 1 OR codigo_hacienda LIKE '%[^0-9]%')
    + (SELECT COUNT_BIG(*) FROM dbo.canton
        WHERE codigo_hacienda NOT LIKE '[0-9][0-9]')
    + (SELECT COUNT_BIG(*) FROM dbo.distrito
        WHERE codigo_hacienda NOT LIKE '[0-9][0-9]')
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Codigos de ubicacion con ceros a la izquierda (1/2/2 posiciones)',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'incorrectos=' + CAST(@n AS VARCHAR(20));

INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Ubicaciones: muestras oficiales (1-01-01 Carmen, 1-02-01 Escazu, 7-06-05 Duacari)',
    CASE WHEN (
        SELECT COUNT(*)
        FROM dbo.distrito AS d
        INNER JOIN dbo.canton AS c ON c.canton_id = d.canton_id
        INNER JOIN dbo.provincia AS p ON p.provincia_id = c.provincia_id
        WHERE (p.codigo_hacienda = '1' AND c.codigo_hacienda = '01' AND d.codigo_hacienda = '01' AND d.nombre = 'Carmen')
            OR (p.codigo_hacienda = '1' AND c.codigo_hacienda = '02' AND d.codigo_hacienda = '01' AND d.nombre = 'Escazú')
            OR (p.codigo_hacienda = '7' AND c.codigo_hacienda = '06' AND d.codigo_hacienda = '05' AND d.nombre = 'Duacarí')
    ) = 3 THEN 'PASS' ELSE 'FAIL' END, 'consulta por jerarquia';

SET @n = (
    SELECT COUNT_BIG(*) FROM dbo.canton AS c
    WHERE NOT EXISTS (SELECT 1 FROM dbo.distrito AS d WHERE d.canton_id = c.canton_id)
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Todo canton tiene al menos un distrito', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    'sin distritos=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*) FROM dbo.distrito AS d
    WHERE NOT EXISTS (SELECT 1 FROM dbo.cliente AS c WHERE c.distrito_id = d.distrito_id)
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'La carga de clientes usa todos los distritos registrados',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'distritos sin clientes=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*) FROM dbo.factura AS f
    INNER JOIN dbo.tipodocumento AS t ON t.tipo_documento_id = f.tipo_documento_id
    WHERE f.numero_factura <> CONVERT(CHAR(8), f.fecha_emision, 112)
        + REPLACE(CONVERT(CHAR(8), f.fecha_emision, 108), ':', '') + '-' + t.codigo
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Identificador de toda factura = fecha_emision + tipo de documento',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'incorrectas=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM dbo.producto_con_existencia AS p
    WHERE p.stock_actual < 0
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Ningun producto con stock negativo (control de existencias)',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'negativos=' + CAST(@n AS VARCHAR(20));

-- ===================== AUDITORIA =====================
SET @n = (
    SELECT COUNT_BIG(*) FROM sys.triggers
    WHERE (name LIKE 'trg[_]%[_]auditoria[_]%' OR name = 'trg_auditoria_inmutable') AND is_disabled = 0
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Triggers de auditoria habilitados (13)', CASE WHEN @n = 13 THEN 'PASS' ELSE 'FAIL' END,
    CAST(@n AS VARCHAR(20));

-- ===================== PROCEDIMIENTOS E INDICES =====================
-- Todo procedimiento usp_ debe tener TRY/CATCH con ROLLBACK, y los que
-- modifican datos, ademas BEGIN TRANSACTION y COMMIT.
SET @n = (
    SELECT COUNT_BIG(*)
    FROM sys.procedures AS p
    INNER JOIN sys.sql_modules AS m ON m.object_id = p.object_id
    WHERE p.name LIKE 'usp[_]%'
        AND (m.definition NOT LIKE '%BEGIN TRY%'
            OR m.definition NOT LIKE '%BEGIN CATCH%'
            OR m.definition NOT LIKE '%ROLLBACK TRANSACTION%')
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Todo usp_ tiene TRY/CATCH con ROLLBACK', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    'sin_manejo=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM sys.procedures AS p
    INNER JOIN sys.sql_modules AS m ON m.object_id = p.object_id
    WHERE p.name LIKE 'usp[_]%'
        AND (m.definition LIKE '%INSERT INTO%' OR m.definition LIKE '%UPDATE %'
            OR m.definition LIKE '%DELETE FROM%')
        AND (m.definition NOT LIKE '%BEGIN TRANSACTION%'
            OR m.definition NOT LIKE '%COMMIT TRANSACTION%')
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Todo usp_ que modifica datos tiene BEGIN TRANSACTION y COMMIT',
    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, 'sin_transaccion=' + CAST(@n AS VARCHAR(20));

SET @n = (
    SELECT COUNT_BIG(*)
    FROM sys.indexes
    WHERE name LIKE 'ix[_]%' AND type_desc = 'NONCLUSTERED'
        AND object_id IN (SELECT object_id FROM sys.tables)
);
INSERT INTO #validacion (criterio, resultado, valor)
SELECT 'Al menos 6 indices no agrupados creados', CASE WHEN @n >= 6 THEN 'PASS' ELSE 'FAIL' END,
    CAST(@n AS VARCHAR(20));

-- ===================== RESULTADO =====================
SELECT orden, criterio, resultado, valor
FROM #validacion
ORDER BY orden;

SELECT
    SUM(CASE WHEN resultado = 'PASS' THEN 1 ELSE 0 END) AS aprobados,
    SUM(CASE WHEN resultado = 'FAIL' THEN 1 ELSE 0 END) AS fallidos
FROM #validacion;
GO
