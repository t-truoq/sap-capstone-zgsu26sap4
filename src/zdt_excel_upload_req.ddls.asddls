@EndUserText.label: 'Excel Upload Request'
define root abstract entity ZDT_EXCEL_UPLOAD_REQ
{
  key id          : abap.char(1);
      table_name  : abap.char(30);
      file_base64 : abap.string;
}
