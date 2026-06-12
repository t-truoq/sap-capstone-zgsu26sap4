CLASS zcl_ddic_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: tt_dd03l TYPE STANDARD TABLE OF dd03l WITH DEFAULT KEY.

    CLASS-METHODS get_label_from_dd04t
      IMPORTING
        iv_rollname    TYPE rollname
      RETURNING
        VALUE(rv_label) TYPE dd04t-reptext.

    CLASS-METHODS get_table_description
      IMPORTING
        iv_tabname     TYPE tabname
      RETURNING
        VALUE(rv_ddtext) TYPE dd02t-ddtext.

    CLASS-METHODS get_table_fields
      IMPORTING
        iv_tabname           TYPE tabname
      RETURNING
        VALUE(rt_fields)     TYPE zcl_ddic_helper=>tt_dd03l.

    CLASS-METHODS get_field_info
      IMPORTING
        iv_tabname     TYPE tabname
        iv_fieldname   TYPE fieldname
      RETURNING
        VALUE(rs_info) TYPE dd03l.

    CLASS-METHODS table_exists
      IMPORTING
        iv_tabname     TYPE tabname
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    CLASS-METHODS map_inttype_to_fe_type
      IMPORTING
        iv_inttype     TYPE inttype
        iv_leng        TYPE leng
        iv_domname     TYPE domname OPTIONAL
      RETURNING
        VALUE(rv_fe_type) TYPE string.

ENDCLASS.

CLASS zcl_ddic_helper IMPLEMENTATION.

  METHOD get_label_from_dd04t.
    SELECT SINGLE reptext FROM dd04t
      WHERE rollname   = @iv_rollname
        AND ddlanguage = @sy-langu
      INTO @rv_label.
    IF rv_label IS NOT INITIAL. RETURN. ENDIF.

    IF sy-langu <> 'E'.
      SELECT SINGLE reptext FROM dd04t
        WHERE rollname   = @iv_rollname
          AND ddlanguage = 'E'
        INTO @rv_label.
      IF rv_label IS NOT INITIAL. RETURN. ENDIF.
    ENDIF.

    SELECT SINGLE reptext FROM dd04t
      WHERE rollname = @iv_rollname
      INTO @rv_label.
  ENDMETHOD.

  METHOD get_table_description.
    SELECT SINGLE ddtext FROM dd02t
      WHERE tabname    = @iv_tabname
        AND ddlanguage = 'E'
      INTO @rv_ddtext.

    IF sy-subrc <> 0 OR rv_ddtext IS INITIAL.
      SELECT SINGLE ddtext FROM dd02t
        WHERE tabname = @iv_tabname
        INTO @rv_ddtext.
    ENDIF.
  ENDMETHOD.

  METHOD get_table_fields.
    SELECT fieldname, position, keyflag, inttype, rollname, domname,
           leng, decimals
      FROM dd03l
      WHERE tabname  = @iv_tabname
        AND as4local = 'A'
        AND fieldname NOT LIKE '.%'
      ORDER BY position
      INTO CORRESPONDING FIELDS OF TABLE @rt_fields.
  ENDMETHOD.

  METHOD get_field_info.
    SELECT SINGLE * FROM dd03l
      WHERE tabname   = @iv_tabname
        AND fieldname = @iv_fieldname
        AND as4local  = 'A'
      INTO @rs_info.
  ENDMETHOD.

  METHOD table_exists.
    SELECT SINGLE tabname FROM dd02l
      WHERE tabname  = @iv_tabname
        AND tabclass = 'TRANSP'
        AND as4local = 'A'
      INTO @DATA(lv_tabname).

    rv_exists = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD map_inttype_to_fe_type.
    rv_fe_type = SWITCH string( iv_inttype
      WHEN 'D' THEN 'date'
      WHEN 'T' THEN 'time'
      WHEN 'I' THEN 'integer'
      WHEN 'F' THEN 'decimal'
      WHEN 'P' THEN 'decimal'
      WHEN 'X' THEN
        COND string(
          WHEN iv_leng = 1  THEN 'boolean'
          WHEN iv_leng = 16 THEN 'uuid'
          ELSE                   'text'
        )
      WHEN 'N' THEN
        COND string(
          WHEN iv_domname IS NOT INITIAL THEN 'domain'
          ELSE                               'text'
        )
      ELSE
        COND string(
          WHEN iv_domname IS NOT INITIAL THEN 'domain'
          ELSE                               'text'
        )
    ).
  ENDMETHOD.

ENDCLASS.
