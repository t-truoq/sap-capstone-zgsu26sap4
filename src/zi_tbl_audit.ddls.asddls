@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Audit Log'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_TBL_AUDIT
  as select from ztbl_audit
{
  key audit_id    as AuditId,
      table_name  as TableName,
      record_key  as RecordKey,
      field_name  as FieldName,
      old_value   as OldValue,
      new_value   as NewValue,
      changed_by  as ChangedBy,
      changed_at  as ChangedAt,
      action_type as ActionType
}
