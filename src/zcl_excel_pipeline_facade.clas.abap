"! <p class="shorttext synchronized">Excel Pipeline Facade (Phase 5 helper)</p>
"! Lớp facade để OData V2 action gọi vào:
"! - download template/data dạng Base64
"! - upload preview (parse + diff)
"! - confirm import từ diff đã duyệt
CLASS zcl_excel_pipeline_facade DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS download_excel_base64
      IMPORTING iv_table_name         TYPE tabname
                iv_template_only      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_file_base64) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS preview_import_base64
      IMPORTING iv_table_name    TYPE tabname
                iv_file_base64   TYPE string
      EXPORTING et_rows          TYPE zcl_excel_types=>tt_parsed_row
                et_diff          TYPE zcl_excel_types=>tt_diff_row
                et_messages      TYPE string_table
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS confirm_import
      IMPORTING iv_table_name        TYPE tabname
                it_diff              TYPE zcl_excel_types=>tt_diff_row
      RETURNING VALUE(rs_summary)    TYPE zcl_excel_types=>ty_summary
      RAISING   zcx_excel_pipeline.

ENDCLASS.


CLASS zcl_excel_pipeline_facade IMPLEMENTATION.

  METHOD download_excel_base64.
    DATA lv_xstring TYPE xstring.

    IF iv_template_only = abap_true.
      lv_xstring = zcl_excel_exporter=>export_template( iv_table_name ).
    ELSE.
      lv_xstring = zcl_excel_exporter=>export_table( iv_table_name ).
    ENDIF.

    rv_file_base64 = cl_http_utility=>encode_x_base64( lv_xstring ).
  ENDMETHOD.


  METHOD preview_import_base64.
    CLEAR: et_rows, et_diff, et_messages.

    DATA(lv_xstring) = cl_http_utility=>decode_x_base64( iv_file_base64 ).

    zcl_excel_importer=>parse_excel(
      EXPORTING
        iv_table_name = iv_table_name
        iv_file       = lv_xstring
      IMPORTING
        et_rows       = et_rows
        et_messages   = et_messages ).

    et_diff = zcl_excel_diff_builder=>build_diff(
                iv_table_name = iv_table_name
                it_rows       = et_rows ).
  ENDMETHOD.


  METHOD confirm_import.
    rs_summary = zcl_excel_committer=>confirm_import(
                   iv_table_name = iv_table_name
                   it_diff       = it_diff
                   iv_do_commit  = abap_false ).
  ENDMETHOD.

ENDCLASS.

