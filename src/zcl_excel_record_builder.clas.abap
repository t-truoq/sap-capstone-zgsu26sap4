"! Merge DB row + Excel cells, serialize JSON cho approval/commit.
CLASS zcl_excel_record_builder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS build_where_from_record_key
      IMPORTING iv_table_name TYPE tabname
                iv_record_key TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      RETURNING VALUE(rv_where) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS read_db_row
      IMPORTING iv_table_name TYPE tabname
                iv_where      TYPE string
      RETURNING VALUE(rr_row) TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS apply_cells_to_record
      IMPORTING iv_table_name TYPE tabname
                it_cells      TYPE zcl_excel_types=>tt_cell
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      CHANGING  cr_record     TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_merged_record
      IMPORTING iv_table_name TYPE tabname
                it_cells      TYPE zcl_excel_types=>tt_cell
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                iv_status     TYPE c
                iv_record_key TYPE string
      EXPORTING ev_old_json   TYPE string
                ev_new_json   TYPE string
                er_record     TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS check_business_key_collision
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                ir_db_row     TYPE REF TO data
                it_cells      TYPE zcl_excel_types=>tt_cell
      RETURNING VALUE(rv_error) TYPE string.

    "! Deserialize new_data ngược lại struct — bắt lỗi tên field JSON ≠ DDIC trước khi gửi duyệt.
    CLASS-METHODS validate_approval_json
      IMPORTING iv_table_name TYPE tabname
                iv_new_json   TYPE string
                it_fields     TYPE zcl_table_inspector=>tt_field_info
      RAISING   zcx_excel_pipeline.

    "! Gán admin field ngay trước INSERT (Approve / commit trực tiếp).
    CLASS-METHODS apply_admin_on_insert
      CHANGING cs_record TYPE any.

    "! Gán LAST_CHANGED_* / CHANGED_* ngay trước UPDATE (Approve / commit trực tiếp).
    CLASS-METHODS apply_admin_on_update
      CHANGING cs_record TYPE any.

  PRIVATE SECTION.

    CLASS-METHODS set_entity_id_if_empty
      CHANGING cs_record TYPE any.

    CLASS-METHODS set_client_mandt
      CHANGING cs_record TYPE any.

    CLASS-METHODS assign_sys_timestamp
      IMPORTING iv_fieldname TYPE fieldname
      CHANGING  cs_record    TYPE any.

    CLASS-METHODS set_admin_on_insert
      CHANGING cs_record TYPE any.

    CLASS-METHODS set_admin_on_update_record
      CHANGING cs_record TYPE any.

    "! JSON Create cho Approve: chỉ business + ENTITY_ID + MANDT (không admin timestamp).
    CLASS-METHODS serialize_new_for_approval
      IMPORTING iv_table_name TYPE tabname
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
                ir_record     TYPE REF TO data
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS is_admin_timestamp_field
      IMPORTING iv_fieldname TYPE fieldname
      RETURNING VALUE(rv_skip) TYPE abap_bool.

    CLASS-METHODS append_field_to_approval_json
      IMPORTING iv_table_name TYPE tabname
                is_field      TYPE zcl_table_inspector=>ty_field_info
                it_fields     TYPE zcl_table_inspector=>tt_field_info
                it_cells      TYPE zcl_excel_types=>tt_cell
                ir_record     TYPE REF TO data
      CHANGING  cv_json       TYPE string
                cv_first      TYPE abap_bool
                ct_seen       TYPE string_table.

    CLASS-METHODS append_json_field
      IMPORTING iv_name  TYPE string
                iv_value TYPE string
                iv_quote TYPE abap_bool DEFAULT abap_true
      CHANGING  cv_json  TYPE string
                cv_first TYPE abap_bool.

    CLASS-METHODS component_to_json_value
      IMPORTING iv_table_name TYPE tabname
                iv_fieldname  TYPE fieldname
                ir_component  TYPE REF TO data
      RETURNING VALUE(rv_value) TYPE string.

ENDCLASS.


CLASS zcl_excel_record_builder IMPLEMENTATION.

  METHOD build_where_from_record_key.
    DATA(lt_keys) = zcl_excel_types=>get_where_key_fields(
      iv_table_name = iv_table_name
      it_fields     = it_fields
      iv_record_key = iv_record_key ).

    DATA lr_rec TYPE REF TO data.
    CREATE DATA lr_rec TYPE (iv_table_name).

    TRY.
        zcl_json_helper=>deserialize(
          EXPORTING iv_json   = iv_record_key
          CHANGING  ca_record = lr_rec ).
      CATCH cx_root INTO DATA(lxj).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |record_key JSON không hợp lệ: { lxj->get_text( ) }|.
    ENDTRY.

    ASSIGN lr_rec->* TO FIELD-SYMBOL(<rec>).
    LOOP AT lt_keys INTO DATA(lv_k).
      ASSIGN COMPONENT lv_k OF STRUCTURE <rec> TO FIELD-SYMBOL(<kv>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_val) = |{ <kv> }|.
      REPLACE ALL OCCURRENCES OF |'| IN lv_val WITH |''|.
      DATA(lv_cond) = |{ lv_k } = '{ lv_val }'|.
      IF rv_where IS INITIAL.
        rv_where = lv_cond.
      ELSE.
        rv_where = rv_where && ` AND ` && lv_cond.
      ENDIF.
    ENDLOOP.

    IF rv_where IS INITIAL.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'Không build được WHERE từ record_key.'.
    ENDIF.
  ENDMETHOD.


  METHOD read_db_row.
    DATA(lr_tab) = zcl_dynamic_table_reader=>get_table_data(
                     iv_table_name   = iv_table_name
                     iv_where_clause = iv_where
                     iv_max_rows     = 1 ).

    FIELD-SYMBOLS <tab> TYPE STANDARD TABLE.
    ASSIGN lr_tab->* TO <tab>.
    IF <tab> IS NOT ASSIGNED OR lines( <tab> ) = 0.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = |Không đọc được record DB với WHERE: { iv_where }|.
    ENDIF.

    READ TABLE <tab> INDEX 1 ASSIGNING FIELD-SYMBOL(<row>).
    CREATE DATA rr_row TYPE (iv_table_name).
    ASSIGN rr_row->* TO FIELD-SYMBOL(<copy>).
    <copy> = <row>.
  ENDMETHOD.


  METHOD apply_cells_to_record.
    IF it_cells IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_json TYPE string.
    lv_json = '{'.
    DATA lv_first TYPE abap_bool VALUE abap_true.

    LOOP AT it_cells INTO DATA(ls_cell).
      READ TABLE it_fields INTO DATA(ls_f) WITH KEY field_name = ls_cell-fieldname.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF zcl_excel_types=>is_match_only_field(
           is_field      = ls_f
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_true.
        CONTINUE.
      ENDIF.
      IF zcl_excel_types=>is_importable_field_for_table(
           is_field      = ls_f
           iv_table_name = iv_table_name
           it_fields     = it_fields ) = abap_false.
        CONTINUE.
      ENDIF.
      IF ls_cell-value IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_val) = ls_cell-value.
      IF ls_f-inttype = 'D' AND strlen( lv_val ) = 8 AND lv_val CO '0123456789'.
        lv_val = |{ lv_val(4) }-{ lv_val+4(2) }-{ lv_val+6(2) }|.
      ENDIF.

      DATA(lv_esc) = lv_val.
      REPLACE ALL OCCURRENCES OF `\` IN lv_esc WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_esc WITH `\"`.

      IF lv_first = abap_false.
        lv_json = lv_json && ','.
      ELSE.
        lv_first = abap_false.
      ENDIF.

      IF ls_f-inttype = 'I' OR ls_f-inttype = 'P'
        OR ls_f-inttype = 'F' OR ls_f-inttype = 'N'.
        lv_json = lv_json && |"{ ls_cell-fieldname }":{ lv_esc }|.
      ELSE.
        lv_json = lv_json && |"{ ls_cell-fieldname }":"{ lv_esc }"|.
      ENDIF.
    ENDLOOP.
    lv_json = lv_json && '}'.

    IF lv_json = '{}'.
      RETURN.
    ENDIF.

    TRY.
        zcl_json_helper=>deserialize(
          EXPORTING iv_json   = lv_json
          CHANGING  ca_record = cr_record ).
      CATCH cx_root INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Gán field Excel lỗi: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD build_merged_record.
    CLEAR: ev_old_json, ev_new_json.
    CREATE DATA er_record TYPE (iv_table_name).
    ASSIGN er_record->* TO FIELD-SYMBOL(<wa>).

    IF iv_status = zcl_excel_types=>c_status-changed.
      DATA(lv_where) = build_where_from_record_key(
        iv_table_name = iv_table_name
        iv_record_key = iv_record_key
        it_fields     = it_fields ).

      DATA(lr_db) = read_db_row(
        iv_table_name = iv_table_name
        iv_where      = lv_where ).

      ASSIGN lr_db->* TO FIELD-SYMBOL(<db_row>).
      TRY.
          <wa> = <db_row>.
        CATCH cx_sy_conversion_not_supported INTO DATA(lx_copy).
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text = |Copy DB row: { lx_copy->get_text( ) }|.
      ENDTRY.
      ev_old_json = zcl_json_helper=>serialize( <wa> ).
    ENDIF.

    apply_cells_to_record(
      EXPORTING iv_table_name = iv_table_name
                it_cells      = it_cells
                it_fields     = it_fields
      CHANGING  cr_record     = er_record ).

    set_client_mandt( CHANGING cs_record = <wa> ).

    IF iv_status = zcl_excel_types=>c_status-new.
      set_entity_id_if_empty( CHANGING cs_record = <wa> ).
      set_admin_on_insert( CHANGING cs_record = <wa> ).
      " Create → JSON tối thiểu; tránh admin date/timestamp initial gây lỗi deserialize lúc Approve
      ev_new_json = serialize_new_for_approval(
        iv_table_name = iv_table_name
        it_fields     = it_fields
        it_cells      = it_cells
        ir_record     = er_record ).
    ELSE.
      set_admin_on_update_record( CHANGING cs_record = <wa> ).
      ev_new_json = serialize_new_for_approval(
        iv_table_name = iv_table_name
        it_fields     = it_fields
        it_cells      = it_cells
        ir_record     = er_record ).
    ENDIF.
  ENDMETHOD.


  METHOD check_business_key_collision.
    DATA(lv_eid_f) = zcl_excel_types=>get_entity_id_field( iv_table_name ).
    IF lv_eid_f IS INITIAL OR ir_db_row IS NOT BOUND.
      RETURN.
    ENDIF.

    ASSIGN ir_db_row->* TO FIELD-SYMBOL(<db>).
    ASSIGN COMPONENT lv_eid_f OF STRUCTURE <db> TO FIELD-SYMBOL(<db_eid>).
    IF sy-subrc <> 0 OR <db_eid> IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_biz) = zcl_excel_types=>get_match_key_fields(
      it_fields     = it_fields
      iv_table_name = iv_table_name ).

    LOOP AT lt_biz INTO DATA(lv_bk).
      DATA(lv_new) = zcl_excel_types=>get_cell_value(
        it_cells = it_cells iv_field = CONV #( lv_bk ) ).
      IF lv_new IS INITIAL.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT lv_bk OF STRUCTURE <db> TO FIELD-SYMBOL(<db_bk>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_old) = |{ <db_bk> }|.
      CONDENSE lv_old.
      DATA(lv_new_c) = lv_new.
      CONDENSE lv_new_c.
      IF lv_old = lv_new_c.
        CONTINUE.
      ENDIF.

      REPLACE ALL OCCURRENCES OF |'| IN lv_new WITH |''|.
      DATA(lv_eid_esc) = |{ <db_eid> }|.
      REPLACE ALL OCCURRENCES OF |'| IN lv_eid_esc WITH |''|.
      DATA(lv_where) = |{ lv_bk } = '{ lv_new }' AND { lv_eid_f } <> '{ lv_eid_esc }'|.

      TRY.
          DATA(lr_hit) = zcl_dynamic_table_reader=>get_table_data(
                           iv_table_name   = iv_table_name
                           iv_where_clause = lv_where
                           iv_max_rows     = 1 ).
          FIELD-SYMBOLS <tab> TYPE STANDARD TABLE.
          ASSIGN lr_hit->* TO <tab>.
          IF <tab> IS ASSIGNED AND lines( <tab> ) > 0.
            rv_error = |Field { lv_bk } giá trị '{ lv_new }' đã thuộc bản ghi khác (trùng mã nghiệp vụ)|.
            RETURN.
          ENDIF.
        CATCH cx_sy_dynamic_osql_error.
          CONTINUE.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_entity_id_if_empty.
    ASSIGN COMPONENT 'ENTITY_ID' OF STRUCTURE cs_record TO FIELD-SYMBOL(<eid>).
    IF sy-subrc <> 0 OR <eid> IS NOT INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_elem) = cl_abap_elemdescr=>describe_by_data( <eid> ).
    TRY.
        IF lo_elem->type_kind = cl_abap_typedescr=>typekind_hex.
          <eid> = cl_system_uuid=>create_uuid_x16_static( ).
        ELSE.
          <eid> = cl_system_uuid=>create_uuid_c32_static( ).
        ENDIF.
      CATCH cx_sy_conversion_not_supported.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  METHOD set_client_mandt.
    FIELD-SYMBOLS <f> TYPE any.
    ASSIGN COMPONENT 'CLIENT' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0.
      TRY.
          <f> = sy-mandt.
        CATCH cx_sy_conversion_not_supported.
      ENDTRY.
    ENDIF.
    ASSIGN COMPONENT 'MANDT' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0.
      TRY.
          <f> = sy-mandt.
        CATCH cx_sy_conversion_not_supported.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD assign_sys_timestamp.
    ASSIGN COMPONENT iv_fieldname OF STRUCTURE cs_record TO FIELD-SYMBOL(<f>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    TRY.
        <f> = utclong_current( ).
      CATCH cx_sy_conversion_not_supported.
        DATA lv_ts TYPE timestampl.
        GET TIME STAMP FIELD lv_ts.
        TRY.
            <f> = lv_ts.
          CATCH cx_sy_conversion_not_supported.
            RETURN.
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD set_admin_on_insert.
    FIELD-SYMBOLS <f> TYPE any.
    ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.
    ASSIGN COMPONENT 'LAST_CHANGED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.
    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.
    assign_sys_timestamp( EXPORTING iv_fieldname = 'CREATED_AT' CHANGING cs_record = cs_record ).
    assign_sys_timestamp( EXPORTING iv_fieldname = 'LAST_CHANGED_AT' CHANGING cs_record = cs_record ).
    assign_sys_timestamp( EXPORTING iv_fieldname = 'LOCAL_LAST_CHANGED_AT' CHANGING cs_record = cs_record ).
    assign_sys_timestamp( EXPORTING iv_fieldname = 'CHANGED_AT' CHANGING cs_record = cs_record ).
  ENDMETHOD.


  METHOD set_admin_on_update_record.
    FIELD-SYMBOLS <f> TYPE any.
    ASSIGN COMPONENT 'LAST_CHANGED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.
    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE cs_record TO <f>.
    IF sy-subrc = 0. <f> = sy-uname. ENDIF.
    assign_sys_timestamp( EXPORTING iv_fieldname = 'LAST_CHANGED_AT' CHANGING cs_record = cs_record ).
    assign_sys_timestamp( EXPORTING iv_fieldname = 'LOCAL_LAST_CHANGED_AT' CHANGING cs_record = cs_record ).
    assign_sys_timestamp( EXPORTING iv_fieldname = 'CHANGED_AT' CHANGING cs_record = cs_record ).
  ENDMETHOD.


  METHOD apply_admin_on_insert.
    set_admin_on_insert( CHANGING cs_record = cs_record ).
  ENDMETHOD.


  METHOD apply_admin_on_update.
    set_admin_on_update_record( CHANGING cs_record = cs_record ).
  ENDMETHOD.


  METHOD append_json_field.
    IF iv_quote = abap_true.
      DATA(lv_esc) = iv_value.
      REPLACE ALL OCCURRENCES OF `\` IN lv_esc WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_esc WITH `\"`.
      DATA(lv_part) = |"{ iv_name }":"{ lv_esc }"|.
    ELSE.
      lv_part = |"{ iv_name }":{ iv_value }|.
    ENDIF.
    IF cv_first = abap_true.
      cv_first = abap_false.
      cv_json = lv_part.
    ELSE.
      cv_json = cv_json && ',' && lv_part.
    ENDIF.
  ENDMETHOD.


  METHOD component_to_json_value.
    DATA(lo_elem) = CAST cl_abap_elemdescr(
      cl_abap_typedescr=>describe_by_data( ir_component->* ) ).

    CASE lo_elem->type_kind.
      WHEN cl_abap_typedescr=>typekind_hex.
        rv_value = |{ ir_component->* }|.
        CONDENSE rv_value NO-GAPS.
        TRANSLATE rv_value TO UPPER CASE.
      WHEN cl_abap_typedescr=>typekind_date.
        DATA lv_d TYPE d.
        lv_d = ir_component->*.
        IF lv_d IS INITIAL.
          CLEAR rv_value.
        ELSE.
          rv_value = |{ lv_d DATE = ISO }|.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_int
        OR cl_abap_typedescr=>typekind_int8
        OR cl_abap_typedescr=>typekind_packed
        OR cl_abap_typedescr=>typekind_float.
        rv_value = |{ ir_component->* }|.
        CONDENSE rv_value.
      WHEN OTHERS.
        rv_value = |{ ir_component->* }|.
        CONDENSE rv_value.
    ENDCASE.
  ENDMETHOD.


  METHOD is_admin_timestamp_field.
    DATA(lv_f) = iv_fieldname.
    TRANSLATE lv_f TO UPPER CASE.
    rv_skip = COND #(
      WHEN lv_f = 'CREATED_AT'
        OR lv_f = 'CHANGED_AT'
        OR lv_f = 'LAST_CHANGED_AT'
        OR lv_f = 'LOCAL_LAST_CHANGED_AT'
      THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD append_field_to_approval_json.
    READ TABLE ct_seen TRANSPORTING NO FIELDS
      WITH KEY table_line = CONV string( is_field-field_name ).
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    ASSIGN ir_record->* TO FIELD-SYMBOL(<wa>).
    DATA(lv_name) = CONV string( is_field-field_name ).
    DATA lv_json_val TYPE string.
    DATA lv_quote TYPE abap_bool VALUE abap_true.

    " JSON key phải trùng tên component DDIC — không fallback key sai (vd COMPANY_CODE vs COMPANY)
    ASSIGN COMPONENT is_field-field_name OF STRUCTURE <wa> TO FIELD-SYMBOL(<cv>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF <cv> IS NOT INITIAL.
      DATA(lr_comp) = REF #( <cv> ).
      lv_json_val = component_to_json_value(
        iv_table_name = iv_table_name
        iv_fieldname  = is_field-field_name
        ir_component  = lr_comp ).
    ENDIF.

    IF lv_json_val IS INITIAL.
      DATA(lv_cell) = zcl_excel_types=>get_cell_value(
        it_cells = it_cells iv_field = is_field-field_name ).
      IF lv_cell IS INITIAL.
        RETURN.
      ENDIF.
      lv_json_val = lv_cell.
      IF is_field-inttype = 'D' AND strlen( lv_json_val ) = 8 AND lv_json_val CO '0123456789'.
        lv_json_val = |{ lv_json_val(4) }-{ lv_json_val+4(2) }-{ lv_json_val+6(2) }|.
      ENDIF.
    ENDIF.

    IF is_field-inttype = 'I' OR is_field-inttype = 'P'
      OR is_field-inttype = 'F' OR is_field-inttype = 'N'.
      lv_quote = abap_false.
    ENDIF.

    APPEND lv_name TO ct_seen.
    append_json_field(
      EXPORTING iv_name  = lv_name
                iv_value = lv_json_val
                iv_quote = lv_quote
      CHANGING  cv_json  = cv_json
                cv_first = cv_first ).
  ENDMETHOD.


  METHOD serialize_new_for_approval.
    " Serialize qua zcl_json_helper; bỏ admin timestamp khỏi JSON (utclong không round-trip → CX_SY_CONVERSION_NO_DATE_TIME).
    " CREATED_BY/CHANGED_BY vẫn có; CREATED_AT do ZBP set lúc INSERT hoặc chấp nhận null sau Approve.
    ASSIGN ir_record->* TO FIELD-SYMBOL(<wa>).
    DATA lr_copy TYPE REF TO data.
    CREATE DATA lr_copy LIKE ir_record->*.
    ASSIGN lr_copy->* TO FIELD-SYMBOL(<cpy>).
    <cpy> = <wa>.

    DATA(lo_sdesc) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data( <wa> ) ).
    LOOP AT lo_sdesc->get_components( ) INTO DATA(ls_comp).
      IF is_admin_timestamp_field( CONV fieldname( ls_comp-name ) ) = abap_true.
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE <cpy> TO FIELD-SYMBOL(<ts>).
        IF sy-subrc = 0.
          CLEAR <ts>.
        ENDIF.
      ENDIF.
    ENDLOOP.

    rv_json = zcl_json_helper=>serialize( <cpy> ).
  ENDMETHOD.


  METHOD validate_approval_json.
    IF iv_new_json IS INITIAL OR iv_new_json = '{}'.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = 'new_data approval rỗng — không gửi duyệt được.'.
    ENDIF.

    DATA lr_test TYPE REF TO data.
    CREATE DATA lr_test TYPE (iv_table_name).
    TRY.
        zcl_json_helper=>deserialize(
          EXPORTING iv_json   = iv_new_json
          CHANGING  ca_record = lr_test ).
      CATCH cx_root INTO DATA(lx_des).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |new_data không deserialize được (Approve sẽ fail): { lx_des->get_text( ) }|.
    ENDTRY.

    ASSIGN lr_test->* TO FIELD-SYMBOL(<chk>).
    DATA(lv_has_biz) = abap_false.
    DATA(lv_eid_f) = zcl_excel_types=>get_entity_id_field( iv_table_name ).
    DATA(lo_sdesc) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data( <chk> ) ).

    LOOP AT lo_sdesc->get_components( ) INTO DATA(ls_comp).
      IF ls_comp-name = 'MANDT' OR ls_comp-name = 'CLIENT'.
        CONTINUE.
      ENDIF.
      IF ls_comp-name = lv_eid_f.
        CONTINUE.
      ENDIF.
      IF is_admin_timestamp_field( CONV fieldname( ls_comp-name ) ) = abap_true.
        CONTINUE.
      ENDIF.
      IF zcl_excel_types=>is_admin_field( CONV fieldname( ls_comp-name ) ) = abap_true.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE <chk> TO FIELD-SYMBOL(<v>).
      IF sy-subrc = 0 AND <v> IS NOT INITIAL.
        lv_has_biz = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_has_biz = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text =
          |new_data có JSON nhưng không map field nghiệp vụ vào { iv_table_name }. | &&
          |Kiểm tra ZFLD_CONFIG: tên field phải trùng DDIC (vd COMPANY, không phải COMPANY_CODE).|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

