CLASS zcl_excel_bulk_aprvl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
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

    CLASS-METHODS submit_bulk
      IMPORTING iv_table_name TYPE ztde_table_name
                it_items      TYPE tt_item
      RETURNING VALUE(rs_result) TYPE ty_submit_result.

    CLASS-METHODS approve_bulk
      IMPORTING iv_aprvl_id TYPE sysuuid_c32
      RETURNING VALUE(rs_result) TYPE ty_apply_result.

    CLASS-METHODS reject_bulk
      IMPORTING iv_aprvl_id TYPE sysuuid_c32
                iv_remarks  TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_apply_result.

  PRIVATE SECTION.
    CONSTANTS:
      c_status_pending  TYPE string VALUE 'PENDING' ##NO_TEXT,
      c_status_approved TYPE string VALUE 'APPROVED' ##NO_TEXT,
      c_status_rejected TYPE string VALUE 'REJECTED' ##NO_TEXT,
      c_record_key_bulk TYPE string VALUE 'BULK' ##NO_TEXT.

    CLASS-METHODS apply_single_item
      IMPORTING is_item          TYPE ztbl_aprvl_item
                iv_parent_audit_id TYPE sysuuid_c32
      RAISING   cx_root.

ENDCLASS.


CLASS zcl_excel_bulk_aprvl IMPLEMENTATION.

  METHOD submit_bulk.
    IF it_items IS INITIAL.
      DATA(lv_msg_empty) = 'No records to submit for approval.' ##NO_TEXT.
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
        DATA(lv_dup_msg) = |{ lv_skip_message } Skipped item { ls_check_item-item_no }: duplicate record { ls_check_item-record_key }.| ##NO_TEXT.
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
          DATA(lv_pending_msg) = |{ lv_skip_message } Skipped item { ls_check_item-item_no }: { lx_pending->get_text( ) }| ##NO_TEXT.
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

        DATA(lv_new_data_hdr) = |Bulk approval: { lines( lt_valid_items ) } item(s)| ##NO_TEXT.

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
          DATA(lv_item_msg) = |Item { ls_item-item_no } submitted| ##NO_TEXT.
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

        DATA(lv_submit_msg) = |Bulk request submitted for approval (ID: { lv_aprvl_id }, items: { lines( lt_db_items ) })| ##NO_TEXT.

        rs_result = VALUE #(
          success    = abap_true
          aprvl_id   = lv_aprvl_id
          item_count = lines( lt_db_items )
          message    = lv_submit_msg ).

        IF lv_skipped_count > 0.
          DATA(lv_skip_suffix) = |{ rs_result-message } { lv_skipped_count } item(s) skipped.{ lv_skip_message }| ##NO_TEXT.
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
      DATA(lv_notfound_msg) = |Bulk approval request { iv_aprvl_id } not found.| ##NO_TEXT.
      rs_result = VALUE #( success = abap_false message = lv_notfound_msg ).
      RETURN.
    ENDIF.

    IF ls_parent-status <> c_status_pending.
      DATA(lv_notpending_msg) = |Request { iv_aprvl_id } is not in PENDING status.| ##NO_TEXT.
      rs_result = VALUE #( success = abap_false message = lv_notpending_msg ).
      RETURN.
    ENDIF.

    SELECT * FROM ztbl_aprvl_item
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = @c_status_pending
      ORDER BY item_no ASCENDING
      INTO TABLE @DATA(lt_items).

    IF lt_items IS INITIAL.
      DATA(lv_noitem_msg) = |Request { iv_aprvl_id } has no pending item.| ##NO_TEXT.
      rs_result = VALUE #( success = abap_false message = lv_noitem_msg ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_parent_audit_id) = cl_system_uuid=>create_uuid_c32_static( ).
        LOOP AT lt_items INTO DATA(ls_item).
          apply_single_item(
            is_item           = ls_item
            iv_parent_audit_id = lv_parent_audit_id ).
        ENDLOOP.

        DATA(lv_now) = utclong_current( ).
        DATA(lv_applied_msg) = 'Applied successfully' ##NO_TEXT.

        UPDATE ztbl_aprvl_item
          SET status  = @c_status_approved,
              message = @lv_applied_msg
          WHERE aprvl_id = @iv_aprvl_id
            AND status   = @c_status_pending.

        UPDATE ztbl_aprvl
          SET status      = @c_status_approved,
              approved_by = @sy-uname,
              approved_at = @lv_now
          WHERE aprvl_id = @iv_aprvl_id.

        DATA(lv_ok_msg) = |Bulk request approved and applied successfully ({ lines( lt_items ) } item(s)).| ##NO_TEXT.

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

        DATA(lv_fail_msg) = |Bulk request failed. Nothing was marked approved: { lv_error_text }| ##NO_TEXT.

        rs_result = VALUE #(
          success = abap_false
          message = lv_fail_msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD reject_bulk.
    DATA(lv_now) = utclong_current( ).
    DATA(lv_default_remark) = 'Rejected by admin' ##NO_TEXT.
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
      DATA(lv_rejectfail_msg) = |Reject failed for request { iv_aprvl_id }.| ##NO_TEXT.
      rs_result = VALUE #( success = abap_false message = lv_rejectfail_msg ).
      RETURN.
    ENDIF.

    UPDATE ztbl_aprvl_item
      SET status  = @c_status_rejected,
          message = @lv_remarks
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = @c_status_pending.

    DATA(lv_rejected_msg) = |Bulk request rejected: { lv_remarks }| ##NO_TEXT.
    rs_result = VALUE #( success = abap_true message = lv_rejected_msg ).
  ENDMETHOD.


  METHOD apply_single_item.
    DATA ls_result TYPE zcl_dyn_record_handler=>ty_result.

    CASE is_item-action_type.
      WHEN zcl_excel_types=>c_action-create.
        ls_result = zcl_dyn_record_handler=>create_record(
          iv_table_name  = is_item-table_name
          iv_record_data = is_item-new_data
          iv_parent_audit_id = iv_parent_audit_id ).

      WHEN zcl_excel_types=>c_action-update.
        ls_result = zcl_dyn_record_handler=>update_record(
          iv_table_name  = is_item-table_name
          iv_record_data = is_item-new_data
          iv_parent_audit_id = iv_parent_audit_id ).

      WHEN zcl_excel_types=>c_action-delete.
        ls_result = zcl_dyn_record_handler=>delete_record(
          iv_table_name = is_item-table_name
          iv_record_key = is_item-record_key
          iv_parent_audit_id = iv_parent_audit_id ).

      WHEN OTHERS.
        DATA(lv_unsupported_msg) = |Unsupported bulk item action { is_item-action_type }.| ##NO_TEXT.
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = lv_unsupported_msg.
    ENDCASE.

    IF ls_result-success <> abap_true.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = ls_result-message.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
