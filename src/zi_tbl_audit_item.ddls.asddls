@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Audit Items'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_TBL_AUDIT_ITEM
  as select from ztbl_audit_item
  association to parent ZI_TBL_AUDIT as _AuditLog
    on $projection.AuditId = _AuditLog.AuditId
  association [0..1] to ztbl_user_master as _CurrentUser
    on _CurrentUser.username = $session.user
  association [0..1] to ztbl_user_perm as _UserPermission
    on  ztbl_audit_item.table_name = _UserPermission.table_name
    and _UserPermission.username = $session.user
{
  key audit_id    as AuditId,
  key item_no     as ItemNo,
      table_name  as TableName,
      record_key  as RecordKey,
      field_name  as FieldName,
      old_value   as OldValue,
      new_value   as NewValue,
      action_type as ActionType,

      _AuditLog
}
where _CurrentUser.active_flag = 'X'
  and ( _CurrentUser.role_type = 'ADMIN'
     or _UserPermission.can_view = 'X' )
