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
    "! Quy tắc: admin/hidden/readonly → false; key nghiệp vụ (không hidden/readonly) → true; còn lại → true.
    CLASS-METHODS is_importable_field
      IMPORTING iv_fieldname         TYPE clike
                iv_is_key            TYPE abap_bool DEFAULT abap_false
                iv_readonly          TYPE abap_bool DEFAULT abap_false
                iv_hidden            TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_importable) TYPE abap_bool.

    "! Wrapper từ metadata ZFLD_CONFIG.
    CLASS-METHODS is_importable_field_info
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
      RETURNING VALUE(rv_importable) TYPE abap_bool.

    "! Import/template: loại DDIC key kỹ thuật (ENTITY_ID) nếu không phải business key.
    CLASS-METHODS is_importable_field_for_table
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
                iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_importable) TYPE abap_bool.

    "! Key fields dùng match Excel↔DB: is_key_field trong config + importable (business key).
    CLASS-METHODS get_match_key_fields
      IMPORTING it_fields            TYPE zcl_table_inspector=>tt_field_info
                iv_table_name        TYPE tabname
      RETURNING VALUE(rt_keys)       TYPE string_table.

    "! DDIC key fields của bảng (ENTITY_ID, …).
    CLASS-METHODS get_ddic_key_fields
      IMPORTING iv_table_name  TYPE tabname
      RETURNING VALUE(rt_keys) TYPE string_table.

    "! Tên field khóa kỹ thuật ENTITY_ID nếu bảng có (rỗng nếu không).
    CLASS-METHODS get_entity_id_field
      IMPORTING iv_table_name   TYPE tabname
      RETURNING VALUE(rv_field) TYPE fieldname.

    "! DDIC key không phải business key — parse từ Excel, không ghi DB (full export).
    CLASS-METHODS is_match_only_field
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
                iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_match_only) TYPE abap_bool.

    "! Cột được map khi import: importable HOẶC match-only (ENTITY_ID full data).
    CLASS-METHODS is_parseable_column
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
                iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_parseable)  TYPE abap_bool.

    "! Giá trị 1 cell trong dòng parse.
    CLASS-METHODS get_cell_value
      IMPORTING it_cells       TYPE tt_cell
                iv_field       TYPE fieldname
      RETURNING VALUE(rv_value) TYPE string.

    "! record_key JSON ổn định từ DB row hoặc Excel cells (ưu tiên ENTITY_ID).
    CLASS-METHODS build_record_key_json
      IMPORTING iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
                ir_row               TYPE REF TO data OPTIONAL
                it_cells             TYPE tt_cell OPTIONAL
      RETURNING VALUE(rv_json)       TYPE string.

    "! Key fields dùng build WHERE từ record_key JSON (ENTITY_ID hoặc business key).
    CLASS-METHODS get_where_key_fields
      IMPORTING iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
                iv_record_key        TYPE string
      RETURNING VALUE(rt_keys)       TYPE string_table
      RAISING   zcx_excel_pipeline.

    "! Build WHERE clause từ cells (match ENTITY_ID trước nếu có).
    CLASS-METHODS build_where_from_cells
      IMPORTING iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
                it_cells             TYPE tt_cell
      RETURNING VALUE(rv_where)      TYPE string.

    "! Field có tham gia so sánh diff / ghi DB hay không.
    CLASS-METHODS is_diff_comparable_field
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
                iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_ok)         TYPE abap_bool.

  PRIVATE SECTION.

    CLASS-METHODS is_config_flag
      IMPORTING iv_flag TYPE ztde_yesno
      RETURNING VALUE(rv_on) TYPE abap_bool.

    CLASS-METHODS append_json_key_value
      IMPORTING iv_key   TYPE string
                iv_value TYPE string
      CHANGING  cv_json  TYPE string
                cv_first TYPE abap_bool.

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
        OR 'CHANGED_BY'
        OR 'CHANGED_AT'
        OR 'LAST_CHANGED_BY'
        OR 'LAST_CHANGED_AT'
        OR 'LOCAL_LAST_CHANGED_AT'.
        rv_admin = abap_true.

      WHEN 'MANDT' OR 'CLIENT'.
        rv_admin = c_skip_client.

      WHEN 'ENTITY_ID'.
        " UUID/khóa kỹ thuật — user không điền qua Excel
        rv_admin = abap_true.

      WHEN OTHERS.
        rv_admin = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD is_config_flag.
    rv_on = COND #(
      WHEN iv_flag = abap_true OR iv_flag = 'X' THEN abap_true
      ELSE abap_false ).
  ENDMETHOD.


  METHOD is_importable_field.
    " 1) Admin/system-managed → không import
    IF is_admin_field( iv_fieldname ) = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    " 2) Hidden → không import (kể cả key kỹ thuật ENTITY_ID)
    IF iv_hidden = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    " 3) Readonly → không import (kể cả key readonly)
    IF iv_readonly = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    " 4) Key nghiệp vụ (không hidden/readonly) → cần để match record
    IF iv_is_key = abap_true.
      rv_importable = abap_true.
      RETURN.
    ENDIF.

    " 5) Field nghiệp vụ bình thường
    rv_importable = abap_true.
  ENDMETHOD.


  METHOD is_importable_field_info.
    rv_importable = is_importable_field(
      iv_fieldname = is_field-field_name
      iv_is_key    = is_config_flag( is_field-is_key_field )
      iv_readonly  = is_config_flag( is_field-readonly_flag )
      iv_hidden    = is_config_flag( is_field-hidden_flag ) ).
  ENDMETHOD.


  METHOD is_importable_field_for_table.
    rv_importable = is_importable_field_info( is_field ).
    IF rv_importable = abap_false.
      RETURN.
    ENDIF.

    " DDIC key nhưng không nằm trong business key (get_match_key_fields) → ẩn khỏi template/import
    DATA(lt_ddic) = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
    READ TABLE lt_ddic TRANSPORTING NO FIELDS
      WITH KEY table_line = CONV string( is_field-field_name ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lt_match) = get_match_key_fields(
      it_fields     = it_fields
      iv_table_name = iv_table_name ).

    READ TABLE lt_match TRANSPORTING NO FIELDS
      WITH KEY table_line = CONV string( is_field-field_name ).
    IF sy-subrc <> 0.
      rv_importable = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD get_match_key_fields.
    CLEAR rt_keys.

    " Ưu tiên business key từ ZFLD_CONFIG (is_key_field + importable)
    LOOP AT it_fields INTO DATA(ls_field).
      IF is_config_flag( ls_field-is_key_field ) = abap_false.
        CONTINUE.
      ENDIF.
      IF is_importable_field_info( ls_field ) = abap_false.
        CONTINUE.
      ENDIF.
      IF ls_field-field_name = 'MANDT' OR ls_field-field_name = 'CLIENT'.
        CONTINUE.
      ENDIF.
      APPEND CONV string( ls_field-field_name ) TO rt_keys.
    ENDLOOP.

    IF rt_keys IS NOT INITIAL.
      RETURN.
    ENDIF.

    " Fallback 2: DDIC key fields còn importable theo config
    DATA(lt_ddic) = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
    LOOP AT lt_ddic INTO DATA(lv_k).
      IF lv_k = 'MANDT' OR lv_k = 'CLIENT'.
        CONTINUE.
      ENDIF.
      READ TABLE it_fields INTO ls_field WITH KEY field_name = lv_k.
      IF sy-subrc <> 0.
        APPEND lv_k TO rt_keys.
        CONTINUE.
      ENDIF.
      IF is_importable_field_info( ls_field ) = abap_true.
        APPEND lv_k TO rt_keys.
      ENDIF.
    ENDLOOP.

    IF rt_keys IS NOT INITIAL.
      RETURN.
    ENDIF.

    " Fallback 3: mandatory + importable (business code, vd PRODUCT) khi chưa set is_key_field
    LOOP AT it_fields INTO ls_field.
      IF is_config_flag( ls_field-mandatory_flag ) = abap_false.
        CONTINUE.
      ENDIF.
      IF is_importable_field_info( ls_field ) = abap_false.
        CONTINUE.
      ENDIF.
      IF ls_field-field_name = 'MANDT' OR ls_field-field_name = 'CLIENT'.
        CONTINUE.
      ENDIF.
      APPEND CONV string( ls_field-field_name ) TO rt_keys.
    ENDLOOP.

    IF rt_keys IS NOT INITIAL.
      RETURN.
    ENDIF.

    " Fallback 4: field mã nghiệp vụ phổ biến (PRODUCT, CODE, …)
    LOOP AT it_fields INTO ls_field.
      DATA(lv_fn) = ls_field-field_name.
      TRANSLATE lv_fn TO UPPER CASE.
      IF lv_fn = 'PRODUCT'
        OR lv_fn = 'PRODUCT_CATEGORY'
        OR lv_fn CP 'PRODUCT_*'
        OR lv_fn CP '*_CODE'
        OR lv_fn = 'CODE'.
        IF is_importable_field_info( ls_field ) = abap_true.
          APPEND CONV string( ls_field-field_name ) TO rt_keys.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_ddic_key_fields.
    rt_keys = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
    DELETE rt_keys WHERE table_line = 'MANDT' OR table_line = 'CLIENT'.
  ENDMETHOD.


  METHOD get_entity_id_field.
    LOOP AT get_ddic_key_fields( iv_table_name ) INTO DATA(lv_k).
      IF lv_k = 'ENTITY_ID'.
        rv_field = 'ENTITY_ID'.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_match_only_field.
    READ TABLE get_ddic_key_fields( iv_table_name ) TRANSPORTING NO FIELDS
      WITH KEY table_line = CONV string( is_field-field_name ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lt_match) = get_match_key_fields(
      it_fields     = it_fields
      iv_table_name = iv_table_name ).

    READ TABLE lt_match TRANSPORTING NO FIELDS
      WITH KEY table_line = CONV string( is_field-field_name ).
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    rv_match_only = abap_true.
  ENDMETHOD.


  METHOD is_parseable_column.
    rv_parseable = COND #(
      WHEN is_importable_field_for_table(
             is_field      = is_field
             iv_table_name = iv_table_name
             it_fields     = it_fields ) = abap_true
        OR is_match_only_field(
             is_field      = is_field
             iv_table_name = iv_table_name
             it_fields     = it_fields ) = abap_true
      THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD get_cell_value.
    READ TABLE it_cells INTO DATA(ls) WITH KEY fieldname = iv_field.
    IF sy-subrc = 0.
      rv_value = ls-value.
    ENDIF.
  ENDMETHOD.


  METHOD append_json_key_value.
    DATA(lv_esc) = iv_value.
    REPLACE ALL OCCURRENCES OF '"' IN lv_esc WITH '\"'.
    IF cv_first = abap_true.
      cv_first = abap_false.
    ELSE.
      cv_json = cv_json && ','.
    ENDIF.
    cv_json = cv_json && |"{ iv_key }":"{ lv_esc }"|.
  ENDMETHOD.


  METHOD build_record_key_json.
    DATA lv_first TYPE abap_bool VALUE abap_true.
    rv_json = '{'.

    DATA(lv_eid_f) = get_entity_id_field( iv_table_name ).

    IF ir_row IS BOUND.
      ASSIGN ir_row->* TO FIELD-SYMBOL(<row>).
      IF lv_eid_f IS NOT INITIAL.
        ASSIGN COMPONENT lv_eid_f OF STRUCTURE <row> TO FIELD-SYMBOL(<eid>).
        IF sy-subrc = 0 AND <eid> IS NOT INITIAL.
          append_json_key_value(
            EXPORTING iv_key = CONV string( lv_eid_f ) iv_value = |{ <eid> }|
            CHANGING  cv_json = rv_json cv_first = lv_first ).
          rv_json = rv_json && '}'.
          RETURN.
        ENDIF.
      ENDIF.

      DATA(lt_biz) = get_match_key_fields(
        it_fields     = it_fields
        iv_table_name = iv_table_name ).
      LOOP AT lt_biz INTO DATA(lv_bk).
        ASSIGN COMPONENT lv_bk OF STRUCTURE <row> TO FIELD-SYMBOL(<bv>).
        IF sy-subrc = 0.
          append_json_key_value(
            EXPORTING iv_key = lv_bk iv_value = |{ <bv> }|
            CHANGING  cv_json = rv_json cv_first = lv_first ).
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF it_cells IS SUPPLIED AND it_cells IS NOT INITIAL.
      IF lv_eid_f IS NOT INITIAL.
        DATA(lv_eid_val) = get_cell_value( it_cells = it_cells iv_field = lv_eid_f ).
        IF lv_eid_val IS NOT INITIAL.
          append_json_key_value(
            EXPORTING iv_key = CONV string( lv_eid_f ) iv_value = lv_eid_val
            CHANGING  cv_json = rv_json cv_first = lv_first ).
          rv_json = rv_json && '}'.
          RETURN.
        ENDIF.
      ENDIF.

      lt_biz = get_match_key_fields(
        it_fields     = it_fields
        iv_table_name = iv_table_name ).
      LOOP AT lt_biz INTO lv_bk.
        DATA(lv_cv) = get_cell_value( it_cells = it_cells iv_field = CONV #( lv_bk ) ).
        append_json_key_value(
          EXPORTING iv_key = lv_bk iv_value = lv_cv
          CHANGING  cv_json = rv_json cv_first = lv_first ).
      ENDLOOP.
    ENDIF.

    rv_json = rv_json && '}'.
  ENDMETHOD.


  METHOD get_where_key_fields.
    CLEAR rt_keys.

    DATA(lv_eid_f) = get_entity_id_field( iv_table_name ).
    IF lv_eid_f IS NOT INITIAL AND iv_record_key IS NOT INITIAL.
      DATA lr_rec TYPE REF TO data.
      CREATE DATA lr_rec TYPE (iv_table_name).
      TRY.
          zcl_json_helper=>deserialize(
            EXPORTING iv_json   = iv_record_key
            CHANGING  ca_record = lr_rec ).
        CATCH cx_root INTO DATA(lxj).
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text = |record_key JSON không hợp lệ: { lxj->get_text( ) }|.
      ENDTRY.
      ASSIGN lr_rec->* TO FIELD-SYMBOL(<rec>).
      ASSIGN COMPONENT lv_eid_f OF STRUCTURE <rec> TO FIELD-SYMBOL(<eid>).
      IF sy-subrc = 0 AND <eid> IS NOT INITIAL.
        APPEND CONV string( lv_eid_f ) TO rt_keys.
        RETURN.
      ENDIF.
    ENDIF.

    rt_keys = get_match_key_fields(
      it_fields     = it_fields
      iv_table_name = iv_table_name ).
  ENDMETHOD.


  METHOD build_where_from_cells.
    DATA(lv_eid_f) = get_entity_id_field( iv_table_name ).
    IF lv_eid_f IS NOT INITIAL.
      DATA(lv_eid) = get_cell_value( it_cells = it_cells iv_field = lv_eid_f ).
      IF lv_eid IS NOT INITIAL.
        REPLACE ALL OCCURRENCES OF |'| IN lv_eid WITH |''|.
        rv_where = |{ lv_eid_f } = '{ lv_eid }'|.
        RETURN.
      ENDIF.
    ENDIF.

    DATA(lt_keys) = get_match_key_fields(
      it_fields     = it_fields
      iv_table_name = iv_table_name ).

    LOOP AT lt_keys INTO DATA(lv_k).
      DATA(lv_val) = get_cell_value( it_cells = it_cells iv_field = CONV #( lv_k ) ).
      REPLACE ALL OCCURRENCES OF |'| IN lv_val WITH |''|.
      DATA(lv_cond) = |{ lv_k } = '{ lv_val }'|.
      IF rv_where IS INITIAL.
        rv_where = lv_cond.
      ELSE.
        rv_where = rv_where && ` AND ` && lv_cond.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_diff_comparable_field.
    rv_ok = is_importable_field_for_table(
      is_field      = is_field
      iv_table_name = iv_table_name
      it_fields     = it_fields ).
  ENDMETHOD.

ENDCLASS.

