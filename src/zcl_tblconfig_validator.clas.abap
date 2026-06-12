CLASS zcl_tblconfig_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_validation_result,
        error TYPE string,
      END OF ty_validation_result.

    CLASS-METHODS validate_tbl_name
      IMPORTING
        iv_tabname     TYPE tabname
        iv_config_uuid TYPE sysuuid_x16 OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE ty_validation_result.

    CLASS-METHODS validate_domain_req
      IMPORTING
        iv_fieldtype  TYPE ztde_field_type
        iv_domainname TYPE dd03l-domname
      RETURNING
        VALUE(rv_error) TYPE string.

    CLASS-METHODS validate_display_order
      IMPORTING
        iv_tablename    TYPE tabname
        iv_fieldname    TYPE fieldname
        iv_displayorder TYPE int2
      RETURNING
        VALUE(rv_error) TYPE string.

ENDCLASS.

CLASS zcl_tblconfig_validator IMPLEMENTATION.

  METHOD validate_tbl_name.
    IF iv_tabname IS INITIAL.
      rs_result-error = 'Table Name cannot be empty'.
      RETURN.
    ENDIF.

    IF iv_tabname(1) <> 'Z' AND iv_tabname(1) <> 'Y'.
      rs_result-error = 'Only Z/Y tables are allowed'.
      RETURN.
    ENDIF.

    IF zcl_ddic_helper=>table_exists( iv_tabname ) = abap_false.
      rs_result-error = |Table { iv_tabname } does not exist|.
      RETURN.
    ENDIF.

    IF iv_config_uuid IS NOT INITIAL.
      SELECT SINGLE table_name FROM ztbl_config
        WHERE table_name  = @iv_tabname
          AND config_uuid <> @iv_config_uuid
        INTO @DATA(lv_exists).
    ELSE.
      SELECT SINGLE table_name FROM ztbl_config
        WHERE table_name = @iv_tabname
        INTO @lv_exists.
    ENDIF.

    IF sy-subrc = 0.
      rs_result-error = |Table { iv_tabname } is already registered|.
    ENDIF.
  ENDMETHOD.

  METHOD validate_domain_req.
    IF iv_fieldtype = 'DOMAIN' AND iv_domainname IS INITIAL.
      rv_error = 'Domain Name is required when Field Type is DOMAIN'.
    ENDIF.
  ENDMETHOD.

  METHOD validate_display_order.
    IF iv_displayorder IS INITIAL. RETURN. ENDIF.

    SELECT SINGLE field_name FROM zfld_config
      WHERE table_name    = @iv_tablename
        AND display_order = @iv_displayorder
        AND field_name   <> @iv_fieldname
      INTO @DATA(lv_exists).

    IF sy-subrc = 0.
      rv_error = |Display Order { iv_displayorder } already used in { iv_tablename }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
