CLASS zcl_json_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS serialize
      IMPORTING ia_data        TYPE any
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS deserialize
      IMPORTING iv_json   TYPE string
      CHANGING  ca_record TYPE REF TO data
      RAISING   cx_root.

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

ENDCLASS.


CLASS zcl_json_helper IMPLEMENTATION.

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

ENDCLASS.
