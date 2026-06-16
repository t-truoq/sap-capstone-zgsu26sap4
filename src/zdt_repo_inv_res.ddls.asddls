@EndUserText.label: 'Repo Inventory — Aggregate Response'
define abstract entity ZDT_REPO_INV_RES
{
  table_name      : abap.char(30);
  data_elements_json : abap.string;
  search_helps_json   : abap.string;
  function_modules_json : abap.string;
  cds_views_json       : abap.string;
  foreign_keys_json    : abap.string;
  error_msg        : abap.string;
}
