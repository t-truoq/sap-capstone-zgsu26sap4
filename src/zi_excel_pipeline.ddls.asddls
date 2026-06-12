@EndUserText.label: 'Excel Pipeline'
define root view entity ZI_EXCEL_PIPELINE
  as select from zexcel_stub
{
  key stub_id as StubId
}
