CLASS zcl_record_autofill DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS on_create
      IMPORTING iv_table_name TYPE tabname
                ir_record     TYPE REF TO data.

    CLASS-METHODS on_update
      IMPORTING ir_new_record TYPE REF TO data
                ir_old_record TYPE REF TO data.

  PRIVATE SECTION.

    CLASS-METHODS fill_client
      IMPORTING ir_record TYPE REF TO data.

    CLASS-METHODS fill_uuid_keys
      IMPORTING iv_table_name TYPE tabname
                ir_record     TYPE REF TO data.

    CLASS-METHODS fill_user_field
      IMPORTING iv_fieldname TYPE fieldname
                ir_record    TYPE REF TO data.

    CLASS-METHODS fill_timestamp_field
      IMPORTING iv_fieldname TYPE fieldname
                ir_record    TYPE REF TO data
                iv_timestamp TYPE timestampl.

    CLASS-METHODS keep_old_field
      IMPORTING iv_fieldname  TYPE fieldname
                ir_new_record TYPE REF TO data
                ir_old_record TYPE REF TO data.

    " Kiểm tra field có phải FK key tham chiếu bảng cha không.
    " Dùng JOIN DD08L + DD05S (active) thay vì DD05Q (view không có keyflag/reftabname).
    " Nếu đúng -> FE phải chọn từ bảng cha, BE không tự gen UUID.
    CLASS-METHODS is_fk_key_field
      IMPORTING iv_table_name   TYPE tabname
                iv_fieldname    TYPE fieldname
      RETURNING VALUE(rv_is_fk) TYPE abap_bool.

ENDCLASS.

CLASS zcl_record_autofill IMPLEMENTATION.

  METHOD on_create.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    fill_client( ir_record = ir_record ).
    fill_uuid_keys( iv_table_name = iv_table_name ir_record = ir_record ).

    fill_user_field( iv_fieldname = 'CREATED_BY'      ir_record = ir_record ).
    fill_user_field( iv_fieldname = 'CREATEDBY'       ir_record = ir_record ).
    fill_user_field( iv_fieldname = 'CHANGED_BY'      ir_record = ir_record ).
    fill_user_field( iv_fieldname = 'CHANGEDBY'       ir_record = ir_record ).
    fill_user_field( iv_fieldname = 'LAST_CHANGED_BY' ir_record = ir_record ).

    fill_timestamp_field( iv_fieldname = 'CREATED_AT'            ir_record = ir_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'CREATEDAT'             ir_record = ir_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'CHANGED_AT'            ir_record = ir_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'CHANGEDAT'             ir_record = ir_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'LAST_CHANGED_AT'       ir_record = ir_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'LOCAL_LAST_CHANGED_AT' ir_record = ir_record iv_timestamp = lv_ts ).
  ENDMETHOD.

  METHOD on_update.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    fill_client( ir_record = ir_new_record ).

    keep_old_field( iv_fieldname = 'CREATED_BY'  ir_new_record = ir_new_record ir_old_record = ir_old_record ).
    keep_old_field( iv_fieldname = 'CREATEDBY'   ir_new_record = ir_new_record ir_old_record = ir_old_record ).
    keep_old_field( iv_fieldname = 'CREATED_AT'  ir_new_record = ir_new_record ir_old_record = ir_old_record ).
    keep_old_field( iv_fieldname = 'CREATEDAT'   ir_new_record = ir_new_record ir_old_record = ir_old_record ).

    fill_user_field( iv_fieldname = 'CHANGED_BY'      ir_record = ir_new_record ).
    fill_user_field( iv_fieldname = 'CHANGEDBY'       ir_record = ir_new_record ).
    fill_user_field( iv_fieldname = 'LAST_CHANGED_BY' ir_record = ir_new_record ).

    fill_timestamp_field( iv_fieldname = 'CHANGED_AT'            ir_record = ir_new_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'CHANGEDAT'             ir_record = ir_new_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'LAST_CHANGED_AT'       ir_record = ir_new_record iv_timestamp = lv_ts ).
    fill_timestamp_field( iv_fieldname = 'LOCAL_LAST_CHANGED_AT' ir_record = ir_new_record iv_timestamp = lv_ts ).
  ENDMETHOD.

  METHOD fill_client.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).
    IF sy-subrc <> 0. RETURN. ENDIF.

    ASSIGN COMPONENT 'CLIENT' OF STRUCTURE <ls_record> TO FIELD-SYMBOL(<lv_client>).
    IF sy-subrc = 0. TRY. <lv_client> = sy-mandt. CATCH cx_root. ENDTRY. ENDIF.

    ASSIGN COMPONENT 'MANDT' OF STRUCTURE <ls_record> TO FIELD-SYMBOL(<lv_mandt>).
    IF sy-subrc = 0. TRY. <lv_mandt> = sy-mandt. CATCH cx_root. ENDTRY. ENDIF.
  ENDMETHOD.

  METHOD fill_uuid_keys.
    " Gen UUID chỉ khi: UUID type + không phải FK key (JOIN DD08L+DD05S)
    " FK key (vd ENTITY_ID -> ZTPC_HEADER): FE phải chọn, BE giữ nguyên
    " Non-FK key (vd ITEM_ID): BE tự gen UUID mới

    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).
    IF sy-subrc <> 0. RETURN. ENDIF.

    DATA(lt_key_fields) = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).

    LOOP AT lt_key_fields INTO DATA(lv_key_field).
      DATA(lv_fieldname) = CONV fieldname( lv_key_field ).

      IF lv_fieldname = 'CLIENT' OR lv_fieldname = 'MANDT'. CONTINUE. ENDIF.

      ASSIGN COMPONENT lv_fieldname OF STRUCTURE <ls_record>
        TO FIELD-SYMBOL(<lv_key_value>).

      " Bỏ qua nếu field không tồn tại hoặc đã có giá trị (FE đã cung cấp)
      IF sy-subrc <> 0 OR <lv_key_value> IS NOT INITIAL. CONTINUE. ENDIF.

      SELECT SINGLE inttype, leng, rollname, domname
        FROM dd03l
        WHERE tabname   = @iv_table_name
          AND fieldname = @lv_fieldname
          AND as4local  = 'A'
        INTO @DATA(ls_dd03l).

      IF sy-subrc <> 0. CONTINUE. ENDIF.

      DATA(lv_rollname) = CONV string( ls_dd03l-rollname ).
      DATA(lv_domname)  = CONV string( ls_dd03l-domname ).
      TRANSLATE lv_rollname TO UPPER CASE.
      TRANSLATE lv_domname  TO UPPER CASE.

      DATA(lv_is_uuid_type) = abap_false.
      IF ls_dd03l-inttype = 'X' AND ls_dd03l-leng = 16.
        lv_is_uuid_type = abap_true.
      ELSEIF ls_dd03l-inttype = 'C' AND ls_dd03l-leng = 32
         AND ( lv_rollname CS 'UUID' OR lv_domname CS 'UUID'
            OR lv_rollname CS 'SYSUUID' OR lv_domname CS 'SYSUUID' ).
        lv_is_uuid_type = abap_true.
      ENDIF.

      IF lv_is_uuid_type = abap_false. CONTINUE. ENDIF.

      " FK guard: nếu field là FK key tham chiếu bảng cha -> FE cung cấp, không gen
      IF is_fk_key_field( iv_table_name = iv_table_name
                          iv_fieldname  = lv_fieldname ) = abap_true.
        CONTINUE.
      ENDIF.

      TRY.
          IF ls_dd03l-inttype = 'X' AND ls_dd03l-leng = 16.
            <lv_key_value> = cl_system_uuid=>create_uuid_x16_static( ).
          ELSE.
            <lv_key_value> = cl_system_uuid=>create_uuid_c32_static( ).
          ENDIF.
        CATCH cx_uuid_error.
        CATCH cx_root.
      ENDTRY.

    ENDLOOP.
  ENDMETHOD.

  METHOD is_fk_key_field.
    " JOIN DD08L + DD05S để kiểm tra field có phải FK key không.
    "
    " DD08L: TABNAME=bảng con, FIELDNAME=tên FK relationship, CHECKTABLE=bảng cha
    " DD05S: TABNAME=bảng con, FIELDNAME=tên FK relationship,
    "        FORKEY=field bên bảng con, FORTABLE=bảng cha
    "
    " Join qua TABNAME + FIELDNAME + AS4LOCAL, chỉ lấy active (AS4LOCAL='A')

    SELECT SINGLE @abap_true
      FROM dd08l
      INNER JOIN dd05s
        ON  dd05s~tabname   = dd08l~tabname
        AND dd05s~fieldname = dd08l~fieldname
        AND dd05s~as4local  = dd08l~as4local
      WHERE dd08l~tabname    = @iv_table_name
        AND dd08l~as4local   = 'A'
        AND dd08l~checktable IS NOT INITIAL
        AND dd05s~forkey     = @iv_fieldname
      INTO @rv_is_fk.

    IF sy-subrc <> 0. rv_is_fk = abap_false. ENDIF.
  ENDMETHOD.

  METHOD fill_user_field.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).
    IF sy-subrc <> 0. RETURN. ENDIF.

    ASSIGN COMPONENT iv_fieldname OF STRUCTURE <ls_record> TO FIELD-SYMBOL(<lv_user>).
    IF sy-subrc = 0 AND <lv_user> IS INITIAL.
      TRY. <lv_user> = sy-uname. CATCH cx_root. ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD fill_timestamp_field.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).
    IF sy-subrc <> 0. RETURN. ENDIF.

    ASSIGN COMPONENT iv_fieldname OF STRUCTURE <ls_record> TO FIELD-SYMBOL(<lv_timestamp>).
    IF sy-subrc = 0 AND <lv_timestamp> IS INITIAL.
      TRY. <lv_timestamp> = iv_timestamp. CATCH cx_root. ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD keep_old_field.
    ASSIGN ir_new_record->* TO FIELD-SYMBOL(<ls_new>).
    ASSIGN ir_old_record->* TO FIELD-SYMBOL(<ls_old>).
    IF sy-subrc <> 0. RETURN. ENDIF.

    ASSIGN COMPONENT iv_fieldname OF STRUCTURE <ls_new> TO FIELD-SYMBOL(<lv_new>).
    IF sy-subrc <> 0. RETURN. ENDIF.

    ASSIGN COMPONENT iv_fieldname OF STRUCTURE <ls_old> TO FIELD-SYMBOL(<lv_old>).
    IF sy-subrc = 0. TRY. <lv_new> = <lv_old>. CATCH cx_root. ENDTRY. ENDIF.
  ENDMETHOD.

ENDCLASS.
