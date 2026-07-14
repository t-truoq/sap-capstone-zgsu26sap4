CLASS zcl_excel_conflict_diff_build DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS build_diff
      IMPORTING iv_table_name  TYPE tabname
                it_rows        TYPE zcl_excel_types=>tt_parsed_row
      RETURNING VALUE(rt_diff) TYPE zcl_excel_types=>tt_diff_row
      RAISING   zcx_excel_pipeline.

ENDCLASS.


CLASS zcl_excel_conflict_diff_build IMPLEMENTATION.

  METHOD build_diff.
    rt_diff = zcl_excel_diff_builder=>build_diff(
      iv_table_name = iv_table_name
      it_rows       = it_rows ).

    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT rt_diff INTO DATA(ls_diff)
      WHERE status = zcl_excel_types=>c_status-changed.

      IF ls_diff-record_key IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_seen_key) = |{ ls_diff-row_no }#{ ls_diff-record_key }|.
      READ TABLE lt_seen TRANSPORTING NO FIELDS WITH KEY table_line = lv_seen_key.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      INSERT lv_seen_key INTO TABLE lt_seen.

      TRY.
          DATA(lv_snapshot) = zcl_excel_conflict_guard=>get_current_snapshot(
            iv_table_name = iv_table_name
            iv_record_key = CONV ztde_record_key( ls_diff-record_key ) ).

          APPEND VALUE #(
            row_no     = ls_diff-row_no
            table_name = iv_table_name
            record_key = ls_diff-record_key
            fieldname  = zcl_excel_conflict_guard=>c_snapshot_field
            old_value  = lv_snapshot
            status     = zcl_excel_types=>c_status-changed
            message    = 'Phase09 old snapshot for stale-data check.' ) TO rt_diff.

        CATCH zcx_excel_pipeline INTO DATA(lx).
          APPEND VALUE #(
            row_no     = ls_diff-row_no
            table_name = iv_table_name
            record_key = ls_diff-record_key
            status     = zcl_excel_types=>c_status-error
            message    = |Cannot capture old snapshot for stale-data check: { lx->get_text( ) }| ) TO rt_diff.
      ENDTRY.
    ENDLOOP.

    zcl_excel_conflict_guard=>mark_preview_conflicts(
      EXPORTING iv_table_name = iv_table_name
      CHANGING  ct_diff       = rt_diff ).
  ENDMETHOD.

ENDCLASS.

