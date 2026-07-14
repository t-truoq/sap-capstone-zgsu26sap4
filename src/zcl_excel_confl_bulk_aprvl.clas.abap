CLASS zcl_excel_confl_bulk_aprvl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_submit_result,
        success    TYPE abap_bool,
        aprvl_id   TYPE sysuuid_c32,
        item_count TYPE i,
        message    TYPE string,
      END OF ty_submit_result,

      BEGIN OF ty_apply_result,
        success TYPE abap_bool,
        message TYPE string,
      END OF ty_apply_result.

    CLASS-METHODS submit_bulk_checked
      IMPORTING iv_table_name TYPE ztde_table_name
                it_items      TYPE zcl_excel_bulk_aprvl=>tt_item
      RETURNING VALUE(rs_result) TYPE ty_submit_result.

    CLASS-METHODS approve_bulk_checked
      IMPORTING iv_aprvl_id TYPE sysuuid_c32
      RETURNING VALUE(rs_result) TYPE ty_apply_result.

    CLASS-METHODS reject_bulk_checked
      IMPORTING iv_aprvl_id TYPE sysuuid_c32
                iv_remarks  TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_apply_result.

  PRIVATE SECTION.
    CLASS-METHODS apply_item_with_crud_api
      IMPORTING is_item TYPE ztbl_aprvl_item
      RETURNING VALUE(rv_message) TYPE string
      RAISING   zcx_excel_pipeline.

ENDCLASS.


CLASS zcl_excel_confl_bulk_aprvl IMPLEMENTATION.

  METHOD submit_bulk_checked.
    IF it_items IS INITIAL.
      rs_result = VALUE #( success = abap_false message = 'No Excel rows to submit for approval.' ).
      RETURN.
    ENDIF.

    LOOP AT it_items INTO DATA(ls_item).
      TRY.
          zcl_excel_conflict_guard=>assert_no_pending_conflict(
            iv_table_name = ls_item-table_name
            iv_record_key = ls_item-record_key ).

          zcl_excel_conflict_guard=>assert_current_state(
            iv_table_name  = CONV tabname( ls_item-table_name )
            iv_action_type = ls_item-action_type
            iv_record_key  = ls_item-record_key
            iv_old_data    = ls_item-old_data ).

        CATCH zcx_excel_pipeline INTO DATA(lx).
          rs_result = VALUE #(
            success = abap_false
            message = |Excel bulk request was not created. Row item { ls_item-item_no } failed final check: { lx->get_text( ) }| ).
          RETURN.
      ENDTRY.
    ENDLOOP.

    DATA(ls_submit) = zcl_excel_bulk_aprvl=>submit_bulk(
      iv_table_name = iv_table_name
      it_items      = it_items ).

    rs_result = VALUE #(
      success    = ls_submit-success
      aprvl_id   = ls_submit-aprvl_id
      item_count = ls_submit-item_count
      message    = ls_submit-message ).
  ENDMETHOD.


  METHOD approve_bulk_checked.
    SELECT SINGLE * FROM ztbl_aprvl
      WHERE aprvl_id = @iv_aprvl_id
      INTO @DATA(ls_parent).

    IF sy-subrc <> 0.
      rs_result = VALUE #( success = abap_false message = |Bulk approval request { iv_aprvl_id } not found.| ).
      RETURN.
    ENDIF.

    IF ls_parent-status <> 'PENDING'.
      rs_result = VALUE #( success = abap_false message = |Request { iv_aprvl_id } is not in PENDING status.| ).
      RETURN.
    ENDIF.

    SELECT * FROM ztbl_aprvl_item
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = 'PENDING'
      ORDER BY item_no ASCENDING
      INTO TABLE @DATA(lt_items).

    IF lt_items IS INITIAL.
      rs_result = VALUE #( success = abap_false message = |Request { iv_aprvl_id } has no pending item.| ).
      RETURN.
    ENDIF.

    DATA lv_applied TYPE i.
    DATA lv_blocked TYPE i.

    LOOP AT lt_items INTO DATA(ls_item).
      TRY.
          zcl_excel_conflict_guard=>assert_no_pending_conflict(
            iv_table_name       = ls_item-table_name
            iv_record_key       = ls_item-record_key
            iv_exclude_aprvl_id = iv_aprvl_id ).

          zcl_excel_conflict_guard=>assert_current_state(
            iv_table_name  = CONV tabname( ls_item-table_name )
            iv_action_type = ls_item-action_type
            iv_record_key  = ls_item-record_key
            iv_old_data    = ls_item-old_data ).

          DATA(lv_message) = apply_item_with_crud_api( ls_item ).

          UPDATE ztbl_aprvl_item
            SET status  = 'APPROVED',
                message = @lv_message
            WHERE aprvl_id = @ls_item-aprvl_id
              AND item_no  = @ls_item-item_no.

          lv_applied = lv_applied + 1.

        CATCH zcx_excel_pipeline INTO DATA(lx_pipe).
          DATA(lv_error) = lx_pipe->get_text( ).
          UPDATE ztbl_aprvl_item
            SET message = @lv_error
            WHERE aprvl_id = @ls_item-aprvl_id
              AND item_no  = @ls_item-item_no.
          lv_blocked = lv_blocked + 1.
      ENDTRY.
    ENDLOOP.

    DATA(lv_now) = utclong_current( ).
    IF lv_blocked = 0.
      DATA(lv_empty_comment) = ``.
      UPDATE ztbl_aprvl
        SET status        = 'APPROVED',
            approved_by   = @sy-uname,
            approved_at   = @lv_now,
            aprvl_comment = @lv_empty_comment
        WHERE aprvl_id = @iv_aprvl_id.

      rs_result = VALUE #(
        success = abap_true
        message = |Bulk request approved and applied successfully ({ lv_applied } item(s)).| ).
    ELSE.
      DATA(lv_comment) = |Phase09 partial apply: applied { lv_applied }, blocked { lv_blocked }. Check item MESSAGE.|.
      UPDATE ztbl_aprvl
        SET aprvl_comment = @lv_comment
        WHERE aprvl_id = @iv_aprvl_id.

      rs_result = VALUE #(
        success = xsdbool( lv_applied > 0 )
        message = lv_comment ).
    ENDIF.
  ENDMETHOD.


  METHOD reject_bulk_checked.
    DATA(ls_reject) = zcl_excel_bulk_aprvl=>reject_bulk(
      iv_aprvl_id = iv_aprvl_id
      iv_remarks  = iv_remarks ).

    rs_result = VALUE #(
      success = ls_reject-success
      message = ls_reject-message ).
  ENDMETHOD.


  METHOD apply_item_with_crud_api.
    DATA ls_result TYPE zcl_dyn_record_handler=>ty_result.

    CASE is_item-action_type.
      WHEN zcl_excel_types=>c_action-create.
        ls_result = zcl_dyn_record_handler=>create_record(
          iv_table_name  = CONV tabname( is_item-table_name )
          iv_record_data = is_item-new_data ).

      WHEN zcl_excel_types=>c_action-update.
        ls_result = zcl_dyn_record_handler=>update_record(
          iv_table_name  = CONV tabname( is_item-table_name )
          iv_record_data = is_item-new_data ).

      WHEN zcl_excel_types=>c_action-delete.
        ls_result = zcl_dyn_record_handler=>delete_record(
          iv_table_name = CONV tabname( is_item-table_name )
          iv_record_key = is_item-record_key ).

      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Unsupported bulk item action { is_item-action_type }.|.
    ENDCASE.

    IF ls_result-success <> abap_true.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = ls_result-message.
    ENDIF.

    rv_message = ls_result-message.
  ENDMETHOD.

ENDCLASS.

