@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Active Flag Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_YESNO_VH
  as select from dd07l as FlagValue
{
  @ObjectModel.text.element: ['FlagText']
  @UI.textArrangement: #TEXT_LAST
  key cast( FlagValue.domvalue_l as abap.char(1) ) as FlagValue,

  @Semantics.text: true
      case FlagValue.domvalue_l
        when 'X' then 'Active'
        else          'Inactive'
      end                                                as FlagText
}
where
      FlagValue.domname  = 'ZTBL_YESNO'
  and FlagValue.as4local = 'A'
