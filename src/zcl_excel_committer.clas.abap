"! <p class="shorttext synchronized">Excel Committer (Phase 4)</p>
"! Nhận diff preview và ghi DB sau khi user confirm.
"! Chỉ xử lý NEW/CHANGED/DELETE, bỏ qua ERROR/UNCHANGED.
"! Có check approval_required trong ZTBL_CONFIG.
CLASS zcl_excel_committer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS confirm_import
      IMPORTING iv_table_name      TYPE tabname
                it_diff            TYPE zcl_excel_types=>tt_diff_row
                iv_do_commit       TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rs_summary)  TYPE zcl_excel_types=>ty_summary
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.

    CONSTANTS c_action_field TYPE fieldname VALUE '__ACTION'.

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
                it_fields         TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_where)   TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS uses_entity_id_where
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                iv_record_key TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool
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
    DATA lv_approval_mode TYPE abap_bool.
    lv_approval_mode = COND #( WHEN sy-subrc = 0 AND lv_appr_req = abap_true THEN abap_true ELSE abap_false ).

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

    " 2) Gom NEW/CHANGED/DELETE thành group theo record_key
    DATA lt_groups TYPE tt_group.
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).

    LOOP AT it_diff INTO DATA(ls_diff)
      WHERE ( status = zcl_excel_types=>c_status-new
           OR status = zcl_excel_types=>c_status-changed
           OR status = zcl_excel_types=>c_status-delete )
        AND fieldname IS NOT INITIAL.

      IF ls_diff-status <> zcl_excel_types=>c_status-delete.
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
      DATA(lt_aprvl_groups) = CORRESPONDING zcl_excel_aprvl_bridge=>tt_group( lt_groups ).
      zcl_excel_aprvl_bridge=>submit_groups(
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
              zcl_excel_record_builder=>build_merged_record(
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
                zcl_audit_logger=>log_change(
                  iv_table_name  = CONV ztde_table_name( iv_table_name )
                  iv_record_key  = CONV ztde_record_key( ls_group-record_key )
                  iv_field_name  = CONV ztde_field_name( ls_cell_chg-fieldname )
                  iv_old_value   = ''
                  iv_new_value   = ls_cell_chg-value
                  iv_action_type = zcl_excel_types=>c_action-update ).
              ENDLOOP.

            WHEN zcl_excel_types=>c_status-delete.
              DATA(lv_where_del) = build_where_from_record_key(
                                     iv_table_name = iv_table_name
                                     iv_record_key = ls_group-record_key
                                     it_fields     = lt_fields ).

              DATA(lv_old_json_del) = zcl_excel_types=>get_cell_value(
                it_cells = ls_group-cells
                iv_field = c_action_field ).

              DATA(lv_fk_error_del) = zcl_dynamic_table_reader=>check_foreign_key(
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
                zcl_audit_logger=>log_change(
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


  METHOD build_where_from_record_key.
    rv_where = zcl_excel_record_builder=>build_where_from_record_key(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key
      it_fields     = it_fields ).
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

    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.

    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE cs_record TO <f>.
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

    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE <wa> TO <f>.
    IF sy-subrc = 0.
      cv_set = cv_set && |, CHANGED_BY = '{ sy-uname }'|.
    ENDIF.

    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <wa> TO <f>.
    IF sy-subrc = 0.
      cv_set = cv_set && |, CHANGED_AT = '{ lv_ts_c }'|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

