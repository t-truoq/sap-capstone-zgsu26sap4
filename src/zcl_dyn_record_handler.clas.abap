
CLASS zcl_dyn_record_handler DEFINITION
PUBLIC FINAL CREATE PUBLIC.
PUBLIC SECTION.
TYPES:
      BEGIN OF ty_result,
        success     TYPE abap_bool,
        message     TYPE string,
        record_key  TYPE ztde_record_key,  "key JSON sau thao tác
      END OF ty_result.

    TYPES:
      BEGIN OF ty_validation_error,
        fieldname TYPE fieldname,
        value     TYPE string,
        message   TYPE string,
      END OF ty_validation_error,
      tt_validation_errors TYPE STANDARD TABLE OF ty_validation_error WITH DEFAULT KEY.

    "INSERT 1 record vào bảng động.
    "Đã bao gồm: deserialize, autofill, insert, audit log.
    CLASS-METHODS create_record
      IMPORTING
        iv_table_name  TYPE tabname
        iv_record_data TYPE string
        iv_parent_audit_id TYPE sysuuid_c32 OPTIONAL
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
        iv_parent_audit_id TYPE sysuuid_c32 OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    "DELETE 1 record khỏi bảng động.
    "Đã bao gồm: foreign key check, select old, delete, audit log.
    CLASS-METHODS delete_record
      IMPORTING
        iv_table_name TYPE tabname
        iv_record_key TYPE ztde_record_key
        iv_parent_audit_id TYPE sysuuid_c32 OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE ty_result.

CLASS-METHODS get_struct_desc
  IMPORTING
    iv_table_name TYPE tabname
  RETURNING
    VALUE(ro_desc) TYPE REF TO cl_abap_structdescr
  RAISING   cx_root.

TYPES:
      tt_string_table TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    CLASS-METHODS:
      get_table_data
        IMPORTING
          iv_table_name   TYPE tabname
          iv_where_clause TYPE string OPTIONAL
          iv_max_rows     TYPE i DEFAULT 100
        RETURNING
          VALUE(rt_data)  TYPE REF TO data
        RAISING
          cx_sy_dynamic_osql_error,

      get_key_fields
        IMPORTING
          iv_table_name        TYPE tabname
        RETURNING
          VALUE(rt_key_fields) TYPE tt_string_table,

      check_foreign_key
        IMPORTING
          iv_table_name        TYPE tabname
          iv_record_key        TYPE string
        RETURNING
          VALUE(rv_error)      TYPE string.

    CLASS-METHODS get_single_record
      IMPORTING iv_table_name  TYPE tabname
                iv_where      TYPE string
      RETURNING VALUE(rr_row)  TYPE REF TO data
      RAISING   zcx_excel_pipeline
                cx_sy_dynamic_osql_error.

CLASS-METHODS serialize
      IMPORTING ia_data        TYPE any
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS deserialize
      IMPORTING iv_json   TYPE string
      CHANGING  ca_record TYPE REF TO data
      RAISING   cx_root.

    "Deserialize JSON array into single-row data references.
    "Each row goes through deserialize() so RAW/UUID handling stays identical.
    TYPES tt_data_refs TYPE STANDARD TABLE OF REF TO data WITH DEFAULT KEY.

    CLASS-METHODS deserialize_batch
      IMPORTING
        iv_table_name  TYPE tabname
        iv_json_array  TYPE string
      RETURNING
        VALUE(rt_refs) TYPE tt_data_refs
      RAISING
        cx_root.

CLASS-METHODS on_create
      IMPORTING iv_table_name TYPE tabname
                ir_record     TYPE REF TO data.

    CLASS-METHODS on_update
      IMPORTING ir_new_record TYPE REF TO data
                ir_old_record TYPE REF TO data.

    CLASS-METHODS apply_admin_on_insert
      CHANGING cs_record TYPE any.

    CLASS-METHODS apply_admin_on_update
      CHANGING cs_record TYPE any.

"Tạo WHERE clause động từ danh sách key fields và 1 record
    CLASS-METHODS build_where_clause
      IMPORTING it_key_fields   TYPE string_table
                ir_record       TYPE REF TO data
                iv_keep_spaces  TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_where) TYPE string.

    "Tạo JSON key {"FIELD":"VALUE"} cho audit log
    CLASS-METHODS build_key_json
      IMPORTING it_key_fields      TYPE string_table
                ir_record          TYPE REF TO data
      RETURNING VALUE(rv_key_json) TYPE string.

    CLASS-METHODS validate_domain_values
      IMPORTING
        iv_table_name TYPE tabname
        ir_record     TYPE REF TO data
      RETURNING VALUE(rt_errors) TYPE tt_validation_errors.
PRIVATE SECTION.
CLASS-METHODS serialize_struct
      IMPORTING ia_struct      TYPE any
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS assign_hex_to_raw
      IMPORTING iv_hex       TYPE string
                iv_fieldname TYPE string
      CHANGING  ca_record    TYPE REF TO data.

    CLASS-METHODS extract_json_value
      IMPORTING iv_json        TYPE string
                iv_field_name  TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    CLASS-METHODS split_json_array
      IMPORTING iv_json         TYPE string
      RETURNING VALUE(rt_items) TYPE string_table.

CLASS-METHODS fill_client
      IMPORTING ir_record TYPE REF TO data.

    CLASS-METHODS fill_uuid_keys
      IMPORTING iv_table_name TYPE tabname
                ir_record     TYPE REF TO data.

    CLASS-METHODS fill_user_field
      IMPORTING iv_fieldname TYPE fieldname
                ir_record    TYPE REF TO data
                iv_force     TYPE abap_bool DEFAULT abap_false.

    CLASS-METHODS fill_timestamp_field
      IMPORTING iv_fieldname TYPE fieldname
                ir_record    TYPE REF TO data
                iv_timestamp TYPE timestampl
                iv_force     TYPE abap_bool DEFAULT abap_false.

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

    TYPES:
      BEGIN OF ty_check_info,
        checktable TYPE tabname,
        has_fixed  TYPE abap_bool,
      END OF ty_check_info.

    CLASS-METHODS get_domain_check_info
      IMPORTING iv_table_name TYPE tabname
                iv_fieldname  TYPE fieldname
      RETURNING VALUE(rs_info) TYPE ty_check_info.

    CLASS-METHODS check_fixed_value
      IMPORTING iv_table_name TYPE tabname
                iv_fieldname  TYPE fieldname
                iv_value      TYPE string
      RETURNING VALUE(rv_valid) TYPE abap_bool.

    CLASS-METHODS build_validation_message
      IMPORTING it_errors TYPE tt_validation_errors
      RETURNING VALUE(rv_msg) TYPE string.
ENDCLASS.


CLASS zcl_dyn_record_handler IMPLEMENTATION.
METHOD create_record.
    TRY.
        DATA(lo_desc) = get_struct_desc( iv_table_name ).
        DATA lo_record TYPE REF TO data.
        CREATE DATA lo_record TYPE HANDLE lo_desc.
        ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_record>).

        zcl_dyn_record_handler=>deserialize(
          EXPORTING iv_json   = iv_record_data
          CHANGING  ca_record = lo_record
        ).

        DATA(lt_val_errors) = validate_domain_values(
          iv_table_name = iv_table_name
          ir_record     = lo_record ).
        IF lt_val_errors IS NOT INITIAL.
          rs_result = VALUE #(
            success = abap_false
            message = build_validation_message( lt_val_errors ) ).
          RETURN.
        ENDIF.

        zcl_dyn_record_handler=>on_create(
          iv_table_name = iv_table_name
          ir_record     = lo_record
        ).

        INSERT (iv_table_name) FROM <ls_record>.

        IF sy-subrc = 0.
          DATA(lt_keys)  = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).
          DATA(lv_key_j) = zcl_dyn_record_handler=>build_key_json(
            it_key_fields = lt_keys
            ir_record     = lo_record
          ).

          zcl_aprvl_util=>log_change(
            iv_table_name  = iv_table_name
            iv_record_key  = CONV #( lv_key_j )
            iv_action_type = 'C'
            iv_new_value   = zcl_dyn_record_handler=>serialize( <ls_record> )
            iv_parent_audit_id = iv_parent_audit_id
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

        zcl_dyn_record_handler=>deserialize(
          EXPORTING iv_json   = iv_record_data
          CHANGING  ca_record = lo_new
        ).

        DATA(lt_val_errors) = validate_domain_values(
          iv_table_name = iv_table_name
          ir_record     = lo_new ).
        IF lt_val_errors IS NOT INITIAL.
          rs_result = VALUE #(
            success = abap_false
            message = build_validation_message( lt_val_errors ) ).
          RETURN.
        ENDIF.

        "── Select old record ──
        DATA lo_old TYPE REF TO data.
        CREATE DATA lo_old TYPE HANDLE lo_desc.
        ASSIGN lo_old->* TO FIELD-SYMBOL(<ls_old>).

        DATA(lt_keys) = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).
        DATA(lv_where) = zcl_dyn_record_handler=>build_where_clause(
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

        DATA(lv_old_json) = zcl_dyn_record_handler=>serialize( <ls_old> ).
        DATA(lv_key_json) = zcl_dyn_record_handler=>build_key_json(
          it_key_fields = lt_keys
          ir_record     = lo_new
        ).

        zcl_dyn_record_handler=>on_update(
          ir_new_record = lo_new
          ir_old_record = lo_old
        ).

        zcl_aprvl_util=>log_change(
          iv_table_name  = iv_table_name
          iv_record_key  = CONV #( lv_key_json )
          iv_action_type = 'U'
          iv_old_value   = lv_old_json
          iv_new_value   = zcl_dyn_record_handler=>serialize( <ls_new> )
          iv_parent_audit_id = iv_parent_audit_id
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

        zcl_dyn_record_handler=>deserialize(
          EXPORTING iv_json   = CONV string( iv_record_key )
          CHANGING  ca_record = lo_record
        ).

        ASSIGN COMPONENT 'CLIENT' OF STRUCTURE <ls_record>
          TO FIELD-SYMBOL(<lv_client>).
        IF sy-subrc = 0. <lv_client> = sy-mandt. ENDIF.

        "── Foreign key check ──
        DATA(lv_fk_error) = zcl_dyn_record_handler=>check_foreign_key(
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

        DATA(lt_keys)  = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).
        DATA(lv_where) = zcl_dyn_record_handler=>build_where_clause(
          it_key_fields = lt_keys
          ir_record     = lo_record
        ).

        IF lv_where IS NOT INITIAL.
          SELECT SINGLE * FROM (iv_table_name)
            WHERE (lv_where)
            INTO @<ls_old>.
        ENDIF.

        DATA(lv_old_json) = zcl_dyn_record_handler=>serialize( <ls_old> ).

        DELETE (iv_table_name) FROM <ls_record>.

        IF sy-subrc = 0.
          zcl_aprvl_util=>log_change(
            iv_table_name  = iv_table_name
            iv_record_key  = iv_record_key
            iv_action_type = 'D'
            iv_old_value   = lv_old_json
            iv_parent_audit_id = iv_parent_audit_id
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

  METHOD get_table_data.
    " Tạo dynamic internal table từ table name
    DATA(lo_struct_desc) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_name( iv_table_name )
    ).

    DATA(lo_table_desc) = cl_abap_tabledescr=>create(
      p_line_type = lo_struct_desc
    ).

    CREATE DATA rt_data TYPE HANDLE lo_table_desc.
    ASSIGN rt_data->* TO FIELD-SYMBOL(<lt_table>).

    " Dynamic SELECT
    IF iv_where_clause IS INITIAL.
      SELECT *
        FROM (iv_table_name)
        INTO TABLE @<lt_table>
        UP TO @iv_max_rows ROWS.
    ELSE.
      SELECT *
        FROM (iv_table_name)
        WHERE (iv_where_clause)
        INTO TABLE @<lt_table>
        UP TO @iv_max_rows ROWS.
    ENDIF.
  ENDMETHOD.

  METHOD get_key_fields.
    " Đọc key fields từ DD03L
    SELECT fieldname
      FROM dd03l
      WHERE tabname  = @iv_table_name
        AND keyflag  = 'X'
        AND as4local = 'A'
        AND fieldname NOT LIKE '.%'
      INTO TABLE @DATA(lt_keys).

    LOOP AT lt_keys INTO DATA(ls_key).
      APPEND ls_key-fieldname TO rt_key_fields.
    ENDLOOP.
  ENDMETHOD.

 METHOD check_foreign_key.
    " Đọc tất cả foreign key relationships từ DD08L
    " DD08L chứa thông tin foreign key definitions
    DATA lt_fk_refs TYPE TABLE OF dd08l.

    SELECT *
      FROM dd08l
      WHERE checktable = @iv_table_name
      INTO TABLE @lt_fk_refs.

    IF lt_fk_refs IS INITIAL.
      RETURN.
    ENDIF.

    " Deserialize record key JSON
    TRY.
        DATA(lo_struct_desc) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( iv_table_name )
        ).
        DATA lo_record TYPE REF TO data.
        CREATE DATA lo_record TYPE HANDLE lo_struct_desc.
        ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_record>).

        /ui2/cl_json=>deserialize(
          EXPORTING json = iv_record_key
          CHANGING  data = <ls_record>
        ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    " Check từng table đang reference
    LOOP AT lt_fk_refs INTO DATA(ls_fk).

      " Đọc field mapping từ DD05Q
      DATA lt_fk_fields TYPE TABLE OF dd05q.
     SELECT *
        FROM dd05q
        WHERE tabname  = @ls_fk-tabname
          AND checktable = @iv_table_name
        INTO TABLE @lt_fk_fields.

      " Build WHERE clause
      DATA lv_where TYPE string.
      LOOP AT lt_fk_fields INTO DATA(ls_fk_field).
        ASSIGN COMPONENT ls_fk_field-checkfield
          OF STRUCTURE <ls_record>
          TO FIELD-SYMBOL(<lv_val>).

        IF sy-subrc = 0 AND <lv_val> IS NOT INITIAL.
          IF lv_where IS INITIAL.
            lv_where = |{ ls_fk_field-fieldname } = '{ <lv_val> }'|.
          ELSE.
            lv_where = lv_where && | AND { ls_fk_field-fieldname } = '{ <lv_val> }'|.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF lv_where IS INITIAL.
        CONTINUE.
      ENDIF.

      " Check xem có record nào reference không
      TRY.
          SELECT SINGLE @abap_true
            FROM (ls_fk-tabname)
            WHERE (lv_where)
            INTO @DATA(lv_exists).

          IF lv_exists = abap_true.
            rv_error = |Cannot delete: record is referenced by table { ls_fk-tabname }|.
            RETURN.
          ENDIF.

        CATCH cx_sy_dynamic_osql_error.
          CONTINUE.
      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

METHOD serialize.
    TRY.
        DATA(lo_desc) = cl_abap_typedescr=>describe_by_data( ia_data ).

        CASE lo_desc->kind.

          WHEN cl_abap_typedescr=>kind_struct.
            " Single structure → serialize_struct xử lý RAW post-process
            rv_json = serialize_struct( ia_data ).

          WHEN cl_abap_typedescr=>kind_table.
            " Table of structures → serialize từng row rồi assemble JSON array
            DATA(lo_tdesc) = CAST cl_abap_tabledescr( lo_desc ).
            DATA(lo_rdesc) = lo_tdesc->get_table_line_type( ).

            IF lo_rdesc->kind = cl_abap_typedescr=>kind_struct.
              " Table chứa structure có RAW fields → cần post-process từng row
              DATA(lv_has_raw) = abap_false.
              DATA(lo_sdesc)   = CAST cl_abap_structdescr( lo_rdesc ).
              LOOP AT lo_sdesc->get_components( ) INTO DATA(ls_comp_check)
                WHERE type->type_kind = cl_abap_typedescr=>typekind_hex.
                lv_has_raw = abap_true. EXIT.
              ENDLOOP.

              IF lv_has_raw = abap_true.
                " Serialize từng row để đảm bảo RAW → hex
                ASSIGN ia_data TO FIELD-SYMBOL(<lt_table>).
                DATA lt_row_jsons TYPE string_table.

                LOOP AT <lt_table> ASSIGNING FIELD-SYMBOL(<ls_row>).
                  APPEND serialize_struct( <ls_row> ) TO lt_row_jsons.
                ENDLOOP.

                rv_json = `[`.
                LOOP AT lt_row_jsons INTO DATA(lv_row_json).
                  IF sy-tabix > 1. rv_json &&= `,`. ENDIF.
                  rv_json &&= lv_row_json.
                ENDLOOP.
                rv_json &&= `]`.
                RETURN.
              ENDIF.
            ENDIF.

            " Table không có RAW → serialize thẳng
            TRY.
                rv_json = /ui2/cl_json=>serialize(
                  data        = ia_data
                  pretty_name = /ui2/cl_json=>pretty_mode-none
                ).
              CATCH cx_root.
                rv_json = '[]'.
            ENDTRY.

          WHEN OTHERS.
            " Primitive, reference, etc. → serialize thẳng
            TRY.
                rv_json = /ui2/cl_json=>serialize(
                  data        = ia_data
                  pretty_name = /ui2/cl_json=>pretty_mode-none
                ).
              CATCH cx_root.
                rv_json = '""'.
            ENDTRY.
        ENDCASE.

      CATCH cx_root.
        rv_json = '{}'.
    ENDTRY.
  ENDMETHOD.
  METHOD serialize_struct.
    " Bước 1: Serialize bình thường — /ui2/cl_json có thể encode RAW thành Base64
    TRY.
        rv_json = /ui2/cl_json=>serialize(
          data        = ia_struct
          pretty_name = /ui2/cl_json=>pretty_mode-none
        ).
      CATCH cx_root.
        rv_json = '{}'. RETURN.
    ENDTRY.

    " Bước 2: Post-process — replace giá trị Base64 của RAW fields bằng hex string
    " SM30 approach: đọc descriptor để biết chính xác field nào là RAW
    TRY.
        DATA(lo_sdesc) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_data( ia_struct )
        ).

        LOOP AT lo_sdesc->get_components( ) INTO DATA(ls_comp)
          WHERE type->type_kind = cl_abap_typedescr=>typekind_hex.

          ASSIGN COMPONENT ls_comp-name OF STRUCTURE ia_struct
            TO FIELD-SYMBOL(<lv_raw>).
          IF sy-subrc <> 0 OR <lv_raw> IS INITIAL. CONTINUE. ENDIF.

          " Lấy hex string chuẩn từ ABAP
          DATA(lv_hex_str) = |{ <lv_raw> }|.
          CONDENSE lv_hex_str NO-GAPS.
          TRANSLATE lv_hex_str TO UPPER CASE.

          " Replace bất kỳ giá trị nào /ui2/cl_json đã ghi cho field này
          " Pattern: "FIELDNAME":"<any_value>"
          DATA(lv_pattern) = |"{ ls_comp-name }":"([^"]*)"|.
          DATA(lv_replace) = |"{ ls_comp-name }":"{ lv_hex_str }"|.
          REPLACE FIRST OCCURRENCE OF REGEX lv_pattern
            IN rv_json
            WITH lv_replace.

        ENDLOOP.

      CATCH cx_root.
        " Nếu fail post-process → vẫn trả JSON gốc, không crash
    ENDTRY.
  ENDMETHOD.

  METHOD deserialize.
    ASSIGN ca_record->* TO FIELD-SYMBOL(<ls_record>).

    TRY.
        DATA(lo_sdesc) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_data( <ls_record> )
        ).
      CATCH cx_sy_move_cast_error.
        " Không phải structure → deserialize thẳng, không xử lý RAW
        TRY.
            /ui2/cl_json=>deserialize( EXPORTING json = iv_json CHANGING data = <ls_record> ).
          CATCH cx_root INTO DATA(lx_plain).
            RAISE EXCEPTION TYPE cx_sy_conversion_no_date_time
              EXPORTING value = lx_plain->get_text( ).
        ENDTRY.
        RETURN.
    ENDTRY.

    " ── Bước 1: Strip RAW fields khỏi JSON để /ui2/cl_json không crash ──
    " Đồng thời lưu lại hex values từ JSON gốc để assign sau
    DATA(lv_json_safe) = iv_json.
    DATA lt_raw_map TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line. " dùng fieldname làm key
    " Dùng string table thay vì hashed để map fieldname → hex value
    TYPES: BEGIN OF ty_raw_entry,
             fieldname TYPE string,
             hex_value TYPE string,
           END OF ty_raw_entry.
    DATA lt_raw_entries TYPE TABLE OF ty_raw_entry.

    LOOP AT lo_sdesc->get_components( ) INTO DATA(ls_comp)
      WHERE type->type_kind = cl_abap_typedescr=>typekind_hex.

      DATA(lv_hex_val) = extract_json_value(
        iv_json       = iv_json
        iv_field_name = ls_comp-name
      ).

      " Lưu lại để assign sau dù có value hay không
      APPEND VALUE #(
        fieldname = ls_comp-name
        hex_value = lv_hex_val
      ) TO lt_raw_entries.

      " Strip khỏi JSON safe nếu có value (tránh /ui2/cl_json crash)
      IF lv_hex_val IS NOT INITIAL.
        REPLACE ALL OCCURRENCES OF |"{ ls_comp-name }":"{ lv_hex_val }"|
          IN lv_json_safe
          WITH |"{ ls_comp-name }":""|.
      ENDIF.
    ENDLOOP.

    " ── Bước 2: Deserialize phần CHAR/DATE/NUM bình thường ──
    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_json_safe
          CHANGING  data = <ls_record>
        ).
      CATCH cx_root INTO DATA(lx_deser).
        RAISE EXCEPTION TYPE cx_sy_conversion_no_date_time
          EXPORTING value = lx_deser->get_text( ).
    ENDTRY.

    " ── Bước 3: Assign RAW fields từ hex string đã lưu ──
    " FE cam kết gửi đúng hex string UPPERCASE — BE convert thẳng, không detect
    LOOP AT lt_raw_entries INTO DATA(ls_raw_entry).
      IF ls_raw_entry-hex_value IS INITIAL. CONTINUE. ENDIF.

      " Validate độ dài: hex string phải = field length * 2
      DATA(lo_comp_type) = CAST cl_abap_elemdescr(
        lo_sdesc->get_component_type( ls_raw_entry-fieldname )
      ).
      DATA(lv_expected_len) = lo_comp_type->length * 2.

      DATA(lv_hex_clean) = ls_raw_entry-hex_value.
      CONDENSE lv_hex_clean NO-GAPS.
      TRANSLATE lv_hex_clean TO UPPER CASE.

      " Fail fast: sai độ dài → bỏ qua field này (contract violation từ FE)
      IF strlen( lv_hex_clean ) <> lv_expected_len.
        CONTINUE.
      ENDIF.

      " Assign hex → RAW
      assign_hex_to_raw(
        EXPORTING iv_hex       = lv_hex_clean
                  iv_fieldname = ls_raw_entry-fieldname
        CHANGING  ca_record    = ca_record
      ).
    ENDLOOP.
  ENDMETHOD.

  METHOD deserialize_batch.
    DATA(lo_desc)       = get_struct_desc( iv_table_name ).
    DATA(lt_json_items) = split_json_array( iv_json_array ).

    IF lt_json_items IS INITIAL.
      RAISE EXCEPTION TYPE cx_sy_conversion_no_date_time
        EXPORTING value = 'JSON array is empty or invalid'.
    ENDIF.

    LOOP AT lt_json_items INTO DATA(lv_item_json).
      DATA lr_item TYPE REF TO data.
      CREATE DATA lr_item TYPE HANDLE lo_desc.

      zcl_dyn_record_handler=>deserialize(
        EXPORTING iv_json   = lv_item_json
        CHANGING  ca_record = lr_item
      ).

      APPEND lr_item TO rt_refs.
    ENDLOOP.
  ENDMETHOD.

  METHOD split_json_array.
    DATA lv_obj_depth TYPE i VALUE 0.
    DATA lv_in_str    TYPE abap_bool VALUE abap_false.
    DATA lv_escape    TYPE abap_bool VALUE abap_false.
    DATA lv_item      TYPE string.
    DATA lv_started   TYPE abap_bool VALUE abap_false.
    DATA lv_char      TYPE c LENGTH 1.
    DATA lv_len       TYPE i.
    DATA lv_idx       TYPE i.

    lv_len = strlen( iv_json ).

    DO lv_len TIMES.
      lv_idx  = sy-index - 1.
      lv_char = iv_json+lv_idx(1).

      IF lv_in_str = abap_true.
        IF lv_started = abap_true.
          lv_item = lv_item && lv_char.
        ENDIF.
        IF lv_escape = abap_true.
          lv_escape = abap_false.
        ELSEIF lv_char = '\'.
          lv_escape = abap_true.
        ELSEIF lv_char = '"'.
          lv_in_str = abap_false.
        ENDIF.
        CONTINUE.
      ENDIF.

      CASE lv_char.
        WHEN '"'.
          lv_in_str = abap_true.
          IF lv_started = abap_true.
            lv_item = lv_item && lv_char.
          ENDIF.

        WHEN '{'.
          IF lv_obj_depth = 0.
            lv_started = abap_true.
            CLEAR lv_item.
          ENDIF.
          lv_obj_depth = lv_obj_depth + 1.
          IF lv_started = abap_true.
            lv_item = lv_item && lv_char.
          ENDIF.

        WHEN '}'.
          IF lv_started = abap_true.
            lv_item = lv_item && lv_char.
          ENDIF.
          lv_obj_depth = lv_obj_depth - 1.
          IF lv_obj_depth = 0.
            APPEND lv_item TO rt_items.
            lv_started = abap_false.
            CLEAR lv_item.
          ENDIF.

        WHEN '[' OR ']'.
          IF lv_started = abap_true.
            lv_item = lv_item && lv_char.
          ENDIF.

        WHEN OTHERS.
          IF lv_started = abap_true.
            lv_item = lv_item && lv_char.
          ENDIF.
      ENDCASE.
    ENDDO.
  ENDMETHOD.

METHOD assign_hex_to_raw.
  ASSIGN ca_record->* TO FIELD-SYMBOL(<ls_record>).

  ASSIGN COMPONENT iv_fieldname OF STRUCTURE <ls_record>
    TO FIELD-SYMBOL(<lv_target>).
  IF sy-subrc <> 0. RETURN. ENDIF.

  DATA lo_raw TYPE REF TO data.

  TRY.
      DATA(lo_elem)    = CAST cl_abap_elemdescr(
        cl_abap_typedescr=>describe_by_data( <lv_target> )
      ).
      DATA(lv_raw_len) = lo_elem->length.

      CREATE DATA lo_raw TYPE x LENGTH lv_raw_len.
      ASSIGN lo_raw->* TO FIELD-SYMBOL(<lv_raw>).

      DO lv_raw_len TIMES.
        DATA(lv_offset)   = ( sy-index - 1 ) * 2.
        DATA(lv_byte_hex) = iv_hex+lv_offset(2).
        DATA(lv_xstring)  = CONV xstring( lv_byte_hex ).
        DATA lv_byte      TYPE x LENGTH 1.
        lv_byte           = lv_xstring.
        DATA(lv_pos)      = sy-index - 1.
        <lv_raw>+lv_pos(1) = lv_byte.
      ENDDO.

      <lv_target> = <lv_raw>.

    CATCH cx_root.
  ENDTRY.
ENDMETHOD.

  METHOD extract_json_value.
    DATA(lv_pattern) = |"{ iv_field_name }"|.

    FIND lv_pattern IN iv_json MATCH OFFSET DATA(lv_off).
    IF sy-subrc <> 0. RETURN. ENDIF.

    lv_off += strlen( lv_pattern ).
    DATA(lv_remaining) = iv_json+lv_off.

    FIND `"` IN lv_remaining MATCH OFFSET DATA(lv_start).
    IF sy-subrc <> 0. RETURN. ENDIF.
    lv_start += 1.

    DATA(lv_after_quote) = lv_remaining+lv_start.
    FIND `"` IN lv_after_quote MATCH OFFSET DATA(lv_end).
    IF sy-subrc <> 0. RETURN. ENDIF.

    rv_value = lv_after_quote+0(lv_end).
  ENDMETHOD.

  METHOD on_create.
    fill_client( ir_record = ir_record ).
    fill_uuid_keys( iv_table_name = iv_table_name ir_record = ir_record ).
    ASSIGN ir_record->* TO FIELD-SYMBOL(<record>).
    IF <record> IS ASSIGNED.
      apply_admin_on_insert( CHANGING cs_record = <record> ).
    ENDIF.
  ENDMETHOD.

  METHOD get_single_record.
    DATA(lr_table) = get_table_data(
      iv_table_name   = iv_table_name
      iv_where_clause = iv_where
      iv_max_rows     = 1 ).

    FIELD-SYMBOLS <table> TYPE STANDARD TABLE.
    ASSIGN lr_table->* TO <table>.
    IF <table> IS NOT ASSIGNED OR <table> IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |No record found for WHERE: { iv_where }|.
    ENDIF.

    READ TABLE <table> INDEX 1 ASSIGNING FIELD-SYMBOL(<row>).
    CREATE DATA rr_row TYPE (iv_table_name).
    ASSIGN rr_row->* TO FIELD-SYMBOL(<copy>).
    <copy> = <row>.
  ENDMETHOD.

  METHOD on_update.
    fill_client( ir_record = ir_new_record ).

    keep_old_field( iv_fieldname = 'CREATED_BY'  ir_new_record = ir_new_record ir_old_record = ir_old_record ).
    keep_old_field( iv_fieldname = 'CREATEDBY'   ir_new_record = ir_new_record ir_old_record = ir_old_record ).
    keep_old_field( iv_fieldname = 'CREATED_AT'  ir_new_record = ir_new_record ir_old_record = ir_old_record ).
    keep_old_field( iv_fieldname = 'CREATEDAT'   ir_new_record = ir_new_record ir_old_record = ir_old_record ).

    ASSIGN ir_new_record->* TO FIELD-SYMBOL(<record>).
    IF <record> IS ASSIGNED.
      apply_admin_on_update( CHANGING cs_record = <record> ).
    ENDIF.
  ENDMETHOD.

  METHOD apply_admin_on_insert.
    DATA lr_record TYPE REF TO data.
    GET REFERENCE OF cs_record INTO lr_record.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    fill_user_field( iv_fieldname = 'CREATED_BY'      ir_record = lr_record iv_force = abap_true ).
    fill_user_field( iv_fieldname = 'CREATEDBY'       ir_record = lr_record iv_force = abap_true ).
    fill_user_field( iv_fieldname = 'CHANGED_BY'      ir_record = lr_record iv_force = abap_true ).
    fill_user_field( iv_fieldname = 'CHANGEDBY'       ir_record = lr_record iv_force = abap_true ).
    fill_user_field( iv_fieldname = 'LAST_CHANGED_BY' ir_record = lr_record iv_force = abap_true ).

    fill_timestamp_field( iv_fieldname = 'CREATED_AT'            ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'CREATEDAT'             ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'CHANGED_AT'            ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'CHANGEDAT'             ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'LAST_CHANGED_AT'       ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'LOCAL_LAST_CHANGED_AT' ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
  ENDMETHOD.

  METHOD apply_admin_on_update.
    DATA lr_record TYPE REF TO data.
    GET REFERENCE OF cs_record INTO lr_record.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    fill_user_field( iv_fieldname = 'CHANGED_BY'      ir_record = lr_record iv_force = abap_true ).
    fill_user_field( iv_fieldname = 'CHANGEDBY'       ir_record = lr_record iv_force = abap_true ).
    fill_user_field( iv_fieldname = 'LAST_CHANGED_BY' ir_record = lr_record iv_force = abap_true ).

    fill_timestamp_field( iv_fieldname = 'CHANGED_AT'            ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'CHANGEDAT'             ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'LAST_CHANGED_AT'       ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
    fill_timestamp_field( iv_fieldname = 'LOCAL_LAST_CHANGED_AT' ir_record = lr_record iv_timestamp = lv_ts iv_force = abap_true ).
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

    DATA(lt_key_fields) = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).

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
    IF sy-subrc = 0 AND ( iv_force = abap_true OR <lv_user> IS INITIAL ).
      TRY. <lv_user> = sy-uname. CATCH cx_root. ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD fill_timestamp_field.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).
    IF sy-subrc <> 0. RETURN. ENDIF.

    ASSIGN COMPONENT iv_fieldname OF STRUCTURE <ls_record> TO FIELD-SYMBOL(<lv_timestamp>).
    IF sy-subrc = 0 AND ( iv_force = abap_true OR <lv_timestamp> IS INITIAL ).
      TRY.
          DATA(lo_type) = cl_abap_typedescr=>describe_by_data( <lv_timestamp> ).
          IF lo_type->type_kind = cl_abap_typedescr=>typekind_int8.
            <lv_timestamp> = utclong_current( ).
          ELSE.
            <lv_timestamp> = iv_timestamp.
          ENDIF.
        CATCH cx_root.
      ENDTRY.
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

METHOD build_where_clause.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).

    LOOP AT it_key_fields INTO DATA(lv_key_field).

      IF lv_key_field = 'MANDT' OR lv_key_field = 'CLIENT'.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT lv_key_field OF STRUCTURE <ls_record>
        TO FIELD-SYMBOL(<lv_val>).
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      DATA(lo_elem_desc) = cl_abap_typedescr=>describe_by_data( <lv_val> ).
      DATA(lv_condition) = VALUE string( ).

      IF lo_elem_desc->type_kind = cl_abap_typedescr=>typekind_hex.
        DATA(lv_hex_str) = |{ <lv_val> }|.
        CONDENSE lv_hex_str NO-GAPS.
        TRANSLATE lv_hex_str TO UPPER CASE.
        lv_condition = |{ lv_key_field } = '{ lv_hex_str }'|.
      ELSE.
        DATA(lv_val_str) = |{ <lv_val> }|.
        IF iv_keep_spaces = abap_false.
          CONDENSE lv_val_str NO-GAPS.
        ENDIF.
        REPLACE ALL OCCURRENCES OF |'| IN lv_val_str WITH |''|.

        DATA(lv_is_uuid) = abap_false.
        IF strlen( lv_val_str ) = 32.
          FIND REGEX '^[0-9A-Fa-f]{32}$' IN lv_val_str.
          IF sy-subrc = 0. lv_is_uuid = abap_true. ENDIF.
        ENDIF.

        IF lv_is_uuid = abap_true.
          TRANSLATE lv_val_str TO UPPER CASE.
          lv_condition = |{ lv_key_field } = '{ lv_val_str }'|.
        ELSE.
          lv_condition = |{ lv_key_field } = '{ lv_val_str }'|.
        ENDIF.
      ENDIF.

      rv_where = COND #(
        WHEN rv_where IS INITIAL THEN lv_condition
        ELSE rv_where && | AND { lv_condition }|
      ).

      UNASSIGN <lv_val>.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_key_json.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).
    DATA lt_pairs TYPE string_table.

    LOOP AT it_key_fields INTO DATA(lv_key_field).

      IF lv_key_field = 'MANDT' OR lv_key_field = 'CLIENT'.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT lv_key_field OF STRUCTURE <ls_record>
        TO FIELD-SYMBOL(<lv_key_val>).
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      DATA(lo_elem_desc) = cl_abap_typedescr=>describe_by_data( <lv_key_val> ).
      DATA lv_val_str TYPE string.

      IF lo_elem_desc->type_kind = cl_abap_typedescr=>typekind_hex.
        lv_val_str = |{ <lv_key_val> }|.
        CONDENSE lv_val_str NO-GAPS.
        TRANSLATE lv_val_str TO UPPER CASE.
      ELSE.
        lv_val_str = |{ <lv_key_val> }|.
        CONDENSE lv_val_str NO-GAPS.
      ENDIF.

      APPEND |"{ lv_key_field }":"{ lv_val_str }"| TO lt_pairs.

      UNASSIGN <lv_key_val>.
    ENDLOOP.

    rv_key_json = `{`.
    LOOP AT lt_pairs INTO DATA(lv_pair).
      IF sy-tabix > 1. rv_key_json &&= `,`. ENDIF.
      rv_key_json &&= lv_pair.
    ENDLOOP.
    rv_key_json &&= `}`.
  ENDMETHOD.

  METHOD validate_domain_values.
    DATA(lo_desc) = get_struct_desc( iv_table_name ).
    ASSIGN ir_record->* TO FIELD-SYMBOL(<record>).
    IF <record> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    LOOP AT lo_desc->get_components( ) INTO DATA(ls_component).
      IF ls_component-name = 'MANDT' OR ls_component-name = 'CLIENT'.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT ls_component-name OF STRUCTURE <record>
        TO FIELD-SYMBOL(<value>).
      IF sy-subrc <> 0 OR <value> IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_value) = |{ <value> }|.
      CONDENSE lv_value.
      DATA(lv_fieldname) = CONV fieldname( ls_component-name ).
      DATA(ls_check) = get_domain_check_info(
        iv_table_name = iv_table_name
        iv_fieldname  = lv_fieldname ).

      IF ls_check-checktable IS NOT INITIAL.
        DATA(lv_exists) = abap_false.
        DATA(lv_where) = |{ lv_fieldname } = '{ lv_value }'|.
        TRY.
            SELECT SINGLE @abap_true
              FROM (ls_check-checktable)
              WHERE (lv_where)
              INTO @lv_exists.
          CATCH cx_sy_dynamic_osql_error.
            CONTINUE.
        ENDTRY.
        IF lv_exists IS INITIAL.
          APPEND VALUE #(
            fieldname = lv_fieldname
            value     = lv_value
            message   = |{ lv_fieldname } = '{ lv_value }' does not exist in { ls_check-checktable }| )
            TO rt_errors.
        ENDIF.
      ELSEIF ls_check-has_fixed = abap_true
         AND check_fixed_value(
               iv_table_name = iv_table_name
               iv_fieldname  = lv_fieldname
               iv_value      = lv_value ) = abap_false.
        APPEND VALUE #(
          fieldname = lv_fieldname
          value     = lv_value
          message   = |{ lv_fieldname } = '{ lv_value }' is not a valid fixed value| )
          TO rt_errors.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_domain_check_info.
    SELECT SINGLE rollname
      FROM dd03l
      WHERE tabname = @iv_table_name
        AND fieldname = @iv_fieldname
        AND as4local = 'A'
      INTO @DATA(lv_rollname).
    IF sy-subrc <> 0 OR lv_rollname IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE domname
      FROM dd04l
      WHERE rollname = @lv_rollname
        AND as4local = 'A'
      INTO @DATA(lv_domname).
    IF sy-subrc <> 0 OR lv_domname IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE entitytab
      FROM dd01l
      WHERE domname = @lv_domname
        AND as4local = 'A'
      INTO @rs_info-checktable.
    IF rs_info-checktable IS NOT INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE @abap_true
      FROM dd07l
      WHERE domname = @lv_domname
        AND as4local = 'A'
      INTO @rs_info-has_fixed.
  ENDMETHOD.

  METHOD check_fixed_value.
    SELECT SINGLE rollname
      FROM dd03l
      WHERE tabname = @iv_table_name
        AND fieldname = @iv_fieldname
        AND as4local = 'A'
      INTO @DATA(lv_rollname).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    SELECT SINGLE domname
      FROM dd04l
      WHERE rollname = @lv_rollname
        AND as4local = 'A'
      INTO @DATA(lv_domname).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    SELECT SINGLE @abap_true
      FROM dd07l
      WHERE domname = @lv_domname
        AND as4local = 'A'
        AND domvalue_l = @iv_value
      INTO @rv_valid.
  ENDMETHOD.

  METHOD build_validation_message.
    LOOP AT it_errors INTO DATA(ls_error).
      rv_msg = COND #(
        WHEN rv_msg IS INITIAL THEN ls_error-message
        ELSE rv_msg && `; ` && ls_error-message ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


