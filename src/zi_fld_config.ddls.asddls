@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Field Config'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_FLD_CONFIG
  as select from zfld_config
  association to parent ZI_TBL_CONFIG as _TblConfig
    on $projection.ConfigUuid = _TblConfig.ConfigUuid
{
  key table_name     as TableName,
  key field_name     as FieldName,
      config_uuid    as ConfigUuid,
      field_type     as FieldType,
      domain_name    as DomainName,
      mandatory_flag as MandatoryFlag,
      display_order  as DisplayOrder,
      label_text     as LabelText,
      is_key_field   as IsKeyField,
      readonly_flag  as ReadonlyFlag,
      hidden_flag    as HiddenFlag,

      _TblConfig
}
