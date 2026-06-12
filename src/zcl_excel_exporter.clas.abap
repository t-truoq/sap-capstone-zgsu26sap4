"! <p class="shorttext synchronized">Excel Exporter (Phase 1)</p>
"! Export 1 Z-Table ra file Excel (XSTRING) bằng abap2xlsx.
"! Tái sử dụng: zcl_table_inspector (validate + metadata),
"!             zcl_dynamic_table_reader (đọc data).
CLASS zcl_excel_exporter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Export bảng iv_table_name ra Excel XSTRING (header + data).
    CLASS-METHODS export_table
      IMPORTING iv_table_name          TYPE tabname
      RETURNING VALUE(rv_file_xstring) TYPE xstring
      RAISING   zcx_excel_pipeline.

    "! Export file mẫu (CHỈ header, không data) để user điền rồi upload lại.
    CLASS-METHODS export_template
      IMPORTING iv_table_name          TYPE tabname
      RETURNING VALUE(rv_file_xstring) TYPE xstring
      RAISING   zcx_excel_pipeline.

    "! Lưu XSTRING Excel ra đường dẫn PC (dùng chung Export + Import).
    CLASS-METHODS save_to_local
      IMPORTING iv_xstring   TYPE xstring
                iv_filepath TYPE string
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.

    CLASS-METHODS validate_table_name
      IMPORTING iv_table_name TYPE tabname
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS get_field_metadata
      IMPORTING iv_table_name    TYPE tabname
      RETURNING VALUE(rt_fields) TYPE zcl_table_inspector=>tt_field_info
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS read_table_data
      IMPORTING iv_table_name  TYPE tabname
      RETURNING VALUE(rr_data) TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_excel
      IMPORTING it_fields          TYPE zcl_table_inspector=>tt_field_info
                ir_data            TYPE REF TO data OPTIONAL
                iv_importable_only TYPE abap_bool DEFAULT abap_false
                iv_tech_header     TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_xstring)  TYPE xstring
      RAISING   zcx_excel_pipeline.

    "! Field này có được xuất ra Excel không (theo chế độ importable_only).
    CLASS-METHODS is_exportable_col
      IMPORTING is_field           TYPE zcl_table_inspector=>ty_field_info
                iv_importable_only TYPE abap_bool
      RETURNING VALUE(rv_ok)       TYPE abap_bool.

ENDCLASS.


CLASS zcl_excel_exporter IMPLEMENTATION.

  METHOD export_table.
    validate_table_name( iv_table_name ).
    DATA(lt_fields) = get_field_metadata( iv_table_name ).
    DATA(lr_data)   = read_table_data( iv_table_name ).
    rv_file_xstring = build_excel( it_fields = lt_fields
                                   ir_data   = lr_data ).
  ENDMETHOD.


  METHOD export_template.
    validate_table_name( iv_table_name ).
    DATA(lt_fields) = get_field_metadata( iv_table_name ).
    " template: chỉ field user điền được, header = tên field kỹ thuật (map import ổn định)
    rv_file_xstring = build_excel(
      it_fields          = lt_fields
      iv_importable_only = abap_true
      iv_tech_header     = abap_true ).
  ENDMETHOD.


  METHOD save_to_local.
    IF iv_xstring IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'File Excel rong, khong luu duoc.'.
    ENDIF.

    DATA lt_bin TYPE STANDARD TABLE OF x255.
    DATA lv_len TYPE i.
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING buffer        = iv_xstring
      IMPORTING output_length = lv_len
      TABLES    binary_tab    = lt_bin.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename     = iv_filepath
        filetype     = 'BIN'
        bin_filesize = lv_len
      CHANGING
        data_tab     = lt_bin ).
  ENDMETHOD.


  METHOD validate_table_name.
    IF iv_table_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'Table name is empty'.
    ENDIF.

    IF iv_table_name NP 'Z*'.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Only Z-tables allowed: { iv_table_name }|.
    ENDIF.

    IF zcl_table_inspector=>table_exists( iv_table_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table not found: { iv_table_name }|.
    ENDIF.
  ENDMETHOD.


  METHOD get_field_metadata.
    rt_fields = zcl_table_inspector=>get_field_list( iv_table_name ).

    IF rt_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } chưa được config trong ZFLD_CONFIG|.
    ENDIF.
  ENDMETHOD.


  METHOD read_table_data.
    TRY.
        " default iv_max_rows = 100 → truyền số lớn để lấy đủ data
        rr_data = zcl_dynamic_table_reader=>get_table_data(
                    iv_table_name = iv_table_name
                    iv_max_rows   = 1000000 ).
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Read data failed: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD is_exportable_col.
    " Hidden luôn ẩn khỏi mọi export
    IF is_field-hidden_flag = abap_true.
      rv_ok = abap_false.
      RETURN.
    ENDIF.

    " Chế độ template (importable_only): chỉ field user điền được
    IF iv_importable_only = abap_true.
      rv_ok = zcl_excel_types=>is_importable_field(
                iv_fieldname = is_field-field_name
                iv_is_key    = is_field-is_key_field
                iv_readonly  = is_field-readonly_flag
                iv_hidden    = is_field-hidden_flag ).
      RETURN.
    ENDIF.

    " Export đầy đủ: giữ mọi field không hidden
    rv_ok = abap_true.
  ENDMETHOD.


  METHOD build_excel.
    DATA lv_col       TYPE i.
    DATA lv_col_alpha TYPE zexcel_cell_column_alpha.
    DATA lv_header    TYPE string.
    DATA lv_row       TYPE i.
    DATA lv_value     TYPE string.

    TRY.
        DATA(lo_excel)     = NEW zcl_excel( ).
        DATA(lo_worksheet) = lo_excel->get_active_worksheet( ).
        lo_worksheet->set_title( ip_title = 'DATA' ).

        " ---- Header row (row 1): tech header nếu yêu cầu, không thì label ----
        lv_col = 1.
        LOOP AT it_fields INTO DATA(ls_field).
          IF is_exportable_col( is_field = ls_field iv_importable_only = iv_importable_only ) = abap_false.
            CONTINUE.
          ENDIF.
          lv_col_alpha = zcl_excel_common=>convert_column2alpha( lv_col ).
          lv_header = COND string(
            WHEN iv_tech_header = abap_true
            THEN CONV string( ls_field-field_name )
            WHEN ls_field-label_text IS NOT INITIAL
            THEN ls_field-label_text
            ELSE CONV string( ls_field-field_name ) ).
          lo_worksheet->set_cell(
            ip_column = lv_col_alpha
            ip_row    = 1
            ip_value  = lv_header ).
          lv_col = lv_col + 1.
        ENDLOOP.

        " ---- Data rows (từ row 2) — bỏ qua nếu không truyền ir_data (template) ----
        FIELD-SYMBOLS <lt_tab> TYPE STANDARD TABLE.
        IF ir_data IS BOUND.
          ASSIGN ir_data->* TO <lt_tab>.
        ENDIF.
        IF <lt_tab> IS ASSIGNED.
          lv_row = 2.
          LOOP AT <lt_tab> ASSIGNING FIELD-SYMBOL(<ls_row>).
            lv_col = 1.
            LOOP AT it_fields INTO ls_field.
              IF is_exportable_col( is_field = ls_field iv_importable_only = iv_importable_only ) = abap_false.
                CONTINUE.
              ENDIF.
              ASSIGN COMPONENT ls_field-field_name
                OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_val>).
              IF sy-subrc = 0.
                lv_value = |{ <lv_val> }|.
              ELSE.
                CLEAR lv_value.
              ENDIF.
              lv_col_alpha = zcl_excel_common=>convert_column2alpha( lv_col ).
              lo_worksheet->set_cell(
                ip_column = lv_col_alpha
                ip_row    = lv_row
                ip_value  = lv_value ).
              lv_col = lv_col + 1.
            ENDLOOP.
            lv_row = lv_row + 1.
          ENDLOOP.
        ENDIF.

        " ---- Ghi ra XSTRING ----
        DATA(lo_writer) = CAST zif_excel_writer( NEW zcl_excel_writer_2007( ) ).
        rv_xstring = lo_writer->write_file( lo_excel ).

      CATCH zcx_excel INTO DATA(lx_excel).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Excel build failed: { lx_excel->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

