REPORT ztest_auth_sync.

PARAMETERS p_table TYPE ztde_table_name.
PARAMETERS p_view   AS CHECKBOX DEFAULT abap_true.
PARAMETERS p_create AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_update AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_delete AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_upload AS CHECKBOX DEFAULT abap_false.

DATA lv_count TYPE i.

IF p_table IS INITIAL.
  lv_count = zcl_auth_permission_sync=>sync_all_users_from_db( ).
ELSE.
  MODIFY ztbl_table_perm FROM @( VALUE ztbl_table_perm(
    client     = sy-mandt
    table_name = p_table
    can_view   = p_view
    can_create = p_create
    can_update = p_update
    can_delete = p_delete
    can_upload = p_upload ) ).

  lv_count = zcl_auth_permission_sync=>sync_table_policy(
    iv_table_name = p_table ).
ENDIF.

COMMIT WORK.

IF p_table IS INITIAL.
  WRITE: / |Synced authorization permissions for { lv_count } users.|.
ELSE.
  WRITE: / |Synced table policy { p_table } for { lv_count } users.|.

  SELECT SINGLE can_view, can_create, can_update, can_delete, can_upload
    FROM ztbl_table_perm
    WHERE table_name = @p_table
    INTO @DATA(ls_policy).

  IF sy-subrc = 0.
    WRITE: / |Applied policy: VIEW={ ls_policy-can_view }, CREATE={ ls_policy-can_create }, UPDATE={ ls_policy-can_update }, DELETE={ ls_policy-can_delete }, UPLOAD={ ls_policy-can_upload }.|.
  ELSE.
    WRITE: / |No ZTBL_TABLE_PERM row found for { p_table }. Default policy is FULL permission, so USER_PERM will not be reduced.|.
  ENDIF.
ENDIF.
