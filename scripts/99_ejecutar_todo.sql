:ON ERROR EXIT

-- =========================================
-- 1. CREAR BASE DE DATOS
-- =========================================
:r .\00_crear_base_datos.sql


-- =========================================
-- 2. CREAR TABLAS
-- =========================================
:r .\01_tablas\01_empresa_emisora.sql
:r .\01_tablas\02_cliente.sql
:r .\01_tablas\03_tipo_documento.sql
:r .\01_tablas\04_moneda.sql
:r .\01_tablas\05_1_unidad_medida.sql
:r .\01_tablas\05_2_tipo_operacion.sql
:r .\01_tablas\05_estado_factura.sql
:r .\01_tablas\06_item_facturable.sql
:r .\01_tablas\07_producto.sql
:r .\01_tablas\08_servicio.sql
:r .\01_tablas\09_factura.sql
:r .\01_tablas\10_factura_detalle.sql
:r .\01_tablas\11_auditoria.sql


-- =========================================
-- 3. CREAR INDICES
-- =========================================
:r .\02_indices\01_ix_factura_cliente.sql
:r .\02_indices\02_ix_factura_empresa.sql
:r .\02_indices\03_ix_factura_fechaemision.sql
:r .\02_indices\04_ix_factura_estado.sql
:r .\02_indices\05_ix_factura_moneda.sql
:r .\02_indices\06_ix_facturadetalle_itemfacturable.sql
:r .\02_indices\07_ix_servicio_unidad_medida.sql
:r .\02_indices\08_ix_auditoria_tipo_operacion.sql
:r .\02_indices\09_ix_auditoria_factura.sql


-- =========================================
-- 4. CREAR PROCEDIMIENTOS
-- =========================================
:r .\03_procedimientos\01_sp_cargar_catalogos.sql


-- =========================================
-- 5. CARGAR DATOS
-- =========================================
:r .\04_datos\01_cargar_catalogos.sql
