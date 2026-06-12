CLASS zcl_record_autofill DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    "Autofill CLIENT, UUID keys rỗng, CREATED_BY/AT, CHANGED_BY/AT khi CREATE
    CLASS-METHODS on_create
      IMPORTING iv_table_name TYPE tabname
                ir_record     TYPE REF TO data.

    "Giữ CREATED_BY/AT từ old record, cập nhật CHANGED_BY/AT khi UPDATE
    CLASS-METHODS on_update
      IMPORTING ir_new_record TYPE REF TO data
                ir_old_record TYPE REF TO data.

ENDCLASS.

CLASS zcl_record_autofill IMPLEMENTATION.

  METHOD on_create.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).

    "── CLIENT ──
    ASSIGN COMPONENT 'CLIENT' OF STRUCTURE <ls_record>
      TO FIELD-SYMBOL(<lv_client>).
    IF sy-subrc = 0. <lv_client> = sy-mandt. ENDIF.

    "── UUID key fields rỗng → generate ──
    DATA(lt_key_fields) = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
    LOOP AT lt_key_fields INTO DATA(lv_uuid_field).
      ASSIGN COMPONENT lv_uuid_field OF STRUCTURE <ls_record>
        TO FIELD-SYMBOL(<lv_uuid_val>).
      IF sy-subrc <> 0 OR <lv_uuid_val> IS NOT INITIAL. CONTINUE. ENDIF.

      SELECT SINGLE inttype, leng FROM dd03l
        WHERE tabname   = @iv_table_name
          AND fieldname = @lv_uuid_field
          AND as4local  = 'A'
        INTO @DATA(ls_dd03l).

      IF ls_dd03l-inttype = 'X' AND ls_dd03l-leng = 16.
        TRY.
            <lv_uuid_val> = cl_system_uuid=>create_uuid_x16_static( ).
          CATCH cx_uuid_error.
        ENDTRY.
      ENDIF.
    ENDLOOP.

    "── CREATED_BY / CHANGED_BY ──
    ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <ls_record>
      TO FIELD-SYMBOL(<lv_created_by>).
    IF sy-subrc = 0 AND <lv_created_by> IS INITIAL. <lv_created_by> = sy-uname. ENDIF.

    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE <ls_record>
      TO FIELD-SYMBOL(<lv_changed_by>).
    IF sy-subrc = 0 AND <lv_changed_by> IS INITIAL. <lv_changed_by> = sy-uname. ENDIF.

    "── CREATED_AT / CHANGED_AT ──
    ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <ls_record>
      TO FIELD-SYMBOL(<lv_created_at>).
    IF sy-subrc = 0 AND <lv_created_at> IS INITIAL.
      TRY. <lv_created_at> = utclong_current( ). CATCH cx_root. ENDTRY.
    ENDIF.

    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <ls_record>
      TO FIELD-SYMBOL(<lv_changed_at>).
    IF sy-subrc = 0 AND <lv_changed_at> IS INITIAL.
      TRY. <lv_changed_at> = utclong_current( ). CATCH cx_root. ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD on_update.
    ASSIGN ir_new_record->* TO FIELD-SYMBOL(<ls_new>).
    ASSIGN ir_old_record->* TO FIELD-SYMBOL(<ls_old>).

    "── CLIENT ──
    ASSIGN COMPONENT 'CLIENT' OF STRUCTURE <ls_new>
      TO FIELD-SYMBOL(<lv_new_client>).
    IF sy-subrc = 0. TRY. <lv_new_client> = sy-mandt. CATCH cx_root. ENDTRY. ENDIF.

    "── Giữ CREATED_BY / CREATED_AT từ old ──
    ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <ls_new> TO FIELD-SYMBOL(<lv_new_cb>).
    ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <ls_old> TO FIELD-SYMBOL(<lv_old_cb>).
    IF sy-subrc = 0. TRY. <lv_new_cb> = <lv_old_cb>. CATCH cx_root. ENDTRY. ENDIF.

    ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <ls_new> TO FIELD-SYMBOL(<lv_new_ca>).
    ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <ls_old> TO FIELD-SYMBOL(<lv_old_ca>).
    IF sy-subrc = 0. TRY. <lv_new_ca> = <lv_old_ca>. CATCH cx_root. ENDTRY. ENDIF.

    "── Cập nhật CHANGED_BY / CHANGED_AT ──
    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE <ls_new>
      TO FIELD-SYMBOL(<lv_changed_by>).
    IF sy-subrc = 0. TRY. <lv_changed_by> = sy-uname. CATCH cx_root. ENDTRY. ENDIF.

    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <ls_new>
      TO FIELD-SYMBOL(<lv_changed_at>).
    IF sy-subrc = 0. TRY. <lv_changed_at> = utclong_current( ). CATCH cx_root. ENDTRY. ENDIF.
  ENDMETHOD.

ENDCLASS.
