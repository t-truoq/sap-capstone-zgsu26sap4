@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Auth Admin - Table Permissions'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_AUTH_TABLE_PERM
  as select from ztbl_table_perm
  association [0..1] to ztbl_user_master as _AdminAccess
    on  _AdminAccess.username    = $session.user
    and _AdminAccess.role_type   = 'ADMIN'
    and _AdminAccess.active_flag = 'X'
{
  key table_name as TableName,
      can_view   as CanView,
      can_create as CanCreate,
      can_update as CanUpdate,
      can_delete as CanDelete,
      can_upload as CanUpload,

  @Consumption.hidden: true
  _AdminAccess
}
