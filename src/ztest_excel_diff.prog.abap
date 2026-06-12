*&---------------------------------------------------------------------*
*& Report ZTEST_EXCEL_DIFF
*& Test report cho Phase 3 — Diff Preview.
*& Upload file .xlsx → parse → so với DB → in NEW/CHANGED/UNCHANGED/ERROR.
*& Mẹo test: sửa 1 giá trị trong file, thêm 1 COURSE_ID mới rồi chạy lại.
*&---------------------------------------------------------------------*
REPORT ztest_excel_diff.

PARAMETERS p_table TYPE tabname DEFAULT 'Z251_SCHEDULE'.
PARAMETERS p_file  TYPE string LOWER CASE DEFAULT 'C:\temp\Z251_SCHEDULE.xlsx'.

START-OF-SELECTION.

  " ---- 1. Upload file → XSTRING ----
  DATA lt_bin TYPE STANDARD TABLE OF x255.
  DATA lv_len TYPE i.

  cl_gui_frontend_services=>gui_upload(
    EXPORTING
      filename   = p_file
      filetype   = 'BIN'
    IMPORTING
      filelength = lv_len
    CHANGING
      data_tab   = lt_bin
    EXCEPTIONS
      OTHERS     = 1 ).

  IF sy-subrc <> 0.
    WRITE: / 'Không đọc được file:', p_file.
    RETURN.
  ENDIF.

  DATA lv_xstring TYPE xstring.
  CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
    EXPORTING
      input_length = lv_len
    IMPORTING
      buffer       = lv_xstring
    TABLES
      binary_tab   = lt_bin.

  " ---- 2. Parse + Diff ----
  TRY.
      zcl_excel_importer=>parse_excel(
        EXPORTING
          iv_table_name = p_table
          iv_file       = lv_xstring
        IMPORTING
          et_rows       = DATA(lt_rows)
          et_messages   = DATA(lt_msg) ).

      DATA(lt_diff) = zcl_excel_diff_builder=>build_diff(
                        iv_table_name = p_table
                        it_rows       = lt_rows ).

      " ---- 3. In kết quả diff ----
      WRITE: / 'TABLE:', p_table, '| rows parsed:', lines( lt_rows ),
             '| diff lines:', lines( lt_diff ).
      ULINE.

      LOOP AT lt_diff INTO DATA(ls).
        WRITE: / 'Row', ls-row_no,
               '|', ls-status,
               '|', ls-fieldname,
               '| old:', ls-old_value,
               '| new:', ls-new_value,
               '| msg:', ls-message.
      ENDLOOP.

    CATCH zcx_excel_pipeline INTO DATA(lx).
      WRITE: / 'Error:', lx->get_text( ).
  ENDTRY.
