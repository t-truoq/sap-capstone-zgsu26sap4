*&---------------------------------------------------------------------*
*& Report ZTEST_AUTH_SEED
*& Seed user thật cho auth/approval test:
*&   DEV-253, DEV-251 = ADMIN
*&   DEV-Z13       = USER
*&   Z251_SCHEDULE approval_required = X
*&   Z253_CAT      approval_required = ''
*& Chạy 1 lần sau activate DDIC + ZCL_AUTH_HELPER
*&---------------------------------------------------------------------*
REPORT ztest_auth_seed.

PARAMETERS p_run AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.

  IF p_run <> abap_true.
    WRITE: / 'Tick P_RUN để INSERT seed data (DEV-253/DEV-251/DEV-Z13).'.
    RETURN.
  ENDIF.

  DATA lt_master TYPE STANDARD TABLE OF ztbl_user_master.
  DATA lt_perm   TYPE STANDARD TABLE OF ztbl_user_perm.
  DATA lt_admin  TYPE STANDARD TABLE OF ztbl_admin_perm.
  DATA lt_config TYPE STANDARD TABLE OF ztbl_config.

  " --- ZTBL_USER_MASTER ---
  DELETE FROM ztbl_user_master
    WHERE username IN ('DEV-253', 'DEV-251', 'DEV-213').

  APPEND VALUE ztbl_user_master(
    username = 'DEV-253' role_type = 'ADMIN' active_flag = 'X' ) TO lt_master.
  APPEND VALUE ztbl_user_master(
    username = 'DEV-251' role_type = 'ADMIN' active_flag = 'X' ) TO lt_master.
  APPEND VALUE ztbl_user_master(
    username = 'DEV-213' role_type = 'USER' active_flag = 'X' ) TO lt_master.
  INSERT ztbl_user_master FROM TABLE @lt_master.

  " --- ZTBL_USER_PERM ---
  DELETE FROM ztbl_user_perm
    WHERE username = 'DEV-213'
      AND table_name IN ('Z251_SCHEDULE', 'Z253_CAT').

  APPEND VALUE ztbl_user_perm(
    username = 'DEV-213' table_name = 'Z251_SCHEDULE'
    can_view = 'X' can_create = 'X' can_update = 'X'
    can_delete = '' can_upload = 'X' ) TO lt_perm.
  APPEND VALUE ztbl_user_perm(
    username = 'DEV-213' table_name = 'Z253_CAT'
    can_view = 'X' can_create = '' can_update = ''
    can_delete = '' can_upload = 'X' ) TO lt_perm.
  INSERT ztbl_user_perm FROM TABLE @lt_perm.

  " --- ZTBL_ADMIN_PERM ---
  DELETE FROM ztbl_admin_perm
    WHERE username IN ('DEV-253', 'DEV-251').

  APPEND VALUE ztbl_admin_perm(
    username         = 'DEV-253'
    can_approve      = 'X'
    can_rollback     = 'X'
    can_config       = 'X'
    can_force_unlock = 'X' ) TO lt_admin.
  APPEND VALUE ztbl_admin_perm(
    username         = 'DEV-251'
    can_approve      = 'X'
    can_rollback     = 'X'
    can_config       = 'X'
    can_force_unlock = 'X' ) TO lt_admin.
  INSERT ztbl_admin_perm FROM TABLE @lt_admin.

  " --- ZTBL_CONFIG approval flag ---
  DELETE FROM ztbl_config
    WHERE table_name IN ('Z251_SCHEDULE', 'Z253_CAT').

  TRY.
      APPEND VALUE ztbl_config(
        config_uuid      = cl_system_uuid=>create_uuid_x16_static( )
        table_name       = 'Z251_SCHEDULE'
        description      = 'Schedule table - approval required'
        approval_required = 'X'
        active_flag      = 'X' ) TO lt_config.

      APPEND VALUE ztbl_config(
        config_uuid      = cl_system_uuid=>create_uuid_x16_static( )
        table_name       = 'Z253_CAT'
        description      = 'Category table - no approval'
        approval_required = ''
        active_flag      = 'X' ) TO lt_config.

    CATCH cx_uuid_error INTO DATA(lx_uuid).
      WRITE: / 'UUID error:', lx_uuid->get_text( ).
      ROLLBACK WORK.
      RETURN.
  ENDTRY.

  INSERT ztbl_config FROM TABLE @lt_config.

  COMMIT WORK.

  WRITE: / 'Seed OK: DEV-253/DEV-251 admin, DEV-Z13 user.'.
  WRITE: / 'Config OK: Z251_SCHEDULE approval=X, Z253_CAT approval=blank.'.
