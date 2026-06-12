@EndUserText.label: 'Excel Download Request'
define root abstract entity ZDT_EXCEL_DOWNLOAD_REQ
{
  key id            : abap.char(1);
      table_name    : abap.char(30);
      template_only : abap_boolean;
}
