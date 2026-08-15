@EndUserText.label: 'Excel Commit Response'
define abstract entity ZDT_EXCEL_COMMIT_RES
{
  key id              : abap.char(1);
      inserted_count  : abap.int4;
      updated_count   : abap.int4;
      unchanged_count : abap.int4;
      skipped_count   : abap.int4;
      error_count     : abap.int4;
      parsed_rows     : abap.int4;
      action_rows     : abap.int4;
      new_count       : abap.int4;
      changed_count   : abap.int4;
      deleted_count   : abap.int4;
      commit_records  : abap.int4;
      message         : abap.string;
}
