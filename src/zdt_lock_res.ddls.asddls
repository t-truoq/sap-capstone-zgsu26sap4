@EndUserText.label: 'Lock Action Response'
define abstract entity ZDT_LOCK_RES
{
  table_name : ztde_table_name;
  session_id : sysuuid_c32;
  success    : abap_boolean;
  message    : abap.string;
  locked_by  : syuname;
  expires_at : timestampl;
}
