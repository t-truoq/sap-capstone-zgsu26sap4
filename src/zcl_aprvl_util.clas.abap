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
      IMPORTING iv_table_name    TYPE ztde_table_name
                iv_record_key    TYPE ztde_record_key
      RETURNING VALUE(rt_history) TYPE tt_aprvl_history.

    CLASS-METHODS get_pending_approvals
      IMPORTING iv_table_name    TYPE ztde_table_name OPTIONAL
      RETURNING VALUE(rt_result)  TYPE tt_aprvl_history.

    CLASS-METHODS is_approval_required
      IMPORTING iv_table_name    TYPE ztde_table_name
      RETURNING VALUE(rv_result)  TYPE abap_bool.
CLASS-METHODS update_status
      IMPORTING
        iv_aprvl_id TYPE sysuuid_c32
        iv_status   TYPE ztde_aprvl_status
        iv_remarks  TYPE string OPTIONAL.


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
ENDCLASS.
