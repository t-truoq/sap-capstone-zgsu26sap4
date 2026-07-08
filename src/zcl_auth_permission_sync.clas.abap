"! <p class="shorttext synchronized">Sync auth master role to permission tables</p>
CLASS zcl_auth_permission_sync DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS sync_user
      IMPORTING iv_username    TYPE syuname
                iv_role_type   TYPE ztde_role_type
                iv_active_flag TYPE ztde_yesno.

    CLASS-METHODS sync_user_from_db
      IMPORTING iv_username TYPE syuname.

    CLASS-METHODS sync_all_users_from_db
      RETURNING VALUE(rv_count) TYPE i.
ENDCLASS.


CLASS zcl_auth_permission_sync IMPLEMENTATION.

  METHOD sync_user.
    IF iv_username IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_active_flag <> abap_true.
      DELETE FROM ztbl_user_perm
        WHERE username = @iv_username.

      DELETE FROM ztbl_admin_perm
        WHERE username = @iv_username.
      RETURN.
    ENDIF.

    CASE iv_role_type.
      WHEN 'ADMIN'.
        DELETE FROM ztbl_user_perm
          WHERE username = @iv_username.

        MODIFY ztbl_admin_perm FROM @( VALUE ztbl_admin_perm(
          client           = sy-mandt
          username         = iv_username
          can_approve      = abap_true
          can_rollback     = abap_true
          can_config       = abap_true
          can_force_unlock = abap_true ) ).

      WHEN 'USER'.
        DELETE FROM ztbl_admin_perm
          WHERE username = @iv_username.

        SELECT table_name
          FROM ztbl_config
          WHERE active_flag = @abap_true
          INTO TABLE @DATA(lt_tables).

        LOOP AT lt_tables INTO DATA(ls_table).
          SELECT SINGLE can_view
            FROM ztbl_user_perm
            WHERE username   = @iv_username
              AND table_name = @ls_table-table_name
            INTO @DATA(lv_can_view).

          IF sy-subrc <> 0.
            INSERT ztbl_user_perm FROM @( VALUE ztbl_user_perm(
              client     = sy-mandt
              username   = iv_username
              table_name = ls_table-table_name
              can_view   = abap_true ) ).
          ELSEIF lv_can_view <> abap_true.
            UPDATE ztbl_user_perm
              SET can_view = @abap_true
              WHERE username   = @iv_username
                AND table_name = @ls_table-table_name.
          ENDIF.
        ENDLOOP.

      WHEN OTHERS.
        DELETE FROM ztbl_user_perm
          WHERE username = @iv_username.

        DELETE FROM ztbl_admin_perm
          WHERE username = @iv_username.
    ENDCASE.
  ENDMETHOD.

  METHOD sync_user_from_db.
    SELECT SINGLE username, role_type, active_flag
      FROM ztbl_user_master
      WHERE username = @iv_username
      INTO @DATA(ls_user).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    sync_user(
      iv_username    = ls_user-username
      iv_role_type   = ls_user-role_type
      iv_active_flag = ls_user-active_flag ).
  ENDMETHOD.

  METHOD sync_all_users_from_db.
    SELECT username, role_type, active_flag
      FROM ztbl_user_master
      INTO TABLE @DATA(lt_users).

    LOOP AT lt_users INTO DATA(ls_user).
      sync_user(
        iv_username    = ls_user-username
        iv_role_type   = ls_user-role_type
        iv_active_flag = ls_user-active_flag ).

      rv_count += 1.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

