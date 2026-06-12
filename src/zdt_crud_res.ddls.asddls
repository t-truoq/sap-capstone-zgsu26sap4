@EndUserText.label: 'Abstract Entity Dynamic CRUD Response'
define abstract entity ZDT_CRUD_RES
{
  table_name  : ztde_table_name;
  record_key  : ztde_record_key;
  success     : abap_boolean;
  message     : abap.string;
}
