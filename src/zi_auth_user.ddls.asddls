@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Auth Admin - User Master'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_AUTH_USER
  as select from ztbl_user_master
{
  key username    as Username,
      role_type   as RoleType,
      active_flag as ActiveFlag
}
