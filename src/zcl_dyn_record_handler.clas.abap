CLASS zcl_dyn_record_handler DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_result,
        success     TYPE abap_bool,
        message     TYPE string,
        record_key  TYPE ztde_record_key,  "key JSON sau thao tác
      END OF ty_result.

    "INSERT 1 record vào bảng động.
    "Đã bao gồm: deserialize, autofill, insert, audit log.
    CLASS-METHODS create_record
      IMPORTING
        iv_table_name  TYPE tabname
        iv_record_data TYPE string
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    "UPDATE 1 record vào bảng động.
    "Đã bao gồm: deserialize, select old, optimistic lock, autofill, update, audit log.
    CLASS-METHODS update_record
      IMPORTING
        iv_table_name  TYPE tabname
        iv_record_data TYPE string
        iv_etag_field  TYPE string OPTIONAL
        iv_etag_value  TYPE string OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    "DELETE 1 record khỏi bảng động.
    "Đã bao gồm: foreign key check, select old, delete, audit log.
    CLASS-METHODS delete_record
      IMPORTING
        iv_table_name TYPE tabname
        iv_record_key TYPE ztde_record_key
      RETURNING
        VALUE(rs_result) TYPE ty_result.

CLASS-METHODS get_struct_desc
  IMPORTING
    iv_table_name TYPE tabname
  RETURNING
    VALUE(ro_desc) TYPE REF TO cl_abap_structdescr
  RAISING   cx_root.

ENDCLASS.

CLASS zcl_dyn_record_handler IMPLEMENTATION.

  METHOD create_record.
    TRY.
        DATA(lo_desc) = get_struct_desc( iv_table_name ).
        DATA lo_record TYPE REF TO data.
        CREATE DATA lo_record TYPE HANDLE lo_desc.
        ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_record>).

        zcl_json_helper=>deserialize(
          EXPORTING iv_json   = iv_record_data
          CHANGING  ca_record = lo_record
        ).

        zcl_record_autofill=>on_create(
          iv_table_name = iv_table_name
          ir_record     = lo_record
        ).

        INSERT (iv_table_name) FROM <ls_record>.

        IF sy-subrc = 0.
          DATA(lt_keys)  = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
          DATA(lv_key_j) = zcl_record_key_builder=>build_key_json(
            it_key_fields = lt_keys
            ir_record     = lo_record
          ).

          zcl_audit_logger=>log_change(
            iv_table_name  = iv_table_name
            iv_record_key  = CONV #( lv_key_j )
            iv_action_type = 'C'
            iv_new_value   = iv_record_data
          ).

          rs_result = VALUE #(
            success    = abap_true
            message    = 'Record created successfully'
            record_key = CONV #( lv_key_j )
          ).
        ELSE.
          rs_result = VALUE #(
            success = abap_false
            message = |Insert failed with sy-subrc = { sy-subrc }|
          ).
        ENDIF.

      CATCH cx_root INTO DATA(lx).
        rs_result = VALUE #(
          success = abap_false
          message = lx->get_text( )
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD update_record.
    TRY.
        DATA(lo_desc) = get_struct_desc( iv_table_name ).

        "── Deserialize new record ──
        DATA lo_new TYPE REF TO data.
        CREATE DATA lo_new TYPE HANDLE lo_desc.
        ASSIGN lo_new->* TO FIELD-SYMBOL(<ls_new>).

        zcl_json_helper=>deserialize(
          EXPORTING iv_json   = iv_record_data
          CHANGING  ca_record = lo_new
        ).

        "── Select old record ──
        DATA lo_old TYPE REF TO data.
        CREATE DATA lo_old TYPE HANDLE lo_desc.
        ASSIGN lo_old->* TO FIELD-SYMBOL(<ls_old>).

        DATA(lt_keys) = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
        DATA(lv_where) = zcl_record_key_builder=>build_where_clause(
          it_key_fields = lt_keys
          ir_record     = lo_new
        ).

        SELECT SINGLE * FROM (iv_table_name)
          WHERE (lv_where)
          INTO @<ls_old>.

        IF sy-subrc <> 0.
          rs_result = VALUE #(
            success = abap_false
            message = 'Record not found — may have been deleted'
          ).
          RETURN.
        ENDIF.

        "── Optimistic lock ──
        IF iv_etag_field IS NOT INITIAL AND iv_etag_value IS NOT INITIAL.
          ASSIGN COMPONENT iv_etag_field OF STRUCTURE <ls_old>
            TO FIELD-SYMBOL(<lv_etag_db>).
          IF sy-subrc = 0.
            IF condense( |{ <lv_etag_db> }| ) <> condense( iv_etag_value ).
              rs_result = VALUE #(
                success = abap_false
                message = 'Optimistic lock failed: record was modified by another user'
              ).
              RETURN.
            ENDIF.
          ENDIF.
        ENDIF.

        DATA(lv_old_json) = zcl_json_helper=>serialize( <ls_old> ).
        DATA(lv_key_json) = zcl_record_key_builder=>build_key_json(
          it_key_fields = lt_keys
          ir_record     = lo_new
        ).

        zcl_record_autofill=>on_update(
          ir_new_record = lo_new
          ir_old_record = lo_old
        ).

        zcl_audit_logger=>log_change(
          iv_table_name  = iv_table_name
          iv_record_key  = CONV #( lv_key_json )
          iv_action_type = 'U'
          iv_old_value   = lv_old_json
          iv_new_value   = iv_record_data
        ).

        UPDATE (iv_table_name) FROM <ls_new>.

        rs_result = COND #(
          WHEN sy-subrc = 0 THEN VALUE #(
            success    = abap_true
            message    = 'Record updated successfully'
            record_key = CONV #( lv_key_json )
          )
          ELSE VALUE #(
            success = abap_false
            message = 'Update failed — record may not exist'
          )
        ).

      CATCH cx_root INTO DATA(lx).
        rs_result = VALUE #(
          success = abap_false
          message = lx->get_text( )
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD delete_record.
    TRY.
        DATA(lo_desc) = get_struct_desc( iv_table_name ).
        DATA lo_record TYPE REF TO data.
        CREATE DATA lo_record TYPE HANDLE lo_desc.
        ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_record>).

        zcl_json_helper=>deserialize(
          EXPORTING iv_json   = CONV string( iv_record_key )
          CHANGING  ca_record = lo_record
        ).

        ASSIGN COMPONENT 'CLIENT' OF STRUCTURE <ls_record>
          TO FIELD-SYMBOL(<lv_client>).
        IF sy-subrc = 0. <lv_client> = sy-mandt. ENDIF.

        "── Foreign key check ──
        DATA(lv_fk_error) = zcl_dynamic_table_reader=>check_foreign_key(
          iv_table_name = iv_table_name
          iv_record_key = CONV string( iv_record_key )
        ).
        IF lv_fk_error IS NOT INITIAL.
          rs_result = VALUE #( success = abap_false  message = lv_fk_error ).
          RETURN.
        ENDIF.

        "── Select old record cho audit ──
        DATA lo_old TYPE REF TO data.
        CREATE DATA lo_old TYPE HANDLE lo_desc.
        ASSIGN lo_old->* TO FIELD-SYMBOL(<ls_old>).

        DATA(lt_keys)  = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
        DATA(lv_where) = zcl_record_key_builder=>build_where_clause(
          it_key_fields = lt_keys
          ir_record     = lo_record
        ).

        IF lv_where IS NOT INITIAL.
          SELECT SINGLE * FROM (iv_table_name)
            WHERE (lv_where)
            INTO @<ls_old>.
        ENDIF.

        DATA(lv_old_json) = zcl_json_helper=>serialize( <ls_old> ).

        DELETE (iv_table_name) FROM <ls_record>.

        IF sy-subrc = 0.
          zcl_audit_logger=>log_change(
            iv_table_name  = iv_table_name
            iv_record_key  = iv_record_key
            iv_action_type = 'D'
            iv_old_value   = lv_old_json
          ).
          rs_result = VALUE #(
            success    = abap_true
            message    = 'Record deleted successfully'
            record_key = iv_record_key
          ).
        ELSE.
          rs_result = VALUE #(
            success = abap_false
            message = 'Delete failed — record may not exist'
          ).
        ENDIF.

      CATCH cx_root INTO DATA(lx).
        rs_result = VALUE #(
          success = abap_false
          message = lx->get_text( )
        ).
    ENDTRY.
  ENDMETHOD.

METHOD get_struct_desc.
  ro_desc = CAST cl_abap_structdescr(
    cl_abap_typedescr=>describe_by_name( iv_table_name )
  ).
ENDMETHOD.

ENDCLASS.
