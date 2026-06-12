*&---------------------------------------------------------------------*
*& Report ZTEST_EXCEL_COMMIT
*& Test report cho Phase 4 — Confirm Import + Audit
*& Upload file .xlsx -> parse -> diff -> commit -> summary.
*&---------------------------------------------------------------------*
REPORT ztest_excel_commit.

PARAMETERS p_table TYPE tabname DEFAULT 'Z251_SCHEDULE'.
PARAMETERS p_file  TYPE string LOWER CASE DEFAULT 'C:\temp\Z251_SCHEDULE.xlsx'.
PARAMETERS p_run   AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.

  IF p_run <> abap_true.
    WRITE: / 'Tick p_run để xác nhận commit DB.'.
    RETURN.
  ENDIF.

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

  TRY.
      zcl_excel_importer=>parse_excel(
        EXPORTING
          iv_table_name = p_table
          iv_file       = lv_xstring
        IMPORTING
          et_rows       = DATA(lt_rows)
          et_messages   = DATA(lt_parse_msg) ).

      DATA(lt_diff) = zcl_excel_diff_builder=>build_diff(
                        iv_table_name = p_table
                        it_rows       = lt_rows ).

      DATA(ls_sum) = zcl_excel_committer=>confirm_import(
                       iv_table_name = p_table
                       it_diff       = lt_diff ).

      WRITE: / 'TABLE:', p_table.
      WRITE: / 'Inserted :', ls_sum-inserted_count.
      WRITE: / 'Updated  :', ls_sum-updated_count.
      WRITE: / 'Unchanged:', ls_sum-unchanged_count.
      WRITE: / 'Skipped  :', ls_sum-skipped_count.
      WRITE: / 'Error    :', ls_sum-error_count.
      ULINE.
      LOOP AT ls_sum-messages INTO DATA(lv_msg).
        WRITE: / lv_msg.
      ENDLOOP.

    CATCH zcx_excel_pipeline INTO DATA(lx).
      WRITE: / 'Error:', lx->get_text( ).
  ENDTRY.
