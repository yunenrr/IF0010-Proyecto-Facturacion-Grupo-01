# Diagrama entidad-relación (19 tablas)

Renderiza en GitHub (Mermaid). Cardinalidades: `||` uno, `o{` cero o muchos, `|o` cero o uno.

```mermaid
erDiagram
    provincia ||--o{ canton : "tiene"
    canton ||--o{ distrito : "tiene"
    distrito ||--o{ cliente : "ubica"
    cliente ||--o| cliente_fisico : "es"
    cliente ||--o| cliente_juridico : "es"
    empresaemisora ||--o{ factura : "emite"
    cliente ||--o{ factura : "compra"
    tipodocumento ||--o{ factura : "clasifica"
    moneda ||--o{ factura : "en"
    estadofactura ||--o{ factura : "estado"
    factura ||--|{ factura_detalle : "contiene"
    item_facturable ||--o{ factura_detalle : "se factura"
    item_facturable ||--o| producto_con_existencia : "es"
    item_facturable ||--o| servicio : "es"
    unidad_medida ||--o{ servicio : "mide"
    entidad_auditada ||--o{ auditoria : "clasifica"
    tipo_operacion ||--o{ auditoria : "operacion"

    provincia { int provincia_id PK
        char codigo_hacienda UK "1 posicion"
        varchar nombre UK }
    canton { int canton_id PK
        int provincia_id FK
        char codigo_hacienda "2 posiciones"
        varchar nombre }
    distrito { int distrito_id PK
        int canton_id FK
        char codigo_hacienda "2 posiciones"
        varchar nombre }
    cliente { int cliente_id PK
        varchar identificacion UK
        varchar correo
        varchar telefono
        int distrito_id FK
        varchar otras_senas
        datetime2 fecha_registro
        datetime2 fecha_actualizacion }
    cliente_fisico { int cliente_id PK_FK
        varchar nombre
        varchar apellido1
        varchar apellido2 }
    cliente_juridico { int cliente_id PK_FK
        varchar razon_social
        varchar nombre_comercial }
    empresaemisora { int empresa_id PK
        varchar nombre_comercial
        varchar razon_social
        varchar cedula
        varchar direccion
        varchar telefono
        varchar correo_electronico
        datetime2 fecha_creacion
        bit activa }
    tipodocumento { int tipo_documento_id PK
        varchar codigo UK
        varchar descripcion }
    moneda { int moneda_id PK
        char codigo UK
        varchar simbolo
        varchar descripcion }
    estadofactura { int estado_factura_id PK
        varchar codigo UK
        varchar descripcion }
    unidad_medida { int unidad_medida_id PK
        varchar descripcion UK }
    item_facturable { int item_facturable_id PK
        varchar codigo_interno UK
        varchar descripcion
        decimal precio_unitario
        decimal porcentaje_impuesto
        bit activo
        datetime2 fecha_creacion }
    producto_con_existencia { int producto_con_existencia_id PK_FK
        int stock_actual }
    servicio { int servicio_id PK_FK
        int unidad_medida_id FK }
    factura { bigint factura_id PK
        int empresa_id FK
        int cliente_id FK
        int tipo_documento_id FK
        int moneda_id FK
        int estado_factura_id FK
        varchar numero_factura UK "AAAAMMDDHHMMSS-TipoDocumento"
        datetime2 fecha_emision
        decimal tipo_cambio
        decimal monto_subtotal
        decimal monto_descuento
        decimal monto_impuesto
        decimal monto_total
        varchar observaciones
        datetime2 fecha_creacion
        datetime2 fecha_modificacion }
    factura_detalle { bigint factura_detalle_id PK
        bigint factura_id FK
        int item_facturable_id FK
        int numero_linea
        varchar descripcion
        decimal cantidad
        decimal precio_unitario
        decimal porcentaje_impuesto
        decimal monto_subtotal
        decimal monto_descuento
        decimal monto_impuesto
        decimal monto_total }
    tipo_operacion { int tipo_operacion_id PK
        varchar descripcion UK "INSERT UPDATE DELETE" }
    entidad_auditada { int entidad_auditada_id PK
        varchar nombre UK }
    auditoria { bigint auditoria_id PK
        int entidad_auditada_id FK
        bigint registro_id "sin FK: sobrevive al DELETE"
        int tipo_operacion_id FK
        nvarchar usuario
        datetime2 fecha_cambio
        nvarchar descripcion
        nvarchar datos_anteriores
        nvarchar datos_nuevos }
```

## Supuestos y especificaciones

- **Participación:** una factura exige al menos una línea (participación total de `factura_detalle` en `factura`); cada cliente pertenece exactamente a uno de los subtipos (`cliente_fisico` o `cliente_juridico`).
- **Dependencia:** `cliente_fisico`, `cliente_juridico`, `producto_con_existencia` y `servicio` comparten su clave primaria con la entidad padre (relación 1 a 1 de especialización).
- **Auditoría:** `auditoria.registro_id` guarda la clave primaria de la fila auditada (factura, línea, cliente o ítem) sin clave foránea, para conservar el historial cuando la fila se elimina.
- **Ubicaciones:** jerarquía provincia → cantón → distrito con los códigos de Hacienda; los barrios no se modelan.
- **Empresa emisora:** su dirección es texto libre.
