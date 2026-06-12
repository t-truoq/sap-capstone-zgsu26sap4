*&---------------------------------------------------------------------*
*& Report ZTEST_EXCEL_UPLOAD
*& IMPORT EXCEL (Upload) — đưa file VÀO hệ thống.
*&
*&  P_FILE  → đường dẫn file .xlsx đã điền
*&  P_DIFF  → hiện diff preview (chưa ghi DB)
*&
*&  Tải file mẫu (template): dùng ZTEST_EXCEL_EXPORT + P_TMPL + P_SAVE.
*&---------------------------------------------------------------------*
REPORT ztest_excel_upload.

PARAMETERS p_table TYPE tabname DEFAULT 'Z251_SCHEDULE'.
PARAMETERS p_file  TYPE string LOWER CASE DEFAULT 'C:\temp\Z251_SCHEDULE.xlsx'.
PARAMETERS p_diff  AS CHECKBOX DEFAULT abap_true.

START-OF-SELECTION.

  WRITE: / '=== Import Excel (Upload) ===', p_table.
  ULINE.

  IF p_file IS INITIAL.
    WRITE: / 'Nhap P_FILE (duong dan file .xlsx) de upload.'.
    RETURN.
  ENDIF.

  PERFORM upload_and_preview USING p_table p_file p_diff.

*----------------------------------------------------------------------*
FORM upload_and_preview USING iv_table TYPE tabname
                              iv_file  TYPE string
                              iv_diff  TYPE abap_bool.
  DATA lt_bin TYPE STANDARD TABLE OF x255.
  DATA lv_len TYPE i.

  cl_gui_frontend_services=>gui_upload(
    EXPORTING
      filename   = iv_file
      filetype   = 'BIN'
    IMPORTING
      filelength = lv_len
    CHANGING
      data_tab   = lt_bin
    EXCEPTIONS
      OTHERS     = 1 ).

  IF sy-subrc <> 0.
    WRITE: / 'Khong doc duoc file:', iv_file.
    RETURN.
  ENDIF.

  DATA lv_xstring TYPE xstring.
  CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
    EXPORTING input_length = lv_len
    IMPORTING buffer       = lv_xstring
    TABLES    binary_tab   = lt_bin.

  TRY.
      zcl_excel_importer=>parse_excel(
        EXPORTING
          iv_table_name = iv_table
          iv_file       = lv_xstring
        IMPORTING
          et_rows       = DATA(lt_rows)
          et_messages   = DATA(lt_msg) ).

      LOOP AT lt_msg INTO DATA(lv_m).
        WRITE: / lv_m.
      ENDLOOP.
      WRITE: / 'Tong dong parse:', lines( lt_rows ).

      IF iv_diff <> abap_true.
        RETURN.
      ENDIF.

      DATA(lt_diff) = zcl_excel_diff_builder=>build_diff(
                        iv_table_name = iv_table
                        it_rows       = lt_rows ).

      ULINE.
      WRITE: / '--- Diff preview (chua ghi DB) ---'.
      LOOP AT lt_diff INTO DATA(ls).
        WRITE: / 'Row', ls-row_no,
               '|', ls-status,
               '|', ls-fieldname,
               '| old:', ls-old_value,
               '| new:', ls-new_value,
               '|', ls-message.
      ENDLOOP.

    CATCH zcx_excel_pipeline INTO DATA(lx).
      WRITE: / 'Loi upload:', lx->get_text( ).
  ENDTRY.
ENDFORM.
