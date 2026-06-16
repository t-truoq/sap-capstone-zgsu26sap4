@EndUserText.label: 'Repo Inventory — CDS / ABAP Object'
define abstract entity ZDT_REPO_INV_CDS
{
  ddlname        : abap.char(40);
  ddlkind        : abap.char(1);
  abap_language  : abap.char(1);
  devclass       : abap.char(30);
  author         : abap.char(12);
  changedate     : abap.dats;
  description    : abap.char(60);
  depends_on_tbl : abap.char(30);
}
