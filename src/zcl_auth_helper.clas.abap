CLASS zcl_auth_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS get_auth_by_status
      IMPORTING iv_status     TYPE ztde_aprvl_status
      RETURNING VALUE(rv_auth) TYPE i.

ENDCLASS.

CLASS zcl_auth_helper IMPLEMENTATION.

  METHOD get_auth_by_status.
    rv_auth = COND #(
      WHEN iv_status = 'PENDING'
      THEN if_abap_behv=>auth-allowed
      ELSE if_abap_behv=>auth-unauthorized
    ).
  ENDMETHOD.

ENDCLASS.
