REPORT ztest_ai_field_describer_v2.

PARAMETERS: p_table TYPE tabname OBLIGATORY DEFAULT 'ZTPC_HEADER'.

TYPES: BEGIN OF ty_alv_row,
         fieldname    TYPE dd03l-fieldname,
         rollname     TYPE dd03l-rollname,
         keyflag      TYPE dd03l-keyflag,
         description  TYPE string,
         constraints  TYPE string,
       END OF ty_alv_row.

DATA: gt_data    TYPE TABLE OF ty_alv_row,
      go_grid    TYPE REF TO cl_gui_alv_grid,
      go_custom  TYPE REF TO cl_gui_custom_container,
      gt_fcat    TYPE lvc_t_fcat.

*----------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS on_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD on_double_click.
    DATA ls_row TYPE ty_alv_row.
    READ TABLE gt_data INTO ls_row INDEX e_row-index.
    IF sy-subrc = 0.
      DATA(lv_msg) =
        |Field: { ls_row-fieldname }\n\n| &&
        |Mô tả: { ls_row-description }\n\n| &&
        |Ràng buộc: { ls_row-constraints }|.
      MESSAGE lv_msg TYPE 'I'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

DATA go_event_handler TYPE REF TO lcl_event_handler.

*----------------------------------------------------------------*
START-OF-SELECTION.

  " B1: Lấy field list gốc từ DD03L
  SELECT fieldname, rollname, keyflag
    FROM dd03l
    WHERE tabname   = @p_table
      AND as4local  = 'A'
      AND fieldname NOT LIKE '.%'
      AND fieldname <> 'MANDT'
      AND fieldname <> 'CLIENT'
    ORDER BY position
    INTO TABLE @DATA(lt_fields).

  IF lt_fields IS INITIAL.
    MESSAGE |Table { p_table } không tồn tại hoặc không có field.| TYPE 'I'.
    RETURN.
  ENDIF.

  " B2: Gọi RAP action getAiDescription để lấy mô tả AI
  SELECT SINGLE config_uuid
    FROM ztbl_config
    INTO @DATA(lv_config_uuid).

  IF sy-subrc <> 0.
    MESSAGE 'Không tìm thấy record TblConfig nào để gọi action.' TYPE 'I'.
    RETURN.
  ENDIF.

  MODIFY ENTITIES OF zi_tbl_config
    ENTITY tblconfig
      EXECUTE getaidescription
      FROM VALUE #( (
        %tky   = VALUE #( configuuid = lv_config_uuid )
        %param = VALUE #( table_name = p_table )
      ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

  COMMIT ENTITIES.

  IF lt_result IS INITIAL OR lt_result[ 1 ]-%param-result_json IS INITIAL.
    MESSAGE |Không nhận được mô tả AI: { COND #( WHEN lt_result IS NOT INITIAL THEN lt_result[ 1 ]-%param-error_msg ELSE 'unknown error' ) }| TYPE 'I'.
    RETURN.
  ENDIF.

  " B3: Parse JSON trả về thành internal table
  TYPES: BEGIN OF ty_ai_desc,
           field_name  TYPE string,
           description TYPE string,
           constraints TYPE string,
         END OF ty_ai_desc.
  DATA lt_ai TYPE TABLE OF ty_ai_desc.

  /ui2/cl_json=>deserialize(
    EXPORTING json = lt_result[ 1 ]-%param-result_json
    CHANGING  data = lt_ai
  ).

  " B4: Merge field list (DD03L) + AI description -> gt_data
  LOOP AT lt_fields INTO DATA(ls_field).
    DATA(ls_row) = VALUE ty_alv_row(
      fieldname = ls_field-fieldname
      rollname  = ls_field-rollname
      keyflag   = ls_field-keyflag
    ).

    READ TABLE lt_ai INTO DATA(ls_ai)
      WITH KEY field_name = CONV string( ls_field-fieldname ).
    IF sy-subrc = 0.
      ls_row-description = ls_ai-description.
      ls_row-constraints = ls_ai-constraints.
    ENDIF.

    APPEND ls_row TO gt_data.
  ENDLOOP.

  IF gt_data IS INITIAL.
    MESSAGE 'Không có dữ liệu để hiển thị.' TYPE 'I'.
    RETURN.
  ENDIF.

  CALL SCREEN 100.

*&---------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_100'.
  SET TITLEBAR 'TITLE_100'.

  IF go_custom IS NOT BOUND.
    go_custom = NEW cl_gui_custom_container( container_name = 'ALV_CONTAINER' ).
    go_grid   = NEW cl_gui_alv_grid( i_parent = go_custom ).

    DATA(ls_fcat) = VALUE lvc_s_fcat( ).

    ls_fcat-fieldname = 'FIELDNAME'.
    ls_fcat-coltext   = 'Field Name'.
    APPEND ls_fcat TO gt_fcat. CLEAR ls_fcat.

    ls_fcat-fieldname = 'ROLLNAME'.
    ls_fcat-coltext   = 'Data Element'.
    APPEND ls_fcat TO gt_fcat. CLEAR ls_fcat.

    ls_fcat-fieldname = 'KEYFLAG'.
    ls_fcat-coltext   = 'Key'.
    ls_fcat-outputlen = 5.
    APPEND ls_fcat TO gt_fcat. CLEAR ls_fcat.

    ls_fcat-fieldname = 'DESCRIPTION'.
    ls_fcat-coltext   = 'Mô tả (AI)'.
    ls_fcat-outputlen = 60.
    APPEND ls_fcat TO gt_fcat. CLEAR ls_fcat.

    ls_fcat-fieldname = 'CONSTRAINTS'.
    ls_fcat-coltext   = 'Ràng buộc (AI)'.
    ls_fcat-outputlen = 60.
    APPEND ls_fcat TO gt_fcat.

    go_grid->set_table_for_first_display(
      CHANGING
        it_outtab       = gt_data
        it_fieldcatalog = gt_fcat
    ).

    go_event_handler = NEW lcl_event_handler( ).
    SET HANDLER go_event_handler->on_double_click FOR go_grid.
  ENDIF.
ENDMODULE.

MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE PROGRAM.
    WHEN 'EXPORT_PDF'.
      PERFORM export_to_pdf.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------*
FORM export_to_pdf.

  DATA: lt_pdf_tab  TYPE TABLE OF tline,
        lv_spoolid  TYPE rspoid,
        lv_jobname  TYPE tbtcjob-jobname VALUE 'AI_FIELD_PDF',
        lv_jobcount TYPE tbtcjob-jobcount,
        lv_filename TYPE string,
        lv_filesize TYPE i.

  CALL FUNCTION 'JOB_OPEN'
    EXPORTING
      jobname          = lv_jobname
    IMPORTING
      jobcount         = lv_jobcount
    EXCEPTIONS
      cant_create_job  = 1
      invalid_job_data = 2
      jobname_missing  = 3
      OTHERS           = 4.

  IF sy-subrc <> 0.
    MESSAGE 'Không tạo được job in.' TYPE 'I'.
    RETURN.
  ENDIF.

  NEW-PAGE PRINT ON NO DIALOG
    DESTINATION 'LOCL'
    LIST NAME 'AI_DICTIONARY'
    IMMEDIATELY ' '
    KEEP IN SPOOL 'X'
    LINE-SIZE 200.

  WRITE: / |DATA DICTIONARY - Table: { p_table }| COLOR COL_HEADING.
  ULINE.
  WRITE: / 'Field', 25 'Data Element', 55 'Key'.
  ULINE.

  LOOP AT gt_data INTO DATA(ls_row).
    WRITE: / ls_row-fieldname, 25 ls_row-rollname, 55 ls_row-keyflag.
    WRITE: / '  Mô tả:', ls_row-description.
    WRITE: / '  Ràng buộc:', ls_row-constraints.
    ULINE.
  ENDLOOP.

  NEW-PAGE PRINT OFF.

  CALL FUNCTION 'JOB_CLOSE'
    EXPORTING
      jobcount              = lv_jobcount
      jobname                = lv_jobname
      strtimmed              = 'X'
    IMPORTING
      out_spoolid             = lv_spoolid
    EXCEPTIONS
      cant_start_immediate  = 1
      invalid_startdate     = 2
      jobname_missing       = 3
      job_close_failed      = 4
      job_nosteps           = 5
      job_notex              = 6
      lock_failed            = 7
      OTHERS                 = 8.

  IF sy-subrc <> 0 OR lv_spoolid IS INITIAL.
    MESSAGE 'Không lấy được spool ID.' TYPE 'I'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'CONVERT_ABAPSPOOLJOB_2_PDF'
    EXPORTING
      src_spoolid           = lv_spoolid
      no_dialog              = 'X'
      pdf_destination         = 'X'
    IMPORTING
      bin_filesize            = lv_filesize
    TABLES
      pdf                     = lt_pdf_tab
    EXCEPTIONS
      err_no_abap_spooljob   = 1
      err_no_spooljob        = 2
      err_no_permission      = 3
      err_conv_not_possible  = 4
      err_bad_destdevice     = 5
      user_cancelled          = 6
      err_spoolerror          = 7
      err_temseerror           = 8
      err_btcjob_open_failed   = 9
      err_btcjob_submit_failed = 10
      err_btcjob_close_failed  = 11
      OTHERS                   = 12.

  IF sy-subrc <> 0.
    MESSAGE 'Convert PDF thất bại.' TYPE 'I'.
    RETURN.
  ENDIF.

  lv_filename = |Data_Dictionary_{ p_table }.pdf|.

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize = lv_filesize
      filename     = lv_filename
      filetype     = 'BIN'
    CHANGING
      data_tab     = lt_pdf_tab
    EXCEPTIONS
      OTHERS       = 1
  ).

  IF sy-subrc = 0.
    MESSAGE |Đã xuất file { lv_filename } thành công.| TYPE 'S'.
  ELSE.
    MESSAGE 'Xuất file PDF thất bại.' TYPE 'I'.
  ENDIF.

ENDFORM.
