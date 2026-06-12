@EndUserText.label: 'Excel Download Response'
define abstract entity ZDT_EXCEL_DOWNLOAD_RES
{
  key id          : abap.char(1);
      file_base64 : abap.string;
      message     : abap.string;
}
