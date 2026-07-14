"! <p class="shorttext synchronized">Excel Importer / Parser (Phase 2)</p>
"! Đọc file Excel (XSTRING) → internal table (tt_parsed_row). KHÔNG ghi DB.
"! Header Excel phải khớp file export/template (label_text hoặc field_name).
"! Tái sử dụng: zcl_table_inspector=>get_field_list (map cột → field).
CLASS zcl_excel_importer DEFINITION
PUBLIC
  FINAL
  CREATE PUBLIC.
PUBLIC SECTION.
"! Parse file Excel thành các dòng dữ liệu (chưa ghi DB).
    "! @parameter iv_table_name | Tên Z-table (để lấy metadata field).
    "! @parameter iv_file       | Nội dung file XLSX dạng XSTRING.
    "! @parameter et_rows       | Các dòng đã parse (fieldname + value string).
    "! @parameter et_messages   | Thông báo/cảnh báo (cột không map, số dòng...).
    CLASS-METHODS parse_excel
      IMPORTING iv_table_name TYPE tabname
                iv_file       TYPE xstring
      EXPORTING et_rows       TYPE zcl_excel_types=>tt_parsed_row
                et_messages   TYPE string_table
      RAISING   zcx_excel_pipeline.

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
CONSTANTS c_source_table_prefix TYPE string VALUE '__SOURCE_TABLE='.
    CONSTANTS c_action_field        TYPE string VALUE '__ACTION'.

    TYPES: BEGIN OF ty_colmap,
             column    TYPE i,
             fieldname TYPE fieldname,
           END OF ty_colmap,
           tt_colmap TYPE STANDARD TABLE OF ty_colmap WITH KEY column.

    TYPES tt_colnum TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    "! Map cột Excel (theo header row 1) → fieldname của bảng.
    "! et_header_cols = các cột CÓ header (dù khớp hay không) — để phân biệt với cột rỗng.
    CLASS-METHODS map_columns
      IMPORTING io_worksheet   TYPE REF TO zcl_excel_worksheet
                iv_max_col     TYPE i
                iv_table_name  TYPE tabname
                it_fields      TYPE zcl_table_inspector=>tt_field_info
      EXPORTING et_colmap      TYPE tt_colmap
                et_header_cols TYPE tt_colnum
                et_messages    TYPE string_table.

    "! Chuẩn hóa text để so khớp header (uppercase, bỏ space thừa).
    CLASS-METHODS validate_source_table_marker
      IMPORTING io_worksheet  TYPE REF TO zcl_excel_worksheet
                iv_max_col    TYPE i
                iv_table_name TYPE tabname
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS normalize
      IMPORTING iv_text        TYPE clike
      RETURNING VALUE(rv_norm) TYPE string.

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


CLASS zcl_excel_importer IMPLEMENTATION.
METHOD parse_excel.
    CLEAR: et_rows, et_messages.

    " ---- 1. Load file XLSX ----
    DATA lo_excel TYPE REF TO zcl_excel.
    TRY.
        DATA(lo_reader) = CAST zif_excel_reader( NEW zcl_excel_reader_2007( ) ).
        lo_excel = lo_reader->load( iv_file ).
      CATCH zcx_excel INTO DATA(lx_read).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Cannot read Excel file: { lx_read->get_text( ) }|.
    ENDTRY.

    DATA(lo_ws)      = lo_excel->get_active_worksheet( ).
    DATA(lv_max_col) = CONV i( lo_ws->get_highest_column( ) ).
    DATA(lv_max_row) = CONV i( lo_ws->get_highest_row( ) ).

    validate_source_table_marker(
      io_worksheet  = lo_ws
      iv_max_col    = lv_max_col
      iv_table_name = iv_table_name ).

    IF lv_max_col = 0 OR lv_max_row < 2.
      APPEND |Excel file has no data rows. Row 1 must be header; data starts from row 2.| TO et_messages.
      RETURN.
    ENDIF.

    " ---- 2. Metadata field của bảng ----
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    IF lt_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } is not configured in ZFLD_CONFIG. Configure fields before Excel import.|.
    ENDIF.

    " ---- 3. Map cột Excel → fieldname ----
    DATA lt_colmap TYPE tt_colmap.
    DATA lt_header_cols TYPE tt_colnum.
    map_columns(
      EXPORTING io_worksheet   = lo_ws
                iv_max_col     = lv_max_col
                iv_table_name  = iv_table_name
                it_fields      = lt_fields
      IMPORTING et_colmap      = lt_colmap
                et_header_cols = lt_header_cols
                et_messages    = DATA(lt_map_msg) ).
    APPEND LINES OF lt_map_msg TO et_messages.

    IF lt_colmap IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Uploaded Excel file does not match table { iv_table_name }. | &&
                            |No header column matches this table. | &&
                            |Select the correct table or download the template/data from { iv_table_name } and upload again.|.
    ENDIF.

    DATA(lt_required_keys) = zcl_excel_types=>get_match_key_fields(
      it_fields     = lt_fields
      iv_table_name = iv_table_name ).
    DATA lt_missing_keys TYPE string_table.

    LOOP AT lt_required_keys INTO DATA(lv_required_key).
      READ TABLE lt_colmap TRANSPORTING NO FIELDS
        WITH KEY fieldname = CONV fieldname( lv_required_key ).
      IF sy-subrc <> 0.
        APPEND lv_required_key TO lt_missing_keys.
      ENDIF.
    ENDLOOP.

    IF lt_missing_keys IS NOT INITIAL.
      DATA(lv_missing_keys) = concat_lines_of( table = lt_missing_keys sep = ', ' ).
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Uploaded Excel file does not match table { iv_table_name }. | &&
                            |Missing required key column(s): { lv_missing_keys }. | &&
                            |Select the correct table or download the template/data from { iv_table_name } and upload again.|.
    ENDIF.

    " ---- 4. Đọc data row 2..max_row (quét mọi cột để phát hiện dữ liệu ngoài vùng) ----
    DATA lv_alpha TYPE zexcel_cell_column_alpha.
    DATA lv_value TYPE zexcel_cell_value.
    DATA lv_str   TYPE string.
    DATA lv_row   TYPE i.
    DATA lv_col   TYPE i.

    lv_row = 2.
    WHILE lv_row <= lv_max_row.
      DATA ls_parsed TYPE zcl_excel_types=>ty_parsed_row.
      CLEAR ls_parsed.
      ls_parsed-row_no = lv_row.

      DATA lv_has_value TYPE abap_bool.
      lv_has_value = abap_false.

      lv_col = 1.
      WHILE lv_col <= lv_max_col.
        lv_alpha = zcl_excel_common=>convert_column2alpha( lv_col ).
        CLEAR lv_value.
        TRY.
            lo_ws->get_cell(
              EXPORTING ip_column = lv_alpha
                        ip_row    = lv_row
              IMPORTING ep_value  = lv_value ).
          CATCH zcx_excel.
            CLEAR lv_value.
        ENDTRY.
        lv_str = lv_value.

        READ TABLE lt_colmap INTO DATA(ls_map) WITH KEY column = lv_col.
        IF sy-subrc = 0.
          " cột đã map → ghi nhận giá trị
          IF lv_str IS NOT INITIAL.
            lv_has_value = abap_true.
          ENDIF.
          APPEND VALUE #( fieldname = ls_map-fieldname
                          value     = lv_str ) TO ls_parsed-cells.
        ELSE.
          " cột chưa map nhưng có dữ liệu: cảnh báo rõ row/column để user sửa file
          IF lv_str IS NOT INITIAL.
            DATA(lv_col_alpha) = zcl_excel_common=>convert_column2alpha( lv_col ).

            READ TABLE lt_header_cols TRANSPORTING NO FIELDS
              WITH KEY table_line = lv_col.
            IF sy-subrc = 0.
              APPEND |Ignored cell { lv_col_alpha }{ lv_row }: its header does not belong to table { iv_table_name }.| TO et_messages.
            ELSE.
              APPEND |Ignored cell { lv_col_alpha }{ lv_row }: data is outside the Excel header area.| TO et_messages.
            ENDIF.
          ENDIF.
        ENDIF.

        lv_col = lv_col + 1.
      ENDWHILE.

      " bỏ dòng rỗng hoàn toàn
      IF lv_has_value = abap_true.
        APPEND ls_parsed TO et_rows.
      ENDIF.

      lv_row = lv_row + 1.
    ENDWHILE.

    APPEND |Parsed { lines( et_rows ) } data rows.| TO et_messages.
  ENDMETHOD.


  METHOD validate_source_table_marker.
    DATA lv_alpha TYPE zexcel_cell_column_alpha.
    DATA lv_value TYPE zexcel_cell_value.
    DATA lv_header TYPE string.
    DATA lv_col TYPE i.
    DATA(lv_prefix_len) = strlen( c_source_table_prefix ).

    lv_col = 1.
    WHILE lv_col <= iv_max_col.
      lv_alpha = zcl_excel_common=>convert_column2alpha( lv_col ).
      CLEAR lv_value.
      TRY.
          io_worksheet->get_cell(
            EXPORTING ip_column = lv_alpha
                      ip_row    = 1
            IMPORTING ep_value  = lv_value ).
        CATCH zcx_excel.
          CLEAR lv_value.
      ENDTRY.

      lv_header = normalize( lv_value ).
      IF strlen( lv_header ) >= lv_prefix_len
         AND lv_header(lv_prefix_len) = c_source_table_prefix.
        DATA(lv_source_table) = lv_header+lv_prefix_len.
        DATA(lv_current_table) = normalize( iv_table_name ).

        IF lv_source_table IS NOT INITIAL AND lv_source_table <> lv_current_table.
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text = |You are importing a { lv_source_table } Excel file into { lv_current_table }. | &&
                                |Switch to { lv_source_table }, or download the template/data from { lv_current_table } and upload that file.|.
        ENDIF.

        RETURN.
      ENDIF.

      lv_col = lv_col + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD map_columns.
    CLEAR: et_colmap, et_header_cols, et_messages.

    DATA lv_alpha TYPE zexcel_cell_column_alpha.
    DATA lv_value TYPE zexcel_cell_value.
    DATA lv_col   TYPE i.

    lv_col = 1.
    WHILE lv_col <= iv_max_col.
      lv_alpha = zcl_excel_common=>convert_column2alpha( lv_col ).
      CLEAR lv_value.
      TRY.
          io_worksheet->get_cell(
            EXPORTING ip_column = lv_alpha
                      ip_row    = 1
            IMPORTING ep_value  = lv_value ).
        CATCH zcx_excel.
          CLEAR lv_value.
      ENDTRY.

      DATA(lv_header_norm) = normalize( lv_value ).

      IF lv_header_norm IS NOT INITIAL.
        DATA(lv_prefix_len) = strlen( c_source_table_prefix ).
        IF strlen( lv_header_norm ) >= lv_prefix_len
           AND lv_header_norm(lv_prefix_len) = c_source_table_prefix.
          lv_col = lv_col + 1.
          CONTINUE.
        ENDIF.
        APPEND lv_col TO et_header_cols.   " cột này có header

        IF lv_header_norm = c_action_field.
          READ TABLE et_colmap TRANSPORTING NO FIELDS
            WITH KEY fieldname = CONV fieldname( c_action_field ).
          IF sy-subrc = 0.
            APPEND |Column '{ lv_value }' maps to field { c_action_field } more than once; duplicate column was ignored.| TO et_messages.
          ELSE.
            APPEND VALUE #( column    = lv_col
                            fieldname = CONV fieldname( c_action_field ) ) TO et_colmap.
          ENDIF.
          lv_col = lv_col + 1.
          CONTINUE.
        ENDIF.

        DATA lv_found TYPE abap_bool.
        lv_found = abap_false.

        " Ưu tiên khớp tên field kỹ thuật trước, sau đó mới tới label
        LOOP AT it_fields INTO DATA(ls_field).
          IF normalize( ls_field-field_name ) = lv_header_norm.
            DATA(lv_match) = ls_field-field_name.
            lv_found = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.

        IF lv_found = abap_false.
          LOOP AT it_fields INTO ls_field.
            IF normalize( ls_field-label_text ) = lv_header_norm.
              lv_match = ls_field-field_name.
              lv_found = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.

        IF lv_found = abap_false.
          APPEND |Column '{ lv_value }' does not belong to table { iv_table_name } and was ignored.| TO et_messages.
        ELSE.
          READ TABLE it_fields INTO DATA(ls_matched) WITH KEY field_name = lv_match.
          IF sy-subrc = 0 AND zcl_excel_types=>is_parseable_column(
            is_field      = ls_matched
            iv_table_name = iv_table_name
            it_fields     = it_fields ) = abap_false.
            APPEND |Column '{ lv_value }' ({ lv_match }) is readonly/hidden/system-managed and was ignored.| TO et_messages.
          ELSE.
            " Label trùng → cùng map về 1 field. Chỉ nhận cột đầu, cột sau cảnh báo.
            READ TABLE et_colmap TRANSPORTING NO FIELDS WITH KEY fieldname = lv_match.
            IF sy-subrc = 0.
              APPEND |Column '{ lv_value }' maps to field { lv_match } more than once; duplicate column was ignored.| TO et_messages.
            ELSE.
              APPEND VALUE #( column    = lv_col
                              fieldname = lv_match ) TO et_colmap.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      lv_col = lv_col + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD normalize.
    rv_norm = iv_text.
    CONDENSE rv_norm.
    TRANSLATE rv_norm TO UPPER CASE.
  ENDMETHOD.

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
        rr_data = zcl_dyn_record_handler=>get_table_data(
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
            col_index   = lines( lt_export_cols ) + 2
            field_name  = ls_field-field_name
            domain_name = ls_field-domain_name ) TO lt_export_cols.
        ENDLOOP.

        " ---- Header row (row 1) ----
        lo_worksheet->set_cell(
          ip_column = 'A'
          ip_row    = 1
          ip_value  = c_action_field ).

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

        lv_col_alpha = zcl_excel_common=>convert_column2alpha( lines( lt_export_cols ) + 2 ).
        lo_worksheet->set_cell(
          ip_column = lv_col_alpha
          ip_row    = 1
          ip_value  = |{ c_source_table_prefix }{ iv_table_name }| ).

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

