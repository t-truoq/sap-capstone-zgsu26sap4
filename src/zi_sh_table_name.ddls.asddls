@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Z/Y Table Names'
@Search.searchable: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #M,
  dataClass: #MASTER
}
define view entity ZI_SH_TABLE_NAME
  as select from dd02l
  left outer join dd02t
    on  dd02l.tabname    = dd02t.tabname
    and dd02t.ddlanguage = 'E'
{
  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  key dd02l.tabname  as TableName,

  @Search.defaultSearchElement: true
      dd02t.ddtext   as Description
}
where
  dd02l.tabclass = 'TRANSP'
  and ( dd02l.tabname like 'Z%' or dd02l.tabname like 'Y%' )
  and dd02l.as4local = 'A'
