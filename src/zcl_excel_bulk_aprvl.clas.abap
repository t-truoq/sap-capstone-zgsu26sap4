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
    CLASS-METHODS apply_single_item
      IMPORTING is_item TYPE ztbl_aprvl_item
      RAISING   cx_root.

ENDCLASS.


CLASS zcl_excel_bulk_aprvl IMPLEMENTATION.

  METHOD submit_bulk.
    IF it_items IS INITIAL.
      rs_result = VALUE #( success = abap_false message = 'No Excel rows to submit for approval.' ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_aprvl_id) = cl_system_uuid=>create_uuid_c32_static( ).
        DATA(lv_now) = utclong_current( ).
        READ TABLE it_items INTO DATA(ls_first_item) INDEX 1.

        INSERT ztbl_aprvl FROM @(
          VALUE ztbl_aprvl(
            aprvl_id     = lv_aprvl_id
            table_name   = iv_table_name
            record_key   = 'BULK'
            action_type  = ls_first_item-action_type
            status       = 'PENDING'
            new_data     = |Excel bulk approval: { lines( it_items ) } item(s)|
            old_data     = ''
            submitted_by = sy-uname
            submitted_at = lv_now ) ).

        DATA lt_db_items TYPE STANDARD TABLE OF ztbl_aprvl_item.
        LOOP AT it_items INTO DATA(ls_item).
          APPEND VALUE ztbl_aprvl_item(
            aprvl_id    = lv_aprvl_id
            item_no     = ls_item-item_no
            table_name  = ls_item-table_name
            record_key  = ls_item-record_key
            action_type = ls_item-action_type
            status      = 'PENDING'
            new_data    = ls_item-new_data
            old_data    = ls_item-old_data ) TO lt_db_items.
        ENDLOOP.

        INSERT ztbl_aprvl_item FROM TABLE @lt_db_items.

        rs_result = VALUE #(
          success    = abap_true
          aprvl_id   = lv_aprvl_id
          item_count = lines( lt_db_items )
          message    = |Excel bulk request submitted for approval (ID: { lv_aprvl_id }, items: { lines( lt_db_items ) })| ).

      CATCH cx_root INTO DATA(lx).
        rs_result = VALUE #( success = abap_false message = lx->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD approve_bulk.
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

    TRY.
        LOOP AT lt_items INTO DATA(ls_item).
          apply_single_item( ls_item ).
        ENDLOOP.

        DATA(lv_now) = utclong_current( ).
        UPDATE ztbl_aprvl_item
          SET status  = 'APPROVED',
              message = 'Applied successfully'
          WHERE aprvl_id = @iv_aprvl_id
            AND status   = 'PENDING'.

        UPDATE ztbl_aprvl
          SET status      = 'APPROVED',
              approved_by = @sy-uname,
              approved_at = @lv_now
          WHERE aprvl_id = @iv_aprvl_id.

        rs_result = VALUE #(
          success = abap_true
          message = |Bulk request approved and applied successfully ({ lines( lt_items ) } item(s)).| ).

      CATCH cx_root INTO DATA(lx).
        DATA(lv_error_text) = lx->get_text( ).
        UPDATE ztbl_aprvl_item
          SET status  = 'PENDING',
              message = @lv_error_text
          WHERE aprvl_id = @iv_aprvl_id
            AND status   = 'PENDING'.

        rs_result = VALUE #(
          success = abap_false
          message = |Bulk request failed. Nothing was marked approved: { lv_error_text }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD reject_bulk.
    DATA(lv_now) = utclong_current( ).
    DATA(lv_remarks) = COND string(
      WHEN iv_remarks IS NOT INITIAL THEN iv_remarks ELSE 'Rejected by admin' ).

    UPDATE ztbl_aprvl
      SET status        = 'REJECTED',
          approved_by   = @sy-uname,
          approved_at   = @lv_now,
          aprvl_comment = @lv_remarks
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = 'PENDING'.

    IF sy-subrc <> 0.
      rs_result = VALUE #( success = abap_false message = |Reject failed for request { iv_aprvl_id }.| ).
      RETURN.
    ENDIF.

    UPDATE ztbl_aprvl_item
      SET status  = 'REJECTED',
          message = @lv_remarks
      WHERE aprvl_id = @iv_aprvl_id
        AND status   = 'PENDING'.

    rs_result = VALUE #( success = abap_true message = |Bulk request rejected: { lv_remarks }| ).
  ENDMETHOD.


  METHOD apply_single_item.
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
  ENDMETHOD.

ENDCLASS.

