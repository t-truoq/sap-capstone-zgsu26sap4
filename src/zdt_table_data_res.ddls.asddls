@EndUserText.label: 'Abstract Entity for Table Data Response'
define abstract entity ZDT_TABLE_DATA_RES
{
  table_name   : ztde_table_name;
  field_list   : abap.string;
  data_json    : abap.string;
  total_rows   : abap.int4;
  error_msg    : abap.string;
}
