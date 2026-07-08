CLASS lhc_AuthUser DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR AuthUser RESULT result.

    METHODS syncrolepermissions FOR DETERMINE ON SAVE
      IMPORTING keys FOR AuthUser~syncRolePermissions.
ENDCLASS.

CLASS lhc_AuthUser IMPLEMENTATION.
  METHOD get_global_authorizations.
    DATA(lv_auth) = COND #( WHEN zcl_auth_helper=>is_admin( ) = abap_true
                            THEN if_abap_behv=>auth-allowed
                            ELSE if_abap_behv=>auth-unauthorized ).

    result-%create = lv_auth.
    result-%update = lv_auth.
    result-%delete = lv_auth.
  ENDMETHOD.

  METHOD syncrolepermissions.
    READ ENTITIES OF zi_auth_user IN LOCAL MODE
      ENTITY authuser
      FIELDS ( Username RoleType ActiveFlag )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    LOOP AT lt_users INTO DATA(ls_user).
      zcl_auth_permission_sync=>sync_user(
        iv_username    = ls_user-username
        iv_role_type   = ls_user-roletype
        iv_active_flag = ls_user-activeflag ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
