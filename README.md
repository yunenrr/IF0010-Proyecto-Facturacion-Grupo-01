# IF0010 - Sistema de facturación (Grupo 01)

Módulo central de facturación comercial para "Soluciones Magníficas S.A.", implementado en Microsoft SQL Server (curso IF0010 - Bases de Datos II). Documentación consolidada de la versión entregada, que incluye tablas, procedimientos, funciones, triggers de auditoría, cargas, índices, vistas, seguridad, consultas y pruebas.

## Descripción general

- Empresas emisoras, clientes (físicos y jurídicos), catálogos, productos y servicios, facturas con sus líneas de detalle y un historial de auditoría.
- Las **operaciones de negocio previstas** se implementan mediante procedimientos almacenados, con transacciones y manejo de errores cuando modifican datos. Esto no impide que un usuario con privilegios suficientes ejecute DML directo fuera de esos procedimientos.
- Las direcciones de los clientes se normalizan con la codificación oficial del Ministerio de Hacienda (provincia → cantón → distrito) y los clientes se separan en personas físicas y jurídicas.
- La auditoría la hacen triggers: registran operación, valores anterior y nuevo, usuario del motor y fecha, sin depender de la aplicación.

## Integrantes

Manuel Ernesto Trejos Angulo B87899 \
Daniel Campos Machado C21626

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `scripts/` | 92 archivos SQL organizados en 10 carpetas numeradas por orden de ejecución (ver más abajo) |
| `pruebas/` | 4 scripts de prueba y validación; no los ejecuta el script de utilitarios |
| `utilitarios/ejecutar_scripts.ps1` | Ejecuta todos los archivos de `scripts/` en orden con `sqlcmd` |
| `diagrama_ER/Diagrama_ER.md` | Diagrama relacional original en Mermaid |
| `diagrama_ER/ProyectoFacturacion_DER_horizontal_sin_leyenda.svg` | DER horizontal de notación conceptual con rombos y atributos; ampliable sin pérdida de nitidez |
| `diagrama_ER/ProyectoFacturacion_DER_horizontal_sin_leyenda.dot` | Fuente Graphviz editable del DER horizontal |
| `diagrama_ER/ProyectoFacturacion_DER_horizontal_sin_leyenda.png` | Vista previa del DER horizontal |
| `estandar_nomenclatura/Estandar_Nomenclatura.md` | Convenciones de nombres, códigos de error y estilo SQL |
| `presentacion/` | Presentación del proyecto |

Los archivos `.txt` originales de `diagrama_ER/`, `estandar_nomenclatura/` y `presentacion/` actúan como marcadores de otros entregables; el estándar actualizado está disponible en Markdown.

## Validación de código

Durante el desarrollo del proyecto se utilizaron herramientas de validación automatizada mediante **GitHub Actions**, ejecutadas al realizar *Pull Requests*:

- **SQLFluff:** para analizar el formato y el cumplimiento de estándares del código SQL.
- **SQL Server:** para comprobar la ejecución de los scripts SQL.

En el Pull Request revisado, ambas comprobaciones aparecen aprobadas: `ejecutar-validacion / Analizar Estándares (SQLFluff)` y `ejecutar-validacion / Probar Ejecución en SQL Server`.

## Requisitos

- SQL Server 2019 o superior (la versión definitiva se probó en SQL Server 2022; usa `DROP ... IF EXISTS`, `THROW`, `CONCAT`, `FOR JSON`).
- `sqlcmd` y PowerShell (para `utilitarios/ejecutar_scripts.ps1`) o SSMS para ejecutar los archivos a mano. El script invoca `sqlcmd` con `-b`, `-C` y `-f i:65001`, así que la versión instalada debe aceptar esas opciones.
- Permiso para crear bases de datos. La base se llama `ProyectoFacturacion`.
- SQLFluff, si se desea aplicar la revisión de estilo localmente (no requerido para ejecutar la BD).

## Instrucciones de ejecución

Base de datos vacía, en este orden (lo hace automáticamente el script de utilitarios, que ordena los archivos por ruta completa y se detiene en el primer error):

```powershell
./utilitarios/ejecutar_scripts.ps1 -Server "localhost,1433" -Username sa
```

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `-Server` | `localhost,1433` | Instancia de SQL Server |
| `-Username` | `sa` | Usuario; la contraseña se pide en consola y no se guarda |
| `-StartAt` | `1` | Número del archivo desde el cual reanudar (de 1 a 92); sirve para continuar después de corregir un error |

El script muestra el avance como `[n/92] carpeta\archivo.sql`, confía en el certificado del servidor (`-C`) y lee los archivos como UTF-8.

**Repetir la instalación:** las funciones, los procedimientos, los triggers y las vistas tienen `DROP ... IF EXISTS` para permitir su recreación. Las tablas y los índices no se recrean de ese modo. Una reinstalación realmente limpia requiere respaldar lo necesario y eliminar/recrear la base antes de ejecutar todos los archivos; `DROP DATABASE ProyectoFacturacion;` **destruye sus datos**, por lo que debe utilizarse solo en una base de práctica cuando proceda. `-StartAt` reanuda la ejecución pero no resuelve por sí solo dependencias o cambios de datos intermedios.

| Carpeta | Archivos | Contenido |
|---|---|---|
| `scripts/01_tablas` | 18 | Crea la base `ProyectoFacturacion` (`00_crear_base_datos.sql`) y las 19 tablas, con `USE ProyectoFacturacion;` en cada archivo |
| `scripts/02_funciones` | 5 | 3 funciones escalares y 2 funciones de tabla (`fn_*`). Van **antes** de los procedimientos y de la carga porque `usp_registrar_factura` y `usp_generar_facturas` usan `fn_generar_clave_comprobante` |
| `scripts/03_procedimientos` | 17 | Tipo de tabla `tipo_detalle_factura` y los 16 procedimientos `usp_*` |
| `scripts/04_triggers` | 19 | 25 triggers de auditoría, creados **antes** de la carga masiva para que los datos cargados también queden en el historial |
| `scripts/05_datos` | 6 | Llama a los procedimientos de carga: ubicaciones de Hacienda, catálogos, 100 empresas, 50 000 clientes, 1 000 productos y 500 000 facturas (lotes de 25 000, 3 a 5 líneas cada una) |
| `scripts/06_indices` | 14 | 14 índices no agrupados, creados **después** de las cargas para no frenarlas |
| `scripts/07_vistas` | 2 | 2 vistas de reporte (`vw_*`) |
| `scripts/08_seguridad` | 1 | Roles de base de datos, usuarios de prueba y permisos `SELECT` sobre las funciones; va después de las funciones porque los permisos las referencian |
| `scripts/09_demostraciones` | 2 | 2 consultas de demostración del control por rol (historial de cambios e información de clientes) |
| `scripts/10_consultas` | 8 | 8 consultas de búsqueda y reporte |

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

El modelo original se encuentra en `diagrama_ER/Diagrama_ER.md` (Mermaid). El DER horizontal definitivo se entrega también en **SVG** y **DOT** dentro de `diagrama_ER/`, manteniendo rectángulos, rombos, atributos y especializaciones. Las reglas de nombres están en `estandar_nomenclatura/Estandar_Nomenclatura.md`. Estos diagramas son representaciones conceptuales; la definición ejecutable de claves y restricciones sigue siendo la de los scripts de `scripts/01_tablas/`.

- **Ubicaciones:** `provincia`, `canton`, `distrito`. Códigos de Hacienda como `CHAR(1)`, `CHAR(2)` y `CHAR(2)` para conservar los ceros a la izquierda. Se cargan 7 provincias, 81 cantones y 475 distritos del documento oficial (sin barrios).
- **Clientes:** `cliente` (datos comunes y `distrito_id` + `otras_senas`), `cliente_fisico` y `cliente_juridico` (la lógica de registro clasifica una persona como física o jurídica; las tablas subtipo comparten `cliente_id` como PK y FK al supertipo). Las FK **no garantizan por sí solas** que un cliente tenga exactamente uno de los dos subtipos ni que estos sean excluyentes.
- **Catálogos:** `tipodocumento`, `moneda`, `estadofactura`, `unidad_medida`, `tipo_operacion`, `entidad_auditada`.
- **Oferta:** `item_facturable` (código, descripción, precio de lista en colones, impuesto), `producto_con_existencia` (stock) y `servicio` (unidad de medida). Los subtipos conservan el mismo **valor** de identificador que `item_facturable`, aunque la columna se llama `producto_con_existencia_id` o `servicio_id`; ambas son PK y FK. La exclusividad entre los dos subtipos depende de la lógica de negocio, no solamente de las FK.
- **Facturación:** `empresaemisora`, `factura` y `factura_detalle`.
- **Auditoría:** `auditoria`.

En las tablas del esquema se emplean `PRIMARY KEY`, `FOREIGN KEY`, `NOT NULL` y `UNIQUE`; no se declararon `CHECK` ni `DEFAULT`. Las columnas definidas en esos `CREATE TABLE` son `NOT NULL`. La exigencia de al menos un detalle por factura, los subtipos y otras validaciones se implementan principalmente en procedimientos, **no mediante restricciones declarativas completas**.

## Procedimientos almacenados (16)

| Tipo | Procedimientos |
|---|---|
| Cargas | `usp_cargar_ubicaciones`, `usp_cargar_catalogos`, `usp_generar_empresas`, `usp_generar_clientes`, `usp_generar_productos`, `usp_generar_facturas` |
| Operaciones | `usp_registrar_cliente`, `usp_actualizar_cliente`, `usp_registrar_producto`, `usp_actualizar_precio_item`, `usp_registrar_factura`, `usp_cambiar_estado_factura`, `usp_eliminar_factura` |
| Consultas | `usp_consultar_totales_factura`, `usp_consultar_facturas_cliente`, `usp_consultar_auditoria` |

Todos devuelven `@codigo_error` (0 = OK) y `@mensaje_error`. Los que crean registros devuelven además el identificador: `@cliente_id` (`usp_registrar_cliente`), `@item_facturable_id` (`usp_registrar_producto`), `@factura_id` y `@numero_factura` (`usp_registrar_factura`). `usp_registrar_factura` recibe las líneas como parámetro de tabla (`dbo.tipo_detalle_factura`: ítem, cantidad y descuento; el precio, el impuesto y la descripción se toman del catálogo).

Los errores propios usan códigos de 50001 a 50999 agrupados por familia (por ejemplo, `50213` = existencias insuficientes). La tabla completa está en el estándar de nomenclatura.

## Funciones (5)

| Función | Tipo | Qué devuelve |
|---|---|---|
| `fn_calcular_monto_final(@factura_id)` | Escalar | Monto a pagar: subtotal − descuentos + impuestos (`NULL` si la factura no existe) |
| `fn_generar_clave_comprobante(@fecha, @codigo_tipo_documento)` | Escalar | Clave `AAAAMMDDHHMMSS-CODIGO`; la usan `usp_registrar_factura` y `usp_generar_facturas` |
| `fn_es_factura_modificable(@numero_factura)` | Escalar | `1` si la factura está en estado BORRADOR; `0` en cualquier otro estado o si no existe |
| `fn_consultar_historial_cambios()` | De tabla | Historial de auditoría; solo devuelve filas a `ROL_AUDITOR`, `ROL_DBA` o `db_owner` |
| `fn_consultar_cliente(@identificacion)` | De tabla | Datos del cliente (físico o jurídico); correo y teléfono completos solo para `ROL_ADMINISTRATIVO`, `ROL_DBA` o `db_owner`, enmascarados para los demás |

`fn_calcular_monto_final` y `fn_es_factura_modificable` están pensadas para la capa de aplicación: ningún procedimiento del proyecto las invoca.

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

Las funciones deciden con `IS_MEMBER`. El enmascarado deja la primera letra del correo y el dominio (`m***@dominio.com`) y los últimos 4 dígitos del teléfono (`****1234`). Las consultas de `scripts/09_demostraciones` muestran el resultado para cada usuario.

## Consultas (8)

Están en `scripts/10_consultas`. Cada una devuelve el resultado pedido para valores de ejemplo que existen en los datos generados.

| Archivo | Qué devuelve | Valor de ejemplo |
|---|---|---|
| `01_facturas_persona_fisica.sql` | Encabezado de las facturas de una persona física a partir de su cédula | cédula `100000001` |
| `02_facturas_persona_juridica.sql` | Encabezado de las facturas de una persona jurídica a partir de su cédula | cédula `3102000010` |
| `03_buscar_persona_fisica_nombre_apellido1.sql` | Personas físicas por nombre y primer apellido | `Laura` `Castro` |
| `04_buscar_persona_fisica_nombre_apellido2.sql` | Personas físicas por nombre y segundo apellido | `Laura` `Esquivel` |
| `05_buscar_persona_juridica_razon_social.sql` | Personas jurídicas por razón social | `Comercial Chaves 10 Sociedad Anonima` |
| `06_buscar_persona_juridica_nombre_comercial.sql` | Personas jurídicas por nombre comercial, con el tiempo de respuesta en milisegundos | nombre comercial del primer cliente jurídico |
| `07_totales_cliente_anio_vigente.sql` | Total de descuentos, de impuestos y monto total facturado de un cliente en el año vigente, en colones | cédula `100000001` |
| `08_ventas_producto_rango_fechas.sql` | Identificador de factura, cantidad y fecha de emisión de un producto en un rango de fechas | producto `PROD-000001`, últimos 6 meses |

## Reglas de negocio

Las siguientes reglas corresponden a los procedimientos y al flujo previsto de la aplicación; no todas son restricciones declarativas verificadas por SQL Server para cualquier modificación directa.

### Facturas

- Identificador de factura: `AAAAMMDDHHMMSS-TipoDocumento` (por ejemplo `20260312143015-FAC`), con el código del tipo de documento (`FAC` o `TIQ`); único. Si ya existe, `usp_registrar_factura` avanza la fecha un segundo.
- `usp_registrar_factura` exige al menos una línea e inserta encabezado y detalles en la misma transacción. La FK impide un detalle huérfano, pero **una FK no impide por sí sola que alguien cree una factura sin detalle mediante un INSERT directo**. Esta regla se garantiza dentro del flujo previsto del procedimiento, sujeto a los permisos del usuario.
- Una factura nueva solo se registra como BORRADOR o EMITIDA (por defecto, EMITIDA). La empresa emisora debe existir y estar activa, y el cliente debe existir.
- Cada línea toma del catálogo el precio, el impuesto y la descripción del ítem, que debe estar activo. Cantidad mayor que cero; descuento no negativo y que no supere el subtotal de la línea.
- Línea: `subtotal = cantidad × precio`; `impuesto = (subtotal − descuento) × porcentaje / 100`; `total = subtotal − descuento + impuesto`. El encabezado suma sus líneas. Cada línea conserva el precio y el impuesto con que se facturó: cambiar el precio de un ítem no altera facturas anteriores.
- Moneda: el precio de lista está en colones (`CRC`). El tipo de cambio debe ser mayor que cero y, para colones, igual a 1. En una factura en dólares (`USD`), el precio de cada línea se divide entre el tipo de cambio.
- Estados: BORRADOR → EMITIDA | CANCELADA; EMITIDA → PAGADA | CANCELADA. PAGADA y CANCELADA son finales. Solo un BORRADOR se puede eliminar.
- Stock: las facturas no canceladas descuentan existencias; cancelar o eliminar un borrador las devuelve. Los productos con existencia se facturan en unidades enteras, las líneas repetidas del mismo producto se suman y el stock no puede quedar negativo. El stock se actualiza producto por producto en orden de identificador para evitar interbloqueos entre facturas concurrentes.

### Clientes y productos

- Cliente: tipo de persona `F` o `J`; identificación obligatoria y única; correo con `@` precedido de al menos un carácter; teléfono y otras señas obligatorios; distrito existente. Una persona física requiere nombre y dos apellidos; una jurídica, razón social y nombre comercial.
- Producto: código interno único, descripción obligatoria, precio mayor que cero, impuesto entre 0 y 100 y stock inicial no negativo.

## Auditoría

25 triggers (`scripts/04_triggers`), creados antes de la carga masiva. Cada trigger de factura, factura_detalle, producto y servicio está en su propio archivo; los de cliente, cliente_fisico y cliente_juridico agrupan sus tres operaciones en un solo archivo por tabla.

| Entidad (`entidad_auditada`) | Triggers | Qué audita |
|---|---|---|
| `FACTURA` | INSERT, UPDATE y DELETE sobre `factura` | Todas las columnas |
| `FACTURA_DETALLE` | INSERT, UPDATE y DELETE sobre `factura_detalle` | Todas las columnas |
| `CLIENTE` | INSERT, UPDATE y DELETE sobre `cliente` | Identificación, correo y teléfono |
| `CLIENTE_FISICO` | INSERT, UPDATE y DELETE sobre `cliente_fisico` | Nombre y apellidos |
| `CLIENTE_JURIDICO` | INSERT, UPDATE y DELETE sobre `cliente_juridico` | Razón social y nombre comercial |
| `CLIENTE_DIRECCION` | UPDATE sobre `cliente` | Distrito y otras señas (la dirección se guarda en `cliente`) |
| `PRODUCTO_CON_EXISTENCIA` | INSERT, UPDATE y DELETE sobre `producto_con_existencia`; UPDATE sobre `item_facturable` | Stock; código, descripción, precio, impuesto y estado activo (solo de ítems que son productos) |
| `SERVICIO` | INSERT, UPDATE y DELETE sobre `servicio`; UPDATE sobre `item_facturable` | Unidad de medida; código, descripción, precio, impuesto y estado activo (solo de ítems que son servicios) |
| `ITEM_FACTURABLE` | Ninguno | Figura en el catálogo, pero ningún trigger registra con ese nombre: los cambios de un ítem quedan como `PRODUCTO_CON_EXISTENCIA` o `SERVICIO` |

Además, `trg_auditoria_inmutable` impide modificar o borrar el historial. En total: 7 entidades con 3 triggers (21), más 3 triggers de UPDATE adicionales (dirección y los dos de `item_facturable`) y el de inmutabilidad.

Detalles:

- Usuario: `ORIGINAL_LOGIN()`. Fecha: `SYSDATETIME()`. Ambos los pone el motor.
- Se guardan los datos anteriores y nuevos en JSON y una descripción de los cambios.
- Los triggers incluyen lógica basada en `INSERTED`/`DELETED` para operaciones por conjuntos y se ejecutan en la transacción del cambio; al revertirse esta, se revierte su auditoría. Algunas verificaciones por escenarios se documentan en `pruebas/04_pruebas_auditoria.sql`.
- `auditoria` no tiene FK hacia las tablas auditadas: el historial permanece aunque se elimine la factura.
- Consulta: `usp_consultar_auditoria` (por entidad, registro, rango de fechas o factura) y `fn_consultar_historial_cambios()` (restringida por rol).

## Notas importantes

- La documentación fue contrastada estáticamente con los SQL de este ZIP. Los resultados de pruebas reflejan los comentarios del equipo en `pruebas/`, **no** ejecuciones realizadas durante esta revisión.

- Como los triggers se crean antes de la carga masiva, los datos iniciales también quedan registrados en `auditoria` (una fila por cliente, producto, factura y línea de detalle). Por eso la carga completa tarda más que sin auditoría.
- `vw_totales_diarios` suma los montos tal como están guardados, sin convertir monedas: un día con facturas en colones y en dólares mezcla ambas monedas en la misma suma. Cuenta todas las facturas, sin importar su estado.
- `ClienteFrecuente` cuenta las facturas del cliente emitidas entre hace 6 meses y la fecha actual (no cuenta facturas con fecha futura), sin importar su estado.
- La consulta `07_totales_cliente_anio_vigente.sql` convierte los montos a colones con el tipo de cambio de cada factura y solo cuenta facturas EMITIDAS y PAGADAS.
- Las consultas de `scripts/10_consultas` usan valores que existen en los datos generados (por ejemplo, la cédula `100000001`, el producto `PROD-000001`). Para medir su tiempo de respuesta se puede usar `SET STATISTICS TIME ON` en SSMS; la consulta 06 ya imprime su duración.
- La consulta de `scripts/09_demostraciones/01_historial_cambios_por_rol.sql` genera un cambio de prueba dentro de una transacción y lo revierte al terminar; no deja datos.
- `empresaemisora.direccion` es texto libre: la normalización por Hacienda se pidió solo para clientes.
- El PDF de Hacienda no incluye los distritos 2-11-03, 2-15-01, 4-03-01, 6-01-10 ni 7-01-03; no se inventaron.
- Los símbolos de moneda se guardan como `VARCHAR` (el colón como `¢`).
