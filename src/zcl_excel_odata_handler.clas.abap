"! <p class="shorttext synchronized">OData action logic (Phase 5)</p>
"! Handler mỏng: map CDS ↔ pipeline classes (Phase 1–4). Không phụ thuộc facade.
CLASS zcl_excel_odata_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      ty_download_req TYPE zdt_excel_download_req,
      ty_download_res TYPE zdt_excel_download_res,
      ty_upload_req   TYPE zdt_excel_upload_req,
      ty_diff_cds     TYPE zdt_excel_diff_row,
      tt_diff_cds     TYPE STANDARD TABLE OF ty_diff_cds WITH EMPTY KEY,
      ty_commit_req   TYPE zdt_excel_commit_req,
      ty_commit_res   TYPE zdt_excel_commit_res.

    CLASS-METHODS download_excel
      IMPORTING is_req         TYPE ty_download_req
      RETURNING VALUE(rs_res)  TYPE ty_download_res
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS upload_excel
      IMPORTING is_req          TYPE ty_upload_req
      EXPORTING et_diff          TYPE tt_diff_cds
                ev_info          TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS run_confirm_import
      IMPORTING is_req          TYPE ty_commit_req
                it_diff_cds     TYPE tt_diff_cds
      RETURNING VALUE(rs_res)    TYPE ty_commit_res
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS parse_diff_json
      IMPORTING iv_json         TYPE string
      RETURNING VALUE(rt_cds)   TYPE tt_diff_cds
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.

    CLASS-METHODS diff_from_internal
      IMPORTING it_diff         TYPE zcl_excel_types=>tt_diff_row
      RETURNING VALUE(rt_cds)    TYPE tt_diff_cds.

    CLASS-METHODS diff_to_internal
      IMPORTING it_cds          TYPE tt_diff_cds
      RETURNING VALUE(rt_diff)  TYPE zcl_excel_types=>tt_diff_row.

    CLASS-METHODS new_diff_id
      RETURNING VALUE(rv_id) TYPE sysuuid_x16.

ENDCLASS.


CLASS zcl_excel_odata_handler IMPLEMENTATION.

  METHOD download_excel.
    CLEAR rs_res.
    rs_res-id = is_req-id.

    DATA lv_xstring TYPE xstring.
    IF is_req-template_only = abap_true.
      lv_xstring = zcl_excel_exporter=>export_template(
        CONV tabname( is_req-table_name ) ).
    ELSE.
      lv_xstring = zcl_excel_exporter=>export_table(
        CONV tabname( is_req-table_name ) ).
    ENDIF.

    rs_res-file_base64 = cl_http_utility=>encode_x_base64( lv_xstring ).
    rs_res-message     = |Download OK: { is_req-table_name }|.
  ENDMETHOD.


  METHOD upload_excel.
    CLEAR: et_diff, ev_info.

    DATA(lv_xstring) = cl_http_utility=>decode_x_base64( is_req-file_base64 ).

    zcl_excel_importer=>parse_excel(
      EXPORTING
        iv_table_name = CONV tabname( is_req-table_name )
        iv_file       = lv_xstring
      IMPORTING
        et_rows       = DATA(lt_rows)
        et_messages   = DATA(lt_msg) ).

    DATA(lt_diff) = zcl_excel_diff_builder=>build_diff(
                      iv_table_name = CONV tabname( is_req-table_name )
                      it_rows       = lt_rows ).

    et_diff = diff_from_internal( lt_diff ).

    IF lt_msg IS NOT INITIAL.
      ev_info = concat_lines_of( table = lt_msg sep = |; | ).
    ENDIF.

    ev_info = |Parsed { lines( lt_rows ) } rows. { ev_info }|.
    CONDENSE ev_info.
  ENDMETHOD.


  METHOD run_confirm_import.
    CLEAR rs_res.
    rs_res-id = is_req-id.

    DATA(lt_diff) = diff_to_internal( it_diff_cds ).

    " Gọi committer trực tiếp (tránh trùng tên method confirm_import với facade/committer)
    DATA(ls_sum) = zcl_excel_committer=>confirm_import(
                     iv_table_name = CONV tabname( is_req-table_name )
                     it_diff       = lt_diff ).

    rs_res-inserted_count  = ls_sum-inserted_count.
    rs_res-updated_count   = ls_sum-updated_count.
    rs_res-unchanged_count = ls_sum-unchanged_count.
    rs_res-skipped_count   = ls_sum-skipped_count.
    rs_res-error_count     = ls_sum-error_count.

    IF ls_sum-messages IS NOT INITIAL.
      rs_res-message = concat_lines_of( table = ls_sum-messages sep = |; | ).
    ELSE.
      rs_res-message = |Commit OK: I={ ls_sum-inserted_count }, U={ ls_sum-updated_count }|.
    ENDIF.
  ENDMETHOD.


  METHOD diff_from_internal.
    LOOP AT it_diff INTO DATA(ls).
      APPEND VALUE #(
        id         = new_diff_id( )
        row_no     = ls-row_no
        table_name = ls-table_name
        record_key = ls-record_key
        field_name = ls-fieldname
        old_value  = ls-old_value
        new_value  = ls-new_value
        status     = ls-status
        message    = ls-message ) TO rt_cds.
    ENDLOOP.
  ENDMETHOD.


  METHOD diff_to_internal.
    LOOP AT it_cds INTO DATA(ls).
      " Bỏ dòng INFO tổng hợp (row_no = 0) nếu UI gửi lại
      IF ls-row_no = 0 AND ls-status = 'INFO'.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        row_no     = ls-row_no
        table_name = CONV tabname( ls-table_name )
        record_key = ls-record_key
        fieldname  = CONV fieldname( ls-field_name )
        old_value  = ls-old_value
        new_value  = ls-new_value
        status     = ls-status
        message    = ls-message ) TO rt_diff.
    ENDLOOP.
  ENDMETHOD.


  METHOD new_diff_id.
    rv_id = cl_system_uuid=>create_uuid_x16_static( ).
  ENDMETHOD.


  METHOD parse_diff_json.
    IF iv_json IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = iv_json
          CHANGING  data = rt_cds ).
      CATCH cx_root INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING
            previous = lx
            iv_text  = |Invalid diff_json: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

