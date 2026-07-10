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
      RAISING   zcx_04_no_auth.

    CLASS-METHODS check_admin_action
      IMPORTING iv_username TYPE syuname DEFAULT sy-uname
                iv_action   TYPE char20
      RAISING   zcx_04_no_auth.

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
      RAISE EXCEPTION TYPE zcx_04_no_auth
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
      RAISE EXCEPTION TYPE zcx_04_no_auth
        EXPORTING iv_text = |User { iv_username } không có quyền { iv_action } trên { iv_table_name }|.
    ENDIF.
  ENDMETHOD.

  METHOD check_admin_action.
    IF is_admin( iv_username ) = abap_false.
      RAISE EXCEPTION TYPE zcx_04_no_auth
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
      RAISE EXCEPTION TYPE zcx_04_no_auth
        EXPORTING iv_text = |ADMIN { iv_username } chưa được cấp quyền { iv_action }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

