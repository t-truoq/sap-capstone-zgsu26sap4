"! <p class="shorttext synchronized">Excel Committer (Phase 4)</p>
"! Nhận diff preview và ghi DB sau khi user confirm.
"! Chỉ xử lý NEW/CHANGED, bỏ qua ERROR/UNCHANGED.
"! Có check approval_required trong ZTBL_CONFIG.
CLASS zcl_excel_committer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS confirm_import
      IMPORTING iv_table_name      TYPE tabname
                it_diff            TYPE zcl_excel_types=>tt_diff_row
      RETURNING VALUE(rs_summary)  TYPE zcl_excel_types=>ty_summary
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_group,
             row_no     TYPE i,
             record_key TYPE string,
             status     TYPE c LENGTH 10,
             cells      TYPE zcl_excel_types=>tt_cell,
           END OF ty_group,
           tt_group TYPE HASHED TABLE OF ty_group WITH UNIQUE KEY row_no record_key status.

    CLASS-METHODS build_where_from_record_key
      IMPORTING iv_table_name     TYPE tabname
                iv_record_key     TYPE string
                it_keys           TYPE zcl_dynamic_table_reader=>tt_string_table
      RETURNING VALUE(rv_where)   TYPE string
      RAISING   zcx_excel_pipeline.

    "! Set admin field do hệ thống quản lý khi INSERT (create).
    "! CREATED_BY/LAST_CHANGED_BY = sy-uname; CREATED_AT/LAST_CHANGED_AT/LOCAL_LAST_CHANGED_AT = now.
    CLASS-METHODS set_admin_on_insert
      CHANGING cs_record TYPE any.

    "! Bổ sung admin field vào SET clause khi UPDATE (chỉ LAST_CHANGED_*).
    "! Chỉ thêm field thực sự tồn tại trong cấu trúc bảng.
    CLASS-METHODS append_admin_on_update
      IMPORTING iv_table_name TYPE tabname
      CHANGING  cv_set        TYPE string.

ENDCLASS.


CLASS zcl_excel_committer IMPLEMENTATION.

  METHOD confirm_import.
    CLEAR rs_summary.

    " 0) Check approval flag
    SELECT SINGLE approval_required
      FROM ztbl_config
      WHERE table_name = @iv_table_name
        AND active_flag = @abap_true
      INTO @DATA(lv_appr_req).
    IF sy-subrc = 0 AND lv_appr_req = abap_true.
      rs_summary-skipped_count = lines( it_diff ).
      APPEND |Bảng { iv_table_name } đang bật approval_required: chưa commit trực tiếp.| TO rs_summary-messages.
      RETURN.
    ENDIF.

    " 1) Pre-count theo status
    LOOP AT it_diff INTO DATA(ls_diff0).
      CASE ls_diff0-status.
        WHEN zcl_excel_types=>c_status-unchanged.
          rs_summary-unchanged_count = rs_summary-unchanged_count + 1.
        WHEN zcl_excel_types=>c_status-error.
          rs_summary-error_count = rs_summary-error_count + 1.
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
      ENDCASE.
    ENDLOOP.

    " 2) Gom NEW/CHANGED thành group theo record_key
    DATA lt_groups TYPE tt_group.

    LOOP AT it_diff INTO DATA(ls_diff)
      WHERE ( status = zcl_excel_types=>c_status-new OR status = zcl_excel_types=>c_status-changed )
        AND fieldname IS NOT INITIAL.

      " Bỏ qua field do hệ thống quản lý (CREATED_*/LAST_CHANGED_*) — không lấy từ Excel
      IF zcl_excel_types=>is_admin_field( ls_diff-fieldname ) = abap_true.
        CONTINUE.
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

      APPEND VALUE #( fieldname = ls_diff-fieldname
                      value     = ls_diff-new_value ) TO <g>-cells.
    ENDLOOP.

    IF lt_groups IS INITIAL.
      APPEND 'Không có dòng NEW/CHANGED để commit.' TO rs_summary-messages.
      RETURN.
    ENDIF.

    " 3) Key fields (trừ client)
    DATA(lt_keys_all) = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
    DATA lt_keys TYPE zcl_dynamic_table_reader=>tt_string_table.
    LOOP AT lt_keys_all INTO DATA(lv_k).
      IF lv_k <> 'MANDT' AND lv_k <> 'CLIENT'.
        APPEND lv_k TO lt_keys.
      ENDIF.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } không có key field để commit|.
    ENDIF.

    " 4) Loop commit từng group (không fail cả batch)
    LOOP AT lt_groups INTO DATA(ls_group).
      TRY.
          CASE ls_group-status.
            WHEN zcl_excel_types=>c_status-new.
              DATA lr_wa TYPE REF TO data.
              CREATE DATA lr_wa TYPE (iv_table_name).
              ASSIGN lr_wa->* TO FIELD-SYMBOL(<wa_new>).

              DATA lt_seen_new TYPE string_table.
              CLEAR lt_seen_new.
              LOOP AT ls_group-cells INTO DATA(ls_cell_new).
                READ TABLE lt_seen_new TRANSPORTING NO FIELDS
                  WITH KEY table_line = CONV string( ls_cell_new-fieldname ).
                IF sy-subrc = 0.
                  CONTINUE.
                ENDIF.
                APPEND CONV string( ls_cell_new-fieldname ) TO lt_seen_new.

                ASSIGN COMPONENT ls_cell_new-fieldname OF STRUCTURE <wa_new> TO FIELD-SYMBOL(<v_new>).
                IF sy-subrc = 0.
                  <v_new> = ls_cell_new-value.
                ENDIF.
              ENDLOOP.

              " Admin field do hệ thống set (không lấy từ Excel)
              set_admin_on_insert( CHANGING cs_record = <wa_new> ).

              INSERT (iv_table_name) FROM @<wa_new>.
              rs_summary-inserted_count = rs_summary-inserted_count + 1.

              LOOP AT ls_group-cells INTO ls_cell_new.
                zcl_audit_logger=>log_change(
                  iv_table_name  = CONV ztde_table_name( iv_table_name )
                  iv_record_key  = CONV ztde_record_key( ls_group-record_key )
                  iv_field_name  = CONV ztde_field_name( ls_cell_new-fieldname )
                  iv_old_value   = ''
                  iv_new_value   = ls_cell_new-value
                  iv_action_type = zcl_excel_types=>c_action-create ).
              ENDLOOP.

            WHEN zcl_excel_types=>c_status-changed.
              DATA(lv_where) = build_where_from_record_key(
                                 iv_table_name = iv_table_name
                                 iv_record_key = ls_group-record_key
                                 it_keys       = lt_keys ).

              DATA lv_set TYPE string.
              DATA lt_seen_set TYPE string_table.
              CLEAR lv_set.
              CLEAR lt_seen_set.
              LOOP AT ls_group-cells INTO DATA(ls_cell_chg).
                " Không update client field
                IF ls_cell_chg-fieldname = 'MANDT' OR ls_cell_chg-fieldname = 'CLIENT'.
                  CONTINUE.
                ENDIF.

                " Không update key field
                READ TABLE lt_keys TRANSPORTING NO FIELDS WITH KEY table_line = CONV string( ls_cell_chg-fieldname ).
                IF sy-subrc = 0.
                  CONTINUE.
                ENDIF.

                " Khử trùng: mỗi field chỉ xuất hiện 1 lần trong SET
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
                READ TABLE lt_keys TRANSPORTING NO FIELDS WITH KEY table_line = CONV string( ls_cell_chg-fieldname ).
                IF sy-subrc = 0.
                  CONTINUE.
                ENDIF.
                zcl_audit_logger=>log_change(
                  iv_table_name  = CONV ztde_table_name( iv_table_name )
                  iv_record_key  = CONV ztde_record_key( ls_group-record_key )
                  iv_field_name  = CONV ztde_field_name( ls_cell_chg-fieldname )
                  iv_old_value   = ''
                  iv_new_value   = ls_cell_chg-value
                  iv_action_type = zcl_excel_types=>c_action-update ).
              ENDLOOP.

          ENDCASE.

        CATCH cx_root INTO DATA(lx).
          rs_summary-error_count = rs_summary-error_count + 1.
          rs_summary-skipped_count = rs_summary-skipped_count + 1.
          APPEND |Row { ls_group-row_no } commit lỗi: { lx->get_text( ) }| TO rs_summary-messages.
      ENDTRY.
    ENDLOOP.

    COMMIT WORK AND WAIT.
    APPEND |Commit xong: I={ rs_summary-inserted_count }, U={ rs_summary-updated_count }, E={ rs_summary-error_count }.| TO rs_summary-messages.
  ENDMETHOD.


  METHOD build_where_from_record_key.
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
    LOOP AT it_keys INTO DATA(lv_k).
      ASSIGN COMPONENT lv_k OF STRUCTURE <rec> TO FIELD-SYMBOL(<kv>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_val) = |{ <kv> }|.
      REPLACE ALL OCCURRENCES OF |'| IN lv_val WITH |''|.
      DATA(lv_cond) = |{ lv_k } = '{ lv_val }'|.
      IF rv_where IS INITIAL.
        rv_where = lv_cond.
      ELSE.
        rv_where = rv_where && ` AND ` && lv_cond.
      ENDIF.
    ENDLOOP.

    IF rv_where IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'Không build được WHERE từ record_key.'.
    ENDIF.
  ENDMETHOD.


  METHOD set_admin_on_insert.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    FIELD-SYMBOLS <f> TYPE any.

    " User fields
    ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.

    ASSIGN COMPONENT 'LAST_CHANGED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.

    " Timestamp fields
    ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = lv_ts. ENDIF.

    ASSIGN COMPONENT 'LAST_CHANGED_AT' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = lv_ts. ENDIF.

    ASSIGN COMPONENT 'LOCAL_LAST_CHANGED_AT' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = lv_ts. ENDIF.
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
  ENDMETHOD.

ENDCLASS.

