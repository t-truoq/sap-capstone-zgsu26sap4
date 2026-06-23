"! <p class="shorttext synchronized">Excel Diff Builder (Phase 3)</p>
"! So sánh các dòng Excel đã parse với data hiện có trong DB.
"! Phân loại: NEW / CHANGED / UNCHANGED / ERROR. CHƯA ghi DB.
"! Match ưu tiên ENTITY_ID (full export), fallback business key (template).
CLASS zcl_excel_diff_builder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS build_diff
      IMPORTING iv_table_name  TYPE tabname
                it_rows        TYPE zcl_excel_types=>tt_parsed_row
      RETURNING VALUE(rt_diff) TYPE zcl_excel_types=>tt_diff_row
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.

    CLASS-METHODS validate_row
      IMPORTING iv_table_name      TYPE tabname
                it_fields          TYPE zcl_table_inspector=>tt_field_info
                it_cells           TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rt_errors) TYPE string_table.

    CLASS-METHODS build_file_key
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rv_key) TYPE string.

    CLASS-METHODS append_new_diff
      IMPORTING iv_row_no     TYPE i
                iv_table_name TYPE tabname
                iv_record_key TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
      CHANGING  ct_diff       TYPE zcl_excel_types=>tt_diff_row.

    CLASS-METHODS append_compare_diff
      IMPORTING iv_row_no     TYPE i
                iv_table_name TYPE tabname
                iv_record_key TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
                ir_db_row     TYPE REF TO data
      CHANGING  ct_diff       TYPE zcl_excel_types=>tt_diff_row
      RETURNING VALUE(rv_changed) TYPE abap_bool.

ENDCLASS.


CLASS zcl_excel_diff_builder IMPLEMENTATION.

  METHOD build_diff.
    CLEAR rt_diff.

    FIELD-SYMBOLS <db_row> TYPE any.
    FIELD-SYMBOLS <db_val> TYPE any.

    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    IF lt_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } chưa được config trong ZFLD_CONFIG|.
    ENDIF.

    DATA lt_biz_keys TYPE string_table.
    lt_biz_keys = zcl_excel_types=>get_match_key_fields(
                    it_fields     = lt_fields
                    iv_table_name = iv_table_name ).

    IF lt_biz_keys IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Table { iv_table_name } không có key field importable để so sánh. | &&
                                |Set is_key_field=X cho business key trong ZFLD_CONFIG.|.
    ENDIF.

    " Đếm key trùng trong file (ENTITY_ID hoặc business key)
    TYPES: BEGIN OF ty_kc,
             rkey TYPE string,
             cnt  TYPE i,
           END OF ty_kc.
    DATA lt_kc TYPE HASHED TABLE OF ty_kc WITH UNIQUE KEY rkey.

    LOOP AT it_rows INTO DATA(ls_pre).
      DATA(lv_prekey) = build_file_key(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_pre-cells ).
      READ TABLE lt_kc ASSIGNING FIELD-SYMBOL(<kc>) WITH KEY rkey = lv_prekey.
      IF sy-subrc = 0.
        <kc>-cnt = <kc>-cnt + 1.
      ELSE.
        INSERT VALUE #( rkey = lv_prekey cnt = 1 ) INTO TABLE lt_kc.
      ENDIF.
    ENDLOOP.

    DATA(lv_eid_f) = zcl_excel_types=>get_entity_id_field( iv_table_name ).

    LOOP AT it_rows INTO DATA(ls_row).

      DATA(lv_fkey) = build_file_key(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).

      READ TABLE lt_kc INTO DATA(ls_kc) WITH KEY rkey = lv_fkey.
      IF sy-subrc = 0 AND ls_kc-cnt > 1.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_fkey
                        status     = zcl_excel_types=>c_status-error
                        message    = |Key bị trùng trong file ({ ls_kc-cnt } dòng cùng key) - sửa file trước khi import| ) TO rt_diff.
        CONTINUE.
      ENDIF.

      DATA(lt_err) = validate_row(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).
      IF lt_err IS NOT INITIAL.
        LOOP AT lt_err INTO DATA(lv_emsg).
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = zcl_excel_types=>c_status-error
                          message    = lv_emsg ) TO rt_diff.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      DATA lv_missing_key TYPE abap_bool VALUE abap_false.
      DATA(lv_has_eid) = abap_false.
      IF lv_eid_f IS NOT INITIAL.
        IF zcl_excel_types=>get_cell_value( it_cells = ls_row-cells iv_field = lv_eid_f ) IS NOT INITIAL.
          lv_has_eid = abap_true.
        ENDIF.
      ENDIF.

      IF lv_has_eid = abap_false.
        LOOP AT lt_biz_keys INTO DATA(lv_k).
          IF zcl_excel_types=>get_cell_value(
               it_cells = ls_row-cells iv_field = CONV #( lv_k ) ) IS INITIAL.
            lv_missing_key = abap_true.
          ENDIF.
        ENDLOOP.
        IF lv_missing_key = abap_true.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = zcl_excel_types=>c_status-error
                          message    = 'Thiếu giá trị key field' ) TO rt_diff.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA(lv_where) = zcl_excel_types=>build_where_from_cells(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        it_cells      = ls_row-cells ).

      IF lv_where IS INITIAL.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_fkey
                        status     = zcl_excel_types=>c_status-error
                        message    = 'Không build được điều kiện tìm bản ghi DB' ) TO rt_diff.
        CONTINUE.
      ENDIF.

      DATA lr_db TYPE REF TO data.
      DATA lv_db_ok TYPE abap_bool VALUE abap_false.

      TRY.
          lr_db = zcl_excel_record_builder=>read_db_row(
                    iv_table_name = iv_table_name
                    iv_where      = lv_where ).
          lv_db_ok = abap_true.
        CATCH zcx_excel_pipeline.
          lv_db_ok = abap_false.
        CATCH cx_sy_dynamic_osql_error INTO DATA(lx).
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = zcl_excel_types=>c_status-error
                          message    = |Đọc DB lỗi: { lx->get_text( ) }| ) TO rt_diff.
          CONTINUE.
      ENDTRY.

      IF lv_db_ok = abap_false.
        IF lv_has_eid = abap_true.
          APPEND VALUE #( row_no     = ls_row-row_no
                          table_name = iv_table_name
                          record_key = lv_fkey
                          status     = zcl_excel_types=>c_status-error
                          message    = |ENTITY_ID không tồn tại trong DB - kiểm tra file export| ) TO rt_diff.
        ELSE.
          append_new_diff(
            EXPORTING iv_row_no     = ls_row-row_no
                      iv_table_name = iv_table_name
                      iv_record_key = lv_fkey
                      it_fields     = lt_fields
                      it_cells      = ls_row-cells
            CHANGING  ct_diff       = rt_diff ).
        ENDIF.
        CONTINUE.
      ENDIF.

      DATA(lv_rkey) = zcl_excel_types=>build_record_key_json(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        ir_row        = lr_db ).

      DATA(lv_collision) = zcl_excel_record_builder=>check_business_key_collision(
        iv_table_name = iv_table_name
        it_fields     = lt_fields
        ir_db_row     = lr_db
        it_cells      = ls_row-cells ).

      IF lv_collision IS NOT INITIAL.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_rkey
                        status     = zcl_excel_types=>c_status-error
                        message    = lv_collision ) TO rt_diff.
        CONTINUE.
      ENDIF.

      DATA(lv_changed) = append_compare_diff(
        EXPORTING iv_row_no     = ls_row-row_no
                  iv_table_name = iv_table_name
                  iv_record_key = lv_rkey
                  it_fields     = lt_fields
                  it_cells      = ls_row-cells
                  ir_db_row     = lr_db
        CHANGING  ct_diff       = rt_diff ).

      IF lv_changed = abap_false.
        APPEND VALUE #( row_no     = ls_row-row_no
                        table_name = iv_table_name
                        record_key = lv_rkey
                        status     = zcl_excel_types=>c_status-unchanged
                        message    = 'Không thay đổi' ) TO rt_diff.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.


  METHOD build_file_key.
    rv_key = zcl_excel_types=>build_record_key_json(
      iv_table_name = iv_table_name
      it_fields     = it_fields
      it_cells      = it_cells ).
  ENDMETHOD.


  METHOD append_new_diff.
    DATA lt_seen TYPE string_table.
    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0 OR zcl_excel_types=>is_diff_comparable_field(
        is_field = ls_f iv_table_name = iv_table_name it_fields = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.
      READ TABLE lt_seen TRANSPORTING NO FIELDS
        WITH KEY table_line = CONV string( ls_cell-fieldname ).
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      APPEND CONV string( ls_cell-fieldname ) TO lt_seen.
      APPEND VALUE #( row_no     = iv_row_no
                      table_name = iv_table_name
                      record_key = iv_record_key
                      fieldname  = ls_cell-fieldname
                      new_value  = ls_cell-value
                      status     = zcl_excel_types=>c_status-new ) TO ct_diff.
    ENDLOOP.
  ENDMETHOD.


  METHOD append_compare_diff.
    rv_changed = abap_false.
    ASSIGN ir_db_row->* TO FIELD-SYMBOL(<db_row>).
    DATA lt_seen TYPE string_table.

    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0 OR zcl_excel_types=>is_diff_comparable_field(
        is_field = ls_f iv_table_name = iv_table_name it_fields = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.
      READ TABLE lt_seen TRANSPORTING NO FIELDS
        WITH KEY table_line = CONV string( ls_cell-fieldname ).
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      APPEND CONV string( ls_cell-fieldname ) TO lt_seen.

      FIELD-SYMBOLS <db_val> TYPE any.
      UNASSIGN <db_val>.
      ASSIGN COMPONENT ls_cell-fieldname OF STRUCTURE <db_row> TO <db_val>.
      DATA lv_dbstr TYPE string.
      IF <db_val> IS ASSIGNED.
        lv_dbstr = |{ <db_val> }|.
      ELSE.
        CLEAR lv_dbstr.
      ENDIF.

      DATA lv_a TYPE string.
      DATA lv_b TYPE string.
      lv_a = lv_dbstr.      CONDENSE lv_a.
      lv_b = ls_cell-value. CONDENSE lv_b.

      IF lv_a <> lv_b.
        rv_changed = abap_true.
        APPEND VALUE #( row_no     = iv_row_no
                        table_name = iv_table_name
                        record_key = iv_record_key
                        fieldname  = ls_cell-fieldname
                        old_value  = lv_dbstr
                        new_value  = ls_cell-value
                        status     = zcl_excel_types=>c_status-changed ) TO ct_diff.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_row.
    LOOP AT it_fields INTO DATA(ls_field).
      IF zcl_excel_types=>is_diff_comparable_field(
           is_field      = ls_field
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_val) = zcl_excel_types=>get_cell_value(
        it_cells = it_cells iv_field = ls_field-field_name ).

      IF ( ls_field-mandatory_flag = abap_true OR ls_field-mandatory_flag = 'X' )
         AND lv_val IS INITIAL.
        APPEND |Field { ls_field-field_name } bắt buộc nhập| TO rt_errors.
        CONTINUE.
      ENDIF.

      IF lv_val IS INITIAL.
        CONTINUE.
      ENDIF.

      IF ls_field-inttype = 'C' AND ls_field-leng > 0 AND strlen( lv_val ) > ls_field-leng.
        APPEND |Field { ls_field-field_name } vượt độ dài { ls_field-leng }| TO rt_errors.
      ENDIF.

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

