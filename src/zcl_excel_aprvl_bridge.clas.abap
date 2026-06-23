"! Gửi diff Excel (NEW/CHANGED) vào ZTBL_APRVL qua zcl_aprvl_util=>submit_for_approval.
"! Không ghi bảng nghiệp vụ trực tiếp; audit chỉ chạy khi approver bấm Approve.
CLASS zcl_excel_aprvl_bridge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

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

ENDCLASS.


CLASS zcl_excel_aprvl_bridge IMPLEMENTATION.

  METHOD submit_groups.
    LOOP AT it_groups INTO DATA(ls_group).
      TRY.
          DATA(lv_action) = COND ztde_action_type(
            WHEN ls_group-status = zcl_excel_types=>c_status-new
            THEN zcl_excel_types=>c_action-create
            WHEN ls_group-status = zcl_excel_types=>c_status-changed
            THEN zcl_excel_types=>c_action-update
            ELSE '' ).

          IF lv_action IS INITIAL.
            cs_summary-skipped_count = cs_summary-skipped_count + 1.
            CONTINUE.
          ENDIF.

          DATA lv_old_json TYPE string.
          DATA lv_new_json TYPE string.
          DATA lr_rec TYPE REF TO data.

          DATA(lv_record_key) = ls_group-record_key.

          zcl_excel_record_builder=>build_merged_record(
            EXPORTING iv_table_name = iv_table_name
                      it_cells      = ls_group-cells
                      it_fields     = it_fields
                      iv_status     = ls_group-status
                      iv_record_key = lv_record_key
            IMPORTING ev_old_json   = lv_old_json
                      ev_new_json   = lv_new_json
                      er_record     = lr_rec ).

          IF ls_group-status = zcl_excel_types=>c_status-new.
            lv_record_key = zcl_excel_types=>build_record_key_json(
              iv_table_name = iv_table_name
              it_fields     = it_fields
              ir_row        = lr_rec ).
          ENDIF.

          zcl_excel_record_builder=>validate_approval_json(
            EXPORTING iv_table_name = iv_table_name
                      iv_new_json   = lv_new_json
                      it_fields     = it_fields ).

          DATA(ls_submit) = zcl_aprvl_util=>submit_for_approval(
            iv_table_name  = CONV ztde_table_name( iv_table_name )
            iv_action_type = lv_action
            iv_record_key  = CONV ztde_record_key( lv_record_key )
            iv_new_data    = lv_new_json
            iv_old_data    = lv_old_json ).

          IF ls_submit-success = abap_true.
            IF lv_action = zcl_excel_types=>c_action-create.
              cs_summary-inserted_count = cs_summary-inserted_count + 1.
            ELSE.
              cs_summary-updated_count = cs_summary-updated_count + 1.
            ENDIF.
            APPEND |Row { ls_group-row_no }: { ls_submit-message }| TO cs_summary-messages.
          ELSE.
            cs_summary-error_count = cs_summary-error_count + 1.
            cs_summary-skipped_count = cs_summary-skipped_count + 1.
            APPEND |Row { ls_group-row_no } gửi duyệt lỗi: { ls_submit-message }| TO cs_summary-messages.
          ENDIF.

        CATCH zcx_excel_pipeline INTO DATA(lx_pipe).
          cs_summary-error_count = cs_summary-error_count + 1.
          cs_summary-skipped_count = cs_summary-skipped_count + 1.
          APPEND |Row { ls_group-row_no } gửi duyệt lỗi: { lx_pipe->get_text( ) }| TO cs_summary-messages.
        CATCH cx_root INTO DATA(lx).
          cs_summary-error_count = cs_summary-error_count + 1.
          cs_summary-skipped_count = cs_summary-skipped_count + 1.
          DATA(lv_cls) = cl_abap_classdescr=>describe_by_object_ref( lx )->get_relative_name( ).
          APPEND |Row { ls_group-row_no } gửi duyệt lỗi [{ lv_cls }]: { lx->get_text( ) }| TO cs_summary-messages.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

