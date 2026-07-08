CLASS zcl_approval_guard DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
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
        zcx_pending_exists.

ENDCLASS.


CLASS zcl_approval_guard IMPLEMENTATION.

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

ENDCLASS.

