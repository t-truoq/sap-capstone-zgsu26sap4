@EndUserText.label: 'Repo Inventory — Foreign Key'
define abstract entity ZDT_REPO_INV_FK
{
  tabname       : abap.char(30);
  fieldname     : abap.char(30);
  checktable    : abap.char(30);
  checkfield    : abap.char(30);
  frk_art       : abap.char(1);
  cardinality   : abap.char(1);
  generic       : abap.char(1);
}
