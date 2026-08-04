@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Auth Admin - Table Permissions'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZI_AUTH_TABLE_PERM
  as select from ztbl_table_perm
  association [0..1] to ztbl_user_master as _AdminAccess
    on  _AdminAccess.username    = $session.user
    and _AdminAccess.role_type   = 'ADMIN'
    and _AdminAccess.active_flag = 'X'
{
  key table_name as TableName,
      @Semantics.booleanIndicator: true
      can_view   as CanView,
      @Semantics.booleanIndicator: true
      can_create as CanCreate,
      @Semantics.booleanIndicator: true
      can_update as CanUpdate,
      @Semantics.booleanIndicator: true
      can_delete as CanDelete,

  @Consumption.hidden: true
  _AdminAccess
}
where _AdminAccess.active_flag = 'X'
