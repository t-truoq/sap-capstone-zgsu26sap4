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

    CLASS-METHODS describe_table
      IMPORTING iv_table_name    TYPE tabname
      RETURNING VALUE(rt_result) TYPE ty_descriptions.

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

  METHOD build_prompt.

    " Đọc field list từ DD03L
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

      " Thêm data element nếu có
      IF ls_field-rollname IS NOT INITIAL.
        lv_line = lv_line && | (DataElement: { ls_field-rollname })|.
      ENDIF.

      " Thêm domain values nếu có
      IF ls_field-domname IS NOT INITIAL.
        SELECT domvalue_l, ddtext
          FROM dd07v
          WHERE domname     = @ls_field-domname
            AND ddlanguage  = 'E'
          INTO TABLE @DATA(lt_vals).

        IF lt_vals IS NOT INITIAL.
          DATA lv_vals TYPE string.
          LOOP AT lt_vals INTO DATA(ls_val).
            lv_vals = lv_vals && |{ ls_val-domvalue_l }={ ls_val-ddtext }; |.
          ENDLOOP.
          lv_line = lv_line && | [Values: { lv_vals }]|.
        ENDIF.
      ENDIF.

      " Đánh dấu key field
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

  DATA(lv_api_key) = 'xxxx'.

  TRY.
      " Tạo HTTP client
      DATA lo_http_client TYPE REF TO if_http_client.

      cl_http_client=>create_by_url(
        EXPORTING
          url                = 'https://api.openai.com/v1/chat/completions'
        IMPORTING
          client             = lo_http_client
        EXCEPTIONS
          argument_not_found = 1
          plugin_not_active  = 2
          internal_error     = 3
          OTHERS             = 4
      ).

      IF sy-subrc <> 0. RETURN. ENDIF.

      " Set method POST
      lo_http_client->request->set_method( 'POST' ).

      " Set headers
      lo_http_client->request->set_header_field(
        name  = 'Authorization'
        value = |Bearer { lv_api_key }|
      ).
      lo_http_client->request->set_header_field(
        name  = 'Content-Type'
        value = 'application/json'
      ).

      " Set body
      DATA(lv_body) = |\{| &&
        |"model":"gpt-4o-mini",| &&
        |"messages":[| &&
          |\{"role":"system","content":"You are an SAP business analyst. Always respond with valid JSON only."\},| &&
          |\{"role":"user","content":| && /ui2/cl_json=>serialize( iv_prompt ) && |\}| &&
        |],| &&
        |"temperature":0.3,| &&
        |"max_tokens":2000| &&
      |\}|.

      lo_http_client->request->set_cdata( lv_body ).

      " Gửi request
      lo_http_client->send(
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          OTHERS                     = 3
      ).

      IF sy-subrc <> 0. RETURN. ENDIF.

      " Nhận response
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
    " Response OpenAI có dạng:
    " {"choices":[{"message":{"content":"[{...}]"}}]}
    " Cần extract phần content rồi parse thành internal table

    TRY.
        " Lấy toàn bộ content từ response JSON
        DATA lv_content TYPE string.

        " Parse outer JSON để lấy choices[0].message.content
        DATA lt_outer TYPE TABLE OF string.

        FIND FIRST OCCURRENCE OF REGEX '"content"\s*:\s*"((?:[^"\\]|\\.)*)"'
          IN iv_json
          SUBMATCHES lv_content.

        IF sy-subrc <> 0 OR lv_content IS INITIAL.
          RETURN.
        ENDIF.

        " Unescape: \" -> " và \n -> newline
        REPLACE ALL OCCURRENCES OF '\"' IN lv_content WITH '"'.
        REPLACE ALL OCCURRENCES OF '\n' IN lv_content WITH ' '.
        REPLACE ALL OCCURRENCES OF '\\' IN lv_content WITH '\'.

        " Trim markdown code block nếu LLM trả về ```json ... ```
        REPLACE FIRST OCCURRENCE OF REGEX '```json\s*' IN lv_content WITH ''.
        REPLACE FIRST OCCURRENCE OF REGEX '```\s*$'    IN lv_content WITH ''.

        " Deserialize JSON array thành internal table
        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_content
          CHANGING  data = rt_result
        ).

      CATCH cx_root.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
