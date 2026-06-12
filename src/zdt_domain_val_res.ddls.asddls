@EndUserText.label: 'Abstract Entity for Domain Values'
define abstract entity ZDT_DOMAIN_VAL_RES
{
  domain_name  : abap.char(30);
  values_json  : abap.string;
  error_msg    : abap.string;
}
