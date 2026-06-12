@EndUserText.label: 'Field Metadata Response'
define abstract entity ZDT_FIELDMETA_RES {
  table_name : ztde_table_name;
  meta_json  : abap.string;
  error_msg  : abap.string;
}
