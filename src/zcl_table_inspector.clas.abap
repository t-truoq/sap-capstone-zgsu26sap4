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

    " 1. Thử đọc fixed values từ DD07T (English trước)
    SELECT domvalue_l AS value,
           ddtext     AS description
      FROM dd07t
      WHERE domname    = @iv_domain_name
        AND ddlanguage = 'E'
        AND as4local   = 'A'
      INTO TABLE @rt_domain_values.

    IF rt_domain_values IS NOT INITIAL.
      RETURN.
    ENDIF.

    " 2. Nếu không có English thì lấy bất kỳ language nào
    SELECT domvalue_l AS value,
           ddtext     AS description
      FROM dd07t
      WHERE domname  = @iv_domain_name
        AND as4local = 'A'
      INTO TABLE @rt_domain_values.

    IF rt_domain_values IS NOT INITIAL.
      RETURN.
    ENDIF.

    " 3. Không có fixed values → thử check table từ DD01L
    DATA lv_check_table TYPE tabname.

    SELECT SINGLE entitytab
      FROM dd01l
      WHERE domname  = @iv_domain_name
        AND as4local = 'A'
      INTO @lv_check_table.

    IF sy-subrc <> 0 OR lv_check_table IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        " Tạo dynamic table từ check table
        DATA lo_data TYPE REF TO data.
        CREATE DATA lo_data TYPE TABLE OF (lv_check_table).
        ASSIGN lo_data->* TO FIELD-SYMBOL(<lt_check>).

        SELECT *
          FROM (lv_check_table)
          INTO TABLE @<lt_check>
          UP TO 100 ROWS.

        " Đọc structure của check table
        DATA(lo_struct) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( lv_check_table )
        ).
        DATA(lt_components) = lo_struct->get_components( ).

        " Tìm text field từ DD03L — field CHAR đầu tiên không phải key
        DATA lv_key_field  TYPE string.
        DATA lv_text_field TYPE string.
        DATA lv_field_count TYPE i VALUE 0.

        LOOP AT lt_components INTO DATA(ls_comp).
          " Bỏ qua CLIENT/MANDT
          IF ls_comp-name = 'CLIENT' OR ls_comp-name = 'MANDT'.
            CONTINUE.
          ENDIF.

          lv_field_count = lv_field_count + 1.

          IF lv_field_count = 1.
            " Field đầu tiên = key field
            lv_key_field = ls_comp-name.
          ELSEIF lv_field_count = 2.
            " Field thứ 2 = text/description field
            lv_text_field = ls_comp-name.
            EXIT.
          ENDIF.
        ENDLOOP.

        " Nếu không tìm được text field thì thử tìm qua DD03L
        IF lv_text_field IS INITIAL.
          SELECT SINGLE fieldname
            FROM dd03l
            WHERE tabname   = @lv_check_table
              AND as4local  = 'A'
              AND fieldname <> 'MANDT'
              AND fieldname <> 'CLIENT'
              AND keyflag   = ' '
              AND inttype   = 'C'
            INTO @lv_text_field.
        ENDIF.

        IF lv_key_field IS INITIAL.
          RETURN.
        ENDIF.

        " Build result list
        LOOP AT <lt_check> ASSIGNING FIELD-SYMBOL(<ls_row>).
          ASSIGN COMPONENT lv_key_field OF STRUCTURE <ls_row>
            TO FIELD-SYMBOL(<lv_key>).

          IF sy-subrc <> 0 OR <lv_key> IS INITIAL.
            CONTINUE.
          ENDIF.

          " Đọc description
          DATA lv_desc_val TYPE string.
          IF lv_text_field IS NOT INITIAL.
            ASSIGN COMPONENT lv_text_field OF STRUCTURE <ls_row>
              TO FIELD-SYMBOL(<lv_text>).
            IF sy-subrc = 0 AND <lv_text> IS NOT INITIAL.
              lv_desc_val = CONV string( <lv_text> ).
            ENDIF.
          ENDIF.

          " Fallback: dùng key làm description
          IF lv_desc_val IS INITIAL.
            lv_desc_val = CONV string( <lv_key> ).
          ENDIF.

          APPEND VALUE #(
            value       = CONV #( <lv_key> )
            description = CONV #( lv_desc_val )
          ) TO rt_domain_values.

        ENDLOOP.

      CATCH cx_root.
        " Silent fail
    ENDTRY.

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

ENDCLASS.

