@EndUserText.label: 'Abstract Entity for Dynamic CRUD Request'
define abstract entity ZDT_CRUD_REQ
{
  table_name  : ztde_table_name;
  record_key  : ztde_record_key;
  record_data : abap.string;
  etag_field  : ztde_field_name;
  etag_value  : abap.string;
}
