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

  PRIVATE SECTION.

    CONSTANTS c_source_table_prefix TYPE string VALUE '__SOURCE_TABLE='.

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

ENDCLASS.

