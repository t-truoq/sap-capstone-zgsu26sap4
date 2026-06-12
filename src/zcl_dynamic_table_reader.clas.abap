CLASS zcl_dynamic_table_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

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

ENDCLASS.

CLASS zcl_dynamic_table_reader IMPLEMENTATION.

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

ENDCLASS.
