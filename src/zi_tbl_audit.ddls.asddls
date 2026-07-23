@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Audit Log'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_TBL_AUDIT
  as select from ztbl_audit as Audit
  association [0..1] to ztbl_user_perm as _UserPermission
    on  Audit.table_name = _UserPermission.table_name
    and _UserPermission.username = $session.user
  association [0..1] to ztbl_user_master as _CurrentUser
    on _CurrentUser.username = $session.user
  composition [0..*] of ZI_TBL_AUDIT_ITEM as _Items
{
  key Audit.audit_id    as AuditId,
      Audit.table_name  as TableName,
      Audit.record_key  as RecordKey,
      Audit.field_name  as FieldName,
      Audit.old_value   as OldValue,
      Audit.new_value   as NewValue,
      Audit.changed_by  as ChangedBy,
      Audit.changed_at  as ChangedAt,
      Audit.action_type as ActionType,
      Audit.rollback_audit_id as RollbackAuditId,

      _Items
}
where _CurrentUser.active_flag = 'X'
  and ( _CurrentUser.role_type = 'ADMIN'
     or _UserPermission.can_view = 'X' )
