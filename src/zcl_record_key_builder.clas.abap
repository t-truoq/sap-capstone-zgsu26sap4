CLASS zcl_record_key_builder DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    "Tạo WHERE clause động từ danh sách key fields và 1 record
    CLASS-METHODS build_where_clause
      IMPORTING it_key_fields  TYPE string_table
                ir_record      TYPE REF TO data
      RETURNING VALUE(rv_where) TYPE string.

    "Tạo JSON key {"FIELD":"VALUE"} cho audit log
    CLASS-METHODS build_key_json
      IMPORTING it_key_fields     TYPE string_table
                ir_record         TYPE REF TO data
      RETURNING VALUE(rv_key_json) TYPE string.

ENDCLASS.

CLASS zcl_record_key_builder IMPLEMENTATION.

  METHOD build_where_clause.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).

    LOOP AT it_key_fields INTO DATA(lv_key_field).
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
        CONDENSE lv_val_str NO-GAPS.

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
    ENDLOOP.

    rv_key_json = `{`.
    LOOP AT lt_pairs INTO DATA(lv_pair).
      IF sy-tabix > 1. rv_key_json &&= `,`. ENDIF.
      rv_key_json &&= lv_pair.
    ENDLOOP.
    rv_key_json &&= `}`.
  ENDMETHOD.

ENDCLASS.
