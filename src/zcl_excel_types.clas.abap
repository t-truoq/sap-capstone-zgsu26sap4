"! <p class="shorttext synchronized">Types & constants dùng chung cho Excel Pipeline</p>
"! Chỉ chứa TYPES + CONSTANTS, không có logic.
"! Field metadata KHÔNG khai báo lại ở đây — dùng zcl_table_inspector=>tt_field_info.
CLASS zcl_excel_types DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " 1 ô dữ liệu = field + value dạng string
    TYPES: BEGIN OF ty_cell,
             fieldname TYPE fieldname,
             value     TYPE string,
           END OF ty_cell,
           tt_cell TYPE STANDARD TABLE OF ty_cell WITH KEY fieldname.

    " 1 dòng Excel đã parse (Phase 2,3,4)
    TYPES: BEGIN OF ty_parsed_row,
             row_no TYPE i,
             cells  TYPE tt_cell,
           END OF ty_parsed_row,
           tt_parsed_row TYPE STANDARD TABLE OF ty_parsed_row WITH KEY row_no.

    " 1 dòng diff (Phase 3,4). record_key là chuỗi JSON các key field.
    TYPES: BEGIN OF ty_diff_row,
             row_no     TYPE i,
             table_name TYPE tabname,
             record_key TYPE string,
             fieldname  TYPE fieldname,
             old_value  TYPE string,
             new_value  TYPE string,
             status     TYPE c LENGTH 10,
             message    TYPE string,
           END OF ty_diff_row,
           tt_diff_row TYPE STANDARD TABLE OF ty_diff_row WITH EMPTY KEY.

    " Summary kết quả import (Phase 4)
    TYPES: BEGIN OF ty_summary,
             inserted_count  TYPE i,
             updated_count   TYPE i,
             unchanged_count TYPE i,
             skipped_count   TYPE i,
             error_count     TYPE i,
             messages        TYPE string_table,
           END OF ty_summary.

    " Trạng thái diff
    CONSTANTS: BEGIN OF c_status,
                 new       TYPE c LENGTH 10 VALUE 'NEW',
                 changed   TYPE c LENGTH 10 VALUE 'CHANGED',
                 unchanged TYPE c LENGTH 10 VALUE 'UNCHANGED',
                 error     TYPE c LENGTH 10 VALUE 'ERROR',
               END OF c_status.

    " Action type — khớp domain ZTBL_ACTION_TYPE (C/U/D)
    CONSTANTS: BEGIN OF c_action,
                 create TYPE ztde_action_type VALUE 'C',
                 update TYPE ztde_action_type VALUE 'U',
                 delete TYPE ztde_action_type VALUE 'D',
               END OF c_action.

    " Bật khi backend tự fill CLIENT = sy-mandt (lúc đó CLIENT coi là admin field).
    " Tạm để OFF vì importer hiện vẫn cần CLIENT trong key.
    CONSTANTS c_skip_client TYPE abap_bool VALUE abap_false.

    "! Field do hệ thống quản lý → không cho Excel ghi (audit/admin).
    "! MANDT/CLIENT chỉ tính admin khi c_skip_client = abap_true.
    CLASS-METHODS is_admin_field
      IMPORTING iv_fieldname    TYPE clike
      RETURNING VALUE(rv_admin) TYPE abap_bool.

    "! Quyết định field có cho user nhập/import (và xuất template) hay không.
    "! Quy tắc: admin/hidden → false; key → true; readonly non-key → false; còn lại → true.
    CLASS-METHODS is_importable_field
      IMPORTING iv_fieldname         TYPE clike
                iv_is_key            TYPE abap_bool DEFAULT abap_false
                iv_readonly          TYPE abap_bool DEFAULT abap_false
                iv_hidden            TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_importable) TYPE abap_bool.

ENDCLASS.


CLASS zcl_excel_types IMPLEMENTATION.

  METHOD is_admin_field.
    DATA lv_fld TYPE string.
    lv_fld = iv_fieldname.
    CONDENSE lv_fld.
    TRANSLATE lv_fld TO UPPER CASE.

    CASE lv_fld.
      WHEN 'CREATED_BY'
        OR 'CREATED_AT'
        OR 'LAST_CHANGED_BY'
        OR 'LAST_CHANGED_AT'
        OR 'LOCAL_LAST_CHANGED_AT'.
        rv_admin = abap_true.

      WHEN 'MANDT' OR 'CLIENT'.
        rv_admin = c_skip_client.

      WHEN OTHERS.
        rv_admin = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD is_importable_field.
    " 1) Admin/system-managed → không import
    IF is_admin_field( iv_fieldname ) = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    " 2) Hidden → không import
    IF iv_hidden = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    " 3) Key field → cần để định danh record → giữ
    IF iv_is_key = abap_true.
      rv_importable = abap_true.
      RETURN.
    ENDIF.

    " 4) Readonly non-key → không cho sửa
    IF iv_readonly = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    " 5) Field nghiệp vụ bình thường
    rv_importable = abap_true.
  ENDMETHOD.

ENDCLASS.

