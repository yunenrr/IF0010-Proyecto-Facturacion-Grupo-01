# IF0010 - Sistema de facturación (Grupo 01)

Módulo central de facturación comercial para "Soluciones Magníficas S.A.", implementado en Microsoft SQL Server (curso IF0010 - Bases de Datos II).

## Descripción general

- Empresas emisoras, clientes (físicos y jurídicos), catálogos, productos y servicios, facturas con sus líneas de detalle y un historial de auditoría.
- Todas las inserciones, actualizaciones y eliminaciones del sistema se hacen mediante procedimientos almacenados con transacciones explícitas y manejo de errores (`TRY/CATCH`).
- Las direcciones de los clientes se normalizan con la codificación oficial del Ministerio de Hacienda (provincia → cantón → distrito) y los clientes se separan en personas físicas y jurídicas.
- La auditoría la hacen triggers: registran operación, valores anterior y nuevo, usuario del motor y fecha, sin depender de la aplicación.

## Integrantes

Manuel Ernesto Trejos Angulo B87899 
Daniel Campos Machado C21626

## Requisitos

- SQL Server 2019 o superior (la versión definitiva se probó en SQL Server 2022; usa `DROP ... IF EXISTS`, `THROW`, `CONCAT`, `FOR JSON`).
- `sqlcmd` y PowerShell (para `utilitarios/ejecutar_scripts.ps1`) o SSMS para ejecutar los archivos a mano.
- Permiso para crear bases de datos. La base se llama `ProyectoFacturacion`.

## Instrucciones de ejecución

Base de datos vacía, en este orden (lo hace automáticamente el script de utilitarios, que ordena los archivos por ruta completa y se detiene en el primer error):

```powershell
./utilitarios/ejecutar_scripts.ps1 -Server "localhost,1433" -Username sa
```

| Carpeta | Contenido |
|---|---|
| `scripts/01_tablas` | Crea la base `ProyectoFacturacion` (`00_crear_base_datos.sql`) y las 19 tablas, con `USE ProyectoFacturacion;` en cada archivo |
| `scripts/02_funciones` | 3 funciones escalares y 2 funciones de tabla (`fn_*`). Van **antes** de los procedimientos y de la carga porque `usp_registrar_factura` y `usp_generar_facturas` usan `fn_generar_clave_comprobante` |
| `scripts/03_procedimientos` | Tipo de tabla `tipo_detalle_factura` y los 16 procedimientos `usp_*` |
| `scripts/04_triggers` | 25 triggers de auditoría, creados **antes** de la carga masiva para que los datos cargados también queden en el historial |
| `scripts/05_datos` | Llama a los procedimientos de carga: ubicaciones de Hacienda, catálogos, 100 empresas, 50 000 clientes, 1 000 productos y 500 000 facturas (lotes de 25 000, 3 a 5 líneas cada una) |
| `scripts/06_indices` | 14 índices no agrupados, creados **después** de las cargas para no frenarlas |
| `scripts/07_vistas` | 2 vistas de reporte (`vw_*`) |
| `scripts/08_seguridad` | Roles de base de datos, usuarios de prueba y permisos `SELECT` sobre las funciones; va después de las funciones porque los permisos las referencian |
| `scripts/09_demostraciones` | 2 consultas de demostración del control por rol (historial de cambios e información de clientes) |
| `scripts/10_consultas` | 8 consultas de búsqueda y reporte con valores de ejemplo fijos |

Cada script de `05_datos` falla con `RAISERROR` si su procedimiento devuelve un código de error distinto de cero, y `sqlcmd -b` detiene la ejecución.

### Pruebas (carpeta `pruebas/`, no se ejecutan con el script anterior)

Ejecutar en SSMS, sobre `ProyectoFacturacion`, **después** de terminar `scripts/`. Todos pueden repetirse en la misma sesión.

| Archivo | Qué hace |
|---|---|
| `01_pruebas_procedimientos.sql` | 44 pruebas funcionales PASS/FAIL de los procedimientos (registro, estados, cálculos, errores, reversión, stock, consultas, identificador) |
| `02_validar_cargas.sql` | Valida cantidades, 3 a 5 detalles por factura, totales, estados y monedas, ubicaciones, clientes y existencia de los triggers |
| `03_concurrencia_manual.sql` | Guía manual con dos sesiones para la concurrencia sobre el stock |
| `04_pruebas_auditoria.sql` | 16 pruebas de auditoría: INSERT, UPDATE, DELETE, reversión, inmutabilidad y consulta |

## Modelo (19 tablas)

El diagrama está en `diagrama_ER/Diagrama_ER.md`.

- **Ubicaciones:** `provincia`, `canton`, `distrito`. Códigos de Hacienda como `CHAR(1)`, `CHAR(2)` y `CHAR(2)` para conservar los ceros a la izquierda. Se cargan 7 provincias, 81 cantones y 475 distritos del documento oficial (sin barrios).
- **Clientes:** `cliente` (datos comunes y `distrito_id` + `otras_senas`), `cliente_fisico` y `cliente_juridico` (una fila en exactamente una de las dos).
- **Catálogos:** `tipodocumento`, `moneda`, `estadofactura`, `unidad_medida`, `tipo_operacion`, `entidad_auditada`.
- **Oferta:** `item_facturable` (código, descripción, precio de lista, impuesto), `producto_con_existencia` (stock) y `servicio` (unidad de medida), ambos 1 a 1 con `item_facturable`.
- **Facturación:** `empresaemisora`, `factura` y `factura_detalle`.
- **Auditoría:** `auditoria`.

Solo se usan restricciones `PRIMARY KEY`, `FOREIGN KEY`, `NOT NULL` y `UNIQUE`; ninguna columna admite nulos.

## Procedimientos almacenados (16)

| Tipo | Procedimientos |
|---|---|
| Cargas | `usp_cargar_ubicaciones`, `usp_cargar_catalogos`, `usp_generar_empresas`, `usp_generar_clientes`, `usp_generar_productos`, `usp_generar_facturas` |
| Operaciones | `usp_registrar_cliente`, `usp_actualizar_cliente`, `usp_registrar_producto`, `usp_actualizar_precio_item`, `usp_registrar_factura`, `usp_cambiar_estado_factura`, `usp_eliminar_factura` |
| Consultas | `usp_consultar_totales_factura`, `usp_consultar_facturas_cliente`, `usp_consultar_auditoria` |

Todos devuelven `@codigo_error` (0 = OK) y `@mensaje_error`. `usp_registrar_factura` recibe las líneas como parámetro de tabla (`dbo.tipo_detalle_factura`).

## Funciones (5)

| Función | Tipo | Qué devuelve |
|---|---|---|
| `fn_calcular_monto_final(@factura_id)` | Escalar | Monto a pagar: subtotal − descuentos + impuestos (`NULL` si la factura no existe) |
| `fn_generar_clave_comprobante(@fecha, @codigo_tipo_documento)` | Escalar | Clave `AAAAMMDDHHMMSS-TipoDocumento`; la usan `usp_registrar_factura` y `usp_generar_facturas` |
| `fn_es_factura_modificable(@numero_factura)` | Escalar | `1` si la factura está en estado BORRADOR; `0` en cualquier otro estado o si no existe |
| `fn_consultar_historial_cambios()` | De tabla | Historial de auditoría; solo devuelve filas a `ROL_AUDITOR`, `ROL_DBA` o `db_owner` |
| `fn_consultar_cliente(@identificacion)` | De tabla | Datos del cliente (físico o jurídico); correo y teléfono completos solo para `ROL_ADMINISTRATIVO`, `ROL_DBA` o `db_owner`, enmascarados para los demás |

## Vistas (2)

| Vista | Columnas |
|---|---|
| `vw_totales_diarios` | `FechaEmision`, `NombreEmpresa`, `TipoDocumento`, `CantidadFacturas`, `SubtotalAcumulado`, `TotalDescuentos`, `TotalImpuestos`, `MontoTotalFacturado`: totales por día, empresa y tipo de documento |
| `vw_clientes_resumen` | `Cedula`, `NombreORazonSocial`, `CantidadFacturas`, `ClienteFrecuente` (`Sí` si el cliente tiene más de 5 facturas entre hace 6 meses y la fecha actual) |

Ninguna de las dos expone IDs técnicos.

## Seguridad por roles

`scripts/08_seguridad/01_roles_usuarios.sql` crea cinco roles de base de datos y un usuario de prueba por rol (sin login, solo para las demostraciones con `EXECUTE AS USER`), y concede `SELECT` sobre `fn_consultar_historial_cambios` y `fn_consultar_cliente`:

| Rol | Usuario de prueba | Historial de cambios | Datos de clientes |
|---|---|---|---|
| `ROL_AUDITOR` | `USR_AUDITOR` | Ve todo | Enmascarados |
| `ROL_DBA` (y `db_owner`) | `USR_DBA` | Ve todo | Completos |
| `ROL_ADMINISTRATIVO` | `USR_ADMIN` | Sin filas | Completos |
| `ROL_CAJERO` | `USR_CAJERO` | Sin filas | Enmascarados |
| `ROL_CONSULTA` | `USR_CONSULTA` | Sin filas | Enmascarados |
| (ninguno) | `USR_SIN_ROL` | Sin permiso | Sin permiso |

Las funciones deciden con `IS_MEMBER`. Las consultas de `scripts/09_demostraciones` muestran el resultado para cada usuario.

## Consultas (8)

Están en `scripts/10_consultas`. Cada una usa un valor de ejemplo fijo, que corresponde a un registro de los datos generados, y devuelve el resultado pedido.

| Archivo | Qué devuelve |
|---|---|
| `01_facturas_persona_fisica.sql` | Encabezado de las facturas de una persona física a partir de su cédula |
| `02_facturas_persona_juridica.sql` | Encabezado de las facturas de una persona jurídica a partir de su cédula |
| `03_buscar_persona_fisica_nombre_apellido1.sql` | Personas físicas por nombre y primer apellido |
| `04_buscar_persona_fisica_nombre_apellido2.sql` | Personas físicas por nombre y segundo apellido |
| `05_buscar_persona_juridica_razon_social.sql` | Personas jurídicas por razón social |
| `06_buscar_persona_juridica_nombre_comercial.sql` | Personas jurídicas por nombre comercial |
| `07_totales_cliente_anio_vigente.sql` | Total de descuentos, de impuestos y monto total facturado de un cliente en el año vigente, en colones |
| `08_ventas_producto_rango_fechas.sql` | Identificador de factura, cantidad y fecha de emisión de un producto en un rango de fechas |

## Reglas de negocio

- Identificador de factura: `AAAAMMDDHHMMSS-TipoDocumento` (por ejemplo `20260312143015-FAC`), con el código del tipo de documento (`FAC` o `TIQ`); único. Si ya existe, `usp_registrar_factura` avanza la fecha un segundo.
- Una factura exige al menos una línea; nunca hay encabezado sin detalle ni detalle sin encabezado.
- Línea: `subtotal = cantidad × precio`; `total = subtotal − descuento + impuesto`. El encabezado suma sus líneas.
- Estados: BORRADOR → EMITIDA | CANCELADA; EMITIDA → PAGADA | CANCELADA. Solo un BORRADOR se puede eliminar.
- Stock: las facturas no canceladas descuentan existencias; cancelar o eliminar un borrador las devuelve. No puede quedar negativo.

## Auditoría

25 triggers (`scripts/04_triggers`), creados antes de la carga masiva. Cada trigger de factura, factura_detalle, producto y servicio está en su propio archivo:

- **INSERT, UPDATE y DELETE** para **factura** (todas las columnas), **factura_detalle** (todas las columnas), **cliente** (identificación, correo, teléfono), **cliente_fisico** (nombre y apellidos), **cliente_juridico** (razón social y nombre comercial), **producto** (`producto_con_existencia`: stock) y **servicio** (unidad de medida).
- **UPDATE** de **producto** y de **servicio** sobre `item_facturable`: código, descripción, precio, impuesto y estado activo. Solo registran los artículos que son productos o servicios, respectivamente.
- **UPDATE** de la **dirección del cliente** (distrito y otras señas). La dirección se guarda en `cliente`, por lo que el trigger está sobre esa tabla.
- `trg_auditoria_inmutable`, que impide modificar o borrar el historial.

Detalles:

- Usuario: `ORIGINAL_LOGIN()`. Fecha: `SYSDATETIME()`. Ambos los pone el motor.
- Se guardan los datos anteriores y nuevos en JSON y una descripción de los cambios.
- `auditoria` no tiene FK hacia las tablas auditadas: el historial permanece aunque se elimine la factura.
- Consulta: `usp_consultar_auditoria` (por entidad, registro, rango de fechas o factura) y `fn_consultar_historial_cambios()` (restringida por rol).

## Notas importantes

- Como los triggers se crean antes de la carga masiva, los datos iniciales también quedan registrados en `auditoria` (una fila por cliente, producto, factura y línea de detalle). Por eso la carga completa tarda más que sin auditoría.
- `vw_totales_diarios` suma los montos tal como están guardados, sin convertir monedas: un día con facturas en colones y en dólares mezcla ambas monedas en la misma suma. Cuenta todas las facturas, sin importar su estado.
- `ClienteFrecuente` cuenta las facturas del cliente emitidas entre hace 6 meses y la fecha actual (no cuenta facturas con fecha futura), sin importar su estado.
- La consulta `07_totales_cliente_anio_vigente.sql` convierte los montos a colones con el tipo de cambio de cada factura y solo cuenta facturas EMITIDAS y PAGADAS.
- Las consultas de `scripts/10_consultas` usan valores fijos que existen en los datos generados (por ejemplo, la cédula `100000001`, el producto `PROD-000001`). Para medir su tiempo de respuesta se puede usar `SET STATISTICS TIME ON` en SSMS.
- La consulta de `scripts/09_demostraciones/01_historial_cambios_por_rol.sql` genera un cambio de prueba dentro de una transacción y lo revierte al terminar; no deja datos.
- `empresaemisora.direccion` es texto libre: la normalización por Hacienda se pidió solo para clientes.
- El PDF de Hacienda no incluye los distritos 2-11-03, 2-15-01, 4-03-01, 6-01-10 ni 7-01-03; no se inventaron.
- Los símbolos de moneda se guardan como `VARCHAR` (el colón como `¢`).
