*&---------------------------------------------------------------------*
*& Report ZTEST_EXCEL_FACADE
*& Test Phase 5 pipeline (Base64 flow, khong can OData Gateway).
*&
*&  CACH DUNG (quan trong):
*&  A) Test TAI TEMPLATE:  P_TMPL=ON, P_SAVE=ON, P_FILE=trong
*&     -> luu C:\temp\<TABLE>_TEMPLATE.xlsx, mo Excel dien data.
*&  B) Test DIFF sau khi sua file:
*&     P_FILE=C:\temp\Z251_SCHEDULE.xlsx (file da sua), P_RUN=OFF
*&  C) Test COMMIT:         giong B + tick P_RUN
*&  D) Round-trip (smoke):   P_FILE=trong, P_TMPL=OFF
*&     -> export DB roi upload lai CUNG file -> luon UNCHANGED (binh thuong!)
*&---------------------------------------------------------------------*
REPORT ztest_excel_facade.

PARAMETERS p_table TYPE tabname DEFAULT 'Z251_SCHEDULE'.
PARAMETERS p_file  TYPE string LOWER CASE DEFAULT ''.
PARAMETERS p_tmpl  AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_save  AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_run   AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.

  TRY.
      WRITE: / '=== Phase 5 Pipeline Test ===', p_table.
      DATA lv_xstring TYPE xstring.
      DATA lv_source  TYPE string.

      " ---- Nguon file: tu PC (P_FILE) hoac export in-memory ----
      IF p_file IS NOT INITIAL.
        lv_source = |Upload tu file: { p_file }|.
        PERFORM read_file_xstring USING p_file CHANGING lv_xstring.
        IF lv_xstring IS INITIAL.
          WRITE: / 'Khong doc duoc file:', p_file.
          RETURN.
        ENDIF.
      ELSE.
        IF p_tmpl = abap_true.
          lv_xstring = zcl_excel_exporter=>export_template( p_table ).
          lv_source = 'Export TEMPLATE (chi header)'.
        ELSE.
          lv_xstring = zcl_excel_exporter=>export_table( p_table ).
          lv_source = 'Export FULL (header + data DB) — round-trip'.
        ENDIF.

        WRITE: / 'Mode  :', lv_source.
        WRITE: / 'Size  :', xstrlen( lv_xstring ), 'bytes'.

        IF p_save = abap_true AND lv_xstring IS NOT INITIAL.
          PERFORM save_xstring_to_pc USING lv_xstring p_table p_tmpl.
        ENDIF.

        IF p_tmpl = abap_true.
          WRITE: / 'Template chi co header -> 0 dong data la DUNG.'.
          WRITE: / 'Tick P_SAVE de luu file, dien Excel, roi chay lai voi P_FILE.'.
          IF p_file IS INITIAL.
            RETURN.
          ENDIF.
        ENDIF.

        IF p_tmpl = abap_false.
          WRITE: / 'CANH BAO: round-trip (export->upload cung file) -> diff luon UNCHANGED.'.
          WRITE: / 'De test diff sau khi SUA: nhap P_FILE = file da sua tren PC.'.
        ENDIF.
      ENDIF.

      IF lv_xstring IS INITIAL.
        WRITE: / 'Khong co du lieu Excel de xu ly.'.
        RETURN.
      ENDIF.

      " ---- Parse + Diff ----
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

      LOOP AT lt_msg INTO DATA(lv_m).
        WRITE: / lv_m.
      ENDLOOP.
      WRITE: / 'Parsed rows:', lines( lt_rows ), '| Diff lines:', lines( lt_diff ).

      ULINE.
      WRITE: / '--- Diff preview ---'.
      LOOP AT lt_diff INTO DATA(ls_d).
        WRITE: / 'Row', ls_d-row_no, '|', ls_d-status, '|', ls_d-fieldname,
               '|', ls_d-old_value, '->', ls_d-new_value.
      ENDLOOP.

      IF p_run <> abap_true.
        ULINE.
        WRITE: / 'Tick P_RUN de confirm commit DB.'.
        RETURN.
      ENDIF.

      " ---- Confirm ----
      DATA(ls_sum) = zcl_excel_committer=>confirm_import(
                       iv_table_name = p_table
                       it_diff       = lt_diff ).

      ULINE.
      WRITE: / 'Inserted :', ls_sum-inserted_count.
      WRITE: / 'Updated  :', ls_sum-updated_count.
      WRITE: / 'Unchanged:', ls_sum-unchanged_count.
      WRITE: / 'Skipped  :', ls_sum-skipped_count.
      WRITE: / 'Error    :', ls_sum-error_count.
      LOOP AT ls_sum-messages INTO DATA(lv_s).
        WRITE: / lv_s.
      ENDLOOP.

    CATCH zcx_excel_pipeline INTO DATA(lx).
      WRITE: / 'Error:', lx->get_text( ).
  ENDTRY.


*----------------------------------------------------------------------*
FORM read_file_xstring USING    iv_path   TYPE string
                       CHANGING cv_xstr  TYPE xstring.
  DATA lt_bin TYPE STANDARD TABLE OF x255.
  DATA lv_len TYPE i.

  cl_gui_frontend_services=>gui_upload(
    EXPORTING filename = iv_path filetype = 'BIN'
    IMPORTING filelength = lv_len
    CHANGING  data_tab   = lt_bin
    EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
    EXPORTING input_length = lv_len
    IMPORTING buffer       = cv_xstr
    TABLES    binary_tab   = lt_bin.
ENDFORM.


*----------------------------------------------------------------------*
FORM save_xstring_to_pc USING iv_xstr  TYPE xstring
                              iv_table TYPE tabname
                              iv_tmpl  TYPE abap_bool.
  DATA lt_bin TYPE STANDARD TABLE OF x255.
  DATA lv_len TYPE i.
  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING buffer        = iv_xstr
    IMPORTING output_length = lv_len
    TABLES    binary_tab    = lt_bin.

  DATA(lv_suffix) = COND string( WHEN iv_tmpl = abap_true THEN '_TEMPLATE' ELSE '' ).
  DATA(lv_path) = |C:\\temp\\{ iv_table }{ lv_suffix }.xlsx|.

  cl_gui_frontend_services=>gui_download(
    EXPORTING filename = lv_path filetype = 'BIN' bin_filesize = lv_len
    CHANGING  data_tab = lt_bin
    EXCEPTIONS OTHERS = 1 ).

  IF sy-subrc = 0.
    WRITE: / 'Saved :', lv_path.
  ELSE.
    WRITE: / 'Khong luu duoc (dong file Excel neu dang mo):', lv_path.
  ENDIF.
ENDFORM.
