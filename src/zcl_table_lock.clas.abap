"! <p class="shorttext synchronized">Application-level table lock (TTL + heartbeat)</p>
"! NEW. Lock mềm trên ZTBL_LOCK cho web edit session. View KHÔNG bị chặn.
"! KHÔNG tự COMMIT WORK — để RAP modify action / caller commit (lock action chạy trong 1 LUW RAP).
CLASS zcl_table_lock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF c_scope,
        table  TYPE ztde_lock_scope VALUE 'TABLE',
        record TYPE ztde_lock_scope VALUE 'RECORD',
        batch  TYPE ztde_lock_scope VALUE 'BATCH',
      END OF c_scope.

    CONSTANTS c_default_ttl_seconds TYPE i VALUE 300.

    "! Acquire lock. Nếu đang bị session khác giữ và còn hạn → zcx_table_locked.
    "! Cùng session gọi lại = gia hạn (idempotent).
    CLASS-METHODS acquire_lock
      IMPORTING iv_table_name  TYPE ztde_table_name
                iv_session_id  TYPE sysuuid_c32
                iv_reason      TYPE ztde_lock_reason DEFAULT 'CRUD'
                iv_lock_scope  TYPE ztde_lock_scope  DEFAULT c_scope-table
                iv_record_key  TYPE ztde_record_key  OPTIONAL
                iv_ttl_seconds TYPE i                DEFAULT c_default_ttl_seconds
      RAISING   zcx_table_locked.

    CLASS-METHODS release_lock
      IMPORTING iv_table_name TYPE ztde_table_name
                iv_session_id TYPE sysuuid_c32
                iv_lock_scope TYPE ztde_lock_scope DEFAULT c_scope-table
                iv_record_key TYPE ztde_record_key OPTIONAL
      RAISING   zcx_table_locked.

    "! Gia hạn lock của chính session. Nếu lock đã mất/hết hạn → zcx_table_locked.
    CLASS-METHODS heartbeat
      IMPORTING iv_table_name  TYPE ztde_table_name
                iv_session_id  TYPE sysuuid_c32
                iv_lock_scope  TYPE ztde_lock_scope DEFAULT c_scope-table
                iv_record_key  TYPE ztde_record_key OPTIONAL
                iv_ttl_seconds TYPE i               DEFAULT c_default_ttl_seconds
      RAISING   zcx_table_locked.

    "! Bắt buộc trước mọi write: lock phải còn hạn và thuộc về session hiện tại.
    CLASS-METHODS assert_locked_by_me
      IMPORTING iv_table_name TYPE ztde_table_name
                iv_session_id TYPE sysuuid_c32
                iv_lock_scope TYPE ztde_lock_scope DEFAULT c_scope-table
                iv_record_key TYPE ztde_record_key OPTIONAL
      RAISING   zcx_table_locked.

    "! Admin force unlock (cần CAN_FORCE_UNLOCK). Xoá mọi lock của bảng.
    CLASS-METHODS force_release
      IMPORTING iv_table_name TYPE ztde_table_name
                iv_username   TYPE syuname DEFAULT sy-uname
      RAISING   zcx_04_no_auth.

    "! Xoá lock đã hết hạn (gọi đầu acquire, hoặc job dọn dẹp).
    CLASS-METHODS cleanup_expired_locks.

  PRIVATE SECTION.
    CLASS-METHODS now
      RETURNING VALUE(rv_now) TYPE timestampl.

    CLASS-METHODS expires_in
      IMPORTING iv_seconds        TYPE i
      RETURNING VALUE(rv_expires) TYPE timestampl.
ENDCLASS.


CLASS zcl_table_lock IMPLEMENTATION.

  METHOD now.
    GET TIME STAMP FIELD rv_now.
  ENDMETHOD.

  METHOD expires_in.
    rv_expires = CONV timestampl(
      cl_abap_tstmp=>add( tstmp = CONV timestamp( now( ) )
                          secs  = iv_seconds ) ).
  ENDMETHOD.

  METHOD acquire_lock.
    cleanup_expired_locks( ).

    DATA(lv_now) = now( ).

    SELECT SINGLE locked_by, session_id, expires_at
      FROM ztbl_lock
      WHERE table_name = @iv_table_name
        AND lock_scope = @iv_lock_scope
        AND record_key = @iv_record_key
      INTO @DATA(ls_existing).

    IF sy-subrc = 0 AND ls_existing-expires_at >= lv_now.
      " Lock còn hạn → chỉ chủ session cũ được gia hạn
      IF ls_existing-session_id <> iv_session_id.
        RAISE EXCEPTION TYPE zcx_table_locked
          EXPORTING
            iv_text      = |{ iv_table_name } đang bị khoá bởi { ls_existing-locked_by }|
            iv_locked_by = ls_existing-locked_by.
      ENDIF.
    ENDIF.

    MODIFY ztbl_lock FROM @( VALUE ztbl_lock(
      table_name     = iv_table_name
      lock_scope     = iv_lock_scope
      record_key     = iv_record_key
      locked_by      = sy-uname
      locked_at      = lv_now
      expires_at     = expires_in( iv_ttl_seconds )
      last_heartbeat = lv_now
      session_id     = iv_session_id
      lock_reason    = iv_reason ) ).
  ENDMETHOD.

  METHOD release_lock.
    cleanup_expired_locks( ).

    IF iv_session_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_table_locked
        EXPORTING iv_text = |Missing lock session for { iv_table_name }|.
    ENDIF.

    DELETE FROM ztbl_lock
      WHERE table_name = @iv_table_name
        AND lock_scope = @iv_lock_scope
        AND record_key = @iv_record_key
        AND session_id = @iv_session_id.

    IF sy-dbcnt = 0.
      SELECT SINGLE locked_by
        FROM ztbl_lock
        WHERE table_name = @iv_table_name
          AND lock_scope = @iv_lock_scope
          AND record_key = @iv_record_key
        INTO @DATA(lv_locked_by).

      DATA(lv_text) = COND string(
        WHEN sy-subrc = 0
        THEN |Lock for { iv_table_name } is owned by { lv_locked_by }|
        ELSE |Lock for { iv_table_name } does not exist or has expired| ).

      RAISE EXCEPTION TYPE zcx_table_locked
        EXPORTING
          iv_text      = lv_text
          iv_locked_by = lv_locked_by.
    ENDIF.
  ENDMETHOD.

  METHOD heartbeat.
    DATA(lv_now)     = now( ).
    DATA(lv_expires) = expires_in( iv_ttl_seconds ).

    UPDATE ztbl_lock
      SET expires_at     = @lv_expires,
          last_heartbeat = @lv_now
      WHERE table_name = @iv_table_name
        AND lock_scope = @iv_lock_scope
        AND record_key = @iv_record_key
        AND session_id = @iv_session_id.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_table_locked
        EXPORTING iv_text = |Lock cho { iv_table_name } đã hết hạn hoặc bị giải phóng|.
    ENDIF.
  ENDMETHOD.

  METHOD assert_locked_by_me.
    DATA(lv_now) = now( ).

    SELECT SINGLE session_id, locked_by, expires_at
      FROM ztbl_lock
      WHERE table_name = @iv_table_name
        AND lock_scope = @iv_lock_scope
        AND record_key = @iv_record_key
      INTO @DATA(ls_lock).

    IF sy-subrc <> 0
       OR ls_lock-expires_at < lv_now
       OR ls_lock-session_id <> iv_session_id.
      RAISE EXCEPTION TYPE zcx_table_locked
        EXPORTING
          iv_text      = |Bạn chưa giữ lock hợp lệ cho { iv_table_name }. Hãy acquire lock trước khi ghi.|
          iv_locked_by = ls_lock-locked_by.
    ENDIF.
  ENDMETHOD.

  METHOD force_release.
    zcl_auth_helper=>check_admin_action(
      iv_username = iv_username
      iv_action   = zcl_auth_helper=>c_admin_action-force_unlock ).

    DELETE FROM ztbl_lock WHERE table_name = @iv_table_name.
  ENDMETHOD.

  METHOD cleanup_expired_locks.
    DATA(lv_now) = now( ).
    DELETE FROM ztbl_lock WHERE expires_at < @lv_now.
  ENDMETHOD.

ENDCLASS.

