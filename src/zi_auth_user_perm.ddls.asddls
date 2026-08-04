@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Auth Admin - User Permissions'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZI_AUTH_USER_PERM
  as select from ztbl_user_perm
  association [0..1] to ztbl_user_master as _CurrentUser
    on  _CurrentUser.username    = $session.user
    and _CurrentUser.role_type   = 'ADMIN'
    and _CurrentUser.active_flag = 'X'
{
  key username   as Username,
  key table_name as TableName,
      @Semantics.booleanIndicator: true
      can_view   as CanView,
      @Semantics.booleanIndicator: true
      can_create as CanCreate,
      @Semantics.booleanIndicator: true
      can_update as CanUpdate,
      @Semantics.booleanIndicator: true
      can_delete as CanDelete
}
where _CurrentUser.role_type   = 'ADMIN'
  and _CurrentUser.active_flag = 'X'
