"! <p class="shorttext synchronized">Excel Diff Builder (Phase 3)</p>
"! So sánh các dòng Excel đã parse với data hiện có trong DB.
"! Phân loại: NEW / CHANGED / UNCHANGED / ERROR. CHƯA ghi DB.
"! Tái sử dụng: zcl_table_inspector (field + domain), zcl_dynamic_table_reader (key + data).
CLASS zcl_excel_diff_builder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! So sánh it_rows với DB → danh sách diff (field-level).
    CLASS-METHODS build_diff
      IMPORTING iv_table_name  TYPE tabname
                it_rows        TYPE zcl_excel_types=>tt_parsed_row
      RETURNING VALUE(rt_diff) TYPE zcl_excel_types=>tt_diff_row
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.

    "! Lấy value của 1 field trong các cell của dòng (rỗng nếu không có).
    CLASS-METHODS get_cell_value
      IMPORTING it_cells       TYPE zcl_excel_types=>tt_cell
                iv_field       TYPE fieldname
      RETURNING VALUE(rv_value) TYPE string.

    "! Build record_key dạng JSON từ các key field (pattern hệ thống).
    CLASS-METHODS build_record_key
      IMPORTING it_keys       TYPE zcl_dynamic_table_reader=>tt_string_table
                it_cells      TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rv_key) TYPE string.

    "! Build WHERE clause động từ key field để đọc record DB.
    CLASS-METHODS build_where
      IMPORTING it_keys         TYPE zcl_dynamic_table_reader=>tt_string_table
                it_cells        TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rv_where) TYPE string.

    "! Validate 1 dòng theo metadata (mandatory / length / domain).
    CLASS-METHODS validate_row
      IMPORTING it_fields        TYPE zcl_table_inspector=>tt_field_info
                it_cells         TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rt_errors) TYPE string_table.

ENDCLASS.


CLASS zcl_excel_diff_builder IMPLEMENTATION.

  METHOD build_diff.
    CLEAR rt_diff.

    FIELD-SYMBOLS <db_tab> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <db_row> TYPE any.
    FIELD-SYMBOLS <db_val> TYPE any.

    " ---- Metadata + key fields ----
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    IF lt_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } chưa được config trong ZFLD_CONFIG|.
    ENDIF.

    DATA(lt_keys_all) = zcl_dynamic_table_reader=>get_key_fields( iv_table_name ).
    DATA lt_keys TYPE zcl_dynamic_table_reader=>tt_string_table.
    LOOP AT lt_keys_all INTO DATA(lv_k).
      IF lv_k <> 'MANDT' AND lv_k <> 'CLIENT'.
        APPEND lv_k TO lt_keys.
      ENDIF.
    ENDLOOP.

    IF lt_keys IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } không có key field để so sánh|.
    ENDIF.

    " ---- Đếm số lần xuất hiện của mỗi record_key trong FILE (phát hiện key trùng) ----
    TYPES: BEGIN OF ty_kc,
             rkey TYPE string,
             cnt  TYPE i,
           END OF ty_kc.
    DATA lt_kc TYPE HASHED TABLE OF ty_kc WITH UNIQUE KEY rkey.

    LOOP AT it_rows INTO DATA(ls_pre).
      DATA(lv_prekey) = build_record_key( it_keys = lt_keys it_cells = ls_pre-cells ).
      READ TABLE lt_kc ASSIGNING FIELD-SYMBOL(<kc>) WITH KEY rkey = lv_prekey.
      IF sy-subrc = 0.
        <kc>-cnt = <kc>-cnt + 1.
      ELSE.
        INSERT VALUE #( rkey = lv_prekey cnt = 1 ) INTO TABLE lt_kc.
      ENDIF.
    ENDLOOP.

    " ---- Duyệt từng dòng Excel ----
    LOOP AT it_rows INTO DATA(ls_row).

      DATA(lv_rkey) = build_record_key( it_keys = lt_keys it_cells = ls_row-cells ).

      " 0) Key trùng trong cùng file → ERROR (không cho import, tránh ghi đè last-wins)
      READ TABLE lt_kc INTO DATA(ls_kc) WITH KEY rkey = lv_rkey.
      IF sy-subrc = 0 AND ls_kc-cnt > 1.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_rkey
                        status     = zcl_excel_types=>c_status-error
                        message    = |Key bị trùng trong file ({ ls_kc-cnt } dòng cùng key) - sửa file trước khi import| ) TO rt_diff.
        CONTINUE.
      ENDIF.

      " 1) Validate
      DATA(lt_err) = validate_row( it_fields = lt_fields it_cells = ls_row-cells ).
      IF lt_err IS NOT INITIAL.
        LOOP AT lt_err INTO DATA(lv_emsg).
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_rkey
                          status     = zcl_excel_types=>c_status-error
                          message    = lv_emsg ) TO rt_diff.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " 2) Key fields phải có giá trị
      DATA lv_missing_key TYPE abap_bool.
      lv_missing_key = abap_false.
      LOOP AT lt_keys INTO lv_k.
        IF get_cell_value( it_cells = ls_row-cells iv_field = CONV #( lv_k ) ) IS INITIAL.
          lv_missing_key = abap_true.
        ENDIF.
      ENDLOOP.
      IF lv_missing_key = abap_true.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_rkey
                        status     = zcl_excel_types=>c_status-error
                        message    = 'Thiếu giá trị key field' ) TO rt_diff.
        CONTINUE.
      ENDIF.

      " 3) Đọc record hiện tại trong DB theo key
      DATA(lv_where) = build_where( it_keys = lt_keys it_cells = ls_row-cells ).
      DATA lr_db TYPE REF TO data.
      TRY.
          lr_db = zcl_dynamic_table_reader=>get_table_data(
                    iv_table_name   = iv_table_name
                    iv_where_clause = lv_where
                    iv_max_rows     = 1 ).
        CATCH cx_sy_dynamic_osql_error INTO DATA(lx).
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_rkey
                          status     = zcl_excel_types=>c_status-error
                          message    = |Đọc DB lỗi: { lx->get_text( ) }| ) TO rt_diff.
          CONTINUE.
      ENDTRY.

      UNASSIGN <db_tab>.
      ASSIGN lr_db->* TO <db_tab>.

      " 4a) Không tồn tại → NEW (mỗi field 1 dòng diff)
      IF <db_tab> IS NOT ASSIGNED OR lines( <db_tab> ) = 0.
        DATA lt_seen_new TYPE string_table.
        CLEAR lt_seen_new.
        LOOP AT ls_row-cells INTO DATA(ls_cell).
          " bỏ field hệ thống tự quản lý
          IF zcl_excel_types=>is_admin_field( ls_cell-fieldname ) = abap_true.
            CONTINUE.
          ENDIF.
          " tránh diff trùng cùng row_no + record_key + fieldname
          READ TABLE lt_seen_new TRANSPORTING NO FIELDS
            WITH KEY table_line = CONV string( ls_cell-fieldname ).
          IF sy-subrc = 0.
            CONTINUE.
          ENDIF.
          APPEND CONV string( ls_cell-fieldname ) TO lt_seen_new.

          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_rkey
                          fieldname  = ls_cell-fieldname
                          new_value  = ls_cell-value
                          status     = zcl_excel_types=>c_status-new ) TO rt_diff.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " 4b) Tồn tại → so sánh từng field
      READ TABLE <db_tab> INDEX 1 ASSIGNING <db_row>.

      DATA lv_changed TYPE abap_bool.
      lv_changed = abap_false.

      DATA lt_seen_chg TYPE string_table.
      CLEAR lt_seen_chg.

      LOOP AT ls_row-cells INTO ls_cell.
        " bỏ field hệ thống tự quản lý
        IF zcl_excel_types=>is_admin_field( ls_cell-fieldname ) = abap_true.
          CONTINUE.
        ENDIF.
        " tránh so sánh trùng field
        READ TABLE lt_seen_chg TRANSPORTING NO FIELDS
          WITH KEY table_line = CONV string( ls_cell-fieldname ).
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.
        APPEND CONV string( ls_cell-fieldname ) TO lt_seen_chg.

        UNASSIGN <db_val>.
        ASSIGN COMPONENT ls_cell-fieldname OF STRUCTURE <db_row> TO <db_val>.
        DATA lv_dbstr TYPE string.
        IF <db_val> IS ASSIGNED.
          lv_dbstr = |{ <db_val> }|.
        ELSE.
          CLEAR lv_dbstr.
        ENDIF.

        " so sánh dạng string (đã trim). Lưu ý: kiểu NUMC/DEC có thể cần chuẩn hóa thêm.
        DATA lv_a TYPE string.
        DATA lv_b TYPE string.
        lv_a = lv_dbstr.        CONDENSE lv_a.
        lv_b = ls_cell-value.   CONDENSE lv_b.

        IF lv_a <> lv_b.
          lv_changed = abap_true.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_rkey
                          fieldname  = ls_cell-fieldname
                          old_value  = lv_dbstr
                          new_value  = ls_cell-value
                          status     = zcl_excel_types=>c_status-changed ) TO rt_diff.
        ENDIF.
      ENDLOOP.

      " 4c) Không field nào đổi → UNCHANGED
      IF lv_changed = abap_false.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_rkey
                        status     = zcl_excel_types=>c_status-unchanged
                        message    = 'Không thay đổi' ) TO rt_diff.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.


  METHOD get_cell_value.
    READ TABLE it_cells INTO DATA(ls) WITH KEY fieldname = iv_field.
    IF sy-subrc = 0.
      rv_value = ls-value.
    ENDIF.
  ENDMETHOD.


  METHOD build_record_key.
    DATA lv_first TYPE abap_bool.
    lv_first = abap_true.
    rv_key = '{'.

    LOOP AT it_keys INTO DATA(lv_k).
      DATA(lv_val) = get_cell_value( it_cells = it_cells iv_field = CONV #( lv_k ) ).
      REPLACE ALL OCCURRENCES OF '"' IN lv_val WITH '\"'.

      IF lv_first = abap_true.
        lv_first = abap_false.
      ELSE.
        rv_key = rv_key && ','.
      ENDIF.
      rv_key = rv_key && |"{ lv_k }":"{ lv_val }"|.
    ENDLOOP.

    rv_key = rv_key && '}'.
  ENDMETHOD.


  METHOD build_where.
    LOOP AT it_keys INTO DATA(lv_k).
      DATA(lv_val) = get_cell_value( it_cells = it_cells iv_field = CONV #( lv_k ) ).
      " escape dấu nháy đơn cho dynamic SQL
      REPLACE ALL OCCURRENCES OF |'| IN lv_val WITH |''|.
      DATA(lv_cond) = |{ lv_k } = '{ lv_val }'|.

      IF rv_where IS INITIAL.
        rv_where = lv_cond.
      ELSE.
        rv_where = rv_where && ` AND ` && lv_cond.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_row.
    LOOP AT it_fields INTO DATA(ls_field).
      DATA(lv_val) = get_cell_value( it_cells = it_cells iv_field = ls_field-field_name ).

      " mandatory
      IF ls_field-mandatory_flag = abap_true AND lv_val IS INITIAL.
        APPEND |Field { ls_field-field_name } bắt buộc nhập| TO rt_errors.
        CONTINUE.
      ENDIF.

      IF lv_val IS INITIAL.
        CONTINUE.
      ENDIF.

      " length — chỉ check field kiểu ký tự
      IF ls_field-inttype = 'C' AND ls_field-leng > 0 AND strlen( lv_val ) > ls_field-leng.
        APPEND |Field { ls_field-field_name } vượt độ dài { ls_field-leng }| TO rt_errors.
      ENDIF.

      " domain fixed values
      IF ls_field-domain_name IS NOT INITIAL.
        DATA(lt_vals) = zcl_table_inspector=>get_domain_values( ls_field-domain_name ).
        IF lt_vals IS NOT INITIAL.
          READ TABLE lt_vals TRANSPORTING NO FIELDS WITH KEY value = lv_val.
          IF sy-subrc <> 0.
            APPEND |Field { ls_field-field_name } giá trị '{ lv_val }' không hợp lệ (domain { ls_field-domain_name })| TO rt_errors.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

