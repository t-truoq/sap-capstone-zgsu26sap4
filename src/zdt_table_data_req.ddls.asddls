@EndUserText.label: 'Abstract Entity for Table Data Request'
define abstract entity ZDT_TABLE_DATA_REQ
{
  table_name  : ztde_table_name;
  where_clause : abap.string;
  max_rows    : abap.int4;
}
