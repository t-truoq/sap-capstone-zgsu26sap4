CLASS zcl_excel_pipeline DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_cell,
             fieldname TYPE fieldname,
             value     TYPE string,
           END OF ty_cell,
           tt_cell TYPE STANDARD TABLE OF ty_cell WITH KEY fieldname.

    TYPES: BEGIN OF ty_parsed_row,
             row_no TYPE i,
             cells  TYPE tt_cell,
           END OF ty_parsed_row,
           tt_parsed_row TYPE STANDARD TABLE OF ty_parsed_row WITH KEY row_no.

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

    TYPES: BEGIN OF ty_summary,
             inserted_count  TYPE i,
             updated_count   TYPE i,
             unchanged_count TYPE i,
             skipped_count   TYPE i,
             error_count     TYPE i,
             messages        TYPE string_table,
           END OF ty_summary.

    CONSTANTS: BEGIN OF c_status,
                 new       TYPE c LENGTH 10 VALUE 'NEW',
                 changed   TYPE c LENGTH 10 VALUE 'CHANGED',
                 delete    TYPE c LENGTH 10 VALUE 'DELETE',
                 unchanged TYPE c LENGTH 10 VALUE 'UNCHANGED',
                 skipped   TYPE c LENGTH 10 VALUE 'SKIPPED',
                 error     TYPE c LENGTH 10 VALUE 'ERROR',
               END OF c_status.

    CONSTANTS: BEGIN OF c_action,
                 create TYPE ztde_action_type VALUE 'C',
                 update TYPE ztde_action_type VALUE 'U',
                 delete TYPE ztde_action_type VALUE 'D',
               END OF c_action.

    CONSTANTS c_skip_client TYPE abap_bool VALUE abap_false.

    TYPES:
      BEGIN OF ty_item,
        item_no     TYPE n LENGTH 6,
        table_name  TYPE ztde_table_name,
        record_key  TYPE ztde_record_key,
        action_type TYPE ztde_action_type,
        new_data    TYPE string,
        old_data    TYPE string,
      END OF ty_item,
      tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_submit_result,
        success    TYPE abap_bool,
        aprvl_id   TYPE sysuuid_c32,
        item_count TYPE i,
        message    TYPE string,
      END OF ty_submit_result.

    TYPES:
      BEGIN OF ty_apply_result,
        success TYPE abap_bool,
        message TYPE string,
      END OF ty_apply_result.

    TYPES:
      ty_download_req TYPE zdt_excel_download_req,
      ty_download_res TYPE zdt_excel_download_res,
      ty_upload_req   TYPE zdt_excel_upload_req,
      ty_diff_cds     TYPE zdt_excel_diff_row,
      tt_diff_cds     TYPE STANDARD TABLE OF ty_diff_cds WITH EMPTY KEY,
      ty_commit_req   TYPE zdt_excel_commit_req,
      ty_commit_res   TYPE zdt_excel_commit_res.

    CLASS-METHODS is_admin_field
      IMPORTING iv_fieldname    TYPE clike
      RETURNING VALUE(rv_admin) TYPE abap_bool.

    CLASS-METHODS is_importable_field
      IMPORTING iv_fieldname         TYPE clike
                iv_is_key            TYPE abap_bool DEFAULT abap_false
                iv_readonly          TYPE abap_bool DEFAULT abap_false
                iv_hidden            TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_importable) TYPE abap_bool.

    CLASS-METHODS is_importable_field_info
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
      RETURNING VALUE(rv_importable) TYPE abap_bool.

    CLASS-METHODS is_importable_field_for_table
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
                iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_importable) TYPE abap_bool.

    CLASS-METHODS get_match_key_fields
      IMPORTING it_fields            TYPE zcl_table_inspector=>tt_field_info
                iv_table_name        TYPE tabname
      RETURNING VALUE(rt_keys)       TYPE string_table.

    CLASS-METHODS get_ddic_key_fields
      IMPORTING iv_table_name  TYPE tabname
      RETURNING VALUE(rt_keys) TYPE string_table.

    CLASS-METHODS get_entity_id_field
      IMPORTING iv_table_name   TYPE tabname
      RETURNING VALUE(rv_field) TYPE fieldname.

    CLASS-METHODS is_match_only_field
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
                iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_match_only) TYPE abap_bool.

    CLASS-METHODS is_parseable_column
      IMPORTING is_field             TYPE zcl_table_inspector=>ty_field_info
                iv_table_name        TYPE tabname
                it_fields            TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_parseable)  TYPE abap_bool.

    CLASS-METHODS get_cell_value
      IMPORTING it_cells        TYPE tt_cell
                iv_field        TYPE fieldname
      RETURNING VALUE(rv_value) TYPE string.

    CLASS-METHODS build_record_key_json
      IMPORTING iv_table_name  TYPE tabname
                it_fields      TYPE zcl_table_inspector=>tt_field_info
                ir_row         TYPE REF TO data OPTIONAL
                it_cells       TYPE tt_cell OPTIONAL
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS get_where_key_fields
      IMPORTING iv_table_name  TYPE tabname
                it_fields      TYPE zcl_table_inspector=>tt_field_info
                iv_record_key  TYPE string
      RETURNING VALUE(rt_keys) TYPE string_table
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_where_from_cells
      IMPORTING iv_table_name   TYPE tabname
                it_fields       TYPE zcl_table_inspector=>tt_field_info
                it_cells        TYPE tt_cell
      RETURNING VALUE(rv_where) TYPE string.

    CLASS-METHODS is_diff_comparable_field
      IMPORTING is_field      TYPE zcl_table_inspector=>ty_field_info
                iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_ok)  TYPE abap_bool.

    CLASS-METHODS build_where_from_record_key
      IMPORTING iv_table_name   TYPE tabname
                iv_record_key   TYPE string
                it_fields       TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_where) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS apply_cells_to_record
      IMPORTING iv_table_name TYPE tabname
                it_cells      TYPE tt_cell
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      CHANGING  cr_record     TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_merged_record
      IMPORTING iv_table_name TYPE tabname
                it_cells      TYPE tt_cell
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                iv_status     TYPE c
                iv_record_key TYPE string
      EXPORTING ev_old_json   TYPE string
                ev_new_json   TYPE string
                er_record     TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS validate_approval_json
      IMPORTING iv_table_name TYPE tabname
                iv_new_json   TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS submit_bulk
      IMPORTING iv_table_name    TYPE ztde_table_name
                it_items         TYPE tt_item
      RETURNING VALUE(rs_result) TYPE ty_submit_result.

  CLASS-METHODS approve_bulk
  IMPORTING iv_aprvl_id      TYPE sysuuid_c32
            iv_remarks       TYPE string OPTIONAL
  RETURNING VALUE(rs_result) TYPE ty_apply_result.

    CLASS-METHODS reject_bulk
      IMPORTING iv_aprvl_id      TYPE sysuuid_c32
                iv_remarks       TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_apply_result.

    CLASS-METHODS build_diff
      IMPORTING iv_table_name  TYPE tabname
                it_rows        TYPE tt_parsed_row
      RETURNING VALUE(rt_diff) TYPE tt_diff_row
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS apply_diff_import
      IMPORTING iv_table_name     TYPE tabname
                it_diff           TYPE tt_diff_row
                iv_do_commit      TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rs_summary) TYPE ty_summary
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS parse_excel
      IMPORTING iv_table_name TYPE tabname
                iv_file       TYPE xstring
      EXPORTING et_rows       TYPE tt_parsed_row
                et_messages   TYPE string_table
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS export_table
      IMPORTING iv_table_name          TYPE tabname
      RETURNING VALUE(rv_file_xstring) TYPE xstring
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS export_template
      IMPORTING iv_table_name          TYPE tabname
      RETURNING VALUE(rv_file_xstring) TYPE xstring
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS save_to_local
      IMPORTING iv_xstring  TYPE xstring
                iv_filepath TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS download_excel
      IMPORTING is_req        TYPE ty_download_req
      RETURNING VALUE(rs_res) TYPE ty_download_res
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS upload_excel
      IMPORTING is_req  TYPE ty_upload_req
      EXPORTING et_diff TYPE tt_diff_cds
                ev_info TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS run_confirm_import
      IMPORTING is_req       TYPE ty_commit_req
                it_diff_cds  TYPE tt_diff_cds
      RETURNING VALUE(rs_res) TYPE ty_commit_res
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS parse_diff_json
      IMPORTING iv_json       TYPE string
      RETURNING VALUE(rt_cds) TYPE tt_diff_cds
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS download_excel_base64
      IMPORTING iv_table_name         TYPE tabname
                iv_template_only      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_file_base64) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS preview_import_base64
      IMPORTING iv_table_name  TYPE tabname
                iv_file_base64 TYPE string
      EXPORTING et_rows        TYPE tt_parsed_row
                et_diff        TYPE tt_diff_row
                et_messages    TYPE string_table
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS confirm_import
      IMPORTING iv_table_name     TYPE tabname
                it_diff           TYPE tt_diff_row
      RETURNING VALUE(rs_summary) TYPE ty_summary
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.
    CONSTANTS:
      c_status_pending  TYPE string VALUE 'PENDING' ,
      c_status_approved TYPE string VALUE 'APPROVED' ,
      c_status_rejected TYPE string VALUE 'REJECTED' ,
      c_record_key_bulk TYPE string VALUE 'BULK' .

    CONSTANTS c_action_field   TYPE string   VALUE '__ACTION' .
    CONSTANTS c_snapshot_field TYPE fieldname VALUE '__SNAPSHOT' .

    TYPES: BEGIN OF ty_group,
             row_no     TYPE i,
             record_key TYPE string,
             status     TYPE c LENGTH 10,
             cells      TYPE tt_cell,
           END OF ty_group,
           tt_group TYPE HASHED TABLE OF ty_group WITH UNIQUE KEY row_no record_key status.

    TYPES: BEGIN OF ty_colmap,
             column    TYPE i,
             fieldname TYPE fieldname,
           END OF ty_colmap,
           tt_colmap TYPE STANDARD TABLE OF ty_colmap WITH KEY column.

    TYPES tt_colnum TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    TYPES: BEGIN OF ty_export_col,
             col_index      TYPE i,
             field_name     TYPE fieldname,
             domain_name    TYPE dd03l-domname,
             is_foreign_key TYPE abap_bool,
             is_lov_field   TYPE abap_bool,
           END OF ty_export_col,
           tt_export_col TYPE STANDARD TABLE OF ty_export_col WITH EMPTY KEY.

    TYPES: BEGIN OF ty_lov_range,
             data_col TYPE i,
             lov_col  TYPE i,
             last_row TYPE i,
           END OF ty_lov_range,
           tt_lov_range TYPE STANDARD TABLE OF ty_lov_range WITH EMPTY KEY.

    CLASS-METHODS apply_single_item
      IMPORTING is_item            TYPE ztbl_aprvl_item
                iv_parent_audit_id TYPE sysuuid_c32
      RAISING   cx_root.

    CLASS-METHODS validate_row
      IMPORTING iv_table_name    TYPE tabname
                it_fields        TYPE zcl_table_inspector=>tt_field_info
                it_cells         TYPE tt_cell
      RETURNING VALUE(rt_errors) TYPE string_table.

    CLASS-METHODS build_file_key
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE tt_cell
      RETURNING VALUE(rv_key) TYPE string.

    CLASS-METHODS get_key_problem
      IMPORTING iv_table_name      TYPE tabname
                iv_entity_id_field TYPE fieldname
                it_biz_keys        TYPE string_table
                it_cells           TYPE tt_cell
      RETURNING VALUE(rv_message)  TYPE string.

    CLASS-METHODS is_fk_key_field
      IMPORTING iv_table_name   TYPE tabname
                iv_field_name   TYPE fieldname
      RETURNING VALUE(rv_is_fk) TYPE abap_bool.

    CLASS-METHODS is_valid_uuid_hex
      IMPORTING iv_value           TYPE string
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    CLASS-METHODS append_new_diff
      IMPORTING iv_row_no     TYPE i
                iv_table_name TYPE tabname
                iv_record_key TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE tt_cell
      CHANGING  ct_diff       TYPE tt_diff_row.

    CLASS-METHODS append_compare_diff
      IMPORTING iv_row_no        TYPE i
                iv_table_name    TYPE tabname
                iv_record_key    TYPE string
                it_fields        TYPE zcl_table_inspector=>tt_field_info
                it_cells         TYPE tt_cell
                ir_db_row        TYPE REF TO data
      CHANGING  ct_diff          TYPE tt_diff_row
      RETURNING VALUE(rv_changed) TYPE abap_bool.

    CLASS-METHODS submit_groups
      IMPORTING iv_table_name TYPE tabname
                it_groups     TYPE tt_group
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      CHANGING  cs_summary    TYPE ty_summary
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS mark_preview_conflicts
      IMPORTING iv_table_name TYPE tabname
      CHANGING  ct_diff       TYPE tt_diff_row.

    CLASS-METHODS mark_permission_skips
      IMPORTING iv_table_name TYPE tabname
      CHANGING  ct_diff       TYPE tt_diff_row.

    CLASS-METHODS get_permission_action
      IMPORTING iv_status        TYPE char10
      RETURNING VALUE(rv_action) TYPE char20.

    CLASS-METHODS assert_no_pending_conflict
      IMPORTING iv_table_name TYPE ztde_table_name
                iv_record_key TYPE ztde_record_key
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS get_current_snapshot
      IMPORTING iv_table_name      TYPE tabname
                iv_record_key      TYPE ztde_record_key
      RETURNING VALUE(rv_snapshot) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS assert_current_state
      IMPORTING iv_table_name  TYPE tabname
                iv_action_type TYPE ztde_action_type
                iv_record_key  TYPE ztde_record_key
                iv_old_data    TYPE string OPTIONAL
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS uses_entity_id_where
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                iv_record_key TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS append_admin_on_update
      IMPORTING iv_table_name TYPE tabname
      CHANGING  cv_set        TYPE string.

    CLASS-METHODS map_columns
      IMPORTING io_worksheet   TYPE REF TO zcl_excel_worksheet
                iv_max_col     TYPE i
                iv_table_name  TYPE tabname
                it_fields      TYPE zcl_table_inspector=>tt_field_info
      EXPORTING et_colmap      TYPE tt_colmap
                et_header_cols TYPE tt_colnum
                et_messages    TYPE string_table.

    CLASS-METHODS normalize
      IMPORTING iv_text        TYPE clike
      RETURNING VALUE(rv_norm) TYPE string.

    CLASS-METHODS validate_table_name
      IMPORTING iv_table_name TYPE tabname
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS get_field_metadata
      IMPORTING iv_table_name    TYPE tabname
      RETURNING VALUE(rt_fields) TYPE zcl_table_inspector=>tt_field_info
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS read_table_data
      IMPORTING iv_table_name  TYPE tabname
      RETURNING VALUE(rr_data) TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_excel
      IMPORTING it_fields          TYPE zcl_table_inspector=>tt_field_info
                iv_table_name      TYPE tabname
                ir_data            TYPE REF TO data OPTIONAL
                iv_importable_only TYPE abap_bool DEFAULT abap_false
                iv_tech_header     TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_xstring)  TYPE xstring
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS is_exportable_col
      IMPORTING is_field           TYPE zcl_table_inspector=>ty_field_info
                it_fields          TYPE zcl_table_inspector=>tt_field_info
                iv_table_name      TYPE tabname
                iv_importable_only TYPE abap_bool
      RETURNING VALUE(rv_ok)       TYPE abap_bool.

    CLASS-METHODS is_field_importable
      IMPORTING is_field              TYPE zcl_table_inspector=>ty_field_info
                it_fields             TYPE zcl_table_inspector=>tt_field_info
                iv_table_name         TYPE tabname
      RETURNING VALUE(rv_importable)  TYPE abap_bool.

    CLASS-METHODS apply_domain_validations
      IMPORTING io_data_ws     TYPE REF TO zcl_excel_worksheet
                io_lov_ws      TYPE REF TO zcl_excel_worksheet
                iv_table_name  TYPE tabname
                it_lov_ranges  TYPE tt_lov_range
                it_export_cols TYPE tt_export_col
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_domain_lov_sheet
      IMPORTING iv_table_name    TYPE tabname
                it_export_cols   TYPE tt_export_col
                io_lov_ws        TYPE REF TO zcl_excel_worksheet
      RETURNING VALUE(rt_ranges) TYPE tt_lov_range.

    CLASS-METHODS is_foreign_key_field
      IMPORTING iv_table_name   TYPE tabname
                iv_field_name   TYPE fieldname
      RETURNING VALUE(rv_is_fk) TYPE abap_bool.

    CLASS-METHODS get_lov_values
      IMPORTING iv_table_name    TYPE tabname
                is_export_col    TYPE ty_export_col
      RETURNING VALUE(rt_values) TYPE string_table.

    CLASS-METHODS diff_from_internal
      IMPORTING it_diff        TYPE tt_diff_row
      RETURNING VALUE(rt_cds)  TYPE tt_diff_cds.

    CLASS-METHODS diff_to_internal
      IMPORTING it_cds         TYPE tt_diff_cds
      RETURNING VALUE(rt_diff) TYPE tt_diff_row.

    CLASS-METHODS new_diff_id
      RETURNING VALUE(rv_id) TYPE sysuuid_x16.

    CLASS-METHODS is_config_flag
      IMPORTING iv_flag        TYPE ztde_yesno
      RETURNING VALUE(rv_on)   TYPE abap_bool.

    CLASS-METHODS append_json_key_value
      IMPORTING iv_key   TYPE string
                iv_value TYPE string
      CHANGING  cv_json  TYPE string
                cv_first TYPE abap_bool.

    CLASS-METHODS serialize_new_for_approval
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE tt_cell
                ir_record     TYPE REF TO data
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS is_admin_timestamp_field
      IMPORTING iv_fieldname   TYPE fieldname
      RETURNING VALUE(rv_skip) TYPE abap_bool.

    CLASS-METHODS is_utclong_field
      IMPORTING io_sdesc         TYPE REF TO cl_abap_structdescr
                iv_fieldname     TYPE fieldname
      RETURNING VALUE(rv_utclong) TYPE abap_bool.

    CLASS-METHODS append_field_to_approval_json
      IMPORTING iv_table_name TYPE tabname
                is_field      TYPE zcl_table_inspector=>ty_field_info
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE tt_cell
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
      IMPORTING iv_table_name   TYPE tabname
                iv_fieldname    TYPE fieldname
                ir_component    TYPE REF TO data
      RETURNING VALUE(rv_value) TYPE string.

ENDCLASS.

CLASS zcl_excel_pipeline IMPLEMENTATION.

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
    IF is_admin_field( iv_fieldname ) = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    IF iv_hidden = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    IF iv_readonly = abap_true.
      rv_importable = abap_false.
      RETURN.
    ENDIF.

    IF iv_is_key = abap_true.
      rv_importable = abap_true.
      RETURN.
    ENDIF.

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

    DATA(lv_eid_f) = get_entity_id_field( iv_table_name ).

    LOOP AT it_fields INTO DATA(ls_field).
      IF is_config_flag( ls_field-is_key_field ) = abap_false.
        CONTINUE.
      ENDIF.
      IF lv_eid_f IS NOT INITIAL AND ls_field-field_name = lv_eid_f.
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

    RETURN.
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

      READ TABLE it_cells TRANSPORTING NO FIELDS
        WITH KEY fieldname = lv_eid_f.
      IF sy-subrc = 0.
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
    DATA(lt_keys) = get_where_key_fields(
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
      IF is_match_only_field(
           is_field      = ls_f
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_true.
        CONTINUE.
      ENDIF.
      IF is_importable_field_for_table(
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

    IF iv_status = c_status-new
       AND iv_record_key IS NOT INITIAL.
      TRY.
          zcl_dyn_record_handler=>deserialize(
            EXPORTING iv_json   = iv_record_key
            CHANGING  ca_record = er_record ).
        CATCH cx_root INTO DATA(lx_new_key).
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text = |Invalid generated record key: { lx_new_key->get_text( ) }|.
      ENDTRY.
    ENDIF.

    IF iv_status = c_status-changed.
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

    IF iv_status = c_status-new.
      zcl_dyn_record_handler=>on_create(
        iv_table_name = iv_table_name
        ir_record     = er_record ).
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
      DATA(lv_cell) = get_cell_value(
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
    CLEAR rv_json.
    DATA lv_first TYPE abap_bool VALUE abap_true.
    DATA lt_seen TYPE string_table.
    DATA(lv_eid_f) = get_entity_id_field( iv_table_name ).

    LOOP AT it_fields INTO DATA(ls_field).
      IF is_admin_field( ls_field-field_name ) = abap_true
         AND ls_field-field_name <> lv_eid_f.
        CONTINUE.
      ENDIF.

      append_field_to_approval_json(
        EXPORTING iv_table_name = iv_table_name
                  is_field      = ls_field
                  it_fields     = it_fields
                  it_cells      = it_cells
                  ir_record     = ir_record
        CHANGING  cv_json       = rv_json
                  cv_first      = lv_first
                  ct_seen       = lt_seen ).
    ENDLOOP.

    rv_json = '{' && rv_json && '}'.
    RETURN.
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
    DATA(lv_eid_f) = get_entity_id_field( iv_table_name ).
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
      IF is_admin_field( CONV fieldname( ls_comp-name ) ) = abap_true.
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

  METHOD submit_bulk.
    IF it_items IS INITIAL.
      DATA(lv_msg_empty) = 'No records to submit for approval.' .
      rs_result = VALUE #( success = abap_false message = lv_msg_empty ).
      RETURN.
    ENDIF.

    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_valid_items TYPE tt_item.
    DATA(lv_skipped_count) = 0.
    DATA(lv_skip_message) = VALUE string( ).

    LOOP AT it_items INTO DATA(ls_check_item).
      DATA(lv_lock_key) = |{ ls_check_item-table_name }#{ ls_check_item-record_key }|.
      INSERT lv_lock_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        lv_skipped_count = lv_skipped_count + 1.
        DATA(lv_dup_msg) = |{ lv_skip_message } Skipped item { ls_check_item-item_no }: duplicate record { ls_check_item-record_key }.| .
        lv_skip_message = lv_dup_msg.
        CONTINUE.
      ENDIF.

      TRY.
          zcl_aprvl_util=>assert_no_conflicting_pending(
            iv_table_name = ls_check_item-table_name
            iv_record_key = ls_check_item-record_key ).
          APPEND ls_check_item TO lt_valid_items.
        CATCH zcx_excel_pipeline INTO DATA(lx_pending).
          lv_skipped_count = lv_skipped_count + 1.
          DATA(lv_pending_msg) = |{ lv_skip_message } Skipped item { ls_check_item-item_no }: { lx_pending->get_text( ) }| .
          lv_skip_message = lv_pending_msg.
      ENDTRY.
    ENDLOOP.

    IF lt_valid_items IS INITIAL.
      rs_result = VALUE #( success = abap_false message = lv_skip_message ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_aprvl_id) = cl_system_uuid=>create_uuid_c32_static( ).
        DATA(lv_now) = utclong_current( ).
        READ TABLE lt_valid_items INTO DATA(ls_first_item) INDEX 1.

        DATA(lv_new_data_hdr) = |Bulk approval: { lines( lt_valid_items ) } item(s)| .

        INSERT ztbl_aprvl FROM @(
          VALUE ztbl_aprvl(
            aprvl_id     = lv_aprvl_id
            table_name   = iv_table_name
            record_key   = c_record_key_bulk
            action_type  = ls_first_item-action_type
            status       = c_status_pending
            new_data     = lv_new_data_hdr
            old_data     = ''
            submitted_by = sy-uname
            submitted_at = lv_now ) ).

        DATA lt_db_items TYPE STANDARD TABLE OF ztbl_aprvl_item.
        LOOP AT lt_valid_items INTO DATA(ls_item).
          DATA(lv_item_msg) = |Item { ls_item-item_no } submitted| .
          APPEND VALUE ztbl_aprvl_item(
            aprvl_id    = lv_aprvl_id
            item_no     = ls_item-item_no
            table_name  = ls_item-table_name
            record_key  = ls_item-record_key
            action_type = ls_item-action_type
            status      = c_status_pending
            new_data    = ls_item-new_data
            old_data    = ls_item-old_data
            message     = lv_item_msg ) TO lt_db_items.
        ENDLOOP.

        INSERT ztbl_aprvl_item FROM TABLE @lt_db_items.

        DATA(lv_submit_msg) = |Bulk request submitted for approval (ID: { lv_aprvl_id }, items: { lines( lt_db_items ) })| .

        rs_result = VALUE #(
          success    = abap_true
          aprvl_id   = lv_aprvl_id
          item_count = lines( lt_db_items )
          message    = lv_submit_msg ).

        IF lv_skipped_count > 0.
          DATA(lv_skip_suffix) = |{ rs_result-message } { lv_skipped_count } item(s) skipped.{ lv_skip_message }| .
          rs_result-message = lv_skip_suffix.
        ENDIF.

      CATCH cx_root INTO DATA(lx).
        rs_result = VALUE #( success = abap_false message = lx->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

 METHOD approve_bulk.
    SELECT SINGLE * FROM ztbl_aprvl
      WHERE aprvl_id = @iv_aprvl_id
      INTO @DATA(ls_parent).

    IF sy-subrc <> 0.
      DATA(lv_notfound_msg) = |Bulk approval request { iv_aprvl_id } not found.|.
      rs_result = VALUE #( success = abap_false message = lv_notfound_msg ).
      RETURN.
    ENDIF.

    IF ls_parent-status <> c_status_pending.
      DATA(lv_notpending_msg) = |Request { iv_aprvl_id } is not in PENDING status.|.
      rs_result = VALUE #( success = abap_false message = lv_notpending_msg ).
      RETURN.
    ENDIF.

    SELECT * FROM ztbl_aprvl_item
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = @c_status_pending
      ORDER BY item_no ASCENDING
      INTO TABLE @DATA(lt_items).

    IF lt_items IS INITIAL.
      DATA(lv_noitem_msg) = |Request { iv_aprvl_id } has no pending item.|.
      rs_result = VALUE #( success = abap_false message = lv_noitem_msg ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_parent_audit_id) = cl_system_uuid=>create_uuid_c32_static( ).
        LOOP AT lt_items INTO DATA(ls_item).
          apply_single_item(
            is_item            = ls_item
            iv_parent_audit_id = lv_parent_audit_id ).
        ENDLOOP.

        DATA(lv_now) = utclong_current( ).
        DATA(lv_applied_msg) = 'Applied successfully'.

        UPDATE ztbl_aprvl_item
          SET status  = @c_status_approved,
              message = @lv_applied_msg
          WHERE aprvl_id = @iv_aprvl_id
            AND status   = @c_status_pending.

        UPDATE ztbl_aprvl
          SET status        = @c_status_approved,
              approved_by   = @sy-uname,
              approved_at   = @lv_now,
              aprvl_comment = @iv_remarks
          WHERE aprvl_id = @iv_aprvl_id.

        DATA(lv_ok_msg) = |Bulk request approved and applied successfully ({ lines( lt_items ) } item(s)).|.

        rs_result = VALUE #(
          success = abap_true
          message = lv_ok_msg ).

      CATCH cx_root INTO DATA(lx).
        DATA(lv_error_text) = lx->get_text( ).
        UPDATE ztbl_aprvl_item
          SET status  = @c_status_pending,
              message = @lv_error_text
          WHERE aprvl_id = @iv_aprvl_id
            AND status   = @c_status_pending.

        DATA(lv_fail_msg) = |Bulk request failed. Nothing was marked approved: { lv_error_text }|.

        rs_result = VALUE #(
          success = abap_false
          message = lv_fail_msg ).
    ENDTRY.
ENDMETHOD.
  METHOD reject_bulk.
    DATA(lv_now) = utclong_current( ).
    DATA(lv_default_remark) = 'Rejected by admin' .
    DATA(lv_remarks) = COND string(
      WHEN iv_remarks IS NOT INITIAL THEN iv_remarks ELSE lv_default_remark ).

    UPDATE ztbl_aprvl
      SET status        = @c_status_rejected,
          approved_by   = @sy-uname,
          approved_at   = @lv_now,
          aprvl_comment = @lv_remarks
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = @c_status_pending.

    IF sy-subrc <> 0.
      DATA(lv_rejectfail_msg) = |Reject failed for request { iv_aprvl_id }.| .
      rs_result = VALUE #( success = abap_false message = lv_rejectfail_msg ).
      RETURN.
    ENDIF.

    UPDATE ztbl_aprvl_item
      SET status  = @c_status_rejected,
          message = @lv_remarks
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = @c_status_pending.

    DATA(lv_rejected_msg) = |Bulk request rejected: { lv_remarks }| .
    rs_result = VALUE #( success = abap_true message = lv_rejected_msg ).
  ENDMETHOD.

  METHOD apply_single_item.
    DATA ls_result TYPE zcl_dyn_record_handler=>ty_result.

    CASE is_item-action_type.
      WHEN c_action-create.
        ls_result = zcl_dyn_record_handler=>create_record(
          iv_table_name  = is_item-table_name
          iv_record_data = is_item-new_data
          iv_parent_audit_id = iv_parent_audit_id ).

      WHEN c_action-update.
        ls_result = zcl_dyn_record_handler=>update_record(
          iv_table_name  = is_item-table_name
          iv_record_data = is_item-new_data
          iv_parent_audit_id = iv_parent_audit_id ).

      WHEN c_action-delete.
        ls_result = zcl_dyn_record_handler=>delete_record(
          iv_table_name = is_item-table_name
          iv_record_key = is_item-record_key
          iv_parent_audit_id = iv_parent_audit_id ).

      WHEN OTHERS.
        DATA(lv_unsupported_msg) = |Unsupported bulk item action { is_item-action_type }.| .
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = lv_unsupported_msg.
    ENDCASE.

    IF ls_result-success <> abap_true.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = ls_result-message.
    ENDIF.
  ENDMETHOD.

  METHOD build_diff.
    CLEAR rt_diff.

    FIELD-SYMBOLS <db_row> TYPE any.
    FIELD-SYMBOLS <db_val> TYPE any.

    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    IF lt_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } is not configured in ZFLD_CONFIG. Configure fields before Excel import.|.
    ENDIF.

    DATA lt_biz_keys TYPE string_table.
    lt_biz_keys = get_match_key_fields(
                    it_fields     = lt_fields
                    iv_table_name = iv_table_name ).
    DATA(lv_eid_f) = get_entity_id_field( iv_table_name ).

    IF lt_biz_keys IS INITIAL AND lv_eid_f IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } has no importable key field for Excel diff. | &&
                            |Set IS_KEY_FIELD = X for the business key in ZFLD_CONFIG.|.
    ENDIF.

    TYPES: BEGIN OF ty_kc,
             rkey TYPE string,
             cnt  TYPE i,
           END OF ty_kc.
    DATA lt_kc TYPE HASHED TABLE OF ty_kc WITH UNIQUE KEY rkey.

    LOOP AT it_rows INTO DATA(ls_pre).
      DATA(lv_prekey) = build_file_key(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_pre-cells ).

      DATA(lv_skip_pre_dupcheck) = abap_false.
      IF lv_eid_f IS NOT INITIAL
         AND is_fk_key_field(
               iv_table_name = iv_table_name
               iv_field_name = lv_eid_f ) = abap_false.
        READ TABLE ls_pre-cells INTO DATA(ls_pre_eid)
          WITH KEY fieldname = lv_eid_f.
        IF sy-subrc = 0 AND ls_pre_eid-value IS INITIAL.
          lv_skip_pre_dupcheck = abap_true.
        ENDIF.
      ENDIF.

      IF get_key_problem(
           iv_table_name      = iv_table_name
           iv_entity_id_field = lv_eid_f
           it_biz_keys        = lt_biz_keys
           it_cells           = ls_pre-cells ) IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      IF lv_skip_pre_dupcheck = abap_true.
        CONTINUE.
      ENDIF.

      READ TABLE lt_kc ASSIGNING FIELD-SYMBOL(<kc>) WITH KEY rkey = lv_prekey.
      IF sy-subrc = 0.
        <kc>-cnt = <kc>-cnt + 1.
      ELSE.
        INSERT VALUE #( rkey = lv_prekey cnt = 1 ) INTO TABLE lt_kc.
      ENDIF.
    ENDLOOP.

    LOOP AT it_rows INTO DATA(ls_row).

      DATA(lv_dupkey) = build_file_key(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).
      DATA(lv_skip_dupcheck) = abap_false.

      DATA(lv_generated_eid) = abap_false.
      IF lv_eid_f IS NOT INITIAL
         AND is_fk_key_field(
               iv_table_name = iv_table_name
               iv_field_name = lv_eid_f ) = abap_false.
        READ TABLE ls_row-cells ASSIGNING FIELD-SYMBOL(<eid_cell>)
          WITH KEY fieldname = lv_eid_f.
        IF sy-subrc = 0 AND <eid_cell>-value IS INITIAL.
          lv_skip_dupcheck = abap_true.
          TRY.
              <eid_cell>-value = cl_system_uuid=>create_uuid_c32_static( ).
              lv_generated_eid = abap_true.
            CATCH cx_uuid_error.
          ENDTRY.
        ENDIF.
      ENDIF.

      DATA(lv_fkey) = build_file_key(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).

      DATA(lv_key_problem) = get_key_problem(
        iv_table_name      = iv_table_name
        iv_entity_id_field = lv_eid_f
        it_biz_keys        = lt_biz_keys
        it_cells           = ls_row-cells ).

      IF lv_key_problem IS NOT INITIAL.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_fkey
                        status     = c_status-error
                        message    = lv_key_problem ) TO rt_diff.
        CONTINUE.
      ENDIF.

      READ TABLE lt_kc INTO DATA(ls_kc) WITH KEY rkey = lv_dupkey.
      IF lv_skip_dupcheck = abap_false AND sy-subrc = 0 AND ls_kc-cnt > 1.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_fkey
                        status     = c_status-error
                        message    = |Duplicate key in uploaded file ({ ls_kc-cnt } rows with the same key). Fix duplicate key { lv_fkey } before import.| ) TO rt_diff.
        CONTINUE.
      ENDIF.

      DATA(lv_requested_action) = get_cell_value(
        it_cells = ls_row-cells
       iv_field = CONV fieldname( c_action_field ) ).
      CONDENSE lv_requested_action.
      TRANSLATE lv_requested_action TO UPPER CASE.

      IF lv_requested_action IS NOT INITIAL
         AND lv_requested_action <> 'C'
         AND lv_requested_action <> 'CREATE'
         AND lv_requested_action <> 'U'
         AND lv_requested_action <> 'UPDATE'
         AND lv_requested_action <> 'D'
         AND lv_requested_action <> 'DELETE'.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_fkey
                        status     = c_status-error
                        message    = |Invalid __ACTION '{ lv_requested_action }'. Allowed values: C, CREATE, U, UPDATE, D, DELETE.| ) TO rt_diff.
        CONTINUE.
      ENDIF.

      IF lv_requested_action = 'D' OR lv_requested_action = 'DELETE'.
        DATA(lv_del_where) = build_where_from_cells(
          iv_table_name = iv_table_name
          it_fields     = lt_fields
          it_cells      = ls_row-cells ).

        IF lv_del_where IS INITIAL.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = c_status-error
                          message    = |Cannot identify record to delete for table { iv_table_name }. Check key columns.| ) TO rt_diff.
          CONTINUE.
        ENDIF.

        TRY.
            DATA(lr_del_db) = zcl_dyn_record_handler=>get_single_record(
              iv_table_name = iv_table_name
              iv_where      = lv_del_where ).

            DATA(lv_del_key) = build_record_key_json(
              iv_table_name = iv_table_name
              it_fields     = lt_fields
              ir_row        = lr_del_db ).

            ASSIGN lr_del_db->* TO FIELD-SYMBOL(<del_db_row>).
            DATA(lv_old_json) = zcl_dyn_record_handler=>serialize( <del_db_row> ).

            APPEND VALUE #( row_no     = ls_row-row_no
                            table_name = iv_table_name
                            record_key = lv_del_key
                            fieldname  = c_action_field
                            old_value  = lv_old_json
                            new_value  = ''
                            status     = c_status-delete
                            message    = 'Record marked for deletion by __ACTION.' ) TO rt_diff.
          CATCH cx_root INTO DATA(lx_del).
            APPEND VALUE #( row_no     = ls_row-row_no
                            table_name = iv_table_name
                            record_key = lv_fkey
                            status     = c_status-error
                            message    = |Delete row does not match an existing record: { lx_del->get_text( ) }| ) TO rt_diff.
        ENDTRY.
        CONTINUE.
      ENDIF.

      DATA(lt_err) = validate_row(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).
      IF lt_err IS NOT INITIAL.
        LOOP AT lt_err INTO DATA(lv_emsg).
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = c_status-error
                          message    = lv_emsg ) TO rt_diff.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      DATA lv_missing_key TYPE abap_bool VALUE abap_false.
      DATA(lv_has_eid) = abap_false.
      IF lv_eid_f IS NOT INITIAL.
        IF get_cell_value( it_cells = ls_row-cells iv_field = lv_eid_f ) IS NOT INITIAL.
          lv_has_eid = abap_true.
        ENDIF.
      ENDIF.

      IF lv_has_eid = abap_false.
        LOOP AT lt_biz_keys INTO DATA(lv_k).
          IF get_cell_value(
               it_cells = ls_row-cells iv_field = CONV #( lv_k ) ) IS INITIAL.
            lv_missing_key = abap_true.
          ENDIF.
        ENDLOOP.
        IF lv_missing_key = abap_true.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = c_status-error
                          message    = |Missing key value for table { iv_table_name }. Fill all key columns before import.| ) TO rt_diff.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA(lv_where) = build_where_from_cells(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).

      IF lv_where IS INITIAL.
        DATA(lv_eid_present) = abap_false.
        IF lv_eid_f IS NOT INITIAL.
          READ TABLE ls_row-cells TRANSPORTING NO FIELDS
            WITH KEY fieldname = lv_eid_f.
          lv_eid_present = xsdbool( sy-subrc = 0 ).
        ENDIF.
        IF lv_eid_present = abap_true.
          append_new_diff(
            EXPORTING iv_row_no     = ls_row-row_no
                      iv_table_name = iv_table_name
                      iv_record_key = lv_fkey
                      it_fields     = lt_fields
                      it_cells      = ls_row-cells
            CHANGING  ct_diff       = rt_diff ).
        ELSE.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = c_status-error
                          message    = |Cannot identify target record for table { iv_table_name }. Check key columns in the uploaded file.| ) TO rt_diff.
        ENDIF.
        CONTINUE.
      ENDIF.

      DATA lr_db TYPE REF TO data.
      DATA lv_db_ok TYPE abap_bool VALUE abap_false.

      TRY.
          lr_db = zcl_dyn_record_handler=>get_single_record(
                    iv_table_name = iv_table_name
                    iv_where      = lv_where ).
          lv_db_ok = abap_true.
        CATCH zcx_excel_pipeline.
          lv_db_ok = abap_false.
        CATCH cx_sy_dynamic_osql_error INTO DATA(lx).
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = c_status-error
                          message    = |Database read failed for { iv_table_name }: { lx->get_text( ) }| ) TO rt_diff.
          CONTINUE.
      ENDTRY.

      IF lv_db_ok = abap_false.
        IF lv_has_eid = abap_true AND lv_generated_eid = abap_false.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = c_status-error
                          message    = |ENTITY_ID from uploaded file does not exist in { iv_table_name }. | &&
                                       |Download data/template from the current table and upload again.| ) TO rt_diff.
        ELSE.
          append_new_diff(
            EXPORTING iv_row_no     = ls_row-row_no
                      iv_table_name = iv_table_name
                      iv_record_key = lv_fkey
                      it_fields     = lt_fields
                      it_cells      = ls_row-cells
            CHANGING  ct_diff       = rt_diff ).
        ENDIF.
        CONTINUE.
      ENDIF.

      DATA(lv_rkey) = build_record_key_json(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        ir_row        = lr_db ).

      DATA(lv_changed) = append_compare_diff(
        EXPORTING iv_row_no     = ls_row-row_no
                  iv_table_name = iv_table_name
                  iv_record_key = lv_rkey
                  it_fields     = lt_fields
                  it_cells      = ls_row-cells
                  ir_db_row     = lr_db
        CHANGING  ct_diff       = rt_diff ).

      IF lv_changed = abap_false.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_rkey
                        status     = c_status-unchanged
                        message    = 'No changes detected' ) TO rt_diff.
      ENDIF.

    ENDLOOP.

    mark_preview_conflicts(
      EXPORTING iv_table_name = iv_table_name
      CHANGING  ct_diff       = rt_diff ).

    mark_permission_skips(
      EXPORTING iv_table_name = iv_table_name
      CHANGING  ct_diff       = rt_diff ).

    IF line_exists( rt_diff[ status = c_status-error ] ).
      DELETE rt_diff WHERE status <> c_status-error.
    ENDIF.
  ENDMETHOD.

  METHOD build_file_key.
    rv_key = build_record_key_json(
      iv_table_name = iv_table_name
      it_fields     = it_fields
      it_cells      = it_cells ).
  ENDMETHOD.

  METHOD get_key_problem.
    IF iv_entity_id_field IS NOT INITIAL.
      DATA(lv_eid) = get_cell_value(
        it_cells = it_cells
        iv_field = iv_entity_id_field ).
      IF lv_eid IS NOT INITIAL.
        IF is_valid_uuid_hex( lv_eid ) = abap_false.
          rv_message = |Invalid { iv_entity_id_field } value '{ lv_eid }'. Upload a downloaded { iv_table_name } file or leave the technical key blank for new rows.|.
          RETURN.
        ENDIF.
        RETURN.
      ENDIF.

      IF is_fk_key_field(
           iv_table_name = iv_table_name
           iv_field_name = iv_entity_id_field ) = abap_true.
        rv_message = |Missing foreign-key key value { iv_entity_id_field }. Select a valid parent value before import.| .
        RETURN.
      ENDIF.
    ENDIF.

    DATA lt_missing_columns TYPE string_table.
    DATA lt_empty_values TYPE string_table.

    LOOP AT it_biz_keys INTO DATA(lv_key).
      IF iv_entity_id_field IS NOT INITIAL
         AND lv_key = CONV string( iv_entity_id_field ).
        CONTINUE.
      ENDIF.

      READ TABLE it_cells TRANSPORTING NO FIELDS
        WITH KEY fieldname = CONV fieldname( lv_key ).

      IF sy-subrc <> 0.
        APPEND lv_key TO lt_missing_columns.
        CONTINUE.
      ENDIF.

      DATA(lv_value) = get_cell_value(
        it_cells = it_cells
        iv_field = CONV #( lv_key ) ).
      IF lv_value IS INITIAL.
        APPEND lv_key TO lt_empty_values.
      ENDIF.
    ENDLOOP.

    IF lt_missing_columns IS NOT INITIAL.
      DATA(lv_missing) = concat_lines_of( table = lt_missing_columns sep = ', ' ).
      rv_message = |Uploaded file does not match the selected table { iv_table_name }. | &&
                   |Missing key column(s): { lv_missing }. | &&
                   |Select the correct table or download the template/data from { iv_table_name } and upload again.|.
      RETURN.
    ENDIF.

    IF lt_empty_values IS NOT INITIAL.
      DATA(lv_empty) = concat_lines_of( table = lt_empty_values sep = ', ' ).
      rv_message = |Missing key value(s) for { lv_empty }. Fill the key column(s) before import.|.
    ENDIF.
  ENDMETHOD.

  METHOD is_fk_key_field.
    SELECT SINGLE @abap_true
      FROM dd08l
      INNER JOIN dd05s
        ON  dd05s~tabname   = dd08l~tabname
        AND dd05s~fieldname = dd08l~fieldname
        AND dd05s~as4local  = dd08l~as4local
      WHERE dd08l~tabname    = @iv_table_name
        AND dd08l~as4local   = 'A'
        AND dd05s~forkey     = @iv_field_name
        AND dd08l~checktable IS NOT INITIAL
      INTO @rv_is_fk.
    IF sy-subrc <> 0.
      rv_is_fk = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD is_valid_uuid_hex.
    DATA(lv_value) = iv_value.
    CONDENSE lv_value NO-GAPS.
    TRANSLATE lv_value TO UPPER CASE.

    rv_is_valid = xsdbool(
      strlen( lv_value ) = 32
      AND lv_value CO '0123456789ABCDEF' ).
  ENDMETHOD.

  METHOD append_new_diff.
    DATA lt_seen TYPE string_table.
    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0 OR is_diff_comparable_field(
        is_field = ls_f iv_table_name = iv_table_name it_fields = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.
      READ TABLE lt_seen TRANSPORTING NO FIELDS
        WITH KEY table_line = CONV string( ls_cell-fieldname ).
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      APPEND CONV string( ls_cell-fieldname ) TO lt_seen.
      APPEND VALUE #( row_no     = iv_row_no
                      table_name = iv_table_name
                      record_key = iv_record_key
                      fieldname  = ls_cell-fieldname
                      new_value  = ls_cell-value
                      status     = c_status-new ) TO ct_diff.
    ENDLOOP.
  ENDMETHOD.

  METHOD append_compare_diff.
    rv_changed = abap_false.
    ASSIGN ir_db_row->* TO FIELD-SYMBOL(<db_row>).
    DATA lt_seen TYPE string_table.

    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0 OR is_diff_comparable_field(
        is_field = ls_f iv_table_name = iv_table_name it_fields = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.
      READ TABLE lt_seen TRANSPORTING NO FIELDS
        WITH KEY table_line = CONV string( ls_cell-fieldname ).
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      APPEND CONV string( ls_cell-fieldname ) TO lt_seen.

      FIELD-SYMBOLS <db_val> TYPE any.
      UNASSIGN <db_val>.
      ASSIGN COMPONENT ls_cell-fieldname OF STRUCTURE <db_row> TO <db_val>.
      DATA lv_dbstr TYPE string.
      IF <db_val> IS ASSIGNED.
        lv_dbstr = |{ <db_val> }|.
      ELSE.
        CLEAR lv_dbstr.
      ENDIF.

      DATA lv_a TYPE string.
      DATA lv_b TYPE string.
      lv_a = lv_dbstr.      CONDENSE lv_a.
      lv_b = ls_cell-value. CONDENSE lv_b.

      IF lv_a <> lv_b.
        rv_changed = abap_true.
        APPEND VALUE #( row_no     = iv_row_no
                        table_name = iv_table_name
                        record_key = iv_record_key
                        fieldname  = ls_cell-fieldname
                        old_value  = lv_dbstr
                        new_value  = ls_cell-value
                        status     = c_status-changed ) TO ct_diff.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_row.
    LOOP AT it_fields INTO DATA(ls_field).
      IF is_diff_comparable_field(
           is_field      = ls_field
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_val) = get_cell_value(
        it_cells = it_cells iv_field = ls_field-field_name ).

      IF ( ls_field-mandatory_flag = abap_true OR ls_field-mandatory_flag = 'X' )
         AND lv_val IS INITIAL.
        APPEND |Field { ls_field-field_name } is required.| TO rt_errors.
        CONTINUE.
      ENDIF.

      IF lv_val IS INITIAL.
        CONTINUE.
      ENDIF.

      IF ls_field-inttype = 'C' AND ls_field-leng > 0 AND strlen( lv_val ) > ls_field-leng.
        APPEND |Field { ls_field-field_name } exceeds max length { ls_field-leng }.| TO rt_errors.
      ENDIF.

      IF ls_field-inttype = 'D'.
        DATA(lv_date_text) = lv_val.
        REPLACE ALL OCCURRENCES OF '-' IN lv_date_text WITH ''.

        IF strlen( lv_date_text ) <> 8 OR lv_date_text CN '0123456789'.
          APPEND |Field { ls_field-field_name } value '{ lv_val }' is not a valid date.| TO rt_errors.
          CONTINUE.
        ENDIF.

        TRY.
            DATA(lv_date) = CONV d( lv_date_text ).
            DATA(lv_checked_date) = lv_date + 0.
          CATCH cx_root.
            APPEND |Field { ls_field-field_name } value '{ lv_val }' is not a valid date.| TO rt_errors.
            CONTINUE.
        ENDTRY.
      ENDIF.

      IF ls_field-domain_name IS NOT INITIAL.
        DATA lv_has_fixed_domain_values TYPE abap_bool.
        CLEAR lv_has_fixed_domain_values.

        SELECT SINGLE @abap_true
          FROM dd07l
          WHERE domname    = @ls_field-domain_name
            AND as4local   = 'A'
            AND domvalue_l <> @space
          INTO @lv_has_fixed_domain_values.

        IF lv_has_fixed_domain_values = abap_true.
          DATA(lt_vals) = zcl_table_inspector=>get_domain_values( ls_field-domain_name ).
          IF lt_vals IS NOT INITIAL.
            READ TABLE lt_vals TRANSPORTING NO FIELDS WITH KEY value = lv_val.
            IF sy-subrc <> 0.
              APPEND |Field { ls_field-field_name } value '{ lv_val }' is not allowed by domain { ls_field-domain_name }.| TO rt_errors.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      DATA lv_fk_table TYPE tabname.
      DATA lv_fk_field TYPE fieldname.
      CLEAR: lv_fk_table, lv_fk_field.

      SELECT SINGLE dd08l~checktable, dd05s~fieldname
        FROM dd08l
        INNER JOIN dd05s
          ON  dd05s~tabname   = dd08l~tabname
          AND dd05s~fieldname = dd08l~fieldname
          AND dd05s~as4local  = dd08l~as4local
        WHERE dd08l~tabname    = @iv_table_name
          AND dd08l~as4local   = 'A'
          AND dd08l~checktable IS NOT INITIAL
          AND dd05s~forkey     = @ls_field-field_name
        INTO (@lv_fk_table, @lv_fk_field).

      IF sy-subrc <> 0 AND ls_field-domain_name IS NOT INITIAL.
        SELECT SINGLE entitytab
          FROM dd01l
          WHERE domname  = @ls_field-domain_name
            AND as4local = 'A'
            AND entitytab IS NOT INITIAL
          INTO @lv_fk_table.

        IF sy-subrc = 0 AND lv_fk_table IS NOT INITIAL.
          SELECT SINGLE dd03l~fieldname
            FROM dd03l
            INNER JOIN dd04l
              ON  dd04l~rollname = dd03l~rollname
              AND dd04l~as4local = dd03l~as4local
            WHERE dd03l~tabname   = @lv_fk_table
              AND dd03l~keyflag   = 'X'
              AND dd03l~as4local  = 'A'
              AND dd03l~fieldname <> 'MANDT'
              AND dd04l~domname   = @ls_field-domain_name
            INTO @lv_fk_field.

          IF sy-subrc <> 0.
            SELECT SINGLE fieldname
              FROM dd03l
              WHERE tabname   = @lv_fk_table
                AND keyflag   = 'X'
                AND as4local  = 'A'
                AND fieldname <> 'MANDT'
              INTO @lv_fk_field.
          ENDIF.
        ENDIF.
      ENDIF.

      IF sy-subrc = 0 AND lv_fk_table IS NOT INITIAL AND lv_fk_field IS NOT INITIAL.
        DATA(lv_fk_value) = lv_val.
        DATA(lv_check_msg_field) = CONV string( ls_field-field_name ).
        SELECT SINGLE leng, inttype
          FROM dd03l
          WHERE tabname   = @lv_fk_table
            AND fieldname = @lv_fk_field
            AND as4local  = 'A'
          INTO @DATA(ls_fk_dd03l).
        IF sy-subrc = 0.
          IF ls_fk_dd03l-leng > 0 AND strlen( lv_fk_value ) > ls_fk_dd03l-leng.
            APPEND |{ lv_check_msg_field } '{ lv_val }' is invalid. Please select an existing { lv_check_msg_field }.| TO rt_errors.
            CONTINUE.
          ENDIF.
          IF ( ls_fk_dd03l-inttype = 'N' OR ls_fk_dd03l-inttype = 'I' )
             AND lv_fk_value CN '0123456789'.
            APPEND |{ lv_check_msg_field } '{ lv_val }' is invalid. Please select an existing { lv_check_msg_field }.| TO rt_errors.
            CONTINUE.
          ENDIF.
        ENDIF.
        REPLACE ALL OCCURRENCES OF |'| IN lv_fk_value WITH |''|.
        DATA(lv_fk_where) = |{ lv_fk_field } = '{ lv_fk_value }'|.
        DATA(lv_fk_exists) = abap_false.
        TRY.
            SELECT SINGLE @abap_true
              FROM (lv_fk_table)
              WHERE (lv_fk_where)
              INTO @lv_fk_exists.
          CATCH cx_root.
            CLEAR lv_fk_exists.
        ENDTRY.
        IF lv_fk_exists = abap_false.
          APPEND |{ lv_check_msg_field } '{ lv_val }' is invalid. Please select an existing { lv_check_msg_field }.| TO rt_errors.
        ENDIF.
      ENDIF.
    ENDLOOP.

    DATA(lv_valid_from) = get_cell_value(
      it_cells = it_cells
      iv_field = 'VALID_FROM' ).
    DATA(lv_valid_to) = get_cell_value(
      it_cells = it_cells
      iv_field = 'VALID_TO' ).
    IF lv_valid_from IS NOT INITIAL AND lv_valid_to IS NOT INITIAL.
      REPLACE ALL OCCURRENCES OF '-' IN lv_valid_from WITH ''.
      REPLACE ALL OCCURRENCES OF '-' IN lv_valid_to WITH ''.
      IF strlen( lv_valid_from ) = 8
         AND strlen( lv_valid_to ) = 8
         AND lv_valid_from CO '0123456789'
         AND lv_valid_to CO '0123456789'
         AND lv_valid_to < lv_valid_from.
        APPEND |VALID_TO must be on or after VALID_FROM.| TO rt_errors.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD apply_diff_import.
    CLEAR rs_summary.

    SELECT SINGLE approval_required
      FROM ztbl_config
      WHERE table_name = @iv_table_name
        AND active_flag = @abap_true
      INTO @DATA(lv_appr_req).
    DATA lv_approval_mode TYPE abap_bool.
    lv_approval_mode = COND #( WHEN sy-subrc = 0 AND lv_appr_req = abap_true THEN abap_true ELSE abap_false ).

    LOOP AT it_diff INTO DATA(ls_diff0).
      CASE ls_diff0-status.
        WHEN c_status-unchanged.
          rs_summary-unchanged_count = rs_summary-unchanged_count + 1.
        WHEN c_status-skipped.
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
        WHEN c_status-error.
          rs_summary-error_count = rs_summary-error_count + 1.
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
      ENDCASE.
    ENDLOOP.

    DATA lt_groups TYPE tt_group.
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    DATA lt_error_groups TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_action_row_count TYPE i.

    LOOP AT it_diff TRANSPORTING NO FIELDS
      WHERE status = c_status-new
         OR status = c_status-changed
         OR status = c_status-delete.
      lv_action_row_count = lv_action_row_count + 1.
    ENDLOOP.

    LOOP AT it_diff INTO DATA(ls_error_diff)
      WHERE status = c_status-error.
      INSERT |{ ls_error_diff-row_no }#{ ls_error_diff-record_key }| INTO TABLE lt_error_groups.
    ENDLOOP.

    LOOP AT it_diff INTO DATA(ls_diff)
      WHERE ( status = c_status-new
           OR status = c_status-changed
           OR status = c_status-delete )
        AND fieldname IS NOT INITIAL.

      READ TABLE lt_error_groups TRANSPORTING NO FIELDS
        WITH TABLE KEY table_line = |{ ls_diff-row_no }#{ ls_diff-record_key }|.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      IF ls_diff-status <> c_status-delete
         AND ls_diff-fieldname <> c_snapshot_field.
        READ TABLE lt_fields INTO DATA(ls_f_commit) WITH KEY field_name = ls_diff-fieldname.
        IF sy-subrc = 0 AND is_importable_field_for_table(
          is_field      = ls_f_commit
          iv_table_name = iv_table_name
          it_fields     = lt_fields ) = abap_false.
          CONTINUE.
        ENDIF.
        IF sy-subrc <> 0 AND is_admin_field( ls_diff-fieldname ) = abap_true.
          CONTINUE.
        ENDIF.
      ENDIF.

      READ TABLE lt_groups ASSIGNING FIELD-SYMBOL(<g>)
        WITH TABLE KEY row_no = ls_diff-row_no
                       record_key = ls_diff-record_key
                       status = ls_diff-status.
      IF sy-subrc <> 0.
        INSERT VALUE #( row_no     = ls_diff-row_no
                        record_key = ls_diff-record_key
                        status     = ls_diff-status ) INTO TABLE lt_groups ASSIGNING <g>.
      ENDIF.

      READ TABLE <g>-cells TRANSPORTING NO FIELDS WITH KEY fieldname = ls_diff-fieldname.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        fieldname = ls_diff-fieldname
        value     = COND string(
          WHEN ls_diff-status = c_status-delete
            OR ls_diff-fieldname = c_snapshot_field
          THEN ls_diff-old_value
        ELSE ls_diff-new_value ) ) TO <g>-cells.
    ENDLOOP.

    DATA lt_authorized_groups TYPE tt_group.
    LOOP AT lt_groups INTO DATA(ls_permission_group).
      DATA(lv_permission_action) =
        get_permission_action( ls_permission_group-status ).
      TRY.
          zcl_auth_helper=>check_permission(
            iv_table_name = CONV ztde_table_name( iv_table_name )
            iv_action     = lv_permission_action ).
          INSERT ls_permission_group INTO TABLE lt_authorized_groups.
        CATCH zcx_excel_pipeline INTO DATA(lx_permission).
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
          APPEND |Row { ls_permission_group-row_no } skipped: { lx_permission->get_text( ) }|
            TO rs_summary-messages.
      ENDTRY.
    ENDLOOP.
    lt_groups = lt_authorized_groups.

    IF lt_groups IS INITIAL.
      rs_summary-error_count = rs_summary-error_count + 1.
      IF lv_action_row_count > 0.
        APPEND 'Excel diff rows were received, but no commit groups could be built. Please preview the Excel file again and confirm with the latest diff.' TO rs_summary-messages.
      ELSE.
        APPEND 'No NEW/CHANGED/DELETE rows were received for commit. Please preview the Excel file again before confirming import.' TO rs_summary-messages.
      ENDIF.
      RETURN.
    ENDIF.

    IF lt_groups IS INITIAL.
      APPEND 'Không có dòng NEW/CHANGED/DELETE để commit.' TO rs_summary-messages.
      RETURN.
    ENDIF.

    DATA lt_keys TYPE string_table.
    lt_keys = get_match_key_fields(
                it_fields     = lt_fields
                iv_table_name = iv_table_name ).

    DATA(lv_commit_eid_f) = get_entity_id_field( iv_table_name ).
    IF lt_keys IS INITIAL AND lv_commit_eid_f IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } không có key field importable để commit|.
    ENDIF.

    IF lv_approval_mode = abap_true.
      DATA(lt_aprvl_groups) = CORRESPONDING tt_group( lt_groups ).
      submit_groups(
        EXPORTING iv_table_name = iv_table_name
                  it_groups     = lt_aprvl_groups
                  it_fields     = lt_fields
        CHANGING  cs_summary    = rs_summary ).

      IF rs_summary-inserted_count = 0 AND rs_summary-updated_count = 0.
        APPEND 'No valid Excel rows were submitted for approval.' TO rs_summary-messages.
        RETURN.
      ENDIF.

      IF iv_do_commit = abap_true.
        COMMIT WORK AND WAIT.
      ENDIF.

      APPEND |Đã gửi duyệt: C={ rs_summary-inserted_count }, U/D={ rs_summary-updated_count }, E={ rs_summary-error_count }. Chờ Approve trên UI.| TO rs_summary-messages.
      RETURN.
    ENDIF.

    DATA lv_parent_audit_id TYPE sysuuid_c32.
    TRY.
        lv_parent_audit_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
    ENDTRY.

    LOOP AT lt_groups INTO DATA(ls_group).
      TRY.
          CASE ls_group-status.
            WHEN c_status-new.
              DATA lv_new_json TYPE string.
              DATA lr_new_rec TYPE REF TO data.
              build_merged_record(
                EXPORTING iv_table_name = iv_table_name
                          it_cells      = ls_group-cells
                          it_fields     = lt_fields
                          iv_status     = ls_group-status
                          iv_record_key = ls_group-record_key
                IMPORTING ev_new_json   = lv_new_json
                          er_record     = lr_new_rec ).
              ASSIGN lr_new_rec->* TO FIELD-SYMBOL(<wa_new>).
              INSERT (iv_table_name) FROM @<wa_new>.
              rs_summary-inserted_count = rs_summary-inserted_count + 1.

              DATA(lv_new_full_json) = zcl_dyn_record_handler=>serialize( <wa_new> ).
              DATA(lv_new_key_json) = build_record_key_json(
                iv_table_name = iv_table_name
                it_fields     = lt_fields
                ir_row        = lr_new_rec ).
              zcl_aprvl_util=>log_change(
                iv_table_name  = CONV ztde_table_name( iv_table_name )
                iv_record_key  = CONV ztde_record_key( lv_new_key_json )
                iv_old_value   = ''
                iv_new_value   = lv_new_full_json
                iv_parent_audit_id = lv_parent_audit_id
                iv_action_type = c_action-create ).

            WHEN c_status-changed.
              DATA(lv_where) = build_where_from_record_key(
                                 iv_table_name = iv_table_name
                                 iv_record_key = ls_group-record_key
                                 it_fields     = lt_fields ).

              DATA(lv_eid_where) = uses_entity_id_where(
                iv_table_name = iv_table_name
                it_fields     = lt_fields
                iv_record_key = ls_group-record_key ).

              DATA lv_set TYPE string.
              DATA lt_seen_set TYPE string_table.
              CLEAR lv_set.
              CLEAR lt_seen_set.
              LOOP AT ls_group-cells INTO DATA(ls_cell_chg).
                IF ls_cell_chg-fieldname = 'MANDT' OR ls_cell_chg-fieldname = 'CLIENT'.
                  CONTINUE.
                ENDIF.

                IF lv_eid_where = abap_false.
                  READ TABLE lt_keys TRANSPORTING NO FIELDS
                    WITH KEY table_line = CONV string( ls_cell_chg-fieldname ).
                  IF sy-subrc = 0.
                    CONTINUE.
                  ENDIF.
                ENDIF.

                READ TABLE lt_fields INTO DATA(ls_f_upd) WITH KEY field_name = ls_cell_chg-fieldname.
                IF sy-subrc <> 0 OR is_diff_comparable_field(
                  is_field = ls_f_upd iv_table_name = iv_table_name it_fields = lt_fields ) = abap_false.
                  CONTINUE.
                ENDIF.

                READ TABLE lt_seen_set TRANSPORTING NO FIELDS
                  WITH KEY table_line = CONV string( ls_cell_chg-fieldname ).
                IF sy-subrc = 0.
                  CONTINUE.
                ENDIF.
                APPEND CONV string( ls_cell_chg-fieldname ) TO lt_seen_set.

                DATA(lv_new_esc) = ls_cell_chg-value.
                REPLACE ALL OCCURRENCES OF |'| IN lv_new_esc WITH |''|.
                DATA(lv_one) = |{ ls_cell_chg-fieldname } = '{ lv_new_esc }'|.
                IF lv_set IS INITIAL.
                  lv_set = lv_one.
                ELSE.
                  lv_set = lv_set && `, ` && lv_one.
                ENDIF.
              ENDLOOP.

              IF lv_set IS INITIAL.
                rs_summary-skipped_count = rs_summary-skipped_count + 1.
                APPEND |Row { ls_group-row_no }: không có field hợp lệ để UPDATE.| TO rs_summary-messages.
                CONTINUE.
              ENDIF.

              append_admin_on_update(
                EXPORTING iv_table_name = iv_table_name
                CHANGING  cv_set        = lv_set ).

              DATA(lv_update_old_json) = VALUE string( ).
              DATA(lv_update_new_json) = VALUE string( ).
              DATA lr_update_rec TYPE REF TO data.
              build_merged_record(
                EXPORTING iv_table_name = iv_table_name
                          it_cells      = ls_group-cells
                          it_fields     = lt_fields
                          iv_status     = ls_group-status
                          iv_record_key = ls_group-record_key
                IMPORTING ev_old_json   = lv_update_old_json
                          ev_new_json   = lv_update_new_json
                          er_record     = lr_update_rec ).
              ASSIGN lr_update_rec->* TO FIELD-SYMBOL(<wa_update_new>).
              lv_update_new_json = zcl_dyn_record_handler=>serialize( <wa_update_new> ).

              UPDATE (iv_table_name)
                SET (lv_set)
                WHERE (lv_where).
              rs_summary-updated_count = rs_summary-updated_count + 1.

              zcl_aprvl_util=>log_change(
                iv_table_name  = CONV ztde_table_name( iv_table_name )
                iv_record_key  = CONV ztde_record_key( ls_group-record_key )
                iv_old_value   = lv_update_old_json
                iv_new_value   = lv_update_new_json
                iv_parent_audit_id = lv_parent_audit_id
                iv_action_type = c_action-update ).

            WHEN c_status-delete.
              DATA(lv_where_del) = build_where_from_record_key(
                                     iv_table_name = iv_table_name
                                     iv_record_key = ls_group-record_key
                                     it_fields     = lt_fields ).

              DATA(lv_old_json_del) = get_cell_value(
                it_cells = ls_group-cells
                iv_field = CONV fieldname( c_action_field ) ).

              DATA(lv_fk_error_del) = zcl_dyn_record_handler=>check_foreign_key(
                iv_table_name = CONV ztde_table_name( iv_table_name )
                iv_record_key = CONV string( ls_group-record_key ) ).
              IF lv_fk_error_del IS NOT INITIAL.
                rs_summary-error_count = rs_summary-error_count + 1.
                rs_summary-skipped_count = rs_summary-skipped_count + 1.
                APPEND |Row { ls_group-row_no } delete blocked: { lv_fk_error_del }| TO rs_summary-messages.
                CONTINUE.
              ENDIF.

              DELETE FROM (iv_table_name) WHERE (lv_where_del).
              IF sy-subrc = 0.
                rs_summary-updated_count = rs_summary-updated_count + 1.
                zcl_aprvl_util=>log_change(
                  iv_table_name  = CONV ztde_table_name( iv_table_name )
                  iv_record_key  = CONV ztde_record_key( ls_group-record_key )
                  iv_field_name  = CONV ztde_field_name( c_action_field )
                  iv_old_value   = lv_old_json_del
                  iv_new_value   = ''
                  iv_parent_audit_id = lv_parent_audit_id
                  iv_action_type = c_action-delete ).
              ELSE.
                rs_summary-error_count = rs_summary-error_count + 1.
                rs_summary-skipped_count = rs_summary-skipped_count + 1.
                APPEND |Row { ls_group-row_no }: record not found for DELETE.| TO rs_summary-messages.
              ENDIF.

          ENDCASE.

        CATCH cx_root INTO DATA(lx).
          rs_summary-error_count = rs_summary-error_count + 1.
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
          APPEND |Row { ls_group-row_no } commit lỗi: { lx->get_text( ) }| TO rs_summary-messages.
      ENDTRY.
    ENDLOOP.

    IF iv_do_commit = abap_true.
      COMMIT WORK AND WAIT.
    ENDIF.
    APPEND |Commit xong: I={ rs_summary-inserted_count }, U/D={ rs_summary-updated_count }, E={ rs_summary-error_count }.| TO rs_summary-messages.
  ENDMETHOD.

  METHOD uses_entity_id_where.
    DATA(lt_wk) = get_where_key_fields(
      iv_table_name = iv_table_name
      it_fields     = it_fields
      iv_record_key = iv_record_key ).
    DATA(lv_eid) = get_entity_id_field( iv_table_name ).
    rv_yes = COND #(
      WHEN lv_eid IS NOT INITIAL
       AND line_exists( lt_wk[ table_line = CONV string( lv_eid ) ] )
      THEN abap_true ELSE abap_false ).
  ENDMETHOD.

  METHOD append_admin_on_update.
    DATA lr_wa TYPE REF TO data.
    CREATE DATA lr_wa TYPE (iv_table_name).
    ASSIGN lr_wa->* TO FIELD-SYMBOL(<wa>).

    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    DATA(lv_ts_c) = |{ lv_ts }|.

    ASSIGN COMPONENT 'LAST_CHANGED_BY' OF STRUCTURE <wa> TO FIELD-SYMBOL(<f>).
    IF sy-subrc = 0.
      cv_set = cv_set && |, LAST_CHANGED_BY = '{ sy-uname }'|.
    ENDIF.

    ASSIGN COMPONENT 'LAST_CHANGED_AT' OF STRUCTURE <wa> TO <f>.
    IF sy-subrc = 0.
      cv_set = cv_set && |, LAST_CHANGED_AT = '{ lv_ts_c }'|.
    ENDIF.

    ASSIGN COMPONENT 'LOCAL_LAST_CHANGED_AT' OF STRUCTURE <wa> TO <f>.
    IF sy-subrc = 0.
      cv_set = cv_set && |, LOCAL_LAST_CHANGED_AT = '{ lv_ts_c }'|.
    ENDIF.

    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE <wa> TO <f>.
    IF sy-subrc = 0.
      cv_set = cv_set && |, CHANGED_BY = '{ sy-uname }'|.
    ENDIF.

    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <wa> TO <f>.
    IF sy-subrc = 0.
      cv_set = cv_set && |, CHANGED_AT = '{ lv_ts_c }'|.
    ENDIF.
  ENDMETHOD.

  METHOD submit_groups.
    DATA lt_items TYPE tt_item.
    DATA lv_item_no TYPE n LENGTH 6.

    LOOP AT it_groups INTO DATA(ls_group).
      TRY.
          DATA(lv_action) = COND ztde_action_type(
            WHEN ls_group-status = c_status-new
            THEN c_action-create
            WHEN ls_group-status = c_status-changed
            THEN c_action-update
            WHEN ls_group-status = c_status-delete
            THEN c_action-delete
            ELSE '' ).

          IF lv_action IS INITIAL.
            cs_summary-skipped_count = cs_summary-skipped_count + 1.
            CONTINUE.
          ENDIF.

          DATA lv_old_json TYPE string.
          DATA lv_new_json TYPE string.
          DATA lr_rec TYPE REF TO data.
          DATA(lv_record_key) = ls_group-record_key.

          assert_no_pending_conflict(
            iv_table_name = CONV ztde_table_name( iv_table_name )
            iv_record_key = CONV ztde_record_key( lv_record_key ) ).

          IF ls_group-status = c_status-delete.
            lv_old_json = get_cell_value(
              it_cells = ls_group-cells
            iv_field = CONV fieldname( c_action_field ) ).

            assert_current_state(
              iv_table_name  = iv_table_name
              iv_action_type = lv_action
              iv_record_key  = CONV ztde_record_key( lv_record_key )
              iv_old_data    = lv_old_json ).

            CLEAR lv_new_json.
          ELSE.
            IF ls_group-status = c_status-changed.
              lv_old_json = get_cell_value(
                it_cells = ls_group-cells
                iv_field = c_snapshot_field ).
              IF lv_old_json IS INITIAL.
                lv_old_json = get_current_snapshot(
                  iv_table_name = iv_table_name
                  iv_record_key = CONV ztde_record_key( lv_record_key ) ).
              ENDIF.
            ENDIF.

            IF ls_group-status = c_status-new.
              assert_current_state(
                iv_table_name  = iv_table_name
                iv_action_type = lv_action
                iv_record_key  = CONV ztde_record_key( lv_record_key ) ).
            ENDIF.

            build_merged_record(
              EXPORTING iv_table_name = iv_table_name
                        it_cells      = ls_group-cells
                        it_fields     = it_fields
                        iv_status     = ls_group-status
                        iv_record_key = lv_record_key
              IMPORTING ev_old_json   = DATA(lv_builder_old_json)
                        ev_new_json   = lv_new_json
                        er_record     = lr_rec ).

            IF lv_old_json IS INITIAL.
              lv_old_json = lv_builder_old_json.
            ENDIF.

            IF ls_group-status = c_status-new.
              lv_record_key = build_record_key_json(
                iv_table_name = iv_table_name
                it_fields     = it_fields
                ir_row        = lr_rec ).
            ELSEIF ls_group-status = c_status-changed.
              assert_current_state(
                iv_table_name  = iv_table_name
                iv_action_type = lv_action
                iv_record_key  = CONV ztde_record_key( lv_record_key )
                iv_old_data    = lv_old_json ).
            ENDIF.

            validate_approval_json(
              EXPORTING iv_table_name = iv_table_name
                        iv_new_json   = lv_new_json
                        it_fields     = it_fields ).
          ENDIF.

          lv_item_no = lv_item_no + 1.
          APPEND VALUE #(
            item_no     = lv_item_no
            table_name  = CONV ztde_table_name( iv_table_name )
            record_key  = CONV ztde_record_key( lv_record_key )
            action_type = lv_action
            new_data    = lv_new_json
            old_data    = lv_old_json ) TO lt_items.

          IF lv_action = c_action-create.
            cs_summary-inserted_count = cs_summary-inserted_count + 1.
          ELSEIF lv_action = c_action-update.
            cs_summary-updated_count = cs_summary-updated_count + 1.
          ELSE.
            cs_summary-updated_count = cs_summary-updated_count + 1.
          ENDIF.

        CATCH zcx_excel_pipeline INTO DATA(lx_pipe).
          cs_summary-skipped_count = cs_summary-skipped_count + 1.
          APPEND |Row { ls_group-row_no } skipped: { lx_pipe->get_text( ) }| TO cs_summary-messages.
        CATCH cx_root INTO DATA(lx).
          cs_summary-error_count = cs_summary-error_count + 1.
          cs_summary-skipped_count = cs_summary-skipped_count + 1.
          DATA(lv_cls) = cl_abap_classdescr=>describe_by_object_ref( lx )->get_relative_name( ).
          APPEND |Row { ls_group-row_no } submit approval failed [{ lv_cls }]: { lx->get_text( ) }| TO cs_summary-messages.
      ENDTRY.
    ENDLOOP.

    IF lt_items IS INITIAL.
      APPEND 'No valid Excel row to submit for approval.' TO cs_summary-messages.
      RETURN.
    ENDIF.

    DATA(ls_submit) = submit_bulk(
      iv_table_name = CONV ztde_table_name( iv_table_name )
      it_items      = lt_items ).

    IF ls_submit-success = abap_true.
      APPEND |Excel bulk request submitted for approval: { ls_submit-aprvl_id } ({ ls_submit-item_count } item(s)).| TO cs_summary-messages.
    ELSE.
      cs_summary-error_count = cs_summary-error_count + lines( lt_items ).
      cs_summary-skipped_count = cs_summary-skipped_count + lines( lt_items ).
      CLEAR: cs_summary-inserted_count, cs_summary-updated_count.
      APPEND |Excel bulk approval submit failed: { ls_submit-message }| TO cs_summary-messages.
    ENDIF.
  ENDMETHOD.

  METHOD mark_preview_conflicts.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT ct_diff INTO DATA(ls_diff)
      WHERE status = c_status-new
         OR status = c_status-changed
         OR status = c_status-delete.
      DATA(lv_group_key) = |{ ls_diff-row_no }#{ ls_diff-record_key }|.
      INSERT lv_group_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      TRY.
          assert_no_pending_conflict(
            iv_table_name = CONV ztde_table_name( iv_table_name )
            iv_record_key = CONV ztde_record_key( ls_diff-record_key ) ).
        CATCH zcx_excel_pipeline INTO DATA(lx_conflict).
          LOOP AT ct_diff ASSIGNING FIELD-SYMBOL(<conflict_diff>)
            WHERE row_no     = ls_diff-row_no
              AND record_key = ls_diff-record_key
              AND ( status = c_status-new
                 OR status = c_status-changed
                 OR status = c_status-delete ).
            <conflict_diff>-status  = c_status-skipped.
            <conflict_diff>-message = lx_conflict->get_text( ).
          ENDLOOP.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD mark_permission_skips.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT ct_diff INTO DATA(ls_diff)
      WHERE status = c_status-new
         OR status = c_status-changed
         OR status = c_status-delete.
      DATA(lv_group_key) =
        |{ ls_diff-row_no }#{ ls_diff-record_key }#{ ls_diff-status }|.
      INSERT lv_group_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_action) = get_permission_action( ls_diff-status ).
      TRY.
          zcl_auth_helper=>check_permission(
            iv_table_name = CONV ztde_table_name( iv_table_name )
            iv_action     = lv_action ).
        CATCH zcx_excel_pipeline INTO DATA(lx_permission).
          LOOP AT ct_diff ASSIGNING FIELD-SYMBOL(<permission_diff>)
            WHERE row_no     = ls_diff-row_no
              AND record_key = ls_diff-record_key
              AND status     = ls_diff-status.
            <permission_diff>-status  = c_status-skipped.
            <permission_diff>-message = lx_permission->get_text( ).
          ENDLOOP.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_permission_action.
    rv_action = SWITCH char20(
      iv_status
      WHEN c_status-new     THEN zcl_auth_helper=>c_action-create
      WHEN c_status-changed THEN zcl_auth_helper=>c_action-update
      WHEN c_status-delete THEN zcl_auth_helper=>c_action-delete
      ELSE '' ).
  ENDMETHOD.

  METHOD assert_no_pending_conflict.
    zcl_aprvl_util=>assert_no_conflicting_pending(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key ).
  ENDMETHOD.

  METHOD get_current_snapshot.
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    DATA(lv_where) = build_where_from_record_key(
      iv_table_name = iv_table_name
      iv_record_key = CONV string( iv_record_key )
      it_fields     = lt_fields ).

    TRY.
        DATA(lr_rows) = zcl_dyn_record_handler=>get_table_data(
          iv_table_name   = iv_table_name
          iv_where_clause = lv_where
          iv_max_rows     = 1 ).
        FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
        ASSIGN lr_rows->* TO <rows>.
        IF <rows> IS NOT ASSIGNED OR <rows> IS INITIAL.
          RETURN.
        ENDIF.
        READ TABLE <rows> INDEX 1 ASSIGNING FIELD-SYMBOL(<row>).
        rv_snapshot = zcl_dyn_record_handler=>serialize( <row> ).
      CATCH cx_root INTO DATA(lx_read).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = lx_read->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD assert_current_state.
    DATA(lv_current) = get_current_snapshot(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key ).

    IF iv_action_type = c_action-create.
      IF lv_current IS NOT INITIAL.
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Record { iv_record_key } was created after preview.|.
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_current IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Record { iv_record_key } no longer exists.|.
    ENDIF.
    IF iv_old_data IS NOT INITIAL AND lv_current <> iv_old_data.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Record { iv_record_key } changed after preview. Refresh and upload again.|.
    ENDIF.
  ENDMETHOD.

  METHOD parse_excel.
    CLEAR: et_rows, et_messages.

    DATA lo_excel TYPE REF TO zcl_excel.
    TRY.
        DATA(lo_reader) = CAST zif_excel_reader( NEW zcl_excel_reader_2007( ) ).
        lo_excel = lo_reader->load( iv_file ).
      CATCH zcx_excel INTO DATA(lx_read).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Cannot read Excel file: { lx_read->get_text( ) }|.
    ENDTRY.

    DATA(lo_ws)      = lo_excel->get_active_worksheet( ).
    DATA(lv_max_col) = CONV i( lo_ws->get_highest_column( ) ).
    DATA(lv_max_row) = CONV i( lo_ws->get_highest_row( ) ).

    IF lv_max_col = 0 OR lv_max_row < 2.
      APPEND |Excel file has no data rows. Row 1 must be header; data starts from row 2.| TO et_messages.
      RETURN.
    ENDIF.

    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    IF lt_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } is not configured in ZFLD_CONFIG. Configure fields before Excel import.|.
    ENDIF.

    DATA lt_colmap TYPE tt_colmap.
    DATA lt_header_cols TYPE tt_colnum.
    map_columns(
      EXPORTING io_worksheet   = lo_ws
                iv_max_col     = lv_max_col
                iv_table_name  = iv_table_name
                it_fields      = lt_fields
      IMPORTING et_colmap      = lt_colmap
                et_header_cols = lt_header_cols
                et_messages    = DATA(lt_map_msg) ).
    APPEND LINES OF lt_map_msg TO et_messages.

    LOOP AT lt_map_msg INTO DATA(lv_map_msg).
      IF lv_map_msg CS |does not belong to table|.
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Uploaded Excel file does not match table { iv_table_name }. | &&
                              |Header contains column(s) that do not belong to this table. | &&
                              |Select the correct table or download the template/data from { iv_table_name } and upload again.|.
      ENDIF.
    ENDLOOP.

    IF lt_colmap IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Uploaded Excel file does not match table { iv_table_name }. | &&
                            |No header column matches this table. | &&
                            |Select the correct table or download the template/data from { iv_table_name } and upload again.|.
    ENDIF.

    DATA(lt_required_keys) = get_match_key_fields(
      it_fields     = lt_fields
      iv_table_name = iv_table_name ).
    DATA lt_missing_keys TYPE string_table.

    LOOP AT lt_required_keys INTO DATA(lv_required_key).
      READ TABLE lt_colmap TRANSPORTING NO FIELDS
        WITH KEY fieldname = CONV fieldname( lv_required_key ).
      IF sy-subrc <> 0.
        APPEND lv_required_key TO lt_missing_keys.
      ENDIF.
    ENDLOOP.

    IF lt_missing_keys IS NOT INITIAL.
      DATA(lv_missing_keys) = concat_lines_of( table = lt_missing_keys sep = ', ' ).
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Uploaded Excel file does not match table { iv_table_name }. | &&
                            |Missing required key column(s): { lv_missing_keys }. | &&
                            |Select the correct table or download the template/data from { iv_table_name } and upload again.|.
    ENDIF.

    DATA lv_alpha TYPE zexcel_cell_column_alpha.
    DATA lv_value TYPE zexcel_cell_value.
    DATA lv_str   TYPE string.
    DATA lv_row   TYPE i.
    DATA lv_col   TYPE i.

    lv_row = 2.
    WHILE lv_row <= lv_max_row.
      DATA ls_parsed TYPE ty_parsed_row.
      CLEAR ls_parsed.
      ls_parsed-row_no = lv_row.

      DATA lv_has_value TYPE abap_bool.
      lv_has_value = abap_false.

      lv_col = 1.
      WHILE lv_col <= lv_max_col.
        lv_alpha = zcl_excel_common=>convert_column2alpha( lv_col ).
        CLEAR lv_value.
        TRY.
            lo_ws->get_cell(
              EXPORTING ip_column = lv_alpha
                        ip_row    = lv_row
              IMPORTING ep_value  = lv_value ).
          CATCH zcx_excel.
            CLEAR lv_value.
        ENDTRY.
        lv_str = lv_value.

        READ TABLE lt_colmap INTO DATA(ls_map) WITH KEY column = lv_col.
        IF sy-subrc = 0.
          IF lv_str IS NOT INITIAL.
            lv_has_value = abap_true.
          ENDIF.
          APPEND VALUE #( fieldname = ls_map-fieldname
                          value     = lv_str ) TO ls_parsed-cells.
        ELSE.
          IF lv_str IS NOT INITIAL.
            DATA(lv_col_alpha) = zcl_excel_common=>convert_column2alpha( lv_col ).

            READ TABLE lt_header_cols TRANSPORTING NO FIELDS
              WITH KEY table_line = lv_col.
            IF sy-subrc = 0.
              APPEND |Ignored cell { lv_col_alpha }{ lv_row }: its header does not belong to table { iv_table_name }.| TO et_messages.
            ELSE.
              APPEND |Ignored cell { lv_col_alpha }{ lv_row }: data is outside the Excel header area.| TO et_messages.
            ENDIF.
          ENDIF.
        ENDIF.

        lv_col = lv_col + 1.
      ENDWHILE.

      IF lv_has_value = abap_true.
        APPEND ls_parsed TO et_rows.
      ENDIF.

      lv_row = lv_row + 1.
    ENDWHILE.

    APPEND |Parsed { lines( et_rows ) } data rows.| TO et_messages.
  ENDMETHOD.

  METHOD map_columns.
    CLEAR: et_colmap, et_header_cols, et_messages.

    DATA lv_alpha TYPE zexcel_cell_column_alpha.
    DATA lv_value TYPE zexcel_cell_value.
    DATA lv_col   TYPE i.

    lv_col = 1.
    WHILE lv_col <= iv_max_col.
      lv_alpha = zcl_excel_common=>convert_column2alpha( lv_col ).
      CLEAR lv_value.
      TRY.
          io_worksheet->get_cell(
            EXPORTING ip_column = lv_alpha
                      ip_row    = 1
            IMPORTING ep_value  = lv_value ).
        CATCH zcx_excel.
          CLEAR lv_value.
      ENDTRY.

      DATA(lv_header_norm) = normalize( lv_value ).

      IF lv_header_norm IS NOT INITIAL.
        APPEND lv_col TO et_header_cols.

        IF lv_header_norm = c_action_field.
          READ TABLE et_colmap TRANSPORTING NO FIELDS
            WITH KEY fieldname = CONV fieldname( c_action_field ).
          IF sy-subrc = 0.
            APPEND |Column '{ lv_value }' maps to field { c_action_field } more than once; duplicate column was ignored.| TO et_messages.
          ELSE.
            APPEND VALUE #( column    = lv_col
                            fieldname = CONV fieldname( c_action_field ) ) TO et_colmap.
          ENDIF.
          lv_col = lv_col + 1.
          CONTINUE.
        ENDIF.

        DATA lv_found TYPE abap_bool.
        lv_found = abap_false.

        LOOP AT it_fields INTO DATA(ls_field).
          IF normalize( ls_field-field_name ) = lv_header_norm.
            DATA(lv_match) = ls_field-field_name.
            lv_found = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.

        IF lv_found = abap_false.
          LOOP AT it_fields INTO ls_field.
            IF normalize( ls_field-label_text ) = lv_header_norm.
              lv_match = ls_field-field_name.
              lv_found = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.

        IF lv_found = abap_false.
          APPEND |Column '{ lv_value }' does not belong to table { iv_table_name } and was ignored.| TO et_messages.
        ELSE.
          READ TABLE it_fields INTO DATA(ls_matched) WITH KEY field_name = lv_match.
          IF sy-subrc = 0 AND is_parseable_column(
            is_field      = ls_matched
            iv_table_name = iv_table_name
            it_fields     = it_fields ) = abap_false.
            APPEND |Column '{ lv_value }' ({ lv_match }) is readonly/hidden/system-managed and was ignored.| TO et_messages.
          ELSE.
            READ TABLE et_colmap TRANSPORTING NO FIELDS WITH KEY fieldname = lv_match.
            IF sy-subrc = 0.
              APPEND |Column '{ lv_value }' maps to field { lv_match } more than once; duplicate column was ignored.| TO et_messages.
            ELSE.
              APPEND VALUE #( column    = lv_col
                              fieldname = lv_match ) TO et_colmap.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      lv_col = lv_col + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD normalize.
    rv_norm = iv_text.
    CONDENSE rv_norm.
    TRANSLATE rv_norm TO UPPER CASE.
  ENDMETHOD.

  METHOD export_table.
    validate_table_name( iv_table_name ).
    DATA(lt_fields) = get_field_metadata( iv_table_name ).
    DATA(lr_data)   = read_table_data( iv_table_name ).
    rv_file_xstring = build_excel( it_fields          = lt_fields
                                  ir_data            = lr_data
                                  iv_table_name      = iv_table_name ).
  ENDMETHOD.

  METHOD export_template.
    validate_table_name( iv_table_name ).
    DATA(lt_fields) = get_field_metadata( iv_table_name ).
    rv_file_xstring = build_excel(
      it_fields          = lt_fields
      iv_table_name      = iv_table_name
      iv_importable_only = abap_true
      iv_tech_header     = abap_true ).
  ENDMETHOD.

  METHOD save_to_local.
    IF iv_xstring IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'File Excel rong, khong luu duoc.'.
    ENDIF.

    DATA lt_bin TYPE STANDARD TABLE OF x255.
    DATA lv_len TYPE i.
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING buffer        = iv_xstring
      IMPORTING output_length = lv_len
      TABLES    binary_tab    = lt_bin.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename     = iv_filepath
        filetype     = 'BIN'
        bin_filesize = lv_len
      CHANGING
        data_tab     = lt_bin ).
  ENDMETHOD.

  METHOD validate_table_name.
    IF iv_table_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'Table name is empty'.
    ENDIF.

    IF iv_table_name NP 'Z*' AND iv_table_name NP 'Y*'.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Only customer tables (Z*/Y*) are allowed: { iv_table_name }|.
    ENDIF.

    IF zcl_table_inspector=>table_exists( iv_table_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table not found: { iv_table_name }|.
    ENDIF.
  ENDMETHOD.

  METHOD get_field_metadata.
    rt_fields = zcl_table_inspector=>get_field_list( iv_table_name ).

    IF rt_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } chưa được config trong ZFLD_CONFIG|.
    ENDIF.
  ENDMETHOD.

  METHOD read_table_data.
    TRY.
        rr_data = zcl_dyn_record_handler=>get_table_data(
                    iv_table_name = iv_table_name
                    iv_max_rows   = 1000000 ).
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Read data failed: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD is_field_importable.
    rv_importable = is_importable_field_for_table(
      is_field      = is_field
      iv_table_name = iv_table_name
      it_fields     = it_fields ).
  ENDMETHOD.

  METHOD is_exportable_col.
    IF iv_importable_only = abap_false.
      IF is_match_only_field(
          is_field      = is_field
          iv_table_name = iv_table_name
          it_fields     = it_fields ) = abap_true.
        rv_ok = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    IF is_field-hidden_flag = abap_true OR is_field-hidden_flag = 'X'.
      rv_ok = abap_false.
      RETURN.
    ENDIF.

    IF iv_importable_only = abap_true.
      rv_ok = is_field_importable(
        is_field      = is_field
        it_fields     = it_fields
        iv_table_name = iv_table_name ).
      RETURN.
    ENDIF.

    rv_ok = abap_true.
  ENDMETHOD.

  METHOD build_excel.
    DATA lv_col       TYPE i.
    DATA lv_col_alpha TYPE zexcel_cell_column_alpha.
    DATA lv_header    TYPE string.
    DATA lv_row       TYPE i.
    DATA lv_value     TYPE string.
    DATA lt_export_cols TYPE tt_export_col.

    TRY.
        DATA(lo_excel)     = NEW zcl_excel( ).
        DATA(lo_worksheet) = lo_excel->get_active_worksheet( ).
        lo_worksheet->set_title( ip_title = 'DATA' ).

        LOOP AT it_fields INTO DATA(ls_field).
          IF is_exportable_col(
              is_field           = ls_field
              it_fields          = it_fields
              iv_table_name      = iv_table_name
              iv_importable_only = iv_importable_only ) = abap_false.
            CONTINUE.
          ENDIF.
          APPEND VALUE #(
            col_index   = lines( lt_export_cols ) + 2
            field_name  = ls_field-field_name
            domain_name = ls_field-domain_name
            is_foreign_key = is_foreign_key_field(
              iv_table_name = iv_table_name
              iv_field_name = ls_field-field_name )
            is_lov_field = is_field_importable(
              is_field      = ls_field
              it_fields     = it_fields
              iv_table_name = iv_table_name ) ) TO lt_export_cols.
        ENDLOOP.

        lo_worksheet->set_cell(
          ip_column = 'A'
          ip_row    = 1
          ip_value  = c_action_field ).

        LOOP AT lt_export_cols INTO DATA(ls_col).
          READ TABLE it_fields INTO ls_field WITH KEY field_name = ls_col-field_name.
          lv_col_alpha = zcl_excel_common=>convert_column2alpha( ls_col-col_index ).
          lv_header = COND string(
            WHEN iv_tech_header = abap_true
            THEN CONV string( ls_col-field_name )
            WHEN ls_field-label_text IS NOT INITIAL
            THEN ls_field-label_text
            ELSE CONV string( ls_col-field_name ) ).
          lo_worksheet->set_cell(
            ip_column = lv_col_alpha
            ip_row    = 1
            ip_value  = lv_header ).
        ENDLOOP.

        FIELD-SYMBOLS <lt_tab> TYPE STANDARD TABLE.
        IF ir_data IS BOUND.
          ASSIGN ir_data->* TO <lt_tab>.
        ENDIF.
        IF <lt_tab> IS ASSIGNED.
          lv_row = 2.
          LOOP AT <lt_tab> ASSIGNING FIELD-SYMBOL(<ls_row>).
            LOOP AT lt_export_cols INTO ls_col.
              READ TABLE it_fields INTO ls_field WITH KEY field_name = ls_col-field_name.
              ASSIGN COMPONENT ls_col-field_name
                OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_val>).
              IF sy-subrc = 0.
                lv_value = |{ <lv_val> }|.
              ELSE.
                CLEAR lv_value.
              ENDIF.
              lv_col_alpha = zcl_excel_common=>convert_column2alpha( ls_col-col_index ).
              lo_worksheet->set_cell(
                ip_column = lv_col_alpha
                ip_row    = lv_row
                ip_value  = lv_value ).
            ENDLOOP.
            lv_row = lv_row + 1.
          ENDLOOP.
        ENDIF.

        IF lt_export_cols IS NOT INITIAL
          AND iv_importable_only = abap_true.
          DATA lt_lov_ranges TYPE tt_lov_range.
          DATA(lo_lov_ws) = lo_excel->add_new_worksheet( ip_title = 'DOMAIN_LOV' ).
          IF lo_lov_ws IS BOUND.
            lt_lov_ranges = build_domain_lov_sheet(
              iv_table_name  = iv_table_name
              it_export_cols = lt_export_cols
              io_lov_ws      = lo_lov_ws ).
            IF lt_lov_ranges IS NOT INITIAL.
              apply_domain_validations(
                io_data_ws    = lo_worksheet
                io_lov_ws     = lo_lov_ws
                iv_table_name = iv_table_name
                it_lov_ranges = lt_lov_ranges
                it_export_cols = lt_export_cols ).
            ENDIF.
            lo_lov_ws->zif_excel_sheet_properties~hidden = zif_excel_sheet_properties=>c_hidden.
          ENDIF.
        ENDIF.

        DATA(lo_writer) = CAST zif_excel_writer( NEW zcl_excel_writer_2007( ) ).
        rv_xstring = lo_writer->write_file( lo_excel ).

      CATCH zcx_excel INTO DATA(lx_excel).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Excel build failed: { lx_excel->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD build_domain_lov_sheet.
    CLEAR rt_ranges.
    DATA lv_lov_col TYPE i VALUE 1.
    DATA lv_lov_row TYPE i.

    LOOP AT it_export_cols INTO DATA(ls_col)
      WHERE is_lov_field = abap_true
        AND ( domain_name IS NOT INITIAL OR is_foreign_key = abap_true ).
      DATA(lt_vals) = get_lov_values(
        iv_table_name = iv_table_name
        is_export_col = ls_col ).
      IF lt_vals IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_lov_alpha) = zcl_excel_common=>convert_column2alpha( lv_lov_col ).
      io_lov_ws->set_cell(
        ip_column = lv_lov_alpha
        ip_row    = 1
        ip_value  = CONV string( ls_col-field_name ) ).

      lv_lov_row = 2.
      LOOP AT lt_vals INTO DATA(lv_lov_value).
        io_lov_ws->set_cell(
          ip_column = lv_lov_alpha
          ip_row    = lv_lov_row
          ip_value  = lv_lov_value ).
        lv_lov_row = lv_lov_row + 1.
      ENDLOOP.

      IF lv_lov_row > 2.
        APPEND VALUE #(
          data_col = ls_col-col_index
          lov_col  = lv_lov_col
          last_row = lv_lov_row - 1 ) TO rt_ranges.
      ENDIF.

      lv_lov_col = lv_lov_col + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD apply_domain_validations.
    CONSTANTS c_max_data_row TYPE i VALUE 500.
    CONSTANTS c_max_inline   TYPE i VALUE 200.

    LOOP AT it_lov_ranges INTO DATA(ls_rng).
      READ TABLE it_export_cols INTO DATA(ls_col) WITH KEY col_index = ls_rng-data_col.
      CHECK sy-subrc = 0.
      CHECK ls_col-is_lov_field = abap_true.
      CHECK ls_col-domain_name IS NOT INITIAL OR ls_col-is_foreign_key = abap_true.

      DATA(lt_vals) = get_lov_values(
        iv_table_name = iv_table_name
        is_export_col = ls_col ).
      IF lt_vals IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA lv_inline TYPE string.
      LOOP AT lt_vals INTO DATA(lv_lov_value).
        IF lv_inline IS INITIAL.
          lv_inline = lv_lov_value.
        ELSE.
          lv_inline = lv_inline && ',' && lv_lov_value.
        ENDIF.
      ENDLOOP.

      IF strlen( lv_inline ) > c_max_inline.
        CONTINUE.
      ENDIF.

      DATA(lv_data_alpha) = zcl_excel_common=>convert_column2alpha( ls_rng-data_col ).
      DATA(lv_formula) = |"{ lv_inline }"|.

      TRY.
          DATA(lo_dval) = io_data_ws->add_new_data_validation( ).
          lo_dval->type = zcl_excel_data_validation=>c_type_list.
          lo_dval->formula1 = lv_formula.
          lo_dval->allowblank = abap_true.
          lo_dval->showdropdown = abap_true.
          lo_dval->cell_row = 2.
          lo_dval->cell_column = lv_data_alpha.
          lo_dval->cell_row_to = c_max_data_row.
        CATCH zcx_excel.
          CONTINUE.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD is_foreign_key_field.
    SELECT SINGLE @abap_true
      FROM dd08l
      INNER JOIN dd05s
        ON  dd05s~tabname   = dd08l~tabname
        AND dd05s~fieldname = dd08l~fieldname
        AND dd05s~as4local  = dd08l~as4local
      WHERE dd08l~tabname    = @iv_table_name
        AND dd08l~as4local   = 'A'
        AND dd05s~forkey     = @iv_field_name
        AND dd08l~checktable IS NOT INITIAL
      INTO @rv_is_fk.

    IF sy-subrc <> 0.
      rv_is_fk = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD get_lov_values.
    IF is_export_col-domain_name IS NOT INITIAL.
      DATA(lt_domain_values) =
        zcl_table_inspector=>get_domain_values( is_export_col-domain_name ).
      LOOP AT lt_domain_values INTO DATA(ls_domain_value).
        APPEND CONV string( ls_domain_value-value ) TO rt_values.
      ENDLOOP.
      IF rt_values IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF is_export_col-is_foreign_key = abap_false.
      RETURN.
    ENDIF.

    DATA lv_check_table TYPE tabname.
    DATA lv_check_field TYPE fieldname.

    SELECT SINGLE dd08l~checktable
      FROM dd08l
      INNER JOIN dd05s
        ON  dd05s~tabname   = dd08l~tabname
        AND dd05s~fieldname = dd08l~fieldname
        AND dd05s~as4local  = dd08l~as4local
      WHERE dd08l~tabname    = @iv_table_name
        AND dd08l~as4local   = 'A'
        AND dd05s~forkey     = @is_export_col-field_name
        AND dd08l~checktable IS NOT INITIAL
      INTO @lv_check_table.

    IF sy-subrc <> 0 OR lv_check_table IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE dd05s~forstring
      FROM dd05s
      INNER JOIN dd08l
        ON  dd08l~tabname   = dd05s~tabname
        AND dd08l~fieldname = dd05s~fieldname
        AND dd08l~as4local  = dd05s~as4local
      WHERE dd05s~tabname   = @iv_table_name
        AND dd05s~as4local  = 'A'
        AND dd05s~forkey    = @is_export_col-field_name
      INTO @lv_check_field.

    IF lv_check_field IS NOT INITIAL.
      SELECT SINGLE @abap_true
        FROM dd03l
        WHERE tabname   = @lv_check_table
          AND fieldname = @lv_check_field
          AND as4local  = 'A'
        INTO @DATA(lv_check_field_exists).
    ENDIF.

    IF lv_check_field IS INITIAL OR lv_check_field_exists = abap_false.
      CLEAR lv_check_field.
      DATA(lt_parent_keys) = zcl_dyn_record_handler=>get_key_fields(
        iv_table_name = lv_check_table ).
      LOOP AT lt_parent_keys INTO DATA(lv_parent_key).
        IF lv_parent_key = 'MANDT' OR lv_parent_key = 'CLIENT'.
          CONTINUE.
        ENDIF.
        lv_check_field = CONV fieldname( lv_parent_key ).
        EXIT.
      ENDLOOP.
    ENDIF.

    IF lv_check_field IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lr_check_data) = zcl_dyn_record_handler=>get_table_data(
          iv_table_name = lv_check_table
          iv_max_rows   = 1000 ).
        ASSIGN lr_check_data->* TO FIELD-SYMBOL(<lt_check_data>).

        LOOP AT <lt_check_data> ASSIGNING FIELD-SYMBOL(<ls_check_row>).
          ASSIGN COMPONENT lv_check_field OF STRUCTURE <ls_check_row>
            TO FIELD-SYMBOL(<lv_check_value>).
          IF sy-subrc <> 0 OR <lv_check_value> IS INITIAL.
            CONTINUE.
          ENDIF.

          DATA(lv_value) = |{ <lv_check_value> }|.
          DATA(lo_value_type) =
            cl_abap_typedescr=>describe_by_data( <lv_check_value> ).
          IF lo_value_type->type_kind = cl_abap_typedescr=>typekind_hex.
            CONDENSE lv_value NO-GAPS.
            TRANSLATE lv_value TO UPPER CASE.
          ENDIF.

          IF lv_value IS NOT INITIAL.
            APPEND lv_value TO rt_values.
          ENDIF.
        ENDLOOP.

        SORT rt_values.
        DELETE ADJACENT DUPLICATES FROM rt_values.
      CATCH cx_root.
        CLEAR rt_values.
    ENDTRY.
  ENDMETHOD.

  METHOD download_excel.
    CLEAR rs_res.
    rs_res-id = is_req-id.

    DATA lv_xstring TYPE xstring.
    IF is_req-template_only = abap_true.
      lv_xstring = export_template(
        CONV tabname( is_req-table_name ) ).
    ELSE.
      lv_xstring = export_table(
        CONV tabname( is_req-table_name ) ).
    ENDIF.

    rs_res-file_base64 = cl_http_utility=>encode_x_base64( lv_xstring ).
    rs_res-message     = |Download OK: { is_req-table_name }|.
  ENDMETHOD.

  METHOD upload_excel.
    CLEAR: et_diff, ev_info.

    DATA(lv_xstring) = cl_http_utility=>decode_x_base64( is_req-file_base64 ).

    parse_excel(
      EXPORTING
        iv_table_name = CONV tabname( is_req-table_name )
        iv_file       = lv_xstring
      IMPORTING
        et_rows       = DATA(lt_rows)
        et_messages   = DATA(lt_msg) ).

    DATA(lt_diff) = build_diff(
                      iv_table_name = CONV tabname( is_req-table_name )
                      it_rows       = lt_rows ).

    et_diff = diff_from_internal( lt_diff ).

    IF lt_msg IS NOT INITIAL.
      ev_info = concat_lines_of( table = lt_msg sep = |; | ).
    ENDIF.

    ev_info = |Parsed { lines( lt_rows ) } rows. { ev_info }|.
    CONDENSE ev_info.
  ENDMETHOD.

  METHOD run_confirm_import.
    CLEAR rs_res.
    rs_res-id = is_req-id.

    IF it_diff_cds IS INITIAL.
      rs_res-error_count = 1.
      rs_res-message = 'No Excel diff rows were received for commit. Please preview the Excel file again before confirming import.'.
      RETURN.
    ENDIF.

    DATA(lt_diff) = diff_to_internal( it_diff_cds ).

    DATA(ls_sum) = apply_diff_import(
                     iv_table_name = CONV tabname( is_req-table_name )
                     it_diff       = lt_diff
                     iv_do_commit  = abap_false ).

    rs_res-inserted_count  = ls_sum-inserted_count.
    rs_res-updated_count   = ls_sum-updated_count.
    rs_res-unchanged_count = ls_sum-unchanged_count.
    rs_res-skipped_count   = ls_sum-skipped_count.
    rs_res-error_count     = ls_sum-error_count.

    IF ls_sum-messages IS NOT INITIAL.
      rs_res-message = concat_lines_of( table = ls_sum-messages sep = |; | ).
    ELSE.
      rs_res-message = |Commit OK: I={ ls_sum-inserted_count }, U={ ls_sum-updated_count }|.
    ENDIF.
  ENDMETHOD.

  METHOD diff_from_internal.
    LOOP AT it_diff INTO DATA(ls).
      APPEND VALUE #(
        id         = new_diff_id( )
        row_no     = ls-row_no
        table_name = ls-table_name
        record_key = ls-record_key
        field_name = ls-fieldname
        old_value  = ls-old_value
        new_value  = ls-new_value
        status     = ls-status
        message    = ls-message ) TO rt_cds.
    ENDLOOP.
  ENDMETHOD.

  METHOD diff_to_internal.
    LOOP AT it_cds INTO DATA(ls).
      IF ls-row_no = 0 AND ls-status = 'INFO'.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        row_no     = ls-row_no
        table_name = CONV tabname( ls-table_name )
        record_key = ls-record_key
        fieldname  = CONV fieldname( ls-field_name )
        old_value  = ls-old_value
        new_value  = ls-new_value
        status     = ls-status
        message    = ls-message ) TO rt_diff.
    ENDLOOP.
  ENDMETHOD.

  METHOD new_diff_id.
    rv_id = cl_system_uuid=>create_uuid_x16_static( ).
  ENDMETHOD.

  METHOD parse_diff_json.
    IF iv_json IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = iv_json
          CHANGING  data = rt_cds ).

        IF NOT line_exists( rt_cds[ status = c_status-new ] )
           AND NOT line_exists( rt_cds[ status = c_status-changed ] )
           AND NOT line_exists( rt_cds[ status = c_status-delete ] )
           AND iv_json CS 'fieldName'.
          CLEAR rt_cds.
          /ui2/cl_json=>deserialize(
            EXPORTING json        = iv_json
                      pretty_name = /ui2/cl_json=>pretty_mode-camel_case
            CHANGING  data        = rt_cds ).
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING
            previous = lx
            iv_text  = |Invalid diff_json: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD download_excel_base64.
    DATA lv_xstring TYPE xstring.

    IF iv_template_only = abap_true.
      lv_xstring = export_template( iv_table_name ).
    ELSE.
      lv_xstring = export_table( iv_table_name ).
    ENDIF.

    rv_file_base64 = cl_http_utility=>encode_x_base64( lv_xstring ).
  ENDMETHOD.

  METHOD preview_import_base64.
    CLEAR: et_rows, et_diff, et_messages.

    DATA(lv_xstring) = cl_http_utility=>decode_x_base64( iv_file_base64 ).

    parse_excel(
      EXPORTING
        iv_table_name = iv_table_name
        iv_file       = lv_xstring
      IMPORTING
        et_rows       = et_rows
        et_messages   = et_messages ).

    et_diff = build_diff(
                iv_table_name = iv_table_name
                it_rows       = et_rows ).
  ENDMETHOD.

  METHOD confirm_import.
    rs_summary = apply_diff_import(
                   iv_table_name = iv_table_name
                   it_diff       = it_diff
                   iv_do_commit  = abap_false ).
  ENDMETHOD.

ENDCLASS.
