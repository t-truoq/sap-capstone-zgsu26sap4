"! Unmanaged behavior — 3 Excel actions on singleton root ZI_EXCEL_PIPELINE.
"! ADT generate local class lhc_ExcelPipeline; dan logic vao do.
"! Action parameter truy cap qua keys-%param (khong co table parameters rieng).
CLASS lhc_ExcelPipeline DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations ##NEEDED
      FOR ExcelPipeline RESULT result ##NEEDED.

    METHODS read FOR READ
      IMPORTING keys FOR READ ExcelPipeline RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK ExcelPipeline ##NEEDED.

    METHODS downloadExcel FOR MODIFY
      IMPORTING keys FOR ACTION ExcelPipeline~downloadExcel RESULT result.

    METHODS uploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION ExcelPipeline~uploadExcel RESULT result.

    METHODS confirmImport FOR MODIFY
      IMPORTING keys FOR ACTION ExcelPipeline~confirmImport RESULT result.

ENDCLASS.

CLASS lhc_ExcelPipeline IMPLEMENTATION.

  METHOD get_global_authorizations ##NEEDED.
    " Dev: cho phep tat ca. Phan quyen that khai bao sau (auth-allowed per action).
  ENDMETHOD.

  METHOD read.
    SELECT FROM zexcel_stub
      FIELDS stub_id AS StubId
      FOR ALL ENTRIES IN @keys
      WHERE stub_id = @keys-StubId
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD lock ##NEEDED.
  ENDMETHOD.

  METHOD downloadExcel.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_param) = ls_key-%param.

      DATA(ls_res) = VALUE zcl_excel_odata_handler=>ty_download_res( ).

      TRY.
          DATA(lv_action) = COND char20(
            WHEN ls_param-template_only = abap_true
            THEN zcl_auth_helper=>c_action-upload
            ELSE zcl_auth_helper=>c_action-view ).

          zcl_auth_helper=>check_permission(
            iv_table_name = CONV #( ls_param-table_name )
            iv_action     = lv_action ).

          ls_res = zcl_excel_odata_handler=>download_excel( ls_param ).
        CATCH zcx_excel_pipeline INTO DATA(lx).
          ls_res-id      = ls_param-id.
          ls_res-message = lx->get_text( ).
      ENDTRY.

      APPEND VALUE #(
        %tky-stubid = ls_key-%tky-stubid
        %param      = ls_res ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD uploadExcel.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_param) = ls_key-%param.

      DATA(lt_diff) = VALUE zcl_excel_odata_handler=>tt_diff_cds( ).
      DATA(lv_info) = VALUE string( ).

      TRY.
          zcl_auth_helper=>check_permission(
            iv_table_name = CONV #( ls_param-table_name )
            iv_action     = zcl_auth_helper=>c_action-upload ).

          zcl_excel_odata_handler=>upload_excel(
            EXPORTING is_req  = ls_param
            IMPORTING et_diff = lt_diff
                      ev_info = lv_info ).
        CATCH zcx_excel_pipeline INTO DATA(lx).
          TRY.
              APPEND VALUE #(
                id      = cl_system_uuid=>create_uuid_x16_static( )
                row_no  = 0
                status  = 'ERROR'
                message = lx->get_text( ) ) TO lt_diff.
            CATCH cx_uuid_error.
              " UUID generation failed - skip row id, keep processing.
              APPEND VALUE #(
                row_no  = 0
                status  = 'ERROR'
                message = lx->get_text( ) ) TO lt_diff.
          ENDTRY.
      ENDTRY.

      IF lv_info IS NOT INITIAL.
        TRY.
            INSERT VALUE #(
              id      = cl_system_uuid=>create_uuid_x16_static( )
              row_no  = 0
              status  = 'INFO'
              message = lv_info ) INTO lt_diff INDEX 1.
          CATCH cx_uuid_error.
            INSERT VALUE #(
              row_no  = 0
              status  = 'INFO'
              message = lv_info ) INTO lt_diff INDEX 1.
        ENDTRY.
      ENDIF.

      LOOP AT lt_diff INTO DATA(ls_diff).
        APPEND VALUE #(
          %tky-stubid = ls_key-%tky-stubid
          %param      = ls_diff ) TO result.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD confirmImport.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_param) = ls_key-%param.

      DATA(ls_res)  = VALUE zcl_excel_odata_handler=>ty_commit_res( ).

      TRY.
          zcl_auth_helper=>check_permission(
            iv_table_name = CONV #( ls_param-table_name )
            iv_action     = zcl_auth_helper=>c_action-upload ).

          DATA(lt_diff) = zcl_excel_odata_handler=>parse_diff_json( ls_param-diff_json ).
          ls_res = zcl_excel_odata_handler=>run_confirm_import(
            is_req      = ls_param
            it_diff_cds = lt_diff ).
        CATCH zcx_excel_pipeline INTO DATA(lx).
          ls_res-id      = ls_param-id.
          ls_res-message = lx->get_text( ).
      ENDTRY.

      APPEND VALUE #(
        %tky-stubid = ls_key-%tky-stubid
        %param      = ls_res ) TO result.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZI_EXCEL_PIPELINE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_EXCEL_PIPELINE IMPLEMENTATION.
  METHOD finalize ##NEEDED.          ENDMETHOD.
  METHOD check_before_save ##NEEDED. ENDMETHOD.
  METHOD save ##NEEDED.              ENDMETHOD.
  METHOD cleanup ##NEEDED.           ENDMETHOD.
  METHOD cleanup_finalize ##NEEDED.  ENDMETHOD.
ENDCLASS.
