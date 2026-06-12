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
        VALUE(rs_result) TYPE ty_result.

ENDCLASS.

CLASS zcl_approval_guard IMPLEMENTATION.

  METHOD check_and_submit.
    IF zcl_aprvl_util=>is_approval_required( iv_table_name ) = abap_false.
      rs_result-needs_approval = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_submit) = zcl_aprvl_util=>submit_for_approval(
      iv_table_name  = iv_table_name
      iv_action_type = iv_action_type
      iv_record_key  = iv_record_key
      iv_new_data    = iv_new_data
      iv_old_data    = iv_old_data
    ).

    rs_result = VALUE #(
      needs_approval = ls_submit-success
      aprvl_id       = ls_submit-aprvl_id
      message        = ls_submit-message
    ).
  ENDMETHOD.

ENDCLASS.
