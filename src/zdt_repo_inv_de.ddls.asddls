@EndUserText.label: 'Repo Inventory — Data Element'
define abstract entity ZDT_REPO_INV_DE
{
  rollname    : abap.char(30);
  domname     : abap.char(30);
  datatype    : abap.char(4);
  leng        : abap.numc(6);
  decimals    : abap.numc(6);
  label_short : abap.char(40);
  label_med   : abap.char(60);
  label_long  : abap.char(255);
  has_sh      : abap_boolean;
  sh_name     : abap.char(30);
}
