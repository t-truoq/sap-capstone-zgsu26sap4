@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Approval Items'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_APRVL_ITEM
  as select from ztbl_aprvl_item
  association to parent ZI_APRVL_REQUEST as _AprvlRequest
    on $projection.AprvlId = _AprvlRequest.AprvlId
  association [0..1] to ztbl_user_master as _CurrentUser
    on _CurrentUser.username = $session.user
{
  key aprvl_id    as AprvlId,
  key item_no     as ItemNo,
      table_name  as TableName,
      record_key  as RecordKey,
      action_type as ActionType,
      status      as Status,
      new_data    as NewData,
      old_data    as OldData,
      message     as Message,

      _AprvlRequest
}
where _CurrentUser.role_type = 'ADMIN'
  and _CurrentUser.active_flag = 'X'
