"! <p class="shorttext synchronized">Excel Diff Builder (Phase 3)</p>
"! So sánh các dòng Excel đã parse với data hiện có trong DB.
"! Phân loại: NEW / CHANGED / UNCHANGED / ERROR. CHƯA ghi DB.
"! Match ưu tiên ENTITY_ID (full export), fallback business key (template).
CLASS zcl_excel_diff_builder DEFINITION
PUBLIC
  FINAL
  CREATE PUBLIC.
PUBLIC SECTION.
CLASS-METHODS build_diff
      IMPORTING iv_table_name  TYPE tabname
                it_rows        TYPE zcl_excel_types=>tt_parsed_row
      RETURNING VALUE(rt_diff) TYPE zcl_excel_types=>tt_diff_row
      RAISING   zcx_excel_pipeline.

CLASS-METHODS confirm_import
      IMPORTING iv_table_name      TYPE tabname
                it_diff            TYPE zcl_excel_types=>tt_diff_row
                iv_do_commit       TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rs_summary)  TYPE zcl_excel_types=>ty_summary
      RAISING   zcx_excel_pipeline.

PRIVATE SECTION.
CONSTANTS c_action_field TYPE fieldname VALUE '__ACTION'.
    CONSTANTS c_snapshot_field TYPE fieldname VALUE '__SNAPSHOT'.

    CLASS-METHODS validate_row
      IMPORTING iv_table_name      TYPE tabname
                it_fields          TYPE zcl_table_inspector=>tt_field_info
                it_cells           TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rt_errors) TYPE string_table.

    CLASS-METHODS build_file_key
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rv_key) TYPE string.

    CLASS-METHODS get_key_problem
      IMPORTING iv_table_name      TYPE tabname
                iv_entity_id_field TYPE fieldname
                it_biz_keys        TYPE string_table
                it_cells           TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rv_message)  TYPE string.

    CLASS-METHODS append_new_diff
      IMPORTING iv_row_no     TYPE i
                iv_table_name TYPE tabname
                iv_record_key TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
      CHANGING  ct_diff       TYPE zcl_excel_types=>tt_diff_row.

    CLASS-METHODS append_compare_diff
      IMPORTING iv_row_no     TYPE i
                iv_table_name TYPE tabname
                iv_record_key TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
                ir_db_row     TYPE REF TO data
      CHANGING  ct_diff       TYPE zcl_excel_types=>tt_diff_row
      RETURNING VALUE(rv_changed) TYPE abap_bool.

TYPES: BEGIN OF ty_group,
             row_no     TYPE i,
             record_key TYPE string,
             status     TYPE c LENGTH 10,
             cells      TYPE zcl_excel_types=>tt_cell,
           END OF ty_group,
           tt_group TYPE HASHED TABLE OF ty_group WITH UNIQUE KEY row_no record_key status.

    CLASS-METHODS submit_groups
      IMPORTING iv_table_name TYPE tabname
                it_groups     TYPE tt_group
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      CHANGING  cs_summary    TYPE zcl_excel_types=>ty_summary
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS mark_preview_conflicts
      IMPORTING iv_table_name TYPE tabname
      CHANGING  ct_diff       TYPE zcl_excel_types=>tt_diff_row.

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

    "! Set admin field do hệ thống quản lý khi INSERT (create).
    "! CREATED_BY/LAST_CHANGED_BY = sy-uname; CREATED_AT/LAST_CHANGED_AT/LOCAL_LAST_CHANGED_AT = now.
    "! Bổ sung admin field vào SET clause khi UPDATE (chỉ LAST_CHANGED_*).
    "! Chỉ thêm field thực sự tồn tại trong cấu trúc bảng.
    CLASS-METHODS append_admin_on_update
      IMPORTING iv_table_name TYPE tabname
      CHANGING  cv_set        TYPE string.
ENDCLASS.


CLASS zcl_excel_diff_builder IMPLEMENTATION.
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
    lt_biz_keys = zcl_excel_types=>get_match_key_fields(
                    it_fields     = lt_fields
                    iv_table_name = iv_table_name ).
    DATA(lv_eid_f) = zcl_excel_types=>get_entity_id_field( iv_table_name ).

    IF lt_biz_keys IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } has no importable key field for Excel diff. | &&
                            |Set IS_KEY_FIELD = X for the business key in ZFLD_CONFIG.|.
    ENDIF.

    " Đếm key trùng trong file (ENTITY_ID hoặc business key)
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

      IF get_key_problem(
           iv_table_name      = iv_table_name
           iv_entity_id_field = lv_eid_f
           it_biz_keys        = lt_biz_keys
           it_cells           = ls_pre-cells ) IS NOT INITIAL.
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
                        status     = zcl_excel_types=>c_status-error
                        message    = lv_key_problem ) TO rt_diff.
        CONTINUE.
      ENDIF.

      READ TABLE lt_kc INTO DATA(ls_kc) WITH KEY rkey = lv_fkey.
      IF sy-subrc = 0 AND ls_kc-cnt > 1.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_fkey
                        status     = zcl_excel_types=>c_status-error
                        message    = |Duplicate key in uploaded file ({ ls_kc-cnt } rows with the same key). Fix duplicate key { lv_fkey } before import.| ) TO rt_diff.
        CONTINUE.
      ENDIF.

      DATA(lv_requested_action) = zcl_excel_types=>get_cell_value(
        it_cells = ls_row-cells
        iv_field = c_action_field ).
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
                        status     = zcl_excel_types=>c_status-error
                        message    = |Invalid __ACTION '{ lv_requested_action }'. Allowed values: C, CREATE, U, UPDATE, D, DELETE.| ) TO rt_diff.
        CONTINUE.
      ENDIF.

      IF lv_requested_action = 'D' OR lv_requested_action = 'DELETE'.
        DATA(lv_del_where) = zcl_excel_types=>build_where_from_cells(
          iv_table_name = iv_table_name
          it_fields     = lt_fields
          it_cells      = ls_row-cells ).

        IF lv_del_where IS INITIAL.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = zcl_excel_types=>c_status-error
                          message    = |Cannot identify record to delete for table { iv_table_name }. Check key columns.| ) TO rt_diff.
          CONTINUE.
        ENDIF.

        TRY.
            DATA(lr_del_db) = zcl_dyn_record_handler=>get_single_record(
              iv_table_name = iv_table_name
              iv_where      = lv_del_where ).

            DATA(lv_del_key) = zcl_excel_types=>build_record_key_json(
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
                            status     = zcl_excel_types=>c_status-delete
                            message    = 'Record marked for deletion by __ACTION.' ) TO rt_diff.
          CATCH cx_root INTO DATA(lx_del).
            APPEND VALUE #( row_no     = ls_row-row_no
                            table_name = iv_table_name
                            record_key = lv_fkey
                            status     = zcl_excel_types=>c_status-error
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
                          status     = zcl_excel_types=>c_status-error
                          message    = lv_emsg ) TO rt_diff.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      DATA lv_missing_key TYPE abap_bool VALUE abap_false.
      DATA(lv_has_eid) = abap_false.
      IF lv_eid_f IS NOT INITIAL.
        IF zcl_excel_types=>get_cell_value( it_cells = ls_row-cells iv_field = lv_eid_f ) IS NOT INITIAL.
          lv_has_eid = abap_true.
        ENDIF.
      ENDIF.

      IF lv_has_eid = abap_false.
        LOOP AT lt_biz_keys INTO DATA(lv_k).
          IF zcl_excel_types=>get_cell_value(
               it_cells = ls_row-cells iv_field = CONV #( lv_k ) ) IS INITIAL.
            lv_missing_key = abap_true.
          ENDIF.
        ENDLOOP.
        IF lv_missing_key = abap_true.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = zcl_excel_types=>c_status-error
                          message    = |Missing key value for table { iv_table_name }. Fill all key columns before import.| ) TO rt_diff.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA(lv_where) = zcl_excel_types=>build_where_from_cells(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).

      IF lv_where IS INITIAL.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_fkey
                        status     = zcl_excel_types=>c_status-error
                        message    = |Cannot identify target record for table { iv_table_name }. Check key columns in the uploaded file.| ) TO rt_diff.
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
                          status     = zcl_excel_types=>c_status-error
                          message    = |Database read failed for { iv_table_name }: { lx->get_text( ) }| ) TO rt_diff.
          CONTINUE.
      ENDTRY.

      IF lv_db_ok = abap_false.
        IF lv_has_eid = abap_true.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = zcl_excel_types=>c_status-error
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

      DATA(lv_rkey) = zcl_excel_types=>build_record_key_json(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        ir_row        = lr_db ).

      DATA(lv_collision) = zcl_excel_types=>check_business_key_collision(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        ir_db_row     = lr_db
        it_cells      = ls_row-cells ).

      IF lv_collision IS NOT INITIAL.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_rkey
                        status     = zcl_excel_types=>c_status-error
                        message    = lv_collision ) TO rt_diff.
        CONTINUE.
      ENDIF.

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
                        status     = zcl_excel_types=>c_status-unchanged
                        message    = 'No changes detected' ) TO rt_diff.
      ENDIF.

    ENDLOOP.

    mark_preview_conflicts(
      EXPORTING iv_table_name = iv_table_name
      CHANGING  ct_diff       = rt_diff ).
  ENDMETHOD.


  METHOD build_file_key.
    rv_key = zcl_excel_types=>build_record_key_json(
      iv_table_name = iv_table_name
      it_fields     = it_fields
      it_cells      = it_cells ).
  ENDMETHOD.


  METHOD get_key_problem.
    IF iv_entity_id_field IS NOT INITIAL.
      DATA(lv_eid) = zcl_excel_types=>get_cell_value(
        it_cells = it_cells
        iv_field = iv_entity_id_field ).
      IF lv_eid IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    DATA lt_missing_columns TYPE string_table.
    DATA lt_empty_values TYPE string_table.

    LOOP AT it_biz_keys INTO DATA(lv_key).
      READ TABLE it_cells TRANSPORTING NO FIELDS
        WITH KEY fieldname = CONV fieldname( lv_key ).

      IF sy-subrc <> 0.
        APPEND lv_key TO lt_missing_columns.
        CONTINUE.
      ENDIF.

      DATA(lv_value) = zcl_excel_types=>get_cell_value(
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


  METHOD append_new_diff.
    DATA lt_seen TYPE string_table.
    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0 OR zcl_excel_types=>is_diff_comparable_field(
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
                      status     = zcl_excel_types=>c_status-new ) TO ct_diff.
    ENDLOOP.
  ENDMETHOD.


  METHOD append_compare_diff.
    rv_changed = abap_false.
    ASSIGN ir_db_row->* TO FIELD-SYMBOL(<db_row>).
    DATA lt_seen TYPE string_table.

    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0 OR zcl_excel_types=>is_diff_comparable_field(
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
                        status     = zcl_excel_types=>c_status-changed ) TO ct_diff.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_row.
    LOOP AT it_fields INTO DATA(ls_field).
      IF zcl_excel_types=>is_diff_comparable_field(
           is_field      = ls_field
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_val) = zcl_excel_types=>get_cell_value(
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

      IF ls_field-domain_name IS NOT INITIAL.
        DATA(lt_vals) = zcl_table_inspector=>get_domain_values( ls_field-domain_name ).
        IF lt_vals IS NOT INITIAL.
          READ TABLE lt_vals TRANSPORTING NO FIELDS WITH KEY value = lv_val.
          IF sy-subrc <> 0.
            APPEND |Field { ls_field-field_name } value '{ lv_val }' is not allowed by domain { ls_field-domain_name }.| TO rt_errors.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

METHOD confirm_import.
    CLEAR rs_summary.

    " 0) Check approval flag
    SELECT SINGLE approval_required
      FROM ztbl_config
      WHERE table_name = @iv_table_name
        AND active_flag = @abap_true
      INTO @DATA(lv_appr_req).
    DATA lv_approval_mode TYPE abap_bool.
    lv_approval_mode = COND #( WHEN sy-subrc = 0 AND lv_appr_req = abap_true THEN abap_true ELSE abap_false ).

    " 1) Pre-count theo status
    LOOP AT it_diff INTO DATA(ls_diff0).
      CASE ls_diff0-status.
        WHEN zcl_excel_types=>c_status-unchanged.
          rs_summary-unchanged_count = rs_summary-unchanged_count + 1.
        WHEN zcl_excel_types=>c_status-skipped.
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
        WHEN zcl_excel_types=>c_status-error.
          rs_summary-error_count = rs_summary-error_count + 1.
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
      ENDCASE.
    ENDLOOP.

    " 2) Gom NEW/CHANGED/DELETE thành group theo record_key
    DATA lt_groups TYPE tt_group.
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    DATA lt_error_groups TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT it_diff INTO DATA(ls_error_diff)
      WHERE status = zcl_excel_types=>c_status-error.
      INSERT |{ ls_error_diff-row_no }#{ ls_error_diff-record_key }| INTO TABLE lt_error_groups.
    ENDLOOP.

    LOOP AT it_diff INTO DATA(ls_diff)
      WHERE ( status = zcl_excel_types=>c_status-new
           OR status = zcl_excel_types=>c_status-changed
           OR status = zcl_excel_types=>c_status-delete )
        AND fieldname IS NOT INITIAL.

      READ TABLE lt_error_groups TRANSPORTING NO FIELDS
        WITH TABLE KEY table_line = |{ ls_diff-row_no }#{ ls_diff-record_key }|.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      IF ls_diff-status <> zcl_excel_types=>c_status-delete
         AND ls_diff-fieldname <> c_snapshot_field.
        READ TABLE lt_fields INTO DATA(ls_f_commit) WITH KEY field_name = ls_diff-fieldname.
        IF sy-subrc = 0 AND zcl_excel_types=>is_importable_field_for_table(
          is_field      = ls_f_commit
          iv_table_name = iv_table_name
          it_fields     = lt_fields ) = abap_false.
          CONTINUE.
        ENDIF.
        IF sy-subrc <> 0 AND zcl_excel_types=>is_admin_field( ls_diff-fieldname ) = abap_true.
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

      " Khử trùng fieldname: mỗi field chỉ vào group 1 lần (tránh UPDATE SET lặp cột)
      READ TABLE <g>-cells TRANSPORTING NO FIELDS WITH KEY fieldname = ls_diff-fieldname.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        fieldname = ls_diff-fieldname
        value     = COND string(
          WHEN ls_diff-status = zcl_excel_types=>c_status-delete
            OR ls_diff-fieldname = c_snapshot_field
          THEN ls_diff-old_value
          ELSE ls_diff-new_value ) ) TO <g>-cells.
    ENDLOOP.

    IF lt_groups IS INITIAL.
      APPEND 'Không có dòng NEW/CHANGED/DELETE để commit.' TO rs_summary-messages.
      RETURN.
    ENDIF.

    " 3) Key fields dùng match (business key từ ZFLD_CONFIG)
    DATA lt_keys TYPE string_table.
    lt_keys = zcl_excel_types=>get_match_key_fields(
                it_fields     = lt_fields
                iv_table_name = iv_table_name ).

    IF lt_keys IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } không có key field importable để commit|.
    ENDIF.

    " 3b) approval_required → gửi ZTBL_APRVL, không ghi bảng nghiệp vụ
    IF lv_approval_mode = abap_true.
      DATA(lt_aprvl_groups) = CORRESPONDING zcl_excel_diff_builder=>tt_group( lt_groups ).
      zcl_excel_diff_builder=>submit_groups(
        EXPORTING iv_table_name = iv_table_name
                  it_groups     = lt_aprvl_groups
                  it_fields     = lt_fields
        CHANGING  cs_summary    = rs_summary ).

      IF iv_do_commit = abap_true.
        COMMIT WORK AND WAIT.
      ENDIF.

      APPEND |Đã gửi duyệt: C={ rs_summary-inserted_count }, U/D={ rs_summary-updated_count }, E={ rs_summary-error_count }. Chờ Approve trên UI.| TO rs_summary-messages.
      RETURN.
    ENDIF.

    " 4) Loop commit từng group (không fail cả batch)
    LOOP AT lt_groups INTO DATA(ls_group).
      TRY.
          CASE ls_group-status.
            WHEN zcl_excel_types=>c_status-new.
              DATA lv_new_json TYPE string.
              DATA lr_new_rec TYPE REF TO data.
              zcl_excel_types=>build_merged_record(
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

              LOOP AT ls_group-cells INTO DATA(ls_cell_new).
                READ TABLE lt_fields INTO DATA(ls_f_new) WITH KEY field_name = ls_cell_new-fieldname.
                IF sy-subrc <> 0 OR zcl_excel_types=>is_diff_comparable_field(
                  is_field = ls_f_new iv_table_name = iv_table_name it_fields = lt_fields ) = abap_false.
                  CONTINUE.
                ENDIF.
                zcl_aprvl_util=>log_change(
                  iv_table_name  = CONV ztde_table_name( iv_table_name )
                  iv_record_key  = CONV ztde_record_key( ls_group-record_key )
                  iv_field_name  = CONV ztde_field_name( ls_cell_new-fieldname )
                  iv_old_value   = ''
                  iv_new_value   = ls_cell_new-value
                  iv_action_type = zcl_excel_types=>c_action-create ).
              ENDLOOP.

            WHEN zcl_excel_types=>c_status-changed.
              DATA(lv_where) = zcl_excel_types=>build_where_from_record_key(
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

                " Khi WHERE theo ENTITY_ID, cho phép UPDATE cả business key
                IF lv_eid_where = abap_false.
                  READ TABLE lt_keys TRANSPORTING NO FIELDS
                    WITH KEY table_line = CONV string( ls_cell_chg-fieldname ).
                  IF sy-subrc = 0.
                    CONTINUE.
                  ENDIF.
                ENDIF.

                READ TABLE lt_fields INTO DATA(ls_f_upd) WITH KEY field_name = ls_cell_chg-fieldname.
                IF sy-subrc <> 0 OR zcl_excel_types=>is_diff_comparable_field(
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

              " Admin field do hệ thống set khi UPDATE (LAST_CHANGED_*)
              append_admin_on_update(
                EXPORTING iv_table_name = iv_table_name
                CHANGING  cv_set        = lv_set ).

              UPDATE (iv_table_name)
                SET (lv_set)
                WHERE (lv_where).
              rs_summary-updated_count = rs_summary-updated_count + 1.

              LOOP AT ls_group-cells INTO ls_cell_chg.
                IF lv_eid_where = abap_false.
                  READ TABLE lt_keys TRANSPORTING NO FIELDS
                    WITH KEY table_line = CONV string( ls_cell_chg-fieldname ).
                  IF sy-subrc = 0.
                    CONTINUE.
                  ENDIF.
                ENDIF.
                READ TABLE lt_fields INTO DATA(ls_f_aud) WITH KEY field_name = ls_cell_chg-fieldname.
                IF sy-subrc <> 0 OR zcl_excel_types=>is_diff_comparable_field(
                  is_field = ls_f_aud iv_table_name = iv_table_name it_fields = lt_fields ) = abap_false.
                  CONTINUE.
                ENDIF.
                zcl_aprvl_util=>log_change(
                  iv_table_name  = CONV ztde_table_name( iv_table_name )
                  iv_record_key  = CONV ztde_record_key( ls_group-record_key )
                  iv_field_name  = CONV ztde_field_name( ls_cell_chg-fieldname )
                  iv_old_value   = ''
                  iv_new_value   = ls_cell_chg-value
                  iv_action_type = zcl_excel_types=>c_action-update ).
              ENDLOOP.

            WHEN zcl_excel_types=>c_status-delete.
              DATA(lv_where_del) = zcl_excel_types=>build_where_from_record_key(
                                     iv_table_name = iv_table_name
                                     iv_record_key = ls_group-record_key
                                     it_fields     = lt_fields ).

              DATA(lv_old_json_del) = zcl_excel_types=>get_cell_value(
                it_cells = ls_group-cells
                iv_field = c_action_field ).

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
                  iv_action_type = zcl_excel_types=>c_action-delete ).
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
    DATA(lt_wk) = zcl_excel_types=>get_where_key_fields(
      iv_table_name = iv_table_name
      it_fields     = it_fields
      iv_record_key = iv_record_key ).
    DATA(lv_eid) = zcl_excel_types=>get_entity_id_field( iv_table_name ).
    rv_yes = COND #(
      WHEN lv_eid IS NOT INITIAL
       AND line_exists( lt_wk[ table_line = CONV string( lv_eid ) ] )
      THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD append_admin_on_update.
    " Dummy work area để kiểm tra field có tồn tại trong bảng
    DATA lr_wa TYPE REF TO data.
    CREATE DATA lr_wa TYPE (iv_table_name).
    ASSIGN lr_wa->* TO FIELD-SYMBOL(<wa>).

    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    DATA(lv_ts_c) = |{ lv_ts }|.

    " LAST_CHANGED_BY = sy-uname
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
    DATA lt_items TYPE zcl_excel_bulk_aprvl=>tt_item.
    DATA lv_item_no TYPE n LENGTH 6.

    LOOP AT it_groups INTO DATA(ls_group).
      TRY.
          DATA(lv_action) = COND ztde_action_type(
            WHEN ls_group-status = zcl_excel_types=>c_status-new
            THEN zcl_excel_types=>c_action-create
            WHEN ls_group-status = zcl_excel_types=>c_status-changed
            THEN zcl_excel_types=>c_action-update
            WHEN ls_group-status = zcl_excel_types=>c_status-delete
            THEN zcl_excel_types=>c_action-delete
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

          IF ls_group-status = zcl_excel_types=>c_status-delete.
            lv_old_json = zcl_excel_types=>get_cell_value(
              it_cells = ls_group-cells
              iv_field = c_action_field ).

            assert_current_state(
              iv_table_name  = iv_table_name
              iv_action_type = lv_action
              iv_record_key  = CONV ztde_record_key( lv_record_key )
              iv_old_data    = lv_old_json ).

            CLEAR lv_new_json.
          ELSE.
            IF ls_group-status = zcl_excel_types=>c_status-changed.
              lv_old_json = zcl_excel_types=>get_cell_value(
                it_cells = ls_group-cells
                iv_field = c_snapshot_field ).
              IF lv_old_json IS INITIAL.
                lv_old_json = get_current_snapshot(
                  iv_table_name = iv_table_name
                  iv_record_key = CONV ztde_record_key( lv_record_key ) ).
              ENDIF.
            ENDIF.

            IF ls_group-status = zcl_excel_types=>c_status-new.
              assert_current_state(
                iv_table_name  = iv_table_name
                iv_action_type = lv_action
                iv_record_key  = CONV ztde_record_key( lv_record_key ) ).
            ENDIF.

            zcl_excel_types=>build_merged_record(
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

            IF ls_group-status = zcl_excel_types=>c_status-new.
              lv_record_key = zcl_excel_types=>build_record_key_json(
                iv_table_name = iv_table_name
                it_fields     = it_fields
                ir_row        = lr_rec ).
            ELSEIF ls_group-status = zcl_excel_types=>c_status-changed.
              assert_current_state(
                iv_table_name  = iv_table_name
                iv_action_type = lv_action
                iv_record_key  = CONV ztde_record_key( lv_record_key )
                iv_old_data    = lv_old_json ).
            ENDIF.

            zcl_excel_types=>validate_approval_json(
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

          IF lv_action = zcl_excel_types=>c_action-create.
            cs_summary-inserted_count = cs_summary-inserted_count + 1.
          ELSEIF lv_action = zcl_excel_types=>c_action-update.
            cs_summary-updated_count = cs_summary-updated_count + lines( ls_group-cells ).
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

    DATA(ls_submit) = zcl_excel_bulk_aprvl=>submit_bulk(
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
    DATA lt_extra TYPE zcl_excel_types=>tt_diff_row.

    LOOP AT ct_diff INTO DATA(ls_diff)
      WHERE status = zcl_excel_types=>c_status-new
         OR status = zcl_excel_types=>c_status-changed
         OR status = zcl_excel_types=>c_status-delete.
      DATA(lv_group_key) = |{ ls_diff-row_no }#{ ls_diff-record_key }|.
      INSERT lv_group_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      TRY.
          assert_no_pending_conflict(
            iv_table_name = CONV ztde_table_name( iv_table_name )
            iv_record_key = CONV ztde_record_key( ls_diff-record_key ) ).

          IF ls_diff-status = zcl_excel_types=>c_status-changed.
            DATA(lv_snapshot) = get_current_snapshot(
              iv_table_name = iv_table_name
              iv_record_key = CONV ztde_record_key( ls_diff-record_key ) ).
            APPEND VALUE #(
              row_no     = ls_diff-row_no
              table_name = iv_table_name
              record_key = ls_diff-record_key
              fieldname  = c_snapshot_field
              old_value  = lv_snapshot
              status     = zcl_excel_types=>c_status-changed ) TO lt_extra.
          ENDIF.
        CATCH zcx_excel_pipeline INTO DATA(lx_conflict).
          APPEND VALUE #(
            row_no     = ls_diff-row_no
            table_name = iv_table_name
            record_key = ls_diff-record_key
            status     = zcl_excel_types=>c_status-error
            message    = lx_conflict->get_text( ) ) TO lt_extra.
      ENDTRY.
    ENDLOOP.

    APPEND LINES OF lt_extra TO ct_diff.
  ENDMETHOD.

  METHOD assert_no_pending_conflict.
    zcl_aprvl_util=>assert_no_conflicting_pending(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key ).
  ENDMETHOD.

  METHOD get_current_snapshot.
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    DATA(lv_where) = zcl_excel_types=>build_where_from_record_key(
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

    IF iv_action_type = zcl_excel_types=>c_action-create.
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

ENDCLASS.

