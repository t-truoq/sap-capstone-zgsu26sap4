@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Auth Admin - User Master'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_AUTH_USER
  as select from ztbl_user_master
  association [0..1] to ztbl_user_master as _CurrentUser
    on  _CurrentUser.username    = $session.user
    and _CurrentUser.role_type   = 'ADMIN'
    and _CurrentUser.active_flag = 'X'
{
  key username    as Username,
      role_type   as RoleType,
      active_flag as ActiveFlag
}
where _CurrentUser.active_flag = 'X'
