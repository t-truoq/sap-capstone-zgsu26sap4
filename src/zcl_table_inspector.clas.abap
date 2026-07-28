
CLASS zcl_table_inspector DEFINITION
PUBLIC
  FINAL
  CREATE PUBLIC.
PUBLIC SECTION.
TYPES:
      BEGIN OF ty_field_info,
        field_name     TYPE fieldname,
        field_type     TYPE ztde_field_type,
        label_text     TYPE dd04t-reptext,
        domain_name    TYPE dd03l-domname,
        display_order  TYPE i,
        is_key_field   TYPE ztde_yesno,
        mandatory_flag TYPE ztde_yesno,
        readonly_flag  TYPE ztde_yesno,
        hidden_flag    TYPE ztde_yesno,
        inttype        TYPE dd03l-inttype,
        leng           TYPE dd03l-leng,
      END OF ty_field_info,
      tt_field_info TYPE STANDARD TABLE OF ty_field_info WITH DEFAULT KEY,

      BEGIN OF ty_domain_value,
        value       TYPE dd07t-domvalue_l,
        description TYPE dd07t-ddtext,
      END OF ty_domain_value,
      tt_domain_value TYPE STANDARD TABLE OF ty_domain_value WITH DEFAULT KEY.

    CLASS-METHODS:
      get_field_list
        IMPORTING iv_table_name        TYPE tabname
        RETURNING VALUE(rt_field_list) TYPE tt_field_info,

      get_domain_values
        IMPORTING iv_domain_name          TYPE dd03l-domname
        RETURNING VALUE(rt_domain_values) TYPE tt_domain_value,

      table_exists
        IMPORTING iv_table_name    TYPE tabname
        RETURNING VALUE(rv_exists) TYPE abap_bool.

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
        VALUE(rt_fields)     TYPE zcl_table_inspector=>tt_dd03l.

    CLASS-METHODS get_field_info
      IMPORTING
        iv_tabname     TYPE tabname
        iv_fieldname   TYPE fieldname
      RETURNING
        VALUE(rs_info) TYPE dd03l.

    CLASS-METHODS ddic_table_exists
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


CLASS zcl_table_inspector IMPLEMENTATION.
METHOD get_field_list.
    " Đọc field config từ ZFLD_CONFIG
    SELECT table_name, field_name, field_type, label_text,
           domain_name, display_order, is_key_field,
           mandatory_flag, readonly_flag, hidden_flag
      FROM zfld_config
      WHERE table_name = @iv_table_name
      INTO TABLE @DATA(lt_config).

    SORT lt_config BY display_order.

    " Đọc thêm inttype và leng từ DD03L
    LOOP AT lt_config INTO DATA(ls_config).
      SELECT SINGLE inttype, leng FROM dd03l
        WHERE tabname   = @iv_table_name
          AND fieldname = @ls_config-field_name
          AND as4local  = 'A'
        INTO @DATA(ls_dd03l).

      APPEND VALUE #(
        field_name     = ls_config-field_name
        field_type     = ls_config-field_type
        label_text     = ls_config-label_text
        domain_name    = ls_config-domain_name
        display_order  = ls_config-display_order
        is_key_field   = ls_config-is_key_field
        mandatory_flag = ls_config-mandatory_flag
        readonly_flag  = ls_config-readonly_flag
        hidden_flag    = ls_config-hidden_flag
        inttype        = ls_dd03l-inttype
        leng           = ls_dd03l-leng
      ) TO rt_field_list.

    ENDLOOP.
  ENDMETHOD.

  METHOD get_domain_values.
    CLEAR rt_domain_values.

    SELECT domvalue_l AS value
      FROM dd07l
      WHERE domname    = @iv_domain_name
        AND as4local   = 'A'
        AND domvalue_l <> @space
      ORDER BY valpos
      INTO CORRESPONDING FIELDS OF TABLE @rt_domain_values.

    LOOP AT rt_domain_values ASSIGNING FIELD-SYMBOL(<domain_value>).
      SELECT SINGLE ddtext
        FROM dd07t
        WHERE domname    = @iv_domain_name
          AND domvalue_l = @<domain_value>-value
          AND ddlanguage = @sy-langu
          AND as4local   = 'A'
        INTO @<domain_value>-description.

      IF <domain_value>-description IS INITIAL AND sy-langu <> 'E'.
        SELECT SINGLE ddtext
          FROM dd07t
          WHERE domname    = @iv_domain_name
            AND domvalue_l = @<domain_value>-value
            AND ddlanguage = 'E'
            AND as4local   = 'A'
          INTO @<domain_value>-description.
      ENDIF.
    ENDLOOP.

    RETURN.

  ENDMETHOD.

  METHOD table_exists.
    " Kiểm tra table tồn tại trong DD02L
    SELECT SINGLE tabname FROM dd02l
      WHERE tabname  = @iv_table_name
        AND tabclass = 'TRANSP'
        AND as4local = 'A'
      INTO @DATA(lv_tabname).

    rv_exists = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

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

  METHOD ddic_table_exists.
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


