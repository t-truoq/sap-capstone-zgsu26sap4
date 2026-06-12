@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Table Config'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_TBL_CONFIG
  as select from ztbl_config
  composition [0..*] of ZI_FLD_CONFIG as _FieldConfig
{
  key config_uuid       as ConfigUuid,
      table_name        as TableName,
      description       as Description,
      approval_required as ApprovalRequired,
      active_flag       as ActiveFlag,

      _FieldConfig
}
