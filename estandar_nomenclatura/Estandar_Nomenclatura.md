# Estándar de nomenclatura

Este documento combina las convenciones **observadas** en los scripts de la versión suministrada con las **reglas de estilo adoptadas por el equipo**. Cuando un nombre se aparta del patrón, se documenta en [Excepciones conocidas](#excepciones-conocidas) sin renombrar objetos que ya existen. Se revisaron `scripts/`, `pruebas/` y `utilitarios/`.

## 1. Reglas generales

- Los nombres se escriben en **español, en `snake_case`, sin tildes, sin eñes y sin espacios** (`otras_senas`, no `otras_señas`).
- Los nombres son **descriptivos y en singular** para tablas y columnas; los verbos van en infinitivo (`registrar`, `consultar`).
- Las tablas, funciones, procedimientos, vistas, triggers y el tipo de tabla viven en el esquema `dbo` y se escriben calificados (`DBO.FACTURA`).
- Las columnas de las **19 tablas persistentes** se declararon `NOT NULL`. No se detectaron restricciones `CHECK` ni cláusulas `DEFAULT` en esas definiciones; muchas reglas de negocio se verifican en procedimientos almacenados. Las columnas de tablas temporales y las expresiones de consulta no necesariamente siguen este patrón.
- La especialización de `cliente` e `item_facturable` se representa conceptualmente como disjunta, pero las FK no aseguran por sí solas que los subtipos sean exclusivos y completos.

### Mayúsculas y minúsculas

| Elemento | Cómo se escribe en los scripts | Ejemplo |
|---|---|---|
| Palabras clave, funciones del sistema y tipos de dato | MAYÚSCULAS | `SELECT`, `SYSDATETIME()`, `DECIMAL(18, 2)` |
| Identificadores de objetos (esquema, tablas, columnas, restricciones, índices, procedimientos, funciones, vistas, triggers, roles y usuarios) | MAYÚSCULAS | `DBO.FACTURA`, `MONTO_TOTAL`, `PK_FACTURA`, `USP_REGISTRAR_FACTURA` |
| Parámetros y variables | minúsculas con `@` | `@codigo_error`, `@factura_id` |
| Tablas temporales | minúsculas con `#` (sus columnas, en MAYÚSCULAS) | `#lineas`, `#cab` |
| Códigos y valores de catálogo | MAYÚSCULAS | `'FAC'`, `'CRC'`, `'BORRADOR'`, `'INSERT'` |

SQL Server **puede** tratar `FACTURA`, `factura` y `Factura` como el mismo objeto bajo una intercalación insensible a mayúsculas (como suele ocurrir en instalaciones habituales), pero esto depende de la *collation* configurada. Por eso **la documentación** (este archivo, el README, el diagrama ER y los comentarios) escribe los nombres en minúscula, que se lee mejor; el nombre es el mismo.

## 2. Patrones por tipo de objeto

| Elemento | Patrón | Ejemplos |
|---|---|---|
| Base de datos | `ProyectoFacturacion` | |
| Esquema | `dbo` | |
| Tablas | sustantivo singular en `snake_case`. Subtipos de `cliente`: `cliente_<subtipo>`. Subtipos de `item_facturable`: nombre propio del subtipo | `cliente`, `cliente_fisico`, `factura_detalle`, `producto_con_existencia`, `servicio` |
| Columnas | `snake_case`. Prefijos y sufijos con significado fijo (ver tabla siguiente) | `monto_total`, `fecha_emision`, `codigo_hacienda` |
| Clave primaria (columna) | `<tabla>_id`. Los subtipos de `cliente` reutilizan `cliente_id` (PK y FK a la vez); `producto_con_existencia` y `servicio` usan `<subtipo>_id` | `factura_id`, `tipo_documento_id`, `cliente_id` en `cliente_fisico`, `servicio_id` |
| Restricción de clave primaria | `pk_<tabla>` | `pk_factura`, `pk_cliente_fisico`, `pk_itemfacturable` |
| Restricción de clave foránea | `fk_<tabla>_<tabla referenciada>` | `fk_factura_cliente`, `fk_distrito_canton`, `fk_servicio_unidad_medida` |
| Restricción única | `uq_<tabla>_<columnas>`; la columna puede abreviarse cuando el nombre es largo | `uq_factura_numero`, `uq_canton_provincia_codigo`, `uq_cliente_identificacion` |
| Índice no agrupado | `ix_<tabla>_<columnas>`. Los índices de las tablas temporales usan `ix_tmp_<descripcion>` | `ix_factura_cliente`, `ix_auditoria_registro`, `ix_cliente_fisico_nombre_apellido1` |
| Procedimientos | `usp_<verbo>_<objeto>` (verbos en la tabla de abajo) | `usp_registrar_factura`, `usp_consultar_auditoria` |
| Funciones (escalares y de tabla) | `fn_<verbo>_<objeto>`; las que responden sí/no (`BIT`) usan `fn_es_<condicion>` | `fn_calcular_monto_final`, `fn_consultar_cliente`, `fn_es_factura_modificable` |
| Vistas | `vw_<descripcion>`; las columnas llevan el nombre del reporte, en PascalCase y entre corchetes | `vw_totales_diarios` con `[FechaEmision]`, `[MontoTotalFacturado]` |
| Tipo de tabla | `tipo_<descripcion>` | `tipo_detalle_factura` |
| Triggers de auditoría | `trg_<objeto auditado>_auditoria_<operacion>`; `<operacion>` es `insert`, `update` o `delete` | `trg_factura_auditoria_update`, `trg_cliente_fisico_auditoria_insert` |
| Trigger de inmutabilidad | `trg_auditoria_inmutable` | |
| Roles de base de datos | `rol_<funcion>` | `rol_auditor`, `rol_cajero` |
| Usuarios de prueba (sin login) | `usr_<funcion>` | `usr_auditor`, `usr_sin_rol` |

### Prefijos y sufijos de columnas

| Patrón | Significado | Ejemplos |
|---|---|---|
| `<tabla>_id` | identificador (clave primaria o foránea) | `cliente_id`, `moneda_id` |
| `monto_*` | importe en la moneda de la factura | `monto_subtotal`, `monto_descuento`, `monto_impuesto`, `monto_total` |
| `porcentaje_*` | porcentaje de 0 a 100 | `porcentaje_impuesto` |
| `fecha_*` | fecha y hora (`DATETIME2`) | `fecha_emision`, `fecha_creacion`, `fecha_cambio` |
| `codigo` / `codigo_*` | código corto de catálogo | `codigo`, `codigo_hacienda`, `codigo_interno` |
| `activo` / `activa` | indicador `BIT`; el género concuerda con la tabla | `item_facturable.activo`, `empresaemisora.activa` |

### Verbos de los procedimientos

| Verbo | Qué hace | Ejemplos |
|---|---|---|
| `cargar` | Carga idempotente de datos fijos (ubicaciones de Hacienda, catálogos) | `usp_cargar_ubicaciones`, `usp_cargar_catalogos` |
| `generar` | Carga masiva sintética hasta un total objetivo; solo inserta lo que falta | `usp_generar_clientes`, `usp_generar_facturas` |
| `registrar` | Crea un registro nuevo | `usp_registrar_cliente`, `usp_registrar_producto`, `usp_registrar_factura` |
| `actualizar` | Modifica datos de un registro existente | `usp_actualizar_cliente`, `usp_actualizar_precio_item` |
| `cambiar` | Cambia el estado de un registro | `usp_cambiar_estado_factura` |
| `eliminar` | Elimina un registro | `usp_eliminar_factura` |
| `consultar` | Solo lectura; no modifica datos | `usp_consultar_totales_factura`, `usp_consultar_auditoria` |

### Tipos de dato

| Uso | Tipo |
|---|---|
| Identificadores | `INT IDENTITY(1, 1)`; `BIGINT` en `factura`, `factura_detalle` y `auditoria`. Las claves de subtipo no son `IDENTITY` |
| Importes | `DECIMAL(18, 2)` |
| Porcentajes | `DECIMAL(5, 2)` |
| Tipo de cambio | `DECIMAL(18, 4)` |
| Fechas | `DATETIME2` |
| Códigos de Hacienda | `CHAR(1)` provincia, `CHAR(2)` cantón y distrito (conservan los ceros a la izquierda) |
| Textos | `VARCHAR(n)`; `NVARCHAR` solo en `auditoria` (usuario, descripción y JSON) |

## 3. Triggers de auditoría

El nombre usa el **objeto auditado** (la entidad que queda registrada en `entidad_auditada`), que casi siempre coincide con la tabla donde vive el trigger. Cuando un cambio en `item_facturable` se audita como producto o servicio, el nombre lo refleja.

| Trigger | Tabla donde vive | Entidad registrada |
|---|---|---|
| `trg_factura_auditoria_{insert,update,delete}` | `factura` | `FACTURA` |
| `trg_factura_detalle_auditoria_{insert,update,delete}` | `factura_detalle` | `FACTURA_DETALLE` |
| `trg_cliente_auditoria_{insert,update,delete}` | `cliente` | `CLIENTE` |
| `trg_cliente_fisico_auditoria_{insert,update,delete}` | `cliente_fisico` | `CLIENTE_FISICO` |
| `trg_cliente_juridico_auditoria_{insert,update,delete}` | `cliente_juridico` | `CLIENTE_JURIDICO` |
| `trg_cliente_direccion_auditoria_update` | `cliente` | `CLIENTE_DIRECCION` |
| `trg_producto_con_existencia_auditoria_{insert,update,delete}` | `producto_con_existencia` | `PRODUCTO_CON_EXISTENCIA` |
| `trg_producto_item_auditoria_update` | `item_facturable` | `PRODUCTO_CON_EXISTENCIA` |
| `trg_servicio_auditoria_{insert,update,delete}` | `servicio` | `SERVICIO` |
| `trg_servicio_item_auditoria_update` | `item_facturable` | `SERVICIO` |
| `trg_auditoria_inmutable` (`INSTEAD OF UPDATE, DELETE`) | `auditoria` | no registra: rechaza el cambio |

## 4. Carpetas y archivos

Las carpetas de la raíz van en minúscula (`scripts`, `pruebas`, `utilitarios`, `presentacion`, `estandar_nomenclatura`); `diagrama_ER` conserva «ER» en mayúscula.

Las carpetas de `scripts/` se llaman `NN_<contenido>` y **el número es el orden de ejecución**: `01_tablas`, `02_funciones`, `03_procedimientos`, `04_triggers`, `05_datos`, `06_indices`, `07_vistas`, `08_seguridad`, `09_demostraciones`, `10_consultas`.

Los archivos se llaman `NN_[N_]descripcion.sql` y **el orden alfabético es el orden de ejecución** (el script `utilitarios/ejecutar_scripts.ps1` los ordena por ruta completa). El sub-número opcional `_N_` coloca un archivo antes del que comparte su `NN_`, porque un dígito ordena antes que una letra. Ejemplo: `02_1_provincia`, `02_2_canton` y `02_3_distrito` se ejecutan antes de `02_cliente`, que depende de `distrito`.

| Carpeta | Patrón del archivo | Ejemplos |
|---|---|---|
| `01_tablas` | `NN_[N_]<tabla>.sql`; el nombre de la tabla se escribe con guion bajo aunque la tabla no lo lleve. `02_cliente.sql` crea el supertipo y sus dos subtipos. `00_crear_base_datos.sql` crea la base | `01_empresa_emisora.sql`, `05_estado_factura.sql` |
| `02_funciones` | `NN_fn_<verbo>_<objeto>.sql` | `01_fn_calcular_monto_final.sql` |
| `03_procedimientos` | `NN_[N_]usp_<verbo>_<objeto>.sql`; el tipo de tabla es `00_tipo_detalle_factura.sql` | `10_usp_registrar_factura.sql` |
| `04_triggers` | Un trigger por archivo: `NN_trg_<objeto>_<operacion>.sql`. Los de `cliente`, `cliente_fisico` y `cliente_juridico` agrupan sus tres operaciones en `NN_trg_<objeto>_auditoria.sql`; `10_trg_cliente_direccion_auditoria.sql` sigue ese patrón con su única operación | `01_trg_factura_insert.sql`, `07_trg_cliente_auditoria.sql` |
| `05_datos` | `NN_[N_]cargar_<objeto>.sql` | `03_cargar_clientes.sql` |
| `06_indices` | `NN_ix_<tabla>_<columnas>.sql` | `01_ix_factura_cliente.sql` |
| `07_vistas` | `NN_vw_<descripcion>.sql` | `01_vw_totales_diarios.sql` |
| `08_seguridad` | `NN_<descripcion>.sql` | `01_roles_usuarios.sql` |
| `09_demostraciones` | `NN_<descripcion>_por_rol.sql` | `01_historial_cambios_por_rol.sql` |
| `10_consultas` | `NN_<descripcion>.sql` | `07_totales_cliente_anio_vigente.sql` |
| `pruebas` | `NN_<descripcion>.sql`; no se ejecutan con el script de utilitarios | `01_pruebas_procedimientos.sql` |

## 5. Parámetros, variables y alias

| Elemento | Patrón | Ejemplos |
|---|---|---|
| Parámetro de entrada | `@<columna>` con el nombre de la columna que representa. Si recibe el código de un catálogo en lugar de su id: `@codigo_<catalogo>` | `@cliente_id`, `@codigo_moneda`, `@codigo_estado_nuevo` |
| Filtros opcionales de consulta | valor por defecto `0` (números) o `''` (texto) = sin filtro; en rangos de fechas, los extremos (`'1900-01-01'` y `'9999-12-31'`) | `@factura_id BIGINT = 0`, `@desde DATETIME2 = '1900-01-01'` |
| Parámetro de tipo de tabla | nombre en plural, `READONLY` | `@detalles dbo.tipo_detalle_factura READONLY` |
| Identificador creado | parámetro `OUTPUT` con el nombre de la clave | `@cliente_id`, `@item_facturable_id`, `@factura_id`, `@numero_factura` |
| Salida de error (todos los `usp_`) | `@codigo_error INT OUTPUT`, `@mensaje_error VARCHAR(250) OUTPUT`; `0` y `'OK'` si todo salió bien | |
| Tabla temporal / variable de tabla | `#<descripcion>` / `@<descripcion>` | `#lineas`, `@usuarios` |
| Alias de tabla | una o dos letras en mayúscula derivadas del nombre; `I` = `INSERTED` y `D` = `DELETED` en los triggers | `F` factura, `CL` cliente, `CF` cliente_fisico, `CJ` cliente_juridico, `EM` empresaemisora, `IT` item_facturable |

## 6. Valores de catálogo y textos

- Códigos de catálogo en MAYÚSCULAS: tipos de documento `FAC` y `TIQ`; monedas `CRC` y `USD`; estados `BORRADOR`, `EMITIDA`, `PAGADA` y `CANCELADA`; operaciones `INSERT`, `UPDATE` y `DELETE`.
- Nombres de las entidades auditadas: el de la tabla en MAYÚSCULAS (`FACTURA_DETALLE`), más `CLIENTE_DIRECCION`.
- Mensajes de error y comentarios: español **sin tildes**, frase completa que empieza con mayúscula y termina en punto; máximo 250 caracteres (`VARCHAR(250)`).
- Los **datos** sí conservan su ortografía oficial: provincias, cantones y distritos de Hacienda (`San José`, `Limón`), el símbolo `¢` y el valor `Sí` de `vw_clientes_resumen.[ClienteFrecuente]`.

## 7. Códigos de error propios (`THROW`)

Rango `50001`–`50999`, agrupado por familia. Los procedimientos devuelven el número en `@codigo_error`; los errores propios de SQL Server (por ejemplo `547` o `2627`) llegan por el mismo parámetro.

| Rango | Familia | Códigos |
|---|---|---|
| `500xx` | Cargas masivas | `50001` empresas; `50011`–`50012` clientes; `50021` productos; `50031`–`50035` facturas; `50041` ubicaciones |
| `501xx` | Clientes y productos | `50101`–`50109` `usp_registrar_cliente`; `50111`–`50115` `usp_actualizar_cliente`; `50121`–`50126` `usp_registrar_producto`; `50131`–`50133` `usp_actualizar_precio_item` |
| `502xx` | Registro de facturas | `50201`–`50213` `usp_registrar_factura` (`50213` = existencias insuficientes) |
| `503xx` | Estado y eliminación de facturas | `50301`–`50303` `usp_cambiar_estado_factura`; `50311`–`50312` `usp_eliminar_factura` |
| `504xx` | Consultas de facturas | `50401`–`50402` `usp_consultar_totales_factura`; `50411`–`50412` `usp_consultar_facturas_cliente` |
| `505xx` | Auditoría | `50501` catálogos de auditoría incompletos (triggers); `50502` auditoría inmutable; `50511`–`50512` `usp_consultar_auditoria` |

Un procedimiento nuevo toma la siguiente decena libre de su familia (por ejemplo, `50141` para un cuarto procedimiento de clientes y productos).

## 8. Estilo SQL

- Palabras clave, funciones y tipos en MAYÚSCULAS; identificadores de objetos en MAYÚSCULAS; variables en minúscula (sección 1).
- Sangría de 4 espacios, sin tabuladores; finales de línea LF; codificación UTF-8.
- **Objetivo de estilo:** máximo de 80 caracteres por línea. En esta entrega existen excepciones: se detectaron **11 líneas** que superan ese límite en los 92 archivos de `scripts/`; varias usan `-- noqa: LT05`, pero no todas. No se presenta el límite como cumplimiento total ya verificado. Los archivos de `pruebas/` contienen más líneas extensas y requieren una política de lint separada si se pretende aplicarles el mismo límite.
- Los scripts que trabajan dentro de la base generalmente comienzan con `USE PROYECTOFACTURACION;` seguido de `GO`; **excepción:** `scripts/01_tablas/00_crear_base_datos.sql` primero verifica/crea la base y después ejecuta `USE`. Los archivos `pruebas/` utilizan capitalización distinta en varios casos. Usar `GO` para separar lotes donde corresponde.
- Una columna por línea en `SELECT` y `CREATE TABLE` (las listas de columnas de `INSERT` y `VALUES` pueden agruparse varias por línea); alias con `AS`; `INNER JOIN` y `LEFT JOIN` explícitos, con `ON` en la línea siguiente. No se usa `SELECT *`.
- `BEGIN` y `END` de un `IF` o `WHILE` van sangrados un nivel respecto del `IF`.
- Procedimientos, funciones, vistas y triggers se crean precedidos de `DROP ... IF EXISTS`, de modo que su archivo se puede volver a ejecutar. Las tablas y los índices no.
- Todo `usp_` empieza con `SET NOCOUNT ON;`; los que modifican datos agregan `SET XACT_ABORT ON;`, abren `BEGIN TRY` con `BEGIN TRANSACTION`, y su `CATCH` hace `ROLLBACK` si queda una transacción abierta y llena `@codigo_error` y `@mensaje_error`.

## Validación de estándares

Se utilizó **SQLFluff** como herramienta de análisis estático para revisar el formato y las convenciones de escritura del código SQL mediante **GitHub Actions** durante los *Pull Requests*. La comprobación `Analizar Estándares (SQLFluff)` aparece aprobada en la captura del Pull Request compartida por el equipo.

## Excepciones conocidas

Nombres y archivos que no siguen exactamente las reglas anteriores. Se conservan para no tocar objetos que ya funcionan, salvo los marcados como pendientes.

| Caso | Detalle | Estado |
|---|---|---|
| Tablas de una sola palabra | `empresaemisora`, `tipodocumento` y `estadofactura` se heredaron así de la primera entrega. Sus claves sí usan guion bajo (`empresa_id`, `tipo_documento_id`, `estado_factura_id`) y sus archivos también (`01_empresa_emisora.sql`) | Se conserva |
| Restricciones con el nombre pegado | A veces el nombre de la tabla aparece sin guion bajo: `pk_itemfacturable`, `fk_clientefisico_cliente`, `fk_clientejuridico_cliente`, `fk_facturadetalle_factura`, `fk_facturadetalle_itemfacturable`, `fk_productoconexistencia_item_facturable`, `ix_facturadetalle_factura`, `ix_facturadetalle_itemfacturable`, `ix_factura_fechaemision` | Se conserva |
| Triggers con el nombre de la entidad | `trg_cliente_direccion_auditoria_update` vive en `cliente`; `trg_producto_item_auditoria_update` y `trg_servicio_item_auditoria_update` viven en `item_facturable` (sección 3) | Se conserva |
| Archivos de triggers de producto | `11_trg_producto_*.sql` y `14_trg_producto_item_update.sql` abrevian `producto_con_existencia` como `producto` en el nombre del archivo; el trigger conserva el nombre completo (excepto `trg_producto_item_auditoria_update`) | Se conserva |
| Columnas equivalentes con nombre distinto | `cliente.correo` y `empresaemisora.correo_electronico`; `cliente.fecha_registro` / `fecha_actualizacion` y `factura.fecha_creacion` / `fecha_modificacion`; `empresaemisora.activa` e `item_facturable.activo` | Se conserva |
| Usuario de prueba abreviado | `usr_admin` corresponde a `rol_administrativo` | Se conserva |
| Archivos con identificadores en minúscula | `scripts/03_procedimientos/00_tipo_detalle_factura.sql` y `01_1_usp_cargar_ubicaciones.sql` usan identificadores en minúscula; `pruebas/` contiene asimismo SQL en minúsculas. El grueso de `scripts/` utiliza identificadores en mayúsculas | Se documenta; unificación opcional |
| Archivos con BOM | `03_procedimientos/01_1_usp_cargar_ubicaciones.sql` y `05_datos/01_1_cargar_ubicaciones.sql` empiezan con BOM de UTF-8; los demás, no | Se conserva; unificación opcional |


## Verificación y alcance de esta revisión

- Se compararon nombres y patrones con los archivos SQL de la copia suministrada del repositorio. El estándar describe lo que ya existe y señala desviaciones; **no renombra tablas ni altera la base**.
- La evidencia de SQLFluff y GitHub Actions corresponde a las comprobaciones mostradas en la captura del Pull Request compartida por el equipo; no se ejecutó SQLFluff durante esta revisión documental.
- La regla de máximo 80 caracteres es una **meta de estilo** con excepciones actuales, no una garantía de que todos los archivos pasen `LT05`.
- Las reglas de claves, transacciones, autorizaciones y negocio se explican en el `README.md`; no deben confundirse con una convención de nombres.
