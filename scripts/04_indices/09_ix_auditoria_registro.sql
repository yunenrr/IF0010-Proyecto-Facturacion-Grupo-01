USE ProyectoFacturacion;
GO

CREATE NONCLUSTERED INDEX ix_auditoria_registro
    ON dbo.auditoria (entidad_auditada_id, registro_id)
    INCLUDE (fecha_cambio);
GO
