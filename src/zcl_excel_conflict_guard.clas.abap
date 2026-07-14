CLASS zcl_excel_conflict_guard DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_conflict,
        has_conflict TYPE abap_bool,
        source_type  TYPE c LENGTH 10,
        aprvl_id     TYPE sysuuid_c32,
        item_no      TYPE n LENGTH 6,
        submitted_by TYPE syuname,
        submitted_at TYPE ztbl_aprvl-submitted_at,
        message      TYPE string,
      END OF ty_conflict.

    CONSTANTS:
      c_source_crud       TYPE c LENGTH 10 VALUE 'CRUD',
      c_source_excel_bulk TYPE c LENGTH 10 VALUE 'EXCEL_BULK',
      c_snapshot_field    TYPE fieldname VALUE '__EXCEL_OLD_DATA'.

    CLASS-METHODS find_pending_conflict
      IMPORTING iv_table_name      TYPE ztde_table_name
                iv_record_key      TYPE ztde_record_key
                iv_exclude_aprvl_id TYPE sysuuid_c32 OPTIONAL
      RETURNING VALUE(rs_conflict) TYPE ty_conflict.

    CLASS-METHODS assert_no_pending_conflict
      IMPORTING iv_table_name      TYPE ztde_table_name
                iv_record_key      TYPE ztde_record_key
                iv_exclude_aprvl_id TYPE sysuuid_c32 OPTIONAL
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS mark_preview_conflicts
      IMPORTING iv_table_name TYPE tabname
      CHANGING  ct_diff       TYPE zcl_excel_types=>tt_diff_row.

    CLASS-METHODS assert_current_state
      IMPORTING iv_table_name  TYPE tabname
                iv_action_type TYPE ztde_action_type
                iv_record_key  TYPE ztde_record_key
                iv_old_data    TYPE string OPTIONAL
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS get_current_snapshot
      IMPORTING iv_table_name     TYPE tabname
                iv_record_key     TYPE ztde_record_key
      RETURNING VALUE(rv_snapshot) TYPE string
      RAISING   zcx_excel_pipeline.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_pending_hit,
        source_type  TYPE c LENGTH 10,
        aprvl_id     TYPE sysuuid_c32,
        item_no      TYPE n LENGTH 6,
        submitted_by TYPE syuname,
        submitted_at TYPE ztbl_aprvl-submitted_at,
      END OF ty_pending_hit.

    CLASS-METHODS is_mutating_status
      IMPORTING iv_status    TYPE c
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    CLASS-METHODS read_current_record
      IMPORTING iv_table_name TYPE tabname
                iv_record_key TYPE ztde_record_key
      RETURNING VALUE(rr_row) TYPE REF TO data
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS normalize_record_json
      IMPORTING iv_table_name TYPE tabname
                iv_json       TYPE string
      RETURNING VALUE(rv_json) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS serialize_record
      IMPORTING ir_record     TYPE REF TO data
      RETURNING VALUE(rv_json) TYPE string
      RAISING   zcx_excel_pipeline.

    CLASS-METHODS build_conflict_message
      IMPORTING is_hit            TYPE ty_pending_hit
                iv_table_name     TYPE ztde_table_name
                iv_record_key     TYPE ztde_record_key
      RETURNING VALUE(rv_message) TYPE string.

ENDCLASS.


CLASS zcl_excel_conflict_guard IMPLEMENTATION.

  METHOD find_pending_conflict.
    DATA lv_table_name TYPE ztde_table_name.
    DATA lv_record_key TYPE ztde_record_key.
    DATA ls_best TYPE ty_pending_hit.
    DATA ls_crud TYPE ty_pending_hit.
    DATA ls_excel TYPE ty_pending_hit.

    lv_table_name = iv_table_name.
    lv_record_key = iv_record_key.
    TRANSLATE lv_table_name TO UPPER CASE.

    SELECT aprvl_id, submitted_by, submitted_at
      FROM ztbl_aprvl
      WHERE table_name = @lv_table_name
        AND record_key = @lv_record_key
        AND status     = 'PENDING'
      ORDER BY submitted_at DESCENDING
      INTO @DATA(ls_crud_db)
      UP TO 1 ROWS.
      ls_crud = VALUE #(
        source_type  = c_source_crud
        aprvl_id     = ls_crud_db-aprvl_id
        submitted_by = ls_crud_db-submitted_by
        submitted_at = ls_crud_db-submitted_at ).
    ENDSELECT.

    SELECT item~aprvl_id, item~item_no, parent~submitted_by, parent~submitted_at
      FROM ztbl_aprvl_item AS item
      INNER JOIN ztbl_aprvl AS parent
        ON parent~aprvl_id = item~aprvl_id
      WHERE item~table_name = @lv_table_name
        AND item~record_key = @lv_record_key
        AND item~status     = 'PENDING'
        AND parent~status   = 'PENDING'
      ORDER BY parent~submitted_at DESCENDING, item~item_no DESCENDING
      INTO @DATA(ls_excel_db)
      UP TO 1 ROWS.
      ls_excel = VALUE #(
        source_type  = c_source_excel_bulk
        aprvl_id     = ls_excel_db-aprvl_id
        item_no      = ls_excel_db-item_no
        submitted_by = ls_excel_db-submitted_by
        submitted_at = ls_excel_db-submitted_at ).
    ENDSELECT.

    IF ls_crud-aprvl_id IS INITIAL.
      ls_best = ls_excel.
    ELSEIF ls_excel-aprvl_id IS INITIAL.
      ls_best = ls_crud.
    ELSEIF ls_excel-submitted_at >= ls_crud-submitted_at.
      ls_best = ls_excel.
    ELSE.
      ls_best = ls_crud.
    ENDIF.

    IF ls_best-aprvl_id IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_exclude_aprvl_id IS NOT INITIAL
       AND ls_best-aprvl_id = iv_exclude_aprvl_id.
      RETURN.
    ENDIF.

    rs_conflict = VALUE #(
      has_conflict = abap_true
      source_type  = ls_best-source_type
      aprvl_id     = ls_best-aprvl_id
      item_no      = ls_best-item_no
      submitted_by = ls_best-submitted_by
      submitted_at = ls_best-submitted_at
      message      = build_conflict_message(
                       is_hit        = ls_best
                       iv_table_name = lv_table_name
                       iv_record_key = lv_record_key ) ).
  ENDMETHOD.


  METHOD assert_no_pending_conflict.
    DATA(ls_conflict) = find_pending_conflict(
      iv_table_name       = iv_table_name
      iv_record_key       = iv_record_key
      iv_exclude_aprvl_id = iv_exclude_aprvl_id ).

    IF ls_conflict-has_conflict = abap_true.
      RAISE EXCEPTION TYPE zcx_excel_pipeline
        EXPORTING iv_text = ls_conflict-message.
    ENDIF.
  ENDMETHOD.


  METHOD mark_preview_conflicts.
    LOOP AT ct_diff ASSIGNING FIELD-SYMBOL(<ls_diff>).
      IF <ls_diff>-fieldname = c_snapshot_field.
        CONTINUE.
      ENDIF.

      IF is_mutating_status( <ls_diff>-status ) = abap_false
         OR <ls_diff>-record_key IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_conflict) = find_pending_conflict(
        iv_table_name = CONV ztde_table_name( iv_table_name )
        iv_record_key = CONV ztde_record_key( <ls_diff>-record_key ) ).

      IF ls_conflict-has_conflict = abap_true.
        <ls_diff>-status  = zcl_excel_types=>c_status-skipped.
        <ls_diff>-message = |Row skipped: pending approval already locks this record. { ls_conflict-message }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD assert_current_state.
    DATA(lv_action) = iv_action_type.
    TRANSLATE lv_action TO UPPER CASE.

    CASE lv_action.
      WHEN zcl_excel_types=>c_action-create.
        TRY.
            read_current_record(
              iv_table_name = iv_table_name
              iv_record_key = iv_record_key ).
            RAISE EXCEPTION TYPE zcx_excel_pipeline
              EXPORTING iv_text = |Record already exists in { iv_table_name }. Download latest data and preview again.|.
          CATCH zcx_excel_pipeline INTO DATA(lx_create).
            IF lx_create->get_text( ) CS 'Record already exists'.
              RAISE EXCEPTION TYPE zcx_excel_pipeline
                EXPORTING iv_text = lx_create->get_text( ).
            ENDIF.
        ENDTRY.

      WHEN zcl_excel_types=>c_action-update
        OR zcl_excel_types=>c_action-delete.
        IF iv_old_data IS INITIAL.
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text = |Cannot verify stale data for { iv_table_name } { iv_record_key }: old snapshot is empty.|.
        ENDIF.

        DATA(lr_current) = read_current_record(
          iv_table_name = iv_table_name
          iv_record_key = iv_record_key ).

        DATA(lv_current_json) = serialize_record( lr_current ).
        DATA(lv_old_json) = normalize_record_json(
          iv_table_name = iv_table_name
          iv_json       = iv_old_data ).

        IF lv_current_json <> lv_old_json.
          RAISE EXCEPTION TYPE zcx_excel_pipeline
            EXPORTING iv_text =
              |Record changed after Excel preview. Download latest data and preview again before applying { iv_record_key }.|.
        ENDIF.

      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Unsupported Excel action { iv_action_type } for stale-data check.|.
    ENDCASE.
  ENDMETHOD.


  METHOD is_mutating_status.
    rv_ok = COND #(
      WHEN iv_status = zcl_excel_types=>c_status-new
        OR iv_status = zcl_excel_types=>c_status-changed
        OR iv_status = zcl_excel_types=>c_status-delete
      THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD get_current_snapshot.
    DATA(lr_current) = read_current_record(
      iv_table_name = iv_table_name
      iv_record_key = iv_record_key ).

    rv_snapshot = serialize_record( lr_current ).
  ENDMETHOD.


  METHOD read_current_record.
    DATA(lt_fields) = zcl_table_inspector=>get_field_list( iv_table_name ).
    DATA(lv_where) = zcl_excel_record_builder=>build_where_from_record_key(
      iv_table_name = iv_table_name
      iv_record_key = CONV string( iv_record_key )
      it_fields     = lt_fields ).

    rr_row = zcl_excel_record_builder=>read_db_row(
      iv_table_name = iv_table_name
      iv_where      = lv_where ).
  ENDMETHOD.


  METHOD normalize_record_json.
    IF iv_json IS INITIAL.
      RETURN.
    ENDIF.

    DATA lr_record TYPE REF TO data.
    CREATE DATA lr_record TYPE (iv_table_name).

    TRY.
        zcl_json_helper=>deserialize(
          EXPORTING iv_json   = iv_json
          CHANGING  ca_record = lr_record ).
      CATCH cx_root INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Cannot read old Excel snapshot for stale check: { lx->get_text( ) }|.
    ENDTRY.

    rv_json = serialize_record( lr_record ).
  ENDMETHOD.


  METHOD serialize_record.
    IF ir_record IS NOT BOUND.
      RETURN.
    ENDIF.

    ASSIGN ir_record->* TO FIELD-SYMBOL(<ls_record>).
    IF <ls_record> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    TRY.
        rv_json = zcl_json_helper=>serialize( <ls_record> ).
      CATCH cx_root INTO DATA(lx).
        RAISE EXCEPTION TYPE zcx_excel_pipeline
          EXPORTING iv_text = |Cannot serialize record for stale check: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD build_conflict_message.
    rv_message =
      |Record is pending approval by { is_hit-submitted_by } and cannot be modified.| &&
      | Table={ iv_table_name }, Key={ iv_record_key }, Source={ is_hit-source_type }, Approval={ is_hit-aprvl_id }|.
  ENDMETHOD.

ENDCLASS.

