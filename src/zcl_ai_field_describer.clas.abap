CLASS zcl_ai_field_describer DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_field_description,
             field_name  TYPE string,
             description TYPE string,
             constraints TYPE string,
           END OF ty_field_description.

    TYPES ty_descriptions TYPE STANDARD TABLE OF ty_field_description
                          WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_alv_row,
             fieldname    TYPE dd03l-fieldname,
             rollname     TYPE dd03l-rollname,
             keyflag      TYPE dd03l-keyflag,
             description  TYPE string,
             constraints  TYPE string,
             tooltip_text TYPE string,
           END OF ty_alv_row.

    TYPES ty_alv_rows TYPE STANDARD TABLE OF ty_alv_row WITH DEFAULT KEY.

    CLASS-METHODS describe_table
      IMPORTING iv_table_name    TYPE tabname
      RETURNING VALUE(rt_result) TYPE ty_descriptions.

    CLASS-METHODS build_alv_data
      IMPORTING iv_table_name    TYPE tabname
      RETURNING VALUE(rt_result) TYPE ty_alv_rows.

  PRIVATE SECTION.

    CLASS-METHODS build_prompt
      IMPORTING iv_table_name    TYPE tabname
      RETURNING VALUE(rv_prompt) TYPE string.

    CLASS-METHODS call_llm
      IMPORTING iv_prompt        TYPE string
      RETURNING VALUE(rv_result) TYPE string.

    CLASS-METHODS parse_response
      IMPORTING iv_json          TYPE string
      RETURNING VALUE(rt_result) TYPE ty_descriptions.

ENDCLASS.

CLASS zcl_ai_field_describer IMPLEMENTATION.

  METHOD describe_table.
    TRY.
        DATA(lv_prompt)   = build_prompt( iv_table_name ).
        DATA(lv_response) = call_llm( lv_prompt ).
        rt_result         = parse_response( lv_response ).
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.

  METHOD build_alv_data.

    SELECT fieldname, rollname, keyflag
      FROM dd03l
      WHERE tabname   = @iv_table_name
        AND as4local  = 'A'
        AND fieldname NOT LIKE '.%'
        AND fieldname <> 'MANDT'
        AND fieldname <> 'CLIENT'
      ORDER BY position
      INTO TABLE @DATA(lt_fields).

    DATA(lt_ai) = describe_table( iv_table_name ).

    LOOP AT lt_fields INTO DATA(ls_field).

      DATA(ls_row) = VALUE ty_alv_row(
        fieldname = ls_field-fieldname
        rollname  = ls_field-rollname
        keyflag   = ls_field-keyflag
      ).

      READ TABLE lt_ai INTO DATA(ls_ai)
        WITH KEY field_name = CONV string( ls_field-fieldname ).

      IF sy-subrc = 0.
        ls_row-description  = ls_ai-description.
        ls_row-constraints  = ls_ai-constraints.
        ls_row-tooltip_text = |{ ls_ai-description } | &&
                               |[Ràng buộc: { ls_ai-constraints }]|.
      ELSE.
        ls_row-tooltip_text = 'Không có mô tả từ AI'.
      ENDIF.

      APPEND ls_row TO rt_result.

    ENDLOOP.

  ENDMETHOD.

  METHOD build_prompt.

    SELECT fieldname, rollname, domname, inttype, leng, keyflag
      FROM dd03l
      WHERE tabname   = @iv_table_name
        AND as4local  = 'A'
        AND fieldname NOT LIKE '.%'
        AND fieldname <> 'MANDT'
        AND fieldname <> 'CLIENT'
      ORDER BY position
      INTO TABLE @DATA(lt_fields).

    DATA lv_fields_text TYPE string.

    LOOP AT lt_fields INTO DATA(ls_field).

      DATA lv_line TYPE string.
      lv_line = |Field: { ls_field-fieldname }|.

      IF ls_field-rollname IS NOT INITIAL.
        lv_line = lv_line && | (DataElement: { ls_field-rollname })|.
      ENDIF.

      IF ls_field-domname IS NOT INITIAL.
        SELECT domvalue_l, ddtext
          FROM dd07v
          WHERE domname     = @ls_field-domname
            AND ddlanguage  = 'E'
          INTO TABLE @DATA(lt_vals)
          UP TO 10 ROWS.

        IF lt_vals IS NOT INITIAL.
          DATA lv_vals TYPE string.
          LOOP AT lt_vals INTO DATA(ls_val).
            lv_vals = lv_vals && |{ ls_val-domvalue_l }={ ls_val-ddtext }; |.
          ENDLOOP.
          lv_line = lv_line && | [Values: { lv_vals }]|.
        ENDIF.
      ENDIF.

      IF ls_field-keyflag = 'X'.
        lv_line = lv_line && | [KEY]|.
      ENDIF.

      lv_fields_text = lv_fields_text && lv_line && |\n|.

    ENDLOOP.

    rv_prompt = |You are an SAP business analyst. | &&
                |Given the SAP table "{ iv_table_name }" with the following fields, | &&
                |return a JSON array. Each element must have exactly 3 keys: | &&
                |"field_name" (string), | &&
                |"description" (string, business purpose in Vietnamese, max 1 sentence), | &&
                |"constraints" (string, input rules in Vietnamese, max 1 sentence). | &&
                |Return ONLY the raw JSON array. No markdown, no explanation, no code block.\n\n| &&
                |Fields:\n{ lv_fields_text }|.

  ENDMETHOD.

  METHOD call_llm.

    DATA lv_api_key TYPE string VALUE 'x'.

    TRY.
        DATA lo_http_client TYPE REF TO if_http_client.

        DATA(lv_url) =
          |https://generativelanguage.googleapis.com/v1beta/models/| &&
          |gemini-flash-latest:generateContent?key={ lv_api_key }|.

        cl_http_client=>create_by_url(
          EXPORTING
            url                = lv_url
          IMPORTING
            client             = lo_http_client
          EXCEPTIONS
            argument_not_found = 1
            plugin_not_active  = 2
            internal_error     = 3
            OTHERS             = 4
        ).

        IF sy-subrc <> 0. RETURN. ENDIF.

        lo_http_client->request->set_method( 'POST' ).

        lo_http_client->request->set_header_field(
          name  = 'Content-Type'
          value = 'application/json'
        ).

        DATA(lv_body) = |\{| &&
          |"contents":[| &&
            |\{"role":"user","parts":[\{"text":| &&
              /ui2/cl_json=>serialize( iv_prompt ) &&
            |\}]\}| &&
          |],| &&
          |"systemInstruction":\{| &&
            |"parts":[\{"text":"You are an SAP business analyst. Always respond with valid JSON only."\}]| &&
          |\},| &&
          |"generationConfig":\{| &&
            |"temperature":0.3,| &&
            |"maxOutputTokens":8000,| &&
            |"thinkingConfig":\{"thinkingBudget":0\}| &&
          |\}| &&
        |\}|.

        lo_http_client->request->set_cdata( lv_body ).

        lo_http_client->send(
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            OTHERS                     = 3
        ).

        IF sy-subrc <> 0. RETURN. ENDIF.

        lo_http_client->receive(
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            http_processing_failed     = 3
            OTHERS                     = 4
        ).

        IF sy-subrc <> 0. RETURN. ENDIF.

        rv_result = lo_http_client->response->get_cdata( ).

        lo_http_client->close( ).

      CATCH cx_root INTO DATA(lx).
        rv_result = ''.
    ENDTRY.

  ENDMETHOD.

  METHOD parse_response.
    TRY.
        DATA lv_content TYPE string.

        FIND FIRST OCCURRENCE OF REGEX '"text"\s*:\s*"((?:[^"\\]|\\.)*)"'
          IN iv_json
          SUBMATCHES lv_content.

        IF sy-subrc <> 0 OR lv_content IS INITIAL.
          RETURN.
        ENDIF.

        REPLACE ALL OCCURRENCES OF '\"' IN lv_content WITH '"'.
        REPLACE ALL OCCURRENCES OF '\n' IN lv_content WITH ' '.
        REPLACE ALL OCCURRENCES OF '\\' IN lv_content WITH '\'.

        REPLACE FIRST OCCURRENCE OF REGEX '```json\s*' IN lv_content WITH ''.
        REPLACE FIRST OCCURRENCE OF REGEX '```\s*$'    IN lv_content WITH ''.

        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_content
          CHANGING  data = rt_result
        ).

      CATCH cx_root.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
