*&---------------------------------------------------------------------*
*& Report ZR_TEST_ADMIN_FIELDS
*&---------------------------------------------------------------------*
*& Mục đích:
*&   1) SCAN  : quét bảng động, tìm record có CREATED_AT / CREATED_BY
*&              đang bị NULL/initial -> in ra danh sách nghi vấn.
*&   2) TEST  : gọi trực tiếp zcl_dyn_record_handler=>create_record /
*&              update_record với dữ liệu test, log từng bước để xác
*&              nhận admin field (CREATED_AT/BY, CHANGED_AT/BY) có
*&              được fill đúng hay không. Test record sẽ bị ROLLBACK
*&              ở cuối, KHÔNG lưu vĩnh viễn vào bảng.
*&
*& Cách dùng:
*&   - Tick "Scan bảng tìm record NULL admin field" để chạy mode 1.
*&   - Tick "Test luồng create_record" để chạy mode 2 (test CREATE).
*&   - Tick "Test luồng update_record" để chạy mode 3 (test UPDATE
*&     trên 1 record có sẵn - dùng để tái hiện lỗi keep_old_field).
*&---------------------------------------------------------------------*
REPORT z_test251 .

TABLES: dd03l.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_tab TYPE tabname OBLIGATORY DEFAULT 'ZTPC_HEADER'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS:
  p_scan  AS CHECKBOX DEFAULT 'X',
  p_ctest AS CHECKBOX DEFAULT 'X',
  p_utest AS CHECKBOX DEFAULT '' .
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
PARAMETERS: p_ukey TYPE string LOWER CASE. "record key JSON cho update test, vd: {"ENTITY_ID":"..."}
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* Global log helper
*----------------------------------------------------------------------*
CLASS lcl_log DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      line  IMPORTING iv_text TYPE string,
      hr,
      title IMPORTING iv_text TYPE string.
ENDCLASS.

CLASS lcl_log IMPLEMENTATION.
  METHOD line.
    WRITE: / iv_text.
  ENDMETHOD.
  METHOD hr.
    ULINE.
  ENDMETHOD.
  METHOD title.
    hr( ).
    WRITE: / iv_text COLOR COL_HEADING.
    hr( ).
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
START-OF-SELECTION.

  lcl_log=>title( |TEST ADMIN FIELD LOGIC - TABLE { p_tab }| ).
  lcl_log=>line( |Run by: { sy-uname }   Time: { sy-datum } { sy-uzeit }| ).

  IF p_scan = abap_true.
    PERFORM scan_null_admin_fields.
  ENDIF.

  IF p_ctest = abap_true.
    PERFORM test_create_flow.
  ENDIF.

  IF p_utest = abap_true.
    PERFORM test_update_flow.
  ENDIF.

  lcl_log=>title( 'DONE' ).

*&---------------------------------------------------------------------*
*&      Form  SCAN_NULL_ADMIN_FIELDS
*&---------------------------------------------------------------------*
FORM scan_null_admin_fields.
  lcl_log=>title( 'MODE 1: SCAN - tìm record có CREATED_AT/CREATED_BY NULL' ).

  " Kiểm tra bảng có field CREATED_AT / CREATED_BY hay không trước khi build WHERE động
  DATA(lv_has_created_at) = abap_false.
  DATA(lv_has_created_by) = abap_false.

  SELECT SINGLE @abap_true FROM dd03l
    WHERE tabname = @p_tab AND fieldname = 'CREATED_AT' AND as4local = 'A'
    INTO @lv_has_created_at.

  SELECT SINGLE @abap_true FROM dd03l
    WHERE tabname = @p_tab AND fieldname = 'CREATED_BY' AND as4local = 'A'
    INTO @lv_has_created_by.

  IF lv_has_created_at = abap_false.
    lcl_log=>line( |Bảng { p_tab } không có field CREATED_AT -> bỏ qua scan.| ).
    RETURN.
  ENDIF.

  TRY.
      DATA(lo_desc) = zcl_dyn_record_handler=>get_struct_desc( p_tab ).
    CATCH cx_root INTO DATA(lx_desc).
      lcl_log=>line( |Lỗi: không đọc được structure của { p_tab }: { lx_desc->get_text( ) }| ).
      RETURN.
  ENDTRY.

  DATA(lv_where) = |CREATED_AT IS NULL|.

  TRY.
      DATA(lr_data) = zcl_dyn_record_handler=>get_table_data(
        iv_table_name   = p_tab
        iv_where_clause = lv_where
        iv_max_rows     = 200 ).
    CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
      lcl_log=>line( |Lỗi SELECT: { lx_sql->get_text( ) }| ).
      RETURN.
  ENDTRY.

  ASSIGN lr_data->* TO FIELD-SYMBOL(<lt_rows>).
  IF <lt_rows> IS NOT ASSIGNED.
    lcl_log=>line( 'Không đọc được dữ liệu.' ).
    RETURN.
  ENDIF.

  DATA(lv_count) = lines( <lt_rows> ).
  lcl_log=>line( |Tìm thấy { lv_count } record có CREATED_AT = NULL trong { p_tab }| ).
  lcl_log=>hr( ).

  IF lv_count = 0.
    lcl_log=>line( 'Không có record nào bị lỗi. OK.' ).
    RETURN.
  ENDIF.

  " In chi tiết từng record nghi vấn (key fields + created_by + changed_by + changed_at)
  DATA(lt_keys) = zcl_dyn_record_handler=>get_key_fields( p_tab ).

  LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
    DATA(lv_line) = VALUE string( ).

    LOOP AT lt_keys INTO DATA(lv_key).
      IF lv_key = 'MANDT' OR lv_key = 'CLIENT'. CONTINUE. ENDIF.
      ASSIGN COMPONENT lv_key OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_kval>).
      IF sy-subrc = 0.
        lv_line = lv_line && |{ lv_key }={ <lv_kval> } |.
      ENDIF.
    ENDLOOP.

    ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_cby>).
    IF sy-subrc = 0.
      lv_line = lv_line && |CREATED_BY={ <lv_cby> } |.
    ENDIF.

    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_chby>).
    IF sy-subrc = 0.
      lv_line = lv_line && |CHANGED_BY={ <lv_chby> } |.
    ENDIF.

    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_chat>).
    IF sy-subrc = 0.
      lv_line = lv_line && |CHANGED_AT={ <lv_chat> }|.
    ENDIF.

    lcl_log=>line( lv_line ).
  ENDLOOP.

  lcl_log=>hr( ).
  lcl_log=>line( 'Gợi ý: các record này KHÔNG được tạo qua zcl_dyn_record_handler=>create_record' ).
  lcl_log=>line( '(method đó luôn force-fill CREATED_AT). Kiểm tra script seed demo data / SE16N.' ).
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  TEST_CREATE_FLOW
*&---------------------------------------------------------------------*
FORM test_create_flow.
  lcl_log=>title( 'MODE 2: TEST create_record() - log admin field trước/sau' ).

  " Build JSON test KHÔNG chứa CREATED_AT/CREATED_BY/CHANGED_AT/CHANGED_BY
  " để mô phỏng đúng payload FE thường gửi lên.
  DATA(lv_ts_before) = utclong_current( ).
  DATA(lv_test_json) =
    |\{"PRODUCT_CATEGORY":"ZTST","DESCRIPTION":"Test admin field log ({ sy-datum } { sy-uzeit })",| &&
    |"STATUS":"A","VALID_FROM":"2026-01-01","VALID_TO":"9999-12-31",| &&
    |"COMPANY_CODE":"TEST","PLANT":"TEST"\}|.

  lcl_log=>line( |JSON gửi vào create_record:| ).
  lcl_log=>line( lv_test_json ).
  lcl_log=>line( |Timestamp trước khi gọi: { lv_ts_before }| ).
  lcl_log=>hr( ).

  TRY.
      DATA(ls_result) = zcl_dyn_record_handler=>create_record(
        iv_table_name  = p_tab
        iv_record_data = lv_test_json ).
    CATCH cx_root INTO DATA(lx_create).
      lcl_log=>line( |EXCEPTION khi gọi create_record: { lx_create->get_text( ) }| ).
      RETURN.
  ENDTRY.

  lcl_log=>line( |success = { ls_result-success }| ).
  lcl_log=>line( |message = { ls_result-message }| ).
  lcl_log=>line( |record_key = { ls_result-record_key }| ).
  lcl_log=>hr( ).

  IF ls_result-success <> abap_true.
    lcl_log=>line( 'create_record báo lỗi -> dừng test, xem message ở trên.' ).
    ROLLBACK WORK.
    RETURN.
  ENDIF.

  " ── Đọc lại record vừa insert để verify admin field thực tế trong bảng ──
  DATA lo_desc TYPE REF TO cl_abap_structdescr.
  TRY.
      lo_desc = zcl_dyn_record_handler=>get_struct_desc( p_tab ).
    CATCH cx_root.
      lcl_log=>line( 'Không đọc được structure để build record key.' ).
      ROLLBACK WORK.
      RETURN.
  ENDTRY.

  DATA lo_record TYPE REF TO data.
  CREATE DATA lo_record TYPE HANDLE lo_desc.
  ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_key_record>).

  TRY.
      zcl_dyn_record_handler=>deserialize(
        EXPORTING iv_json   = CONV string( ls_result-record_key )
        CHANGING  ca_record = lo_record ).
    CATCH cx_root INTO DATA(lx_deser).
      lcl_log=>line( |Không deserialize được record_key: { lx_deser->get_text( ) }| ).
      ROLLBACK WORK.
      RETURN.
  ENDTRY.

  DATA(lt_keys) = zcl_dyn_record_handler=>get_key_fields( p_tab ).
  DATA(lv_where) = zcl_dyn_record_handler=>build_where_clause(
    it_key_fields = lt_keys
    ir_record     = lo_record ).

  DATA lo_row TYPE REF TO data.
  CREATE DATA lo_row TYPE HANDLE lo_desc.
  ASSIGN lo_row->* TO FIELD-SYMBOL(<ls_row_check>).

  SELECT SINGLE * FROM (p_tab) WHERE (lv_where) INTO CORRESPONDING FIELDS OF @<ls_row_check>.

  IF sy-subrc <> 0.
    lcl_log=>line( 'Không SELECT lại được record vừa tạo (lạ). Kiểm tra WHERE clause / key.' ).
    ROLLBACK WORK.
    RETURN.
  ENDIF.

  lcl_log=>line( 'Giá trị admin field NGAY SAU KHI INSERT (đọc lại từ DB):' ).

  ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <ls_row_check> TO FIELD-SYMBOL(<lv_r_cby>).
  IF sy-subrc = 0. lcl_log=>line( |  CREATED_BY = { <lv_r_cby> }| ). ENDIF.

  ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <ls_row_check> TO FIELD-SYMBOL(<lv_r_cat>).
  IF sy-subrc = 0.
    IF <lv_r_cat> IS INITIAL.
      lcl_log=>line( '  CREATED_AT = <NULL/INITIAL>  <<<<< BUG XÁC NHẬN Ở apply_admin_on_insert' ).
    ELSE.
      lcl_log=>line( |  CREATED_AT = { <lv_r_cat> }  (OK - có giá trị)| ).
    ENDIF.
  ENDIF.

  ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE <ls_row_check> TO FIELD-SYMBOL(<lv_r_chby>).
  IF sy-subrc = 0. lcl_log=>line( |  CHANGED_BY = { <lv_r_chby> }| ). ENDIF.

  ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <ls_row_check> TO FIELD-SYMBOL(<lv_r_chat>).
  IF sy-subrc = 0.
    IF <lv_r_chat> IS INITIAL.
      lcl_log=>line( '  CHANGED_AT = <NULL/INITIAL>' ).
    ELSE.
      lcl_log=>line( |  CHANGED_AT = { <lv_r_chat> }| ).
    ENDIF.
  ENDIF.

  lcl_log=>hr( ).
  lcl_log=>line( 'ROLLBACK WORK -> record test KHÔNG được lưu vĩnh viễn.' ).
  ROLLBACK WORK.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  TEST_UPDATE_FLOW
*&---------------------------------------------------------------------*
FORM test_update_flow.
  lcl_log=>title( 'MODE 3: TEST update_record() - kiểm tra keep_old_field / backfill' ).

  IF p_ukey IS INITIAL.
    lcl_log=>line( 'Chưa nhập P_UKEY (record key JSON, vd {"ENTITY_ID":"..."}) -> bỏ qua mode này.' ).
    RETURN.
  ENDIF.

  TRY.
      DATA(lo_desc) = zcl_dyn_record_handler=>get_struct_desc( p_tab ).
    CATCH cx_root INTO DATA(lx_desc).
      lcl_log=>line( |Lỗi đọc structure: { lx_desc->get_text( ) }| ).
      RETURN.
  ENDTRY.

  DATA lo_key_record TYPE REF TO data.
  CREATE DATA lo_key_record TYPE HANDLE lo_desc.
  ASSIGN lo_key_record->* TO FIELD-SYMBOL(<ls_key>).

  TRY.
      zcl_dyn_record_handler=>deserialize(
        EXPORTING iv_json   = p_ukey
        CHANGING  ca_record = lo_key_record ).
    CATCH cx_root INTO DATA(lx_ds).
      lcl_log=>line( |Không parse được P_UKEY: { lx_ds->get_text( ) }| ).
      RETURN.
  ENDTRY.

  DATA(lt_keys)  = zcl_dyn_record_handler=>get_key_fields( p_tab ).
  DATA(lv_where) = zcl_dyn_record_handler=>build_where_clause(
    it_key_fields = lt_keys
    ir_record     = lo_key_record ).

  DATA lo_before TYPE REF TO data.
  CREATE DATA lo_before TYPE HANDLE lo_desc.
  ASSIGN lo_before->* TO FIELD-SYMBOL(<ls_before>).

  SELECT SINGLE * FROM (p_tab) WHERE (lv_where) INTO CORRESPONDING FIELDS OF @<ls_before>.
  IF sy-subrc <> 0.
    lcl_log=>line( |Không tìm thấy record với WHERE: { lv_where }| ).
    RETURN.
  ENDIF.

  lcl_log=>line( 'Giá trị admin field TRƯỚC update:' ).
  ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <ls_before> TO FIELD-SYMBOL(<lv_b_cat>).
  IF sy-subrc = 0.
    lcl_log=>line( COND #( WHEN <lv_b_cat> IS INITIAL
      THEN '  CREATED_AT = <NULL/INITIAL> (record này đã bị lỗi từ trước)'
      ELSE |  CREATED_AT = { <lv_b_cat> }| ) ).
  ENDIF.

  " Serialize record hiện tại thành JSON rồi gọi update_record với đúng dữ liệu đó
  " (mô phỏng 1 update bình thường không đổi field nào, chỉ để trace admin field)
  DATA(lv_update_json) = zcl_dyn_record_handler=>serialize( <ls_before> ).

  lcl_log=>hr( ).
  lcl_log=>line( 'Gọi update_record() với chính dữ liệu hiện tại...' ).

  TRY.
      DATA(ls_upd_result) = zcl_dyn_record_handler=>update_record(
        iv_table_name  = p_tab
        iv_record_data = lv_update_json ).
    CATCH cx_root INTO DATA(lx_upd).
      lcl_log=>line( |EXCEPTION khi gọi update_record: { lx_upd->get_text( ) }| ).
      RETURN.
  ENDTRY.

  lcl_log=>line( |success = { ls_upd_result-success }| ).
  lcl_log=>line( |message = { ls_upd_result-message }| ).
  lcl_log=>hr( ).

  DATA lo_after TYPE REF TO data.
  CREATE DATA lo_after TYPE HANDLE lo_desc.
  ASSIGN lo_after->* TO FIELD-SYMBOL(<ls_after>).

  SELECT SINGLE * FROM (p_tab) WHERE (lv_where) INTO CORRESPONDING FIELDS OF @<ls_after>.

  lcl_log=>line( 'Giá trị admin field SAU update:' ).
  ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <ls_after> TO FIELD-SYMBOL(<lv_a_cat>).
  IF sy-subrc = 0.
    lcl_log=>line( COND #( WHEN <lv_a_cat> IS INITIAL
      THEN '  CREATED_AT = <NULL/INITIAL>  <<<<< keep_old_field đang copy NULL từ record cũ'
      ELSE |  CREATED_AT = { <lv_a_cat> }| ) ).
  ENDIF.

  ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <ls_after> TO FIELD-SYMBOL(<lv_a_chat>).
  IF sy-subrc = 0.
    lcl_log=>line( COND #( WHEN <lv_a_chat> IS INITIAL
      THEN '  CHANGED_AT = <NULL/INITIAL>  <<<<< BUG - apply_admin_on_update không chạy?'
      ELSE |  CHANGED_AT = { <lv_a_chat> }  (OK - force-fill hoạt động đúng)| ) ).
  ENDIF.

  lcl_log=>hr( ).
  lcl_log=>line( 'LƯU Ý: mode này ĐÃ COMMIT thật vào bảng (vì update_record dùng UPDATE trực tiếp,' ).
  lcl_log=>line( 'không rollback được an toàn cho record thật đang tồn tại). Chỉ chạy trên record test/demo.' ).
ENDFORM.
