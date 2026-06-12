@EndUserText.label: 'Excel Commit Response'
define abstract entity ZDT_EXCEL_COMMIT_RES
{
  key id              : abap.char(1);
      inserted_count  : abap.int4;
      updated_count   : abap.int4;
      unchanged_count : abap.int4;
      skipped_count   : abap.int4;
      error_count     : abap.int4;
      message         : abap.string;
}
