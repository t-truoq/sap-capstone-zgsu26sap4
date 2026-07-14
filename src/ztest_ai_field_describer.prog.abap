REPORT ztest_ai_description.

PARAMETERS: p_table TYPE tabname OBLIGATORY DEFAULT 'ZTPC_HEADER'.

START-OF-SELECTION.

  SELECT SINGLE config_uuid
    FROM ztbl_config
    INTO @DATA(lv_config_uuid).

  IF sy-subrc <> 0.
    WRITE: / 'Không tìm thấy record TblConfig nào trong hệ thống để test.'.
    RETURN.
  ENDIF.

  MODIFY ENTITIES OF zi_tbl_config
    ENTITY tblconfig
      EXECUTE getaidescription
      FROM VALUE #( (
        %tky   = VALUE #( configuuid = lv_config_uuid )
        %param = VALUE #( table_name = p_table )
      ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

  COMMIT ENTITIES.

  IF lt_result IS NOT INITIAL.
    LOOP AT lt_result INTO DATA(ls_res).
      WRITE: / 'Table     :', ls_res-%param-table_name.
      WRITE: / 'Error msg :', ls_res-%param-error_msg.
      ULINE.
      WRITE: / 'Result JSON:'.
      WRITE: / ls_res-%param-result_json.
    ENDLOOP.
  ELSE.
    WRITE: / 'Không có kết quả trả về.'.
  ENDIF.

  IF ls_failed IS NOT INITIAL.
    WRITE: / 'FAILED:'.
    LOOP AT ls_failed-tblconfig INTO DATA(ls_fail).
      WRITE: / 'ConfigUuid:', ls_fail-%tky-configuuid.
    ENDLOOP.
  ENDIF.

  IF ls_reported IS NOT INITIAL.
    WRITE: / 'REPORTED messages:'.
    LOOP AT ls_reported-tblconfig INTO DATA(ls_msg).
      WRITE: / ls_msg-%msg->if_message~get_text( ).
    ENDLOOP.
  ENDIF.
