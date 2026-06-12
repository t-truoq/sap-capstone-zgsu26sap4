@EndUserText.label: 'Excel Pipeline'
define root view entity ZC_EXCEL_PIPELINE
  provider contract transactional_query
  as projection on ZI_EXCEL_PIPELINE
{
  key StubId
}
