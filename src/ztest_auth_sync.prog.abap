REPORT ztest_auth_sync.

PARAMETERS p_table  TYPE ztde_table_name.
PARAMETERS p_set    AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_view   AS CHECKBOX DEFAULT abap_true.
PARAMETERS p_create AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_update AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_delete AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_upload AS CHECKBOX DEFAULT abap_false.

DATA lv_count TYPE i.

IF p_table IS INITIAL.
  lv_count = zcl_auth_permission_sync=>sync_all_users_from_db( ).
  COMMIT WORK.
  WRITE: / |Synced authorization permissions for { lv_count } users.|.
  RETURN.
ENDIF.

IF p_set = abap_true.
  MODIFY ztbl_table_perm FROM @( VALUE ztbl_table_perm(
    client     = sy-mandt
    table_name = p_table
    can_view   = p_view
    can_create = p_create
    can_update = p_update
    can_delete = p_delete
    can_upload = p_upload ) ).
ENDIF.

lv_count = zcl_auth_permission_sync=>sync_table_policy(
  iv_table_name = p_table ).

COMMIT WORK.

WRITE: / |Synced table policy { p_table } for { lv_count } users.|.

SELECT SINGLE can_view, can_create, can_update, can_delete, can_upload
  FROM ztbl_table_perm
  WHERE table_name = @p_table
  INTO @DATA(ls_policy).

IF sy-subrc <> 0.
  WRITE: / |No ZTBL_TABLE_PERM row found for { p_table }. Default policy is FULL permission, so USER_PERM will not be reduced.|.
  RETURN.
ENDIF.

WRITE: / |Applied policy: VIEW={ ls_policy-can_view }, CREATE={ ls_policy-can_create }, UPDATE={ ls_policy-can_update }, DELETE={ ls_policy-can_delete }, UPLOAD={ ls_policy-can_upload }.|.

SELECT u~username,
       p~table_name AS perm_table_name,
       p~can_view,
       p~can_create,
       p~can_update,
       p~can_delete,
       p~can_upload
  FROM ztbl_user_master AS u
  LEFT OUTER JOIN ztbl_user_perm AS p
    ON  p~username   = u~username
    AND p~table_name = @p_table
  WHERE u~role_type   = 'USER'
    AND u~active_flag = @abap_true
  INTO TABLE @DATA(lt_results).

DATA lv_mismatch TYPE i.

ULINE.
LOOP AT lt_results INTO DATA(ls_result).
  DATA(lv_status) = COND string(
    WHEN ls_result-perm_table_name IS INITIAL
      THEN 'MISSING'
    WHEN ls_result-can_view   = ls_policy-can_view
     AND ls_result-can_create = ls_policy-can_create
     AND ls_result-can_update = ls_policy-can_update
     AND ls_result-can_delete = ls_policy-can_delete
     AND ls_result-can_upload = ls_policy-can_upload
      THEN 'OK'
    ELSE 'MISMATCH' ).

  IF lv_status <> 'OK'.
    lv_mismatch += 1.
  ENDIF.

  WRITE: / |{ ls_result-username }: VIEW={ ls_result-can_view }, CREATE={ ls_result-can_create }, UPDATE={ ls_result-can_update }, DELETE={ ls_result-can_delete }, UPLOAD={ ls_result-can_upload } [{ lv_status }]|.
ENDLOOP.

ULINE.
IF lv_mismatch = 0.
  WRITE: / |PASS: all { lines( lt_results ) } active USER permission rows match the table policy.|.
ELSE.
  WRITE: / |FAIL: { lv_mismatch } USER permission row(s) do not match the table policy.|.
ENDIF.
