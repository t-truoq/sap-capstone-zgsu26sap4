@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Role Type Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_AUTH_ROLE_VH
  as select from dd07l as RoleValue
{
  @ObjectModel.text.element: ['RoleText']
  @UI.textArrangement: #TEXT_FIRST
  key cast( RoleValue.domvalue_l as abap.char(10) ) as RoleType,

  @Semantics.text: true
      case RoleValue.domvalue_l
        when 'ADMIN' then 'Administrator'
        when 'USER'  then 'User'
        else RoleValue.domvalue_l
      end                                               as RoleText
}
where
      RoleValue.domname  = 'ZDO_ROLE_TYPE'
  and RoleValue.as4local = 'A'
