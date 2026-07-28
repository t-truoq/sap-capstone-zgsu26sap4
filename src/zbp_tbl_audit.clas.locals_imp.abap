CLASS lhc_auditlog DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_rollback_blocker,
        audit_id    TYPE sysuuid_c32,
        changed_at  TYPE ztbl_audit-changed_at,
        action_type TYPE ztde_action_type,
      END OF ty_rollback_blocker.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR auditlog RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR auditlog RESULT result.

    METHODS rollback FOR MODIFY
      IMPORTING keys FOR ACTION auditlog~rollback RESULT result.

    METHODS apply_rollback
      IMPORTING iv_table_name  TYPE tabname
                iv_record_key  TYPE ztde_record_key
                iv_old_value   TYPE string
                iv_action_type TYPE ztde_action_type
                iv_parent_audit_id TYPE sysuuid_c32
      RETURNING VALUE(rs_result) TYPE zcl_dyn_record_handler=>ty_result.

    METHODS validate_rollback_item
      IMPORTING iv_table_name  TYPE tabname
                iv_record_key  TYPE ztde_record_key
                iv_new_value   TYPE string
                iv_action_type TYPE ztde_action_type
      RETURNING VALUE(rv_error) TYPE string
      RAISING cx_root.

    METHODS find_newer_audit
      IMPORTING iv_table_name TYPE tabname
                iv_record_key TYPE ztde_record_key
                iv_changed_at TYPE ztbl_audit-changed_at
      RETURNING VALUE(rs_blocker) TYPE ty_rollback_blocker.

    METHODS strip_rollback_admin_fields
      IMPORTING iv_json        TYPE string
      RETURNING VALUE(rv_json) TYPE string.
ENDCLASS.

CLASS lhc_auditlog IMPLEMENTATION.
  METHOD get_instance_authorizations.
    DATA(lv_auth) = if_abap_behv=>auth-unauthorized.
    TRY.
        zcl_auth_helper=>check_admin_action(
          iv_action = zcl_auth_helper=>c_admin_action-rollback ).
        lv_auth = if_abap_behv=>auth-allowed.
      CATCH zcx_excel_pipeline.
    ENDTRY.

    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #(
        %tky             = ls_key-%tky
        %action-rollback = lv_auth
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    LOOP AT keys INTO DATA(ls_key).
      SELECT SINGLE action_type, rollback_audit_id
        FROM ztbl_audit
        WHERE audit_id = @ls_key-auditid
        INTO @DATA(ls_audit_state).

      DATA(lv_feature) = COND #(
        WHEN ls_audit_state-action_type = 'R'
          OR ls_audit_state-rollback_audit_id IS NOT INITIAL
        THEN if_abap_behv=>fc-o-disabled
        ELSE if_abap_behv=>fc-o-enabled ).

      APPEND VALUE #(
        %tky             = ls_key-%tky
        %action-rollback = lv_feature
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD rollback.
    READ ENTITIES OF zi_tbl_audit IN LOCAL MODE
      ENTITY auditlog
        FIELDS ( auditid tablename recordkey fieldname oldvalue newvalue changedat actiontype rollbackauditid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_audit).

    LOOP AT lt_audit INTO DATA(ls_audit).
      TRY.
          zcl_auth_helper=>check_admin_action(
            iv_action = zcl_auth_helper=>c_admin_action-rollback ).

          IF ls_audit-actiontype = 'R'.
            RAISE EXCEPTION TYPE zcx_excel_pipeline
              EXPORTING iv_text = 'Rollback audit cannot be rolled back again.'.
          ENDIF.

          IF ls_audit-rollbackauditid IS NOT INITIAL.
            RAISE EXCEPTION TYPE zcx_excel_pipeline
              EXPORTING iv_text = |Audit was already rolled back by { ls_audit-rollbackauditid }.|.
          ENDIF.

          SELECT * FROM ztbl_audit_item
            WHERE audit_id = @ls_audit-auditid
            ORDER BY item_no DESCENDING
            INTO TABLE @DATA(lt_items).

          "Preflight the complete operation before changing any data. This
          "prevents a partial rollback when one item has newer changes.
          DATA lv_blocked_table TYPE tabname.
          DATA lv_blocked_key TYPE ztde_record_key.
          IF lt_items IS INITIAL.
            lv_blocked_table = CONV tabname( ls_audit-tablename ).
            lv_blocked_key = ls_audit-recordkey.
            DATA(lv_preflight_error) = validate_rollback_item(
              iv_table_name   = lv_blocked_table
              iv_record_key   = lv_blocked_key
              iv_new_value    = CONV string( ls_audit-newvalue )
              iv_action_type  = CONV ztde_action_type( ls_audit-actiontype ) ).
          ELSE.
            LOOP AT lt_items INTO DATA(ls_preflight_item).
              lv_blocked_table = CONV tabname( ls_preflight_item-table_name ).
              lv_blocked_key = ls_preflight_item-record_key.
              lv_preflight_error = validate_rollback_item(
                iv_table_name   = lv_blocked_table
                iv_record_key   = lv_blocked_key
                iv_new_value    = CONV string( ls_preflight_item-new_value )
                iv_action_type  = ls_preflight_item-action_type ).
              IF lv_preflight_error IS NOT INITIAL.
                EXIT.
              ENDIF.
            ENDLOOP.
          ENDIF.

          IF lv_preflight_error IS NOT INITIAL.
            IF lv_preflight_error CS 'newer changes'.
              DATA(ls_blocker) = find_newer_audit(
                iv_table_name = lv_blocked_table
                iv_record_key = lv_blocked_key
                iv_changed_at = ls_audit-changedat ).
              IF ls_blocker-audit_id IS NOT INITIAL.
                DATA(lv_blocker_time_utc_minus5) = utclong_add(
                  val   = ls_blocker-changed_at
                  hours = -5 ).
                lv_preflight_error =
                  |Rollback blocked for { lv_blocked_key }. |
                  && |Rollback newer audit { ls_blocker-audit_id } |
                  && |(action { ls_blocker-action_type }, changed at { lv_blocker_time_utc_minus5 } UTC-5) first, |
                  && |then retry audit { ls_audit-auditid }.|.
              ENDIF.
            ENDIF.
            RAISE EXCEPTION TYPE zcx_excel_pipeline
              EXPORTING iv_text = lv_preflight_error.
          ENDIF.

          DATA ls_result TYPE zcl_dyn_record_handler=>ty_result.
          DATA(lv_rollback_audit_id) = cl_system_uuid=>create_uuid_c32_static( ).
          INSERT ztbl_audit FROM @(
            VALUE ztbl_audit(
              audit_id    = lv_rollback_audit_id
              table_name  = ls_audit-tablename
              record_key  = ls_audit-recordkey
              field_name  = space
              old_value   = space
              new_value   = |Rollback of audit { ls_audit-auditid }|
              changed_by  = sy-uname
              changed_at  = utclong_current( )
              action_type = 'R' ) ).

          IF lt_items IS INITIAL.
            ls_result = apply_rollback(
              iv_table_name  = CONV tabname( ls_audit-tablename )
              iv_record_key  = ls_audit-recordkey
              iv_old_value   = CONV string( ls_audit-oldvalue )
              iv_action_type = CONV ztde_action_type( ls_audit-actiontype )
              iv_parent_audit_id = lv_rollback_audit_id ).
          ELSE.
            ls_result = VALUE #( success = abap_true message = |Rolled back { lines( lt_items ) } audit item(s)| ).

            LOOP AT lt_items INTO DATA(ls_item).
              DATA(ls_item_result) = apply_rollback(
                iv_table_name  = CONV tabname( ls_item-table_name )
                iv_record_key  = ls_item-record_key
                iv_old_value   = CONV string( ls_item-old_value )
                iv_action_type = ls_item-action_type
                iv_parent_audit_id = lv_rollback_audit_id ).

              IF ls_item_result-success <> abap_true.
                ls_result = ls_item_result.
                EXIT.
              ENDIF.

            ENDLOOP.
          ENDIF.

          APPEND VALUE #(
            %tky = ls_audit-%tky
            %param = VALUE #(
              table_name = ls_audit-tablename
              success    = ls_result-success
              message    = ls_result-message )
          ) TO result.

          IF ls_result-success = abap_true.
            UPDATE ztbl_audit
              SET rollback_audit_id = @lv_rollback_audit_id
              WHERE audit_id = @ls_audit-auditid.

            APPEND VALUE #(
              %tky = ls_audit-%tky
              %msg = new_message_with_text(
                severity = if_abap_behv_message=>severity-success
                text     = ls_result-message )
            ) TO reported-auditlog.
          ELSE.
            APPEND VALUE #(
              %tky = ls_audit-%tky
              %msg = new_message_with_text(
                severity = if_abap_behv_message=>severity-error
                text     = ls_result-message )
            ) TO reported-auditlog.
          ENDIF.

        CATCH zcx_excel_pipeline INTO DATA(lx_auth).
          APPEND VALUE #(
            %tky = ls_audit-%tky
            %param = VALUE #(
              table_name = ls_audit-tablename
              success    = abap_false
              message    = lx_auth->get_text( ) )
          ) TO result.
          APPEND VALUE #(
            %tky = ls_audit-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = lx_auth->get_text( ) )
          ) TO reported-auditlog.

        CATCH cx_root INTO DATA(lx_any).
          APPEND VALUE #(
            %tky = ls_audit-%tky
            %param = VALUE #(
              table_name = ls_audit-tablename
              success    = abap_false
              message    = lx_any->get_text( ) )
          ) TO result.
          APPEND VALUE #(
            %tky = ls_audit-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = lx_any->get_text( ) )
          ) TO reported-auditlog.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_newer_audit.
    SELECT audit_id, changed_at, action_type
      FROM ztbl_audit
      WHERE table_name = @iv_table_name
        AND record_key = @iv_record_key
        AND changed_at > @iv_changed_at
        AND action_type <> 'R'
        AND rollback_audit_id = @space
      ORDER BY changed_at DESCENDING
      INTO TABLE @DATA(lt_direct)
      UP TO 1 ROWS.

    SELECT FROM ztbl_audit AS audit
      INNER JOIN ztbl_audit_item AS item
        ON item~audit_id = audit~audit_id
      FIELDS audit~audit_id,
             audit~changed_at,
             audit~action_type
      WHERE item~table_name = @iv_table_name
        AND item~record_key = @iv_record_key
        AND audit~changed_at > @iv_changed_at
        AND audit~action_type <> 'R'
        AND audit~rollback_audit_id = @space
      ORDER BY audit~changed_at DESCENDING
      INTO TABLE @DATA(lt_bulk)
      UP TO 1 ROWS.

    IF lt_direct IS NOT INITIAL.
      rs_blocker = CORRESPONDING #( lt_direct[ 1 ] ).
    ENDIF.

    IF lt_bulk IS NOT INITIAL
       AND ( rs_blocker-audit_id IS INITIAL
          OR lt_bulk[ 1 ]-changed_at > rs_blocker-changed_at ).
      rs_blocker = CORRESPONDING #( lt_bulk[ 1 ] ).
    ENDIF.
  ENDMETHOD.

  METHOD validate_rollback_item.
    DATA(lv_action) = CONV string( iv_action_type ).
    CONDENSE lv_action.
    TRANSLATE lv_action TO UPPER CASE.

    IF lv_action = 'R' OR lv_action = 'ROLLBACK'.
      rv_error = 'Rollback audit cannot be rolled back again.'.
      RETURN.
    ENDIF.

    DATA(lo_desc) = zcl_dyn_record_handler=>get_struct_desc( iv_table_name ).
    DATA lr_key TYPE REF TO data.
    CREATE DATA lr_key TYPE HANDLE lo_desc.
    zcl_dyn_record_handler=>deserialize(
      EXPORTING iv_json = CONV string( iv_record_key )
      CHANGING  ca_record = lr_key ).

    DATA(lt_keys) = zcl_dyn_record_handler=>get_key_fields( iv_table_name ).
    DATA(lv_where) = zcl_dyn_record_handler=>build_where_clause(
      it_key_fields = lt_keys
      ir_record     = lr_key ).

    DATA lr_current TYPE REF TO data.
    CREATE DATA lr_current TYPE HANDLE lo_desc.
    ASSIGN lr_current->* TO FIELD-SYMBOL(<current>).
    SELECT SINGLE * FROM (iv_table_name)
      WHERE (lv_where)
      INTO @<current>.
    DATA(lv_exists) = xsdbool( sy-subrc = 0 ).

    IF lv_action = 'D' OR lv_action = 'DELETE'.
      IF lv_exists = abap_true.
        rv_error = |Rollback blocked for { iv_record_key }: record has newer changes.|.
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_action <> 'C' AND lv_action <> 'CREATE'
       AND lv_action <> 'U' AND lv_action <> 'UPDATE'.
      rv_error = |Unsupported audit action { iv_action_type } for rollback|.
      RETURN.
    ENDIF.

    IF lv_exists = abap_false.
      rv_error = |Rollback blocked for { iv_record_key }: record no longer exists.|.
      RETURN.
    ENDIF.

    IF iv_new_value IS INITIAL.
      rv_error = |Rollback blocked for { iv_record_key }: audit snapshot is incomplete.|.
      RETURN.
    ENDIF.

    DATA lr_expected TYPE REF TO data.
    CREATE DATA lr_expected TYPE HANDLE lo_desc.
    DATA(lv_new_value_safe) = strip_rollback_admin_fields( iv_new_value ).
    zcl_dyn_record_handler=>deserialize(
      EXPORTING iv_json = lv_new_value_safe
      CHANGING  ca_record = lr_expected ).
    ASSIGN lr_expected->* TO FIELD-SYMBOL(<expected>).

    "Compare business fields only. Legacy audit rows may have been logged
    "before technical fields were enriched by the dynamic handler.
    LOOP AT lo_desc->components INTO DATA(ls_component).
      DATA(lv_field) = ls_component-name.
      IF lv_field = 'CLIENT'
         OR lv_field = 'CREATED_BY' OR lv_field = 'CREATEDBY'
         OR lv_field = 'CREATED_AT' OR lv_field = 'CREATEDAT'
         OR lv_field = 'CHANGED_BY' OR lv_field = 'CHANGEDBY'
         OR lv_field = 'CHANGED_AT' OR lv_field = 'CHANGEDAT'
         OR lv_field = 'LAST_CHANGED_BY'
         OR lv_field = 'LAST_CHANGED_AT'
         OR lv_field = 'LOCAL_LAST_CHANGED_AT'.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT lv_field OF STRUCTURE <current>
        TO FIELD-SYMBOL(<current_value>).
      ASSIGN COMPONENT lv_field OF STRUCTURE <expected>
        TO FIELD-SYMBOL(<expected_value>).
      IF <current_value> IS ASSIGNED AND <expected_value> IS ASSIGNED
         AND |{ <current_value> }| <> |{ <expected_value> }|.
        rv_error = |Rollback blocked for { iv_record_key }: record has newer changes.|.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD apply_rollback.
    DATA(lv_action) = CONV string( iv_action_type ).
    CONDENSE lv_action.
    TRANSLATE lv_action TO UPPER CASE.

    CASE lv_action.
      WHEN 'C' OR 'CREATE'.
        rs_result = zcl_dyn_record_handler=>delete_record(
          iv_table_name = iv_table_name
          iv_record_key = iv_record_key
          iv_parent_audit_id = iv_parent_audit_id ).

      WHEN 'U' OR 'UPDATE'.
        IF iv_old_value IS INITIAL.
          rs_result = VALUE #(
            success = abap_false
            message = 'Rollback update failed: old record snapshot is empty.' ).
        ELSE.
          DATA(lv_old_update_safe) = strip_rollback_admin_fields( iv_old_value ).
          rs_result = zcl_dyn_record_handler=>update_record(
            iv_table_name  = iv_table_name
            iv_record_data = lv_old_update_safe
            iv_parent_audit_id = iv_parent_audit_id ).
        ENDIF.

      WHEN 'D' OR 'DELETE'.
        IF iv_old_value IS INITIAL.
          rs_result = VALUE #(
            success = abap_false
            message = 'Rollback delete failed: old record snapshot is empty.' ).
        ELSE.
          DATA(lv_old_create_safe) = strip_rollback_admin_fields( iv_old_value ).
          rs_result = zcl_dyn_record_handler=>create_record(
            iv_table_name  = iv_table_name
            iv_record_data = lv_old_create_safe
            iv_parent_audit_id = iv_parent_audit_id ).
        ENDIF.

      WHEN OTHERS.
        rs_result = VALUE #(
          success = abap_false
          message = |Unsupported audit action { iv_action_type } for rollback| ).
    ENDCASE.
  ENDMETHOD.

  METHOD strip_rollback_admin_fields.
    rv_json = iv_json.

    DATA lt_fields TYPE string_table.
    APPEND 'CREATED_AT' TO lt_fields.
    APPEND 'CHANGED_AT' TO lt_fields.
    APPEND 'LAST_CHANGED_AT' TO lt_fields.
    APPEND 'LOCAL_LAST_CHANGED_AT' TO lt_fields.

    LOOP AT lt_fields INTO DATA(lv_field).
      DATA(lv_pattern) = |,"{ lv_field }":"[^"]*"|.
      REPLACE ALL OCCURRENCES OF REGEX lv_pattern IN rv_json WITH ``.

      lv_pattern = |"{ lv_field }":"[^"]*",|.
      REPLACE ALL OCCURRENCES OF REGEX lv_pattern IN rv_json WITH ``.

      lv_pattern = |"{ lv_field }":"[^"]*"|.
      REPLACE ALL OCCURRENCES OF REGEX lv_pattern IN rv_json WITH ``.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
