CLASS lhc_auditlog DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR auditlog RESULT result.

    METHODS rollback FOR MODIFY
      IMPORTING keys FOR ACTION auditlog~rollback RESULT result.
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

    READ ENTITIES OF zi_tbl_audit IN LOCAL MODE
      ENTITY auditlog
        FIELDS ( auditid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_audit).

    LOOP AT lt_audit INTO DATA(ls_audit).
      APPEND VALUE #(
        %tky             = ls_audit-%tky
        %action-rollback = lv_auth
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD rollback.
    READ ENTITIES OF zi_tbl_audit IN LOCAL MODE
      ENTITY auditlog
        FIELDS ( auditid tablename recordkey fieldname oldvalue newvalue actiontype )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_audit).

    LOOP AT lt_audit INTO DATA(ls_audit).
      TRY.
          zcl_auth_helper=>check_admin_action(
            iv_action = zcl_auth_helper=>c_admin_action-rollback ).

          DATA ls_result TYPE zcl_dyn_record_handler=>ty_result.
          DATA(lv_old_value) = CONV string( ls_audit-oldvalue ).
          DATA(lv_action) = CONV string( ls_audit-actiontype ).
          CONDENSE lv_action.
          TRANSLATE lv_action TO UPPER CASE.

          CASE lv_action.
            WHEN 'C' OR 'CREATE'.
              IF ls_audit-fieldname IS NOT INITIAL.
                ls_result = VALUE #(
                  success = abap_false
                  message = 'Rollback is only supported for full-record create audit entries.' ).
              ELSE.
                ls_result = zcl_dyn_record_handler=>delete_record(
                  iv_table_name = CONV tabname( ls_audit-tablename )
                  iv_record_key = ls_audit-recordkey ).
              ENDIF.

            WHEN 'U' OR 'UPDATE'.
              IF lv_old_value IS INITIAL.
                ls_result = VALUE #(
                  success = abap_false
                  message = 'Rollback update failed: old record snapshot is empty.' ).
              ELSE.
                ls_result = zcl_dyn_record_handler=>update_record(
                  iv_table_name  = CONV tabname( ls_audit-tablename )
                  iv_record_data = lv_old_value ).
              ENDIF.

            WHEN 'D' OR 'DELETE'.
              IF lv_old_value IS INITIAL.
                ls_result = VALUE #(
                  success = abap_false
                  message = 'Rollback delete failed: old record snapshot is empty.' ).
              ELSE.
                ls_result = zcl_dyn_record_handler=>create_record(
                  iv_table_name  = CONV tabname( ls_audit-tablename )
                  iv_record_data = lv_old_value ).
              ENDIF.

            WHEN OTHERS.
              ls_result = VALUE #(
                success = abap_false
                message = |Unsupported audit action { ls_audit-actiontype } for rollback| ).
          ENDCASE.

          IF ls_result-success = abap_true.
            zcl_aprvl_util=>log_change(
              iv_table_name  = ls_audit-tablename
              iv_record_key  = ls_audit-recordkey
              iv_field_name  = CONV ztde_field_name( ls_audit-fieldname )
              iv_old_value   = CONV string( ls_audit-newvalue )
              iv_new_value   = lv_old_value
              iv_action_type = 'R' ).
          ENDIF.

          APPEND VALUE #(
            %tky = ls_audit-%tky
            %param = VALUE #(
              table_name = ls_audit-tablename
              success    = ls_result-success
              message    = ls_result-message )
          ) TO result.

        CATCH zcx_excel_pipeline INTO DATA(lx_auth).
          APPEND VALUE #(
            %tky = ls_audit-%tky
            %param = VALUE #(
              table_name = ls_audit-tablename
              success    = abap_false
              message    = lx_auth->get_text( ) )
          ) TO result.

        CATCH cx_root INTO DATA(lx_any).
          APPEND VALUE #(
            %tky = ls_audit-%tky
            %param = VALUE #(
              table_name = ls_audit-tablename
              success    = abap_false
              message    = lx_any->get_text( ) )
          ) TO result.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
