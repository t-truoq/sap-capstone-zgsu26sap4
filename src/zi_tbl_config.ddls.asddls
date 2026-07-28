@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Table Config'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZI_TBL_CONFIG
  as select from ztbl_config
  association [0..1] to ztbl_user_master as _CurrentUser
    on  _CurrentUser.username    = $session.user
    and _CurrentUser.active_flag = 'X'
  composition [0..*] of ZI_FLD_CONFIG as _FieldConfig
{
  key config_uuid       as ConfigUuid,
      table_name        as TableName,
      description       as Description,
      approval_required as ApprovalRequired,
      active_flag       as ActiveFlag,

      _FieldConfig
}
where _CurrentUser.active_flag = 'X'
