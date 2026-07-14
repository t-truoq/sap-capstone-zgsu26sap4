"! Excel approval bridge: submit one BULK approval parent plus many detail items.
"! CRUD approval flow is not used here and remains unchanged.
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

  PRIVATE SECTION.
    CONSTANTS c_action_field TYPE fieldname VALUE '__ACTION'.

ENDCLASS.


CLASS zcl_excel_aprvl_bridge IMPLEMENTATION.

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

          zcl_excel_conflict_guard=>assert_no_pending_conflict(
            iv_table_name = CONV ztde_table_name( iv_table_name )
            iv_record_key = CONV ztde_record_key( lv_record_key ) ).

          IF ls_group-status = zcl_excel_types=>c_status-delete.
            lv_old_json = zcl_excel_types=>get_cell_value(
              it_cells = ls_group-cells
              iv_field = c_action_field ).

            zcl_excel_conflict_guard=>assert_current_state(
              iv_table_name  = iv_table_name
              iv_action_type = lv_action
              iv_record_key  = CONV ztde_record_key( lv_record_key )
              iv_old_data    = lv_old_json ).

            CLEAR lv_new_json.
          ELSE.
            IF ls_group-status = zcl_excel_types=>c_status-changed.
              lv_old_json = zcl_excel_types=>get_cell_value(
                it_cells = ls_group-cells
                iv_field = zcl_excel_conflict_guard=>c_snapshot_field ).
              IF lv_old_json IS INITIAL.
                lv_old_json = zcl_excel_conflict_guard=>get_current_snapshot(
                  iv_table_name = iv_table_name
                  iv_record_key = CONV ztde_record_key( lv_record_key ) ).
              ENDIF.
            ENDIF.

            IF ls_group-status = zcl_excel_types=>c_status-new.
              zcl_excel_conflict_guard=>assert_current_state(
                iv_table_name  = iv_table_name
                iv_action_type = lv_action
                iv_record_key  = CONV ztde_record_key( lv_record_key ) ).
            ENDIF.

            zcl_excel_record_builder=>build_merged_record(
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
              zcl_excel_conflict_guard=>assert_current_state(
                iv_table_name  = iv_table_name
                iv_action_type = lv_action
                iv_record_key  = CONV ztde_record_key( lv_record_key )
                iv_old_data    = lv_old_json ).
            ENDIF.

            zcl_excel_record_builder=>validate_approval_json(
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

ENDCLASS.

