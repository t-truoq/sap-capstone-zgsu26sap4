@EndUserText.label: 'Excel Diff Row'
define abstract entity ZDT_EXCEL_DIFF_ROW
{
  key id         : sysuuid_x16;
      row_no     : abap.int4;
      table_name : abap.char(30);
      record_key : abap.string;
      field_name : abap.char(30);
      old_value  : abap.string;
      new_value  : abap.string;
      status     : abap.char(10);
      message    : abap.string;
}
