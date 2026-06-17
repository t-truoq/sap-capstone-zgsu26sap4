@EndUserText.label: 'Repo Inventory — Function Module'
define abstract entity ZDT_REPO_INV_FM
{
  funcname    : abap.char(30);
  area        : abap.char(26);
  fmode       : abap.char(1);
  stext       : abap.char(40);
  devclass    : abap.char(30);
  author      : abap.char(12);
  source      : abap.char(1);
  used_in_tadir_obj : abap.char(30);
}
