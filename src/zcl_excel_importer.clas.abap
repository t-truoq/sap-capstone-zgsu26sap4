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
              is_foreign_key TYPE abap_bool,
              is_lov_field TYPE abap_bool,
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
                  iv_table_name  TYPE tabname
                  it_lov_ranges  TYPE tt_lov_range
                  it_export_cols TYPE tt_export_col
        RAISING   zcx_excel_pipeline.

      CLASS-METHODS build_domain_lov_sheet
        IMPORTING iv_table_name  TYPE tabname
                  it_export_cols TYPE tt_export_col
                  io_lov_ws      TYPE REF TO zcl_excel_worksheet
        RETURNING VALUE(rt_ranges) TYPE tt_lov_range.

      CLASS-METHODS is_foreign_key_field
        IMPORTING iv_table_name TYPE tabname
                  iv_field_name TYPE fieldname
        RETURNING VALUE(rv_is_fk) TYPE abap_bool.

      CLASS-METHODS get_lov_values
        IMPORTING iv_table_name TYPE tabname
                  is_export_col TYPE ty_export_col
        RETURNING VALUE(rt_values) TYPE string_table.
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

      LOOP AT lt_map_msg INTO DATA(lv_map_msg).
        IF lv_map_msg CS |does not belong to table|.
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text = |Uploaded Excel file does not match table { iv_table_name }. | &&
                                |Header contains column(s) that do not belong to this table. | &&
                                |Select the correct table or download the template/data from { iv_table_name } and upload again.|.
        ENDIF.
      ENDLOOP.

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

      IF iv_table_name NP 'Z*' AND iv_table_name NP 'Y*'.
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Only customer tables (Z*/Y*) are allowed: { iv_table_name }|.
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
              domain_name = ls_field-domain_name
              is_foreign_key = is_foreign_key_field(
                iv_table_name = iv_table_name
                iv_field_name = ls_field-field_name )
              is_lov_field = is_field_importable(
                is_field      = ls_field
                it_fields     = it_fields
                iv_table_name = iv_table_name ) ) TO lt_export_cols.
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

          " ---- Template only: sheet DOMAIN_LOV + dropdown domain/FK ----
          " A data export must remain a single DATA sheet.  Keeping the
          " auxiliary LOV sheet out of data exports avoids Excel reopening the
          " hidden sheet as the active sheet and makes the exported workbook
          " unambiguous for the importer.
          IF lt_export_cols IS NOT INITIAL
            AND iv_importable_only = abap_true.
            DATA lt_lov_ranges TYPE tt_lov_range.
            DATA(lo_lov_ws) = lo_excel->add_new_worksheet( ip_title = 'DOMAIN_LOV' ).
            IF lo_lov_ws IS BOUND.
              lt_lov_ranges = build_domain_lov_sheet(
                iv_table_name  = iv_table_name
                it_export_cols = lt_export_cols
                io_lov_ws      = lo_lov_ws ).
              IF lt_lov_ranges IS NOT INITIAL.
                apply_domain_validations(
                  io_data_ws    = lo_worksheet
                  io_lov_ws     = lo_lov_ws
                  iv_table_name = iv_table_name
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

      LOOP AT it_export_cols INTO DATA(ls_col)
        WHERE is_lov_field = abap_true
          AND ( domain_name IS NOT INITIAL OR is_foreign_key = abap_true ).
        DATA(lt_vals) = get_lov_values(
          iv_table_name = iv_table_name
          is_export_col = ls_col ).
        IF lt_vals IS INITIAL.
          CONTINUE.
        ENDIF.

        DATA(lv_lov_alpha) = zcl_excel_common=>convert_column2alpha( lv_lov_col ).
        io_lov_ws->set_cell(
          ip_column = lv_lov_alpha
          ip_row    = 1
          ip_value  = CONV string( ls_col-field_name ) ).

        lv_lov_row = 2.
        LOOP AT lt_vals INTO DATA(lv_lov_value).
          io_lov_ws->set_cell(
            ip_column = lv_lov_alpha
            ip_row    = lv_lov_row
            ip_value  = lv_lov_value ).
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
        CHECK ls_col-is_lov_field = abap_true.
        CHECK ls_col-domain_name IS NOT INITIAL OR ls_col-is_foreign_key = abap_true.

        DATA(lt_vals) = get_lov_values(
          iv_table_name = iv_table_name
          is_export_col = ls_col ).
        IF lt_vals IS INITIAL.
          CONTINUE.
        ENDIF.

        " Inline list tránh named range (hay gây lỗi XML khi mở/sửa file Excel)
        DATA lv_inline TYPE string.
        LOOP AT lt_vals INTO DATA(lv_lov_value).
          IF lv_inline IS INITIAL.
            lv_inline = lv_lov_value.
          ELSE.
            lv_inline = lv_inline && ',' && lv_lov_value.
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


    METHOD is_foreign_key_field.
      SELECT SINGLE @abap_true
        FROM dd08l
        INNER JOIN dd05s
          ON  dd05s~tabname   = dd08l~tabname
          AND dd05s~fieldname = dd08l~fieldname
          AND dd05s~as4local  = dd08l~as4local
        WHERE dd08l~tabname    = @iv_table_name
          AND dd08l~as4local   = 'A'
          AND dd05s~forkey     = @iv_field_name
          AND dd08l~checktable IS NOT INITIAL
        INTO @rv_is_fk.

      IF sy-subrc <> 0.
        rv_is_fk = abap_false.
      ENDIF.
    ENDMETHOD.


    METHOD get_lov_values.
      IF is_export_col-domain_name IS NOT INITIAL.
        DATA(lt_domain_values) =
          zcl_table_inspector=>get_domain_values( is_export_col-domain_name ).
        LOOP AT lt_domain_values INTO DATA(ls_domain_value).
          APPEND CONV string( ls_domain_value-value ) TO rt_values.
        ENDLOOP.
        IF rt_values IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDIF.

      IF is_export_col-is_foreign_key = abap_false.
        RETURN.
      ENDIF.

      DATA lv_check_table TYPE tabname.
      DATA lv_check_field TYPE fieldname.

      " Dùng cùng cách tra bảng cha với action getForeignKeyData đang phục vụ UI.
      SELECT SINGLE dd08l~checktable
        FROM dd08l
        INNER JOIN dd05s
          ON  dd05s~tabname   = dd08l~tabname
          AND dd05s~fieldname = dd08l~fieldname
          AND dd05s~as4local  = dd08l~as4local
        WHERE dd08l~tabname    = @iv_table_name
          AND dd08l~as4local   = 'A'
          AND dd05s~forkey     = @is_export_col-field_name
          AND dd08l~checktable IS NOT INITIAL
        INTO @lv_check_table.

      IF sy-subrc <> 0 OR lv_check_table IS INITIAL.
        RETURN.
      ENDIF.

      SELECT SINGLE dd05s~forstring
        FROM dd05s
        INNER JOIN dd08l
          ON  dd08l~tabname   = dd05s~tabname
          AND dd08l~fieldname = dd05s~fieldname
          AND dd08l~as4local  = dd05s~as4local
        WHERE dd05s~tabname   = @iv_table_name
          AND dd05s~as4local  = 'A'
          AND dd05s~forkey    = @is_export_col-field_name
        INTO @lv_check_field.

      " FORSTRING không hợp lệ thì dùng key không phải client của bảng cha.
      IF lv_check_field IS NOT INITIAL.
        SELECT SINGLE @abap_true
          FROM dd03l
          WHERE tabname   = @lv_check_table
            AND fieldname = @lv_check_field
            AND as4local  = 'A'
          INTO @DATA(lv_check_field_exists).
      ENDIF.

      IF lv_check_field IS INITIAL OR lv_check_field_exists = abap_false.
        CLEAR lv_check_field.
        DATA(lt_parent_keys) = zcl_dyn_record_handler=>get_key_fields(
          iv_table_name = lv_check_table ).
        LOOP AT lt_parent_keys INTO DATA(lv_parent_key).
          IF lv_parent_key = 'MANDT' OR lv_parent_key = 'CLIENT'.
            CONTINUE.
          ENDIF.
          lv_check_field = CONV fieldname( lv_parent_key ).
          EXIT.
        ENDLOOP.
      ENDIF.

      IF lv_check_field IS INITIAL.
        RETURN.
      ENDIF.

      TRY.
          DATA(lr_check_data) = zcl_dyn_record_handler=>get_table_data(
            iv_table_name = lv_check_table
            iv_max_rows   = 1000 ).
          ASSIGN lr_check_data->* TO FIELD-SYMBOL(<lt_check_data>).

          LOOP AT <lt_check_data> ASSIGNING FIELD-SYMBOL(<ls_check_row>).
            ASSIGN COMPONENT lv_check_field OF STRUCTURE <ls_check_row>
              TO FIELD-SYMBOL(<lv_check_value>).
            IF sy-subrc <> 0 OR <lv_check_value> IS INITIAL.
              CONTINUE.
            ENDIF.

            DATA(lv_value) = |{ <lv_check_value> }|.
            DATA(lo_value_type) =
              cl_abap_typedescr=>describe_by_data( <lv_check_value> ).
            IF lo_value_type->type_kind = cl_abap_typedescr=>typekind_hex.
              CONDENSE lv_value NO-GAPS.
              TRANSLATE lv_value TO UPPER CASE.
            ENDIF.

            IF lv_value IS NOT INITIAL.
              APPEND lv_value TO rt_values.
            ENDIF.
          ENDLOOP.

          SORT rt_values.
          DELETE ADJACENT DUPLICATES FROM rt_values.
        CATCH cx_root.
          CLEAR rt_values.
      ENDTRY.
    ENDMETHOD.

  ENDCLASS.


