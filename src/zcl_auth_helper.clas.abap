"! <p class="shorttext synchronized">Authorization helper (ADMIN/USER + per-table permission)</p>
"! Mở ZCL_AUTH_HELPER đã có → tab Source → Ctrl+A → paste TOÀN BỘ file này → Ctrl+F3
"! (Không tạo class mới. get_auth_by_status giữ nguyên logic teammate.)
CLASS zcl_auth_helper DEFINITION
PUBLIC
  FINAL
  CREATE PUBLIC.
PUBLIC SECTION.
CLASS-METHODS get_auth_by_status
      IMPORTING iv_status      TYPE ztde_aprvl_status
      RETURNING VALUE(rv_auth) TYPE i.

    CONSTANTS:
      BEGIN OF c_action,
        view   TYPE char20 VALUE 'VIEW',
        create TYPE char20 VALUE 'CREATE',
        update TYPE char20 VALUE 'UPDATE',
        delete TYPE char20 VALUE 'DELETE',
        upload TYPE char20 VALUE 'UPLOAD',
      END OF c_action.

    CONSTANTS:
      BEGIN OF c_admin_action,
        approve      TYPE char20 VALUE 'APPROVE',
        rollback     TYPE char20 VALUE 'ROLLBACK',
        config       TYPE char20 VALUE 'CONFIG',
        force_unlock TYPE char20 VALUE 'FORCE_UNLOCK',
      END OF c_admin_action.

    CLASS-METHODS is_admin
      IMPORTING iv_username        TYPE syuname DEFAULT sy-uname
      RETURNING VALUE(rv_is_admin) TYPE abap_bool.

    CLASS-METHODS is_active_user
      IMPORTING iv_username          TYPE syuname DEFAULT sy-uname
      RETURNING VALUE(rv_is_active)  TYPE abap_bool.

    CLASS-METHODS get_user_permissions
      IMPORTING iv_username   TYPE syuname DEFAULT sy-uname
                iv_table_name TYPE ztde_table_name
      RETURNING VALUE(rs_perm) TYPE ztde_user_permission.

    CLASS-METHODS get_table_permissions
      IMPORTING iv_table_name TYPE ztde_table_name
      RETURNING VALUE(rs_perm) TYPE ztde_user_permission.

    CLASS-METHODS check_permission
      IMPORTING iv_username   TYPE syuname DEFAULT sy-uname
                iv_table_name TYPE ztde_table_name
                iv_action     TYPE char20
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS check_admin_action
      IMPORTING iv_username TYPE syuname DEFAULT sy-uname
                iv_action   TYPE char20
      RAISING   zcx_excel_pipeline.

CLASS-METHODS sync_user
      IMPORTING iv_username    TYPE syuname
                iv_role_type   TYPE ztde_role_type
                iv_active_flag TYPE ztde_yesno.

    CLASS-METHODS sync_user_from_db
      IMPORTING iv_username TYPE syuname.

    CLASS-METHODS sync_all_users_from_db
      RETURNING VALUE(rv_count) TYPE i.

    CLASS-METHODS sync_table_policy
      IMPORTING iv_table_name TYPE ztde_table_name
      RETURNING VALUE(rv_count) TYPE i.

    CLASS-METHODS apply_table_policy
      IMPORTING iv_table_name TYPE ztde_table_name
                iv_can_view   TYPE ztde_yesno
                iv_can_create TYPE ztde_yesno
                iv_can_update TYPE ztde_yesno
                iv_can_delete TYPE ztde_yesno
                iv_can_upload TYPE ztde_yesno
      RETURNING VALUE(rv_count) TYPE i.
ENDCLASS.


CLASS zcl_auth_helper IMPLEMENTATION.
METHOD get_auth_by_status.
    rv_auth = COND #(
      WHEN iv_status = 'PENDING'
      THEN if_abap_behv=>auth-allowed
      ELSE if_abap_behv=>auth-unauthorized
    ).
  ENDMETHOD.

  METHOD is_admin.
    SELECT SINGLE @abap_true
      FROM ztbl_user_master
      WHERE username    = @iv_username
        AND role_type   = 'ADMIN'
        AND active_flag = 'X'
      INTO @rv_is_admin.
  ENDMETHOD.

  METHOD is_active_user.
    SELECT SINGLE @abap_true
      FROM ztbl_user_master
      WHERE username    = @iv_username
        AND active_flag = 'X'
      INTO @rv_is_active.
  ENDMETHOD.

  METHOD get_user_permissions.
    IF is_active_user( iv_username ) = abap_false.
      RETURN.
    ENDIF.

    SELECT SINGLE can_view, can_create, can_update, can_delete, can_upload
      FROM ztbl_user_perm
      WHERE username   = @iv_username
        AND table_name = @iv_table_name
      INTO CORRESPONDING FIELDS OF @rs_perm.

    DATA(ls_table_perm) = get_table_permissions(
      iv_table_name = iv_table_name ).

    rs_perm-can_view   = COND #( WHEN rs_perm-can_view   = abap_true AND ls_table_perm-can_view   = abap_true THEN abap_true ELSE abap_false ).
    rs_perm-can_create = COND #( WHEN rs_perm-can_create = abap_true AND ls_table_perm-can_create = abap_true THEN abap_true ELSE abap_false ).
    rs_perm-can_update = COND #( WHEN rs_perm-can_update = abap_true AND ls_table_perm-can_update = abap_true THEN abap_true ELSE abap_false ).
    rs_perm-can_delete = COND #( WHEN rs_perm-can_delete = abap_true AND ls_table_perm-can_delete = abap_true THEN abap_true ELSE abap_false ).
    rs_perm-can_upload = COND #( WHEN rs_perm-can_upload = abap_true AND ls_table_perm-can_upload = abap_true THEN abap_true ELSE abap_false ).
  ENDMETHOD.

  METHOD get_table_permissions.
    SELECT SINGLE can_view, can_create, can_update, can_delete, can_upload
      FROM ztbl_table_perm
      WHERE table_name = @iv_table_name
      INTO CORRESPONDING FIELDS OF @rs_perm.

    IF sy-subrc <> 0.
      rs_perm-can_view   = abap_true.
      rs_perm-can_create = abap_true.
      rs_perm-can_update = abap_true.
      rs_perm-can_delete = abap_true.
      rs_perm-can_upload = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD check_permission.
    IF is_active_user( iv_username ) = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |User { iv_username } không tồn tại hoặc không active trong ZTBL_USER_MASTER|.
    ENDIF.

    IF is_admin( iv_username ) = abap_true.
      RETURN.
    ENDIF.

    DATA(ls_perm) = get_user_permissions(
      iv_username   = iv_username
      iv_table_name = iv_table_name ).

    DATA(lv_allowed) = SWITCH abap_bool( iv_action
      WHEN c_action-view   THEN ls_perm-can_view
      WHEN c_action-create THEN ls_perm-can_create
      WHEN c_action-update THEN ls_perm-can_update
      WHEN c_action-delete THEN ls_perm-can_delete
      WHEN c_action-upload THEN ls_perm-can_upload
      ELSE abap_false ).

    IF lv_allowed <> abap_true.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |User { iv_username } không có quyền { iv_action } trên { iv_table_name }|.
    ENDIF.
  ENDMETHOD.

  METHOD check_admin_action.
    IF is_admin( iv_username ) = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Action { iv_action } chỉ dành cho ADMIN|.
    ENDIF.

    SELECT SINGLE can_approve, can_rollback, can_config, can_force_unlock
      FROM ztbl_admin_perm
      WHERE username = @iv_username
      INTO @DATA(ls_admin).

    DATA(lv_allowed) = SWITCH abap_bool( iv_action
      WHEN c_admin_action-approve      THEN ls_admin-can_approve
      WHEN c_admin_action-rollback     THEN ls_admin-can_rollback
      WHEN c_admin_action-config       THEN ls_admin-can_config
      WHEN c_admin_action-force_unlock THEN ls_admin-can_force_unlock
      ELSE abap_false ).

    IF lv_allowed <> abap_true.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |ADMIN { iv_username } chưa được cấp quyền { iv_action }|.
    ENDIF.
  ENDMETHOD.

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
          DATA(ls_policy) = zcl_auth_helper=>get_table_permissions(
            iv_table_name = ls_table-table_name ).

          SELECT SINGLE can_view, can_create, can_update, can_delete, can_upload
            FROM ztbl_user_perm
            WHERE username   = @iv_username
              AND table_name = @ls_table-table_name
            INTO @DATA(ls_existing_perm).

          IF sy-subrc <> 0.
            INSERT ztbl_user_perm FROM @( VALUE ztbl_user_perm(
              client     = sy-mandt
              username   = iv_username
              table_name = ls_table-table_name
              can_view   = ls_policy-can_view
              can_create = ls_policy-can_create
              can_update = ls_policy-can_update
              can_delete = ls_policy-can_delete
              can_upload = ls_policy-can_upload ) ).
          ELSE.
            IF ls_policy-can_view = abap_false.
              CLEAR ls_existing_perm-can_view.
            ENDIF.
            IF ls_policy-can_create = abap_false.
              CLEAR ls_existing_perm-can_create.
            ENDIF.
            IF ls_policy-can_update = abap_false.
              CLEAR ls_existing_perm-can_update.
            ENDIF.
            IF ls_policy-can_delete = abap_false.
              CLEAR ls_existing_perm-can_delete.
            ENDIF.
            IF ls_policy-can_upload = abap_false.
              CLEAR ls_existing_perm-can_upload.
            ENDIF.

            UPDATE ztbl_user_perm
              SET can_view   = @ls_existing_perm-can_view,
                  can_create = @ls_existing_perm-can_create,
                  can_update = @ls_existing_perm-can_update,
                  can_delete = @ls_existing_perm-can_delete,
                  can_upload = @ls_existing_perm-can_upload
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

    SELECT DISTINCT username
      FROM ztbl_user_perm
      INTO TABLE @DATA(lt_perm_users).

    LOOP AT lt_perm_users INTO DATA(ls_perm_user).
      READ TABLE lt_users TRANSPORTING NO FIELDS
        WITH KEY username = ls_perm_user-username
                 active_flag = abap_true.
      IF sy-subrc <> 0.
        DELETE FROM ztbl_user_perm
          WHERE username = @ls_perm_user-username.
      ENDIF.
    ENDLOOP.

    SELECT DISTINCT username
      FROM ztbl_admin_perm
      INTO TABLE @DATA(lt_admin_users).

    LOOP AT lt_admin_users INTO DATA(ls_admin_user).
      READ TABLE lt_users TRANSPORTING NO FIELDS
        WITH KEY username = ls_admin_user-username
                 active_flag = abap_true.
      IF sy-subrc <> 0.
        DELETE FROM ztbl_admin_perm
          WHERE username = @ls_admin_user-username.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_users INTO DATA(ls_user).
      sync_user(
        iv_username    = ls_user-username
        iv_role_type   = ls_user-role_type
        iv_active_flag = ls_user-active_flag ).

      rv_count += 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD sync_table_policy.
    IF iv_table_name IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_policy) = zcl_auth_helper=>get_table_permissions(
      iv_table_name = iv_table_name ).

    rv_count = apply_table_policy(
      iv_table_name = iv_table_name
      iv_can_view   = ls_policy-can_view
      iv_can_create = ls_policy-can_create
      iv_can_update = ls_policy-can_update
      iv_can_delete = ls_policy-can_delete
      iv_can_upload = ls_policy-can_upload ).
  ENDMETHOD.

  METHOD apply_table_policy.
    IF iv_table_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT username
      FROM ztbl_user_master
      WHERE role_type   = 'USER'
        AND active_flag = @abap_true
      INTO TABLE @DATA(lt_users).

    LOOP AT lt_users INTO DATA(ls_user).
      MODIFY ztbl_user_perm FROM @( VALUE ztbl_user_perm(
        client     = sy-mandt
        username   = ls_user-username
        table_name = iv_table_name
        can_view   = iv_can_view
        can_create = iv_can_create
        can_update = iv_can_update
        can_delete = iv_can_delete
        can_upload = iv_can_upload ) ).

      rv_count += 1.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

