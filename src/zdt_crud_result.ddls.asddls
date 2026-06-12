define abstract entity ZDT_CRUD_RESULT {
  table_name : abap.char(30);
  success    : abap_boolean;
  message    : abap.char(255);
}
