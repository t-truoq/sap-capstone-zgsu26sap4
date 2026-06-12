@EndUserText.label: 'Excel Commit Request'
define root abstract entity ZDT_EXCEL_COMMIT_REQ
{
  key id         : abap.char(1);
      table_name : abap.char(30);
      diff_json  : abap.string;
}
