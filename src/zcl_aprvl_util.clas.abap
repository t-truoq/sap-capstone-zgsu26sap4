
CLASS zcl_aprvl_util DEFINITION
PUBLIC FINAL CREATE PUBLIC.
PUBLIC SECTION.
TYPES tt_aprvl_history TYPE STANDARD TABLE OF ztbl_aprvl WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_submit_result,
        success  TYPE abap_bool,
        aprvl_id TYPE sysuuid_c32,
        message  TYPE string,
      END OF ty_submit_result.

    CLASS-METHODS submit_for_approval
      IMPORTING
        iv_table_name  TYPE ztde_table_name
        iv_action_type TYPE ztde_action_type
        iv_record_key  TYPE ztde_record_key
        iv_new_data    TYPE string OPTIONAL
        iv_old_data    TYPE string OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE ty_submit_result.

    CLASS-METHODS get_approval_history
      IMPORTING iv_table_name     TYPE ztde_table_name
                iv_record_key     TYPE ztde_record_key
      RETURNING VALUE(rt_history) TYPE tt_aprvl_history.

    CLASS-METHODS get_pending_approvals
      IMPORTING iv_table_name   TYPE ztde_table_name OPTIONAL
      RETURNING VALUE(rt_result) TYPE tt_aprvl_history.

    CLASS-METHODS is_approval_required
      IMPORTING iv_table_name   TYPE ztde_table_name
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS update_status
      IMPORTING
        iv_aprvl_id TYPE sysuuid_c32
        iv_status   TYPE ztde_aprvl_status
        iv_remarks  TYPE string OPTIONAL.

    CLASS-METHODS find_pending_by_record
      IMPORTING iv_table_name     TYPE ztde_table_name
                iv_record_key     TYPE ztde_record_key
      RETURNING VALUE(rs_pending) TYPE ztbl_aprvl.

    CLASS-METHODS assert_no_conflicting_pending
      IMPORTING iv_table_name TYPE ztde_table_name
                iv_record_key TYPE ztde_record_key
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS update_pending_data
      IMPORTING iv_aprvl_id    TYPE sysuuid_c32
                iv_action_type TYPE ztde_action_type
                iv_new_data    TYPE string OPTIONAL
                iv_old_data    TYPE string OPTIONAL.

TYPES:
      BEGIN OF ty_result,
        needs_approval TYPE abap_bool,
        aprvl_id       TYPE sysuuid_c32,
        message        TYPE string,
      END OF ty_result.

    CLASS-METHODS check_and_submit
      IMPORTING
        iv_table_name  TYPE ztde_table_name
        iv_action_type TYPE ztde_action_type
        iv_record_key  TYPE ztde_record_key
        iv_new_data    TYPE string OPTIONAL
        iv_old_data    TYPE string OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_excel_pipeline.

CLASS-METHODS:
      log_change
        IMPORTING
          iv_table_name  TYPE ztde_table_name
          iv_record_key  TYPE ztde_record_key
          iv_field_name  TYPE ztde_field_name OPTIONAL
          iv_old_value   TYPE string OPTIONAL
          iv_new_value   TYPE string OPTIONAL
          iv_parent_audit_id TYPE sysuuid_c32 OPTIONAL
          iv_action_type TYPE ztde_action_type.
ENDCLASS.


CLASS zcl_aprvl_util IMPLEMENTATION.
METHOD submit_for_approval.
    TRY.
        DATA(lv_aprvl_id) = cl_system_uuid=>create_uuid_c32_static( ).

        INSERT ztbl_aprvl FROM @(
          VALUE ztbl_aprvl(
            aprvl_id     = lv_aprvl_id
            table_name   = iv_table_name
            record_key   = iv_record_key
            action_type  = iv_action_type
            status       = 'PENDING'
            new_data     = iv_new_data
            old_data     = iv_old_data
            submitted_by = sy-uname
            submitted_at = utclong_current( )
          )
        ).

        IF sy-subrc <> 0.
          rs_result = VALUE #(
            success = abap_false
            message = |Cannot create approval request for { iv_record_key }| ).
          RETURN.
        ENDIF.

        INSERT ztbl_aprvl_item FROM @(
          VALUE ztbl_aprvl_item(
            aprvl_id    = lv_aprvl_id
            item_no     = '000001'
            table_name  = iv_table_name
            record_key  = iv_record_key
            action_type = iv_action_type
            status      = 'PENDING'
            new_data    = iv_new_data
            old_data    = iv_old_data
            message     = 'Submitted from CRUD' ) ).

        IF sy-subrc <> 0.
          DELETE FROM ztbl_aprvl WHERE aprvl_id = @lv_aprvl_id.
          rs_result = VALUE #(
            success = abap_false
            message = |Cannot create approval item for { iv_record_key }| ).
          RETURN.
        ENDIF.

        rs_result = VALUE #(
          success  = abap_true
          aprvl_id = lv_aprvl_id
          message  = |Request submitted for approval (ID: { lv_aprvl_id })|
        ).

      CATCH cx_root INTO DATA(lx).
        rs_result = VALUE #(
          success = abap_false
          message = lx->get_text( )
        ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_approval_history.
    SELECT * FROM ztbl_aprvl
      WHERE table_name = @iv_table_name
        AND record_key = @iv_record_key
      ORDER BY submitted_at DESCENDING
      INTO TABLE @rt_history.
  ENDMETHOD.


  METHOD get_pending_approvals.
    IF iv_table_name IS NOT INITIAL.
      SELECT * FROM ztbl_aprvl
        WHERE table_name = @iv_table_name
          AND status     = 'PENDING'
        ORDER BY submitted_at ASCENDING
        INTO TABLE @rt_result.
    ELSE.
      SELECT * FROM ztbl_aprvl
        WHERE status = 'PENDING'
        ORDER BY submitted_at ASCENDING
        INTO TABLE @rt_result.
    ENDIF.
  ENDMETHOD.


  METHOD is_approval_required.
    SELECT SINGLE approval_required FROM ztbl_config
      WHERE table_name = @iv_table_name
      INTO @DATA(lv_flag).

    rv_result = COND #( WHEN lv_flag = 'X' THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD update_status.
    DATA(lv_now) = utclong_current( ).

    UPDATE ztbl_aprvl
      SET status        = @iv_status,
          approved_by   = @sy-uname,
          approved_at   = @lv_now,
          aprvl_comment = @iv_remarks
      WHERE aprvl_id    = @iv_aprvl_id.
  ENDMETHOD.


  METHOD find_pending_by_record.
    SELECT * FROM ztbl_aprvl
      WHERE table_name = @iv_table_name
        AND record_key = @iv_record_key
        AND status     = 'PENDING'
      ORDER BY submitted_at DESCENDING
      INTO @rs_pending
      UP TO 1 ROWS.
      EXIT.
    ENDSELECT.

    IF rs_pending-aprvl_id IS NOT INITIAL.
      RETURN.
    ENDIF.

    SELECT aprvl~* FROM ztbl_aprvl AS aprvl
      INNER JOIN ztbl_aprvl_item AS item
        ON aprvl~aprvl_id = item~aprvl_id
      WHERE item~table_name = @iv_table_name
        AND item~record_key = @iv_record_key
        AND aprvl~status    = 'PENDING'
        AND item~status     = 'PENDING'
      ORDER BY aprvl~submitted_at DESCENDING
      INTO @rs_pending
      UP TO 1 ROWS.
      EXIT.
    ENDSELECT.
  ENDMETHOD.


  METHOD assert_no_conflicting_pending.
    DATA(ls_pending) = find_pending_by_record(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key ).

    IF ls_pending-aprvl_id IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING
          iv_text         = |Record đang chờ duyệt bởi { ls_pending-submitted_by }. Không thể tạo request mới.|
          iv_submitted_by = ls_pending-submitted_by.
    ENDIF.
  ENDMETHOD.


  METHOD update_pending_data.
    DATA(lv_now) = utclong_current( ).

    UPDATE ztbl_aprvl
      SET action_type  = @iv_action_type,
          new_data     = @iv_new_data,
          old_data     = @iv_old_data,
          submitted_at = @lv_now
      WHERE aprvl_id = @iv_aprvl_id.

    SELECT SINGLE table_name, record_key
      FROM ztbl_aprvl
      WHERE aprvl_id = @iv_aprvl_id
      INTO @DATA(ls_parent).

    IF sy-subrc = 0.
      MODIFY ztbl_aprvl_item FROM @(
        VALUE ztbl_aprvl_item(
          aprvl_id    = iv_aprvl_id
          item_no     = '000001'
          table_name  = ls_parent-table_name
          record_key  = ls_parent-record_key
          action_type = iv_action_type
          status      = 'PENDING'
          new_data    = iv_new_data
          old_data    = iv_old_data
          message     = 'Updated from CRUD' ) ).
    ENDIF.
  ENDMETHOD.

METHOD check_and_submit.
    IF zcl_aprvl_util=>is_approval_required( iv_table_name ) = abap_false.
      rs_result-needs_approval = abap_false.
      RETURN.
    ENDIF.

    zcl_aprvl_util=>assert_no_conflicting_pending(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key ).

    DATA(ls_pending) = zcl_aprvl_util=>find_pending_by_record(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key ).

    IF ls_pending-aprvl_id IS NOT INITIAL.
      zcl_aprvl_util=>update_pending_data(
        iv_aprvl_id    = ls_pending-aprvl_id
        iv_action_type = iv_action_type
        iv_new_data    = iv_new_data
        iv_old_data    = iv_old_data ).

      rs_result = VALUE #(
        needs_approval = abap_true
        aprvl_id       = ls_pending-aprvl_id
        message        = |Đã cập nhật request đang chờ duyệt ({ ls_pending-aprvl_id })| ).
      RETURN.
    ENDIF.

    DATA(ls_submit) = zcl_aprvl_util=>submit_for_approval(
      iv_table_name  = iv_table_name
      iv_action_type = iv_action_type
      iv_record_key  = iv_record_key
      iv_new_data    = iv_new_data
      iv_old_data    = iv_old_data ).

    rs_result = VALUE #(
      needs_approval = ls_submit-success
      aprvl_id       = ls_submit-aprvl_id
      message        = ls_submit-message ).
  ENDMETHOD.

METHOD log_change.
    TRY.
        DATA(lv_audit_id) = iv_parent_audit_id.
        DATA(lv_is_bulk) = xsdbool( lv_audit_id IS NOT INITIAL ).
        IF lv_audit_id IS INITIAL.
          lv_audit_id = cl_system_uuid=>create_uuid_c32_static( ).
        ENDIF.

        SELECT SINGLE audit_id FROM ztbl_audit
          WHERE audit_id = @lv_audit_id
          INTO @DATA(lv_parent_exists).

        IF sy-subrc <> 0.
          DATA(lv_parent_record_key) = COND ztde_record_key(
            WHEN lv_is_bulk = abap_true THEN 'BULK'
            ELSE iv_record_key ).
          DATA(lv_parent_field_name) = COND ztde_field_name(
            WHEN lv_is_bulk = abap_true THEN space
            ELSE iv_field_name ).
          DATA lv_parent_old_value TYPE ztbl_audit-old_value.
          DATA lv_parent_new_value TYPE ztbl_audit-new_value.
          IF lv_is_bulk = abap_true.
            lv_parent_new_value = 'Bulk audit'.
          ELSE.
            lv_parent_old_value = iv_old_value.
            lv_parent_new_value = iv_new_value.
          ENDIF.

          INSERT ztbl_audit FROM @(
            VALUE ztbl_audit(
              audit_id    = lv_audit_id
              table_name  = iv_table_name
              record_key  = lv_parent_record_key
              field_name  = lv_parent_field_name
              old_value   = lv_parent_old_value
              new_value   = lv_parent_new_value
              changed_by  = sy-uname
              changed_at  = utclong_current( )
              action_type = iv_action_type ) ).
        ENDIF.

        SELECT MAX( item_no ) FROM ztbl_audit_item
          WHERE audit_id = @lv_audit_id
          INTO @DATA(lv_last_item_no).

        DATA lv_item_no TYPE n LENGTH 6.
        lv_item_no = CONV i( lv_last_item_no ) + 1.
        INSERT ztbl_audit_item FROM @(
          VALUE ztbl_audit_item(
            audit_id    = lv_audit_id
            item_no     = lv_item_no
            table_name  = iv_table_name
            record_key  = iv_record_key
            field_name  = iv_field_name
            old_value   = iv_old_value
            new_value   = iv_new_value
            action_type = iv_action_type ) ).

        IF lv_is_bulk = abap_true.
          DATA(lv_summary) = |Bulk audit: { lv_item_no } item(s)|.
          UPDATE ztbl_audit
            SET new_value = @lv_summary
            WHERE audit_id = @lv_audit_id.
        ENDIF.

      CATCH cx_uuid_error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


