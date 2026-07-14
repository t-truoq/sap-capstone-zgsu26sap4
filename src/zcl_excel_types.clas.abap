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
                 delete    TYPE c LENGTH 10 VALUE 'DELETE',
                 unchanged TYPE c LENGTH 10 VALUE 'UNCHANGED',
                 skipped   TYPE c LENGTH 10 VALUE 'SKIPPED',
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

CLASS-METHODS build_where_from_record_key
      IMPORTING iv_table_name TYPE tabname
                iv_record_key TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_where) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS apply_cells_to_record
      IMPORTING iv_table_name TYPE tabname
                it_cells      TYPE zcl_excel_types=>tt_cell
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      CHANGING  cr_record     TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_merged_record
      IMPORTING iv_table_name TYPE tabname
                it_cells      TYPE zcl_excel_types=>tt_cell
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                iv_status     TYPE c
                iv_record_key TYPE string
      EXPORTING ev_old_json   TYPE string
                ev_new_json   TYPE string
                er_record     TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS check_business_key_collision
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                ir_db_row     TYPE REF TO data
                it_cells      TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rv_error) TYPE string.

    "! Deserialize new_data ngược lại struct — bắt lỗi tên field JSON ≠ DDIC trước khi gửi duyệt.
    CLASS-METHODS validate_approval_json
      IMPORTING iv_table_name TYPE tabname
                iv_new_json   TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      RAISING   zcx_excel_pipeline.

    "! Gán admin field ngay trước INSERT (Approve / commit trực tiếp).
    "! Gán LAST_CHANGED_* / CHANGED_* ngay trước UPDATE (Approve / commit trực tiếp).
PRIVATE SECTION.
CLASS-METHODS is_config_flag
      IMPORTING iv_flag TYPE ztde_yesno
      RETURNING VALUE(rv_on) TYPE abap_bool.

    CLASS-METHODS append_json_key_value
      IMPORTING iv_key   TYPE string
                iv_value TYPE string
      CHANGING  cv_json  TYPE string
                cv_first TYPE abap_bool.

    "! CREATED_AT trống nhưng CHANGED_AT đã có (khác kiểu utclong/timestampl) → copy.
    "! JSON cho Approve: business + ENTITY_ID + MANDT; giữ TIMESTAMPL admin, bỏ UTCLONG.
    CLASS-METHODS serialize_new_for_approval
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
                ir_record     TYPE REF TO data
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS is_admin_timestamp_field
      IMPORTING iv_fieldname TYPE fieldname
      RETURNING VALUE(rv_skip) TYPE abap_bool.

    CLASS-METHODS is_utclong_field
      IMPORTING io_sdesc     TYPE REF TO cl_abap_structdescr
                iv_fieldname TYPE fieldname
      RETURNING VALUE(rv_utclong) TYPE abap_bool.

    CLASS-METHODS append_field_to_approval_json
      IMPORTING iv_table_name TYPE tabname
                is_field      TYPE zcl_table_inspector=>ty_field_info
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
                ir_record     TYPE REF TO data
      CHANGING  cv_json       TYPE string
                cv_first      TYPE abap_bool
                ct_seen       TYPE string_table.

    CLASS-METHODS append_json_field
      IMPORTING iv_name  TYPE string
                iv_value TYPE string
                iv_quote TYPE abap_bool DEFAULT abap_true
      CHANGING  cv_json  TYPE string
                cv_first TYPE abap_bool.

    CLASS-METHODS component_to_json_value
      IMPORTING iv_table_name TYPE tabname
                iv_fieldname  TYPE fieldname
                ir_component  TYPE REF TO data
      RETURNING VALUE(rv_value) TYPE string.
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
    DATA(lt_ddic) = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).
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
    DATA(lt_ddic) = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).
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
    rt_keys = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).
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
          zcl_dyn_record_handler=>deserialize(
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

METHOD build_where_from_record_key.
    DATA(lt_keys) = zcl_excel_types=>get_where_key_fields(
      iv_table_name = iv_table_name
      it_fields     = it_fields
      iv_record_key = iv_record_key ).

    DATA lr_rec TYPE REF TO data.
    CREATE DATA lr_rec TYPE (iv_table_name).

    TRY.
        zcl_dyn_record_handler=>deserialize(
          EXPORTING iv_json   = iv_record_key
          CHANGING  ca_record = lr_rec ).
      CATCH cx_root INTO DATA(lxj).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |record_key JSON không hợp lệ: { lxj->get_text( ) }|.
    ENDTRY.

    rv_where = zcl_dyn_record_handler=>build_where_clause(
      it_key_fields  = lt_keys
      ir_record      = lr_rec
      iv_keep_spaces = abap_true ).

    IF rv_where IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'Không build được WHERE từ record_key.'.
    ENDIF.
  ENDMETHOD.
METHOD apply_cells_to_record.
    IF it_cells IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_json TYPE string.
    lv_json = '{'.
    DATA lv_first TYPE abap_bool VALUE abap_true.

    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF zcl_excel_types=>is_match_only_field(
           is_field      = ls_f
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_true.
        CONTINUE.
      ENDIF.
      IF zcl_excel_types=>is_importable_field_for_table(
           is_field      = ls_f
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.
      IF ls_cell-value IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_val) = ls_cell-value.
      IF ls_f-inttype = 'D' AND strlen( lv_val ) = 8 AND lv_val CO '0123456789'.
        lv_val = |{ lv_val(4) }-{ lv_val+4(2) }-{ lv_val+6(2) }|.
      ENDIF.

      DATA(lv_esc) = lv_val.
      REPLACE ALL OCCURRENCES OF `\` IN lv_esc WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_esc WITH `\"`.

      IF lv_first = abap_false.
        lv_json = lv_json && ','.
      ELSE.
        lv_first = abap_false.
      ENDIF.

      IF ls_f-inttype = 'I' OR ls_f-inttype = 'P'
        OR ls_f-inttype = 'F' OR ls_f-inttype = 'N'.
        lv_json = lv_json && |"{ ls_cell-fieldname }":{ lv_esc }|.
      ELSE.
        lv_json = lv_json && |"{ ls_cell-fieldname }":"{ lv_esc }"|.
      ENDIF.
    ENDLOOP.
    lv_json = lv_json && '}'.

    IF lv_json = '{}'.
      RETURN.
    ENDIF.

    TRY.
        zcl_dyn_record_handler=>deserialize(
          EXPORTING iv_json   = lv_json
          CHANGING  ca_record = cr_record ).
      CATCH cx_root INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Gán field Excel lỗi: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD build_merged_record.
    CLEAR: ev_old_json, ev_new_json.
    CREATE DATA er_record TYPE (iv_table_name).
    ASSIGN er_record->* TO FIELD-SYMBOL(<wa>).
    DATA lr_db TYPE REF TO data.

    IF iv_status = zcl_excel_types=>c_status-changed.
      DATA(lv_where) = build_where_from_record_key(
        iv_table_name = iv_table_name
        iv_record_key = iv_record_key
        it_fields     = it_fields ).

      lr_db = zcl_dyn_record_handler=>get_single_record(
        iv_table_name = iv_table_name
        iv_where      = lv_where ).

      ASSIGN lr_db->* TO FIELD-SYMBOL(<db_row>).
      TRY.
          <wa> = <db_row>.
        CATCH cx_sy_conversion_not_supported INTO DATA(lx_copy).
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text = |Copy DB row: { lx_copy->get_text( ) }|.
      ENDTRY.
      ev_old_json = zcl_dyn_record_handler=>serialize( <wa> ).
    ENDIF.

    apply_cells_to_record(
      EXPORTING iv_table_name = iv_table_name
                it_cells      = it_cells
                it_fields     = it_fields
      CHANGING  cr_record     = er_record ).

    IF iv_status = zcl_excel_types=>c_status-new.
      zcl_dyn_record_handler=>on_create(
        iv_table_name = iv_table_name
        ir_record     = er_record ).
      " Create → JSON tối thiểu; tránh admin date/timestamp initial gây lỗi deserialize lúc Approve
      ev_new_json = serialize_new_for_approval(
        iv_table_name = iv_table_name
        it_fields     = it_fields
        it_cells      = it_cells
        ir_record     = er_record ).
    ELSE.
      zcl_dyn_record_handler=>on_update(
        ir_new_record = er_record
        ir_old_record = lr_db ).
      ev_new_json = serialize_new_for_approval(
        iv_table_name = iv_table_name
        it_fields     = it_fields
        it_cells      = it_cells
        ir_record     = er_record ).
    ENDIF.
  ENDMETHOD.


  METHOD check_business_key_collision.
    DATA(lv_eid_f) = zcl_excel_types=>get_entity_id_field( iv_table_name ).
    IF lv_eid_f IS INITIAL OR ir_db_row IS NOT BOUND.
      RETURN.
    ENDIF.

    ASSIGN ir_db_row->* TO FIELD-SYMBOL(<db>).
    ASSIGN COMPONENT lv_eid_f OF STRUCTURE <db> TO FIELD-SYMBOL(<db_eid>).
    IF sy-subrc <> 0 OR <db_eid> IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_biz) = zcl_excel_types=>get_match_key_fields(
      it_fields     = it_fields
      iv_table_name = iv_table_name ).

    LOOP AT lt_biz INTO DATA(lv_bk).
      DATA(lv_new) = zcl_excel_types=>get_cell_value(
        it_cells = it_cells iv_field = CONV #( lv_bk ) ).
      IF lv_new IS INITIAL.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT lv_bk OF STRUCTURE <db> TO FIELD-SYMBOL(<db_bk>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_old) = |{ <db_bk> }|.
      CONDENSE lv_old.
      DATA(lv_new_c) = lv_new.
      CONDENSE lv_new_c.
      IF lv_old = lv_new_c.
        CONTINUE.
      ENDIF.

      REPLACE ALL OCCURRENCES OF |'| IN lv_new WITH |''|.
      DATA(lv_eid_esc) = |{ <db_eid> }|.
      REPLACE ALL OCCURRENCES OF |'| IN lv_eid_esc WITH |''|.
      DATA(lv_where) = |{ lv_bk } = '{ lv_new }' AND { lv_eid_f } <> '{ lv_eid_esc }'|.

      TRY.
          DATA(lr_hit) = zcl_dyn_record_handler=>get_table_data(
                           iv_table_name   = iv_table_name
                           iv_where_clause = lv_where
                           iv_max_rows     = 1 ).
          FIELD-SYMBOLS <tab> TYPE STANDARD TABLE.
          ASSIGN lr_hit->* TO <tab>.
          IF <tab> IS ASSIGNED AND lines( <tab> ) > 0.
            rv_error = |Field { lv_bk } giá trị '{ lv_new }' đã thuộc bản ghi khác (trùng mã nghiệp vụ)|.
            RETURN.
          ENDIF.
        CATCH cx_sy_dynamic_osql_error.
          CONTINUE.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
METHOD append_json_field.
    IF iv_quote = abap_true.
      DATA(lv_esc) = iv_value.
      REPLACE ALL OCCURRENCES OF `\` IN lv_esc WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_esc WITH `\"`.
      DATA(lv_part) = |"{ iv_name }":"{ lv_esc }"|.
    ELSE.
      lv_part = |"{ iv_name }":{ iv_value }|.
    ENDIF.
    IF cv_first = abap_true.
      cv_first = abap_false.
      cv_json = lv_part.
    ELSE.
      cv_json = cv_json && ',' && lv_part.
    ENDIF.
  ENDMETHOD.


  METHOD component_to_json_value.
    DATA(lo_elem) = CAST cl_abap_elemdescr(
      cl_abap_typedescr=>describe_by_data( ir_component->* ) ).

    CASE lo_elem->type_kind.
      WHEN cl_abap_typedescr=>typekind_hex.
        rv_value = |{ ir_component->* }|.
        CONDENSE rv_value NO-GAPS.
        TRANSLATE rv_value TO UPPER CASE.
      WHEN cl_abap_typedescr=>typekind_date.
        DATA lv_d TYPE d.
        lv_d = ir_component->*.
        IF lv_d IS INITIAL.
          CLEAR rv_value.
        ELSE.
          rv_value = |{ lv_d DATE = ISO }|.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_int
        OR cl_abap_typedescr=>typekind_int8
        OR cl_abap_typedescr=>typekind_packed
        OR cl_abap_typedescr=>typekind_float.
        rv_value = |{ ir_component->* }|.
        CONDENSE rv_value.
      WHEN OTHERS.
        rv_value = |{ ir_component->* }|.
        CONDENSE rv_value.
    ENDCASE.
  ENDMETHOD.


  METHOD is_admin_timestamp_field.
    DATA(lv_f) = iv_fieldname.
    TRANSLATE lv_f TO UPPER CASE.
    rv_skip = COND #(
      WHEN lv_f = 'CREATED_AT'
        OR lv_f = 'CHANGED_AT'
        OR lv_f = 'LAST_CHANGED_AT'
        OR lv_f = 'LOCAL_LAST_CHANGED_AT'
      THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD append_field_to_approval_json.
    READ TABLE ct_seen TRANSPORTING NO FIELDS
      WITH KEY table_line = CONV string( is_field-field_name ).
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    ASSIGN ir_record->* TO FIELD-SYMBOL(<wa>).
    DATA(lv_name) = CONV string( is_field-field_name ).
    DATA lv_json_val TYPE string.
    DATA lv_quote TYPE abap_bool VALUE abap_true.

    " JSON key phải trùng tên component DDIC — không fallback key sai (vd COMPANY_CODE vs COMPANY)
    ASSIGN COMPONENT is_field-field_name OF STRUCTURE <wa> TO FIELD-SYMBOL(<cv>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF <cv> IS NOT INITIAL.
      DATA(lr_comp) = REF #( <cv> ).
      lv_json_val = component_to_json_value(
        iv_table_name = iv_table_name
        iv_fieldname  = is_field-field_name
        ir_component  = lr_comp ).
    ENDIF.

    IF lv_json_val IS INITIAL.
      DATA(lv_cell) = zcl_excel_types=>get_cell_value(
        it_cells = it_cells iv_field = is_field-field_name ).
      IF lv_cell IS INITIAL.
        RETURN.
      ENDIF.
      lv_json_val = lv_cell.
      IF is_field-inttype = 'D' AND strlen( lv_json_val ) = 8 AND lv_json_val CO '0123456789'.
        lv_json_val = |{ lv_json_val(4) }-{ lv_json_val+4(2) }-{ lv_json_val+6(2) }|.
      ENDIF.
    ENDIF.

    IF is_field-inttype = 'I' OR is_field-inttype = 'P'
      OR is_field-inttype = 'F' OR is_field-inttype = 'N'.
      lv_quote = abap_false.
    ENDIF.

    APPEND lv_name TO ct_seen.
    append_json_field(
      EXPORTING iv_name  = lv_name
                iv_value = lv_json_val
                iv_quote = lv_quote
      CHANGING  cv_json  = cv_json
                cv_first = cv_first ).
  ENDMETHOD.


  METHOD is_utclong_field.
    DATA(lo_elem) = CAST cl_abap_elemdescr(
      io_sdesc->get_component_type( iv_fieldname ) ).
    rv_utclong = COND #(
      WHEN lo_elem->type_kind = cl_abap_typedescr=>typekind_int8
      THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD serialize_new_for_approval.
    " ZBP trên SAP không gọi apply_admin_on_insert → CREATED_AT (TIMESTAMPL) phải có trong JSON.
    " Chỉ bỏ admin timestamp kiểu UTCLONG (int8): /ui2/cl_json không round-trip → CX_SY_CONVERSION_NO_DATE_TIME.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<wa>).
    DATA lr_copy TYPE REF TO data.
    CREATE DATA lr_copy LIKE ir_record->*.
    ASSIGN lr_copy->* TO FIELD-SYMBOL(<cpy>).
    <cpy> = <wa>.

    DATA(lo_sdesc) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data( <wa> ) ).
    LOOP AT lo_sdesc->get_components( ) INTO DATA(ls_comp).
      IF is_admin_timestamp_field( CONV fieldname( ls_comp-name ) ) = abap_false.
        CONTINUE.
      ENDIF.
      IF is_utclong_field(
           io_sdesc     = lo_sdesc
           iv_fieldname = CONV fieldname( ls_comp-name ) ) = abap_false.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE <cpy> TO FIELD-SYMBOL(<ts>).
      IF sy-subrc = 0.
        CLEAR <ts>.
      ENDIF.
    ENDLOOP.

    rv_json = zcl_dyn_record_handler=>serialize( <cpy> ).
  ENDMETHOD.


  METHOD validate_approval_json.
    IF iv_new_json IS INITIAL OR iv_new_json = '{}'.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'new_data approval rỗng — không gửi duyệt được.'.
    ENDIF.

    DATA lr_test TYPE REF TO data.
    CREATE DATA lr_test TYPE (iv_table_name).
    TRY.
        zcl_dyn_record_handler=>deserialize(
          EXPORTING iv_json   = iv_new_json
          CHANGING  ca_record = lr_test ).
      CATCH cx_root INTO DATA(lx_des).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |new_data không deserialize được (Approve sẽ fail): { lx_des->get_text( ) }|.
    ENDTRY.

    ASSIGN lr_test->* TO FIELD-SYMBOL(<chk>).
    DATA(lv_has_biz) = abap_false.
    DATA(lv_eid_f) = zcl_excel_types=>get_entity_id_field( iv_table_name ).
    DATA(lo_sdesc) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data( <chk> ) ).

    LOOP AT lo_sdesc->get_components( ) INTO DATA(ls_comp).
      IF ls_comp-name = 'MANDT' OR ls_comp-name = 'CLIENT'.
        CONTINUE.
      ENDIF.
      IF ls_comp-name = lv_eid_f.
        CONTINUE.
      ENDIF.
      IF is_admin_timestamp_field( CONV fieldname( ls_comp-name ) ) = abap_true.
        CONTINUE.
      ENDIF.
      IF zcl_excel_types=>is_admin_field( CONV fieldname( ls_comp-name ) ) = abap_true.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE <chk> TO FIELD-SYMBOL(<v>).
      IF sy-subrc = 0 AND <v> IS NOT INITIAL.
        lv_has_biz = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_has_biz = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text =
          |new_data có JSON nhưng không map field nghiệp vụ vào { iv_table_name }. | &&
          |Kiểm tra ZFLD_CONFIG: tên field phải trùng DDIC (vd COMPANY, không phải COMPANY_CODE).|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

