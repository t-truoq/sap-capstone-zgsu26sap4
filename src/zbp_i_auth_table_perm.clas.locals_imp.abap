CLASS lhc_AuthTablePerm DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR AuthTablePerm RESULT result.

    METHODS syncuserpermissions FOR DETERMINE ON SAVE
      IMPORTING keys FOR AuthTablePerm~syncUserPermissions.
ENDCLASS.

CLASS lhc_AuthTablePerm IMPLEMENTATION.
  METHOD get_global_authorizations.
    DATA(lv_auth) = COND #( WHEN zcl_auth_helper=>is_admin( ) = abap_true
                            THEN if_abap_behv=>auth-allowed
                            ELSE if_abap_behv=>auth-unauthorized ).

    result-%create = lv_auth.
    result-%update = lv_auth.
    result-%delete = lv_auth.
  ENDMETHOD.

  METHOD syncuserpermissions.
    READ ENTITIES OF zi_auth_table_perm IN LOCAL MODE
      ENTITY AuthTablePerm
      FIELDS ( TableName CanView CanCreate CanUpdate CanDelete CanUpload )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_policies).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_policies INTO DATA(ls_policy)
        WITH KEY TableName = ls_key-TableName.

      IF sy-subrc = 0.
        zcl_auth_helper=>apply_table_policy(
          iv_table_name = ls_policy-TableName
          iv_can_view   = ls_policy-CanView
          iv_can_create = ls_policy-CanCreate
          iv_can_update = ls_policy-CanUpdate
          iv_can_delete = ls_policy-CanDelete
          iv_can_upload = ls_policy-CanUpload ).
      ELSE.
        zcl_auth_helper=>apply_table_policy(
          iv_table_name = ls_key-TableName
          iv_can_view   = abap_true
          iv_can_create = abap_true
          iv_can_update = abap_true
          iv_can_delete = abap_true
          iv_can_upload = abap_true ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
