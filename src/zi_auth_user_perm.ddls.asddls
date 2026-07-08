@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Auth Admin - User Permissions'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_AUTH_USER_PERM
  as select from ztbl_user_perm
{
  key username   as Username,
  key table_name as TableName,
      can_view   as CanView,
      can_create as CanCreate,
      can_update as CanUpdate,
      can_delete as CanDelete,
      can_upload as CanUpload
}
