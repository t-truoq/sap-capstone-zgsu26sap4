@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Aprvl'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_APRVL_REQUEST
  as select from ztbl_aprvl
  association [0..1] to ztbl_user_master as _CurrentUser
    on _CurrentUser.username = $session.user
  composition [0..*] of ZI_APRVL_ITEM as _Items
{
  key aprvl_id      as AprvlId,
      table_name    as TableName,
      record_key    as RecordKey,
      action_type   as ActionType,
      status        as Status,
      new_data      as NewData,
      old_data      as OldData,
      submitted_by  as SubmittedBy,
      submitted_at  as SubmittedAt,
      approved_by   as ApprovedBy,
      approved_at   as ApprovedAt,
      aprvl_comment as AprvlComment,

      _Items
}
where _CurrentUser.role_type = 'ADMIN'
  and _CurrentUser.active_flag = 'X'
