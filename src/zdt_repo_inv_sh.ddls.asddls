@EndUserText.label: 'Repo Inventory — Search Help'
define abstract entity ZDT_REPO_INV_SH
{
  sh_name     : abap.char(30);
  sh_type     : abap.char(1);
  text        : abap.char(60);
  fieldname   : abap.char(30);
  param       : abap.char(30);
  param_imp   : abap.char(1);
  selopt      : abap.char(1);
}
