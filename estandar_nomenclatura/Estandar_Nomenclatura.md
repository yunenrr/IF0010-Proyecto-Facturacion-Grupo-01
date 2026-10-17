# Estándar de nomenclatura (reflejado en los scripts)

Los nombres de tablas de varias palabras aparecen a veces con y a veces sin guion bajo en las restricciones (p. ej. `fk_facturadetalle_factura`), porque se heredaron de la primera entrega; se conservaron sin renombrar para no tocar tablas que ya funcionan.

Todo en minúsculas con guion bajo, sin tildes. Las tablas conservan los nombres del modelo original (algunas en una sola palabra: `empresaemisora`, `tipodocumento`, `estadofactura`).

| Elemento | Patrón | Ejemplos |
|---|---|---|
| Base de datos | `ProyectoFacturacion` | |
| Tablas | sustantivo singular; subtipos `tabla_subtipo` | `cliente`, `cliente_fisico`, `factura_detalle`, `producto_con_existencia` |
| Columnas | `snake_case`; clave primaria `<tabla>_id`; montos `monto_*`; fechas `fecha_*`; códigos de Hacienda `codigo_hacienda` | `monto_total`, `fecha_emision` |
| Llave primaria | `pk_<tabla>` | `pk_factura`, `pk_cliente_fisico`, `pk_itemfacturable` |
| Llave foránea | `fk_<tabla>_<tabla referenciada>` | `fk_factura_cliente`, `fk_distrito_canton`, `fk_facturadetalle_factura` |
| Restricción única | `uq_<tabla>_<columnas>` | `uq_factura_numero`, `uq_canton_provincia_codigo` |
| Índice no agrupado | `ix_<tabla>_<columna>` | `ix_factura_cliente`, `ix_auditoria_registro` |
| Procedimientos | `usp_<verbo>_<objeto>` | `usp_registrar_factura`, `usp_consultar_auditoria` |
| Tipo de tabla | `tipo_<descripcion>` | `tipo_detalle_factura` |
| Triggers | `trg_<tabla>_auditoria_<operacion>` | `trg_factura_auditoria_update`; `trg_auditoria_inmutable` |
| Funciones / vistas | pendientes de la siguiente revisión | |
| Archivos SQL | `NN_[N_]descripcion.sql` dentro de `NN_carpeta`; el orden alfabético es el orden de ejecución | `01_tablas/02_cliente.sql` |
| Parámetros de salida de error | `@codigo_error INT`, `@mensaje_error VARCHAR(250)` | |
| Códigos de error propios | 50001-50999 (por familia de procedimiento) | 50213 = existencias insuficientes |

Estilo SQL (`.sqlfluff`, dialecto `tsql`): palabras clave, funciones y literales en MAYÚSCULAS; identificadores en minúsculas.
