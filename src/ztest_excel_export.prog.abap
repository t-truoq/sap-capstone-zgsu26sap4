*&---------------------------------------------------------------------*
*& Report ZTEST_EXCEL_EXPORT
*& TẢI FILE RA PC (Export) — không phải Import.
*&
*&  P_TMPL = OFF → file đầy đủ (header + data DB)
*&  P_TMPL = ON  → file MẪU (chỉ header, để user điền rồi Import)
*&  P_SAVE = ON  → lưu xuống C:\temp\
*&
*&  Tải mẫu: P_TMPL = ON. Import file đã điền: ZTEST_EXCEL_UPLOAD.
*&---------------------------------------------------------------------*
REPORT ztest_excel_export.

PARAMETERS p_table TYPE tabname DEFAULT 'Z251_SCHEDULE'.
PARAMETERS p_tmpl  AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_save  AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.

  TRY.
      DATA lv_xstring TYPE xstring.
      DATA lv_mode   TYPE string.

      IF p_tmpl = abap_true.
        lv_xstring = zcl_excel_exporter=>export_template( p_table ).
        lv_mode = 'TEMPLATE (chi header)'.
      ELSE.
        lv_xstring = zcl_excel_exporter=>export_table( p_table ).
        lv_mode = 'FULL (header + data)'.
      ENDIF.

      WRITE: / '=== Excel Export (tai file RA) ==='.
      WRITE: / 'Mode  :', lv_mode.
      WRITE: / 'Table :', p_table.
      WRITE: / 'Size  :', xstrlen( lv_xstring ).

      IF p_save = abap_true AND xstrlen( lv_xstring ) > 0.
        DATA lt_bin TYPE STANDARD TABLE OF x255.
        DATA lv_len TYPE i.
        CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
          EXPORTING buffer        = lv_xstring
          IMPORTING output_length = lv_len
          TABLES    binary_tab    = lt_bin.

        DATA(lv_suffix) = COND string( WHEN p_tmpl = abap_true THEN '_TEMPLATE' ELSE '' ).
        DATA(lv_path) = |C:\\temp\\{ p_table }{ lv_suffix }.xlsx|.
        cl_gui_frontend_services=>gui_download(
          EXPORTING
            filename     = lv_path
            filetype     = 'BIN'
            bin_filesize = lv_len
          CHANGING
            data_tab     = lt_bin
          EXCEPTIONS
            file_write_error = 1
            no_authority     = 2
            access_denied    = 3
            OTHERS           = 4 ).

        IF sy-subrc = 0.
          WRITE: / 'Saved :', lv_path.
        ELSE.
          WRITE: / 'Khong luu duoc file (subrc=', sy-subrc, '):', lv_path.
          WRITE: / '-> Dong file', lv_path, 'trong Excel roi chay lai,'.
          WRITE: / '   hoac kiem tra thu muc C:\temp ton tai & co quyen ghi.'.
        ENDIF.
      ELSE.
        WRITE: / 'Tick P_SAVE de luu file xuong PC.'.
      ENDIF.

    CATCH zcx_excel_pipeline INTO DATA(lx).
      WRITE: / 'Error:', lx->get_text( ).
  ENDTRY.
