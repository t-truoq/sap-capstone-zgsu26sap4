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
                iv_table_name      TYPE tabname
                ir_data            TYPE REF TO data OPTIONAL
                iv_importable_only TYPE abap_bool DEFAULT abap_false
                iv_tech_header     TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_xstring)  TYPE xstring
      RAISING   zcx_excel_pipeline.

    "! Field này có được xuất ra Excel không (theo chế độ importable_only).
    CLASS-METHODS is_exportable_col
      IMPORTING is_field           TYPE zcl_table_inspector=>ty_field_info
                it_fields          TYPE zcl_table_inspector=>tt_field_info
                iv_table_name      TYPE tabname
                iv_importable_only TYPE abap_bool
      RETURNING VALUE(rv_ok)       TYPE abap_bool.

    CLASS-METHODS is_field_importable
      IMPORTING is_field           TYPE zcl_table_inspector=>ty_field_info
                it_fields          TYPE zcl_table_inspector=>tt_field_info
                iv_table_name      TYPE tabname
      RETURNING VALUE(rv_importable) TYPE abap_bool.

    TYPES: BEGIN OF ty_export_col,
             col_index   TYPE i,
             field_name  TYPE fieldname,
             domain_name TYPE dd03l-domname,
           END OF ty_export_col,
           tt_export_col TYPE STANDARD TABLE OF ty_export_col WITH EMPTY KEY.

    TYPES: BEGIN OF ty_lov_range,
             data_col    TYPE i,
             lov_col     TYPE i,
             last_row    TYPE i,
           END OF ty_lov_range,
           tt_lov_range TYPE STANDARD TABLE OF ty_lov_range WITH EMPTY KEY.

    CLASS-METHODS apply_domain_validations
      IMPORTING io_data_ws     TYPE REF TO zcl_excel_worksheet
                io_lov_ws      TYPE REF TO zcl_excel_worksheet
                it_lov_ranges  TYPE tt_lov_range
                it_export_cols TYPE tt_export_col
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_domain_lov_sheet
      IMPORTING it_export_cols TYPE tt_export_col
                io_lov_ws      TYPE REF TO zcl_excel_worksheet
      RETURNING VALUE(rt_ranges) TYPE tt_lov_range.

ENDCLASS.


CLASS zcl_excel_exporter IMPLEMENTATION.

  METHOD export_table.
    validate_table_name( iv_table_name ).
    DATA(lt_fields) = get_field_metadata( iv_table_name ).
    DATA(lr_data)   = read_table_data( iv_table_name ).
    rv_file_xstring = build_excel( it_fields          = lt_fields
                                   ir_data            = lr_data
                                   iv_table_name      = iv_table_name ).
  ENDMETHOD.


  METHOD export_template.
    validate_table_name( iv_table_name ).
    DATA(lt_fields) = get_field_metadata( iv_table_name ).
    " template: chỉ field user điền được, header = tên field kỹ thuật (map import ổn định)
    rv_file_xstring = build_excel(
      it_fields          = lt_fields
      iv_table_name      = iv_table_name
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


  METHOD is_field_importable.
    rv_importable = zcl_excel_types=>is_importable_field_for_table(
      is_field      = is_field
      iv_table_name = iv_table_name
      it_fields     = it_fields ).
  ENDMETHOD.


  METHOD is_exportable_col.
    " Full data: luôn xuất ENTITY_ID / match-only dù hidden trong config
    IF iv_importable_only = abap_false.
      IF zcl_excel_types=>is_match_only_field(
           is_field      = is_field
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_true.
        rv_ok = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    " Hidden luôn ẩn khỏi mọi export (trừ match-only ở trên)
    IF is_field-hidden_flag = abap_true OR is_field-hidden_flag = 'X'.
      rv_ok = abap_false.
      RETURN.
    ENDIF.

    " Chế độ template (importable_only): chỉ field user điền được
    IF iv_importable_only = abap_true.
      rv_ok = is_field_importable(
        is_field      = is_field
        it_fields     = it_fields
        iv_table_name = iv_table_name ).
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
    DATA lt_export_cols TYPE tt_export_col.

    TRY.
        DATA(lo_excel)     = NEW zcl_excel( ).
        DATA(lo_worksheet) = lo_excel->get_active_worksheet( ).
        lo_worksheet->set_title( ip_title = 'DATA' ).

        " ---- Thu thập cột export ----
        LOOP AT it_fields INTO DATA(ls_field).
          IF is_exportable_col(
               is_field           = ls_field
               it_fields          = it_fields
               iv_table_name      = iv_table_name
               iv_importable_only = iv_importable_only ) = abap_false.
            CONTINUE.
          ENDIF.
          APPEND VALUE #(
            col_index   = lines( lt_export_cols ) + 1
            field_name  = ls_field-field_name
            domain_name = ls_field-domain_name ) TO lt_export_cols.
        ENDLOOP.

        " ---- Header row (row 1) ----
        LOOP AT lt_export_cols INTO DATA(ls_col).
          READ TABLE it_fields INTO ls_field WITH KEY field_name = ls_col-field_name.
          lv_col_alpha = zcl_excel_common=>convert_column2alpha( ls_col-col_index ).
          lv_header = COND string(
            WHEN iv_tech_header = abap_true
            THEN CONV string( ls_col-field_name )
            WHEN ls_field-label_text IS NOT INITIAL
            THEN ls_field-label_text
            ELSE CONV string( ls_col-field_name ) ).
          lo_worksheet->set_cell(
            ip_column = lv_col_alpha
            ip_row    = 1
            ip_value  = lv_header ).
        ENDLOOP.

        " ---- Data rows (từ row 2) ----
        FIELD-SYMBOLS <lt_tab> TYPE STANDARD TABLE.
        IF ir_data IS BOUND.
          ASSIGN ir_data->* TO <lt_tab>.
        ENDIF.
        IF <lt_tab> IS ASSIGNED.
          lv_row = 2.
          LOOP AT <lt_tab> ASSIGNING FIELD-SYMBOL(<ls_row>).
            LOOP AT lt_export_cols INTO ls_col.
              READ TABLE it_fields INTO ls_field WITH KEY field_name = ls_col-field_name.
              ASSIGN COMPONENT ls_col-field_name
                OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_val>).
              IF sy-subrc = 0.
                lv_value = |{ <lv_val> }|.
              ELSE.
                CLEAR lv_value.
              ENDIF.
              lv_col_alpha = zcl_excel_common=>convert_column2alpha( ls_col-col_index ).
              lo_worksheet->set_cell(
                ip_column = lv_col_alpha
                ip_row    = lv_row
                ip_value  = lv_value ).
            ENDLOOP.
            lv_row = lv_row + 1.
          ENDLOOP.
        ENDIF.

        " ---- Template: sheet DOMAIN_LOV + dropdown domain ----
        IF iv_importable_only = abap_true AND lt_export_cols IS NOT INITIAL.
          DATA lt_lov_ranges TYPE tt_lov_range.
          DATA(lo_lov_ws) = lo_excel->add_new_worksheet( ip_title = 'DOMAIN_LOV' ).
          IF lo_lov_ws IS BOUND.
            lt_lov_ranges = build_domain_lov_sheet(
              it_export_cols = lt_export_cols
              io_lov_ws      = lo_lov_ws ).
            IF lt_lov_ranges IS NOT INITIAL.
              apply_domain_validations(
                io_data_ws    = lo_worksheet
                io_lov_ws     = lo_lov_ws
                it_lov_ranges = lt_lov_ranges
                it_export_cols = lt_export_cols ).
            ENDIF.
            lo_lov_ws->zif_excel_sheet_properties~hidden = zif_excel_sheet_properties=>c_hidden.
          ENDIF.
        ENDIF.

        " ---- Ghi ra XSTRING ----
        DATA(lo_writer) = CAST zif_excel_writer( NEW zcl_excel_writer_2007( ) ).
        rv_xstring = lo_writer->write_file( lo_excel ).

      CATCH zcx_excel INTO DATA(lx_excel).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Excel build failed: { lx_excel->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD build_domain_lov_sheet.
    CLEAR rt_ranges.
    DATA lv_lov_col TYPE i VALUE 1.
    DATA lv_lov_row TYPE i.

    LOOP AT it_export_cols INTO DATA(ls_col) WHERE domain_name IS NOT INITIAL.
      DATA(lt_vals) = zcl_table_inspector=>get_domain_values( ls_col-domain_name ).
      IF lt_vals IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_lov_alpha) = zcl_excel_common=>convert_column2alpha( lv_lov_col ).
      io_lov_ws->set_cell(
        ip_column = lv_lov_alpha
        ip_row    = 1
        ip_value  = CONV string( ls_col-field_name ) ).

      lv_lov_row = 2.
      LOOP AT lt_vals INTO DATA(ls_val).
        io_lov_ws->set_cell(
          ip_column = lv_lov_alpha
          ip_row    = lv_lov_row
          ip_value  = ls_val-value ).
        lv_lov_row = lv_lov_row + 1.
      ENDLOOP.

      IF lv_lov_row > 2.
        APPEND VALUE #(
          data_col = ls_col-col_index
          lov_col  = lv_lov_col
          last_row = lv_lov_row - 1 ) TO rt_ranges.
      ENDIF.

      lv_lov_col = lv_lov_col + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD apply_domain_validations.
    CONSTANTS c_max_data_row TYPE i VALUE 500.
    CONSTANTS c_max_inline   TYPE i VALUE 200.

    LOOP AT it_lov_ranges INTO DATA(ls_rng).
      READ TABLE it_export_cols INTO DATA(ls_col) WITH KEY col_index = ls_rng-data_col.
      CHECK sy-subrc = 0.
      CHECK ls_col-domain_name IS NOT INITIAL.

      DATA(lt_vals) = zcl_table_inspector=>get_domain_values( ls_col-domain_name ).
      IF lt_vals IS INITIAL.
        CONTINUE.
      ENDIF.

      " Inline list tránh named range (hay gây lỗi XML khi mở/sửa file Excel)
      DATA lv_inline TYPE string.
      LOOP AT lt_vals INTO DATA(ls_val).
        IF lv_inline IS INITIAL.
          lv_inline = ls_val-value.
        ELSE.
          lv_inline = lv_inline && ',' && ls_val-value.
        ENDIF.
      ENDLOOP.

      IF strlen( lv_inline ) > c_max_inline.
        CONTINUE.
      ENDIF.

      DATA(lv_data_alpha) = zcl_excel_common=>convert_column2alpha( ls_rng-data_col ).
      DATA(lv_formula) = |"{ lv_inline }"|.

      TRY.
          DATA(lo_dval) = io_data_ws->add_new_data_validation( ).
          lo_dval->type = zcl_excel_data_validation=>c_type_list.
          lo_dval->formula1 = lv_formula.
          lo_dval->allowblank = abap_true.
          lo_dval->showdropdown = abap_true.
          lo_dval->cell_row = 2.
          lo_dval->cell_column = lv_data_alpha.
          lo_dval->cell_row_to = c_max_data_row.
        CATCH zcx_excel.
          CONTINUE.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

