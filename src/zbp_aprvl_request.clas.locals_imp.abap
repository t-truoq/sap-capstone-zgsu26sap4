
CLASS lhc_aprvlrequest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR aprvlrequest RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION aprvlrequest~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION aprvlrequest~reject RESULT result.
ENDCLASS.

CLASS lhc_aprvlrequest IMPLEMENTATION.

  METHOD get_instance_authorizations.
    READ ENTITIES OF zi_aprvl_request IN LOCAL MODE
      ENTITY aprvlrequest
        FIELDS ( status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_data).

    LOOP AT lt_data INTO DATA(ls).
      APPEND VALUE #(
        %tky            = ls-%tky
        %action-approve = zcl_auth_helper=>get_auth_by_status( ls-status )
        %action-reject  = zcl_auth_helper=>get_auth_by_status( ls-status )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD approve.
    READ ENTITIES OF zi_aprvl_request IN LOCAL MODE
      ENTITY aprvlrequest
        FIELDS ( aprvlid tablename actiontype newdata olddata recordkey status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests INTO DATA(ls_req).

      IF ls_req-status <> 'PENDING'.
        APPEND VALUE #(
          %tky   = ls_req-%tky
          %param = VALUE #(
            success = abap_false
            message = |Request { ls_req-aprvlid } is not in PENDING status|
          )
        ) TO result.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(lo_desc) = CAST cl_abap_structdescr(
            cl_abap_typedescr=>describe_by_name( ls_req-tablename )
          ).

          DATA lo_record TYPE REF TO data.
          CREATE DATA lo_record TYPE HANDLE lo_desc.

          CASE ls_req-actiontype.

            WHEN 'C'.
              zcl_json_helper=>deserialize(
                EXPORTING iv_json   = ls_req-newdata
                CHANGING  ca_record = lo_record
              ).
              ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_rec_c>).
              zcl_record_autofill=>on_create(
                iv_table_name = ls_req-tablename
                ir_record     = lo_record
              ).
              INSERT (ls_req-tablename) FROM <ls_rec_c>.

            WHEN 'U'.
              zcl_json_helper=>deserialize(
                EXPORTING iv_json   = ls_req-newdata
                CHANGING  ca_record = lo_record
              ).
              ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_rec_u>).
              ASSIGN COMPONENT 'CLIENT' OF STRUCTURE <ls_rec_u>
                TO FIELD-SYMBOL(<lv_cli_u>).
              IF sy-subrc = 0. <lv_cli_u> = sy-mandt. ENDIF.
              UPDATE (ls_req-tablename) FROM <ls_rec_u>.

            WHEN 'D'.
              DATA(lv_fk_error) = zcl_dynamic_table_reader=>check_foreign_key(
                iv_table_name = ls_req-tablename
                iv_record_key = CONV string( ls_req-recordkey )
              ).
              IF lv_fk_error IS NOT INITIAL.
                APPEND VALUE #(
                  %tky   = ls_req-%tky
                  %param = VALUE #(
                    success = abap_false
                    message = lv_fk_error
                  )
                ) TO result.
                CONTINUE.
              ENDIF.

              zcl_json_helper=>deserialize(
                EXPORTING iv_json   = CONV string( ls_req-recordkey )
                CHANGING  ca_record = lo_record
              ).
              ASSIGN lo_record->* TO FIELD-SYMBOL(<ls_rec_d>).
              ASSIGN COMPONENT 'CLIENT' OF STRUCTURE <ls_rec_d>
                TO FIELD-SYMBOL(<lv_cli_d>).
              IF sy-subrc = 0. <lv_cli_d> = sy-mandt. ENDIF.
              DELETE (ls_req-tablename) FROM <ls_rec_d>.

          ENDCASE.

          IF sy-subrc = 0.
            zcl_aprvl_util=>update_status(
              iv_aprvl_id = ls_req-aprvlid
              iv_status   = 'APPROVED'
            ).

            zcl_audit_logger=>log_change(
              iv_table_name  = ls_req-tablename
              iv_record_key  = ls_req-recordkey
              iv_action_type = ls_req-actiontype
              iv_old_value   = ls_req-olddata
              iv_new_value   = ls_req-newdata
            ).

            APPEND VALUE #(
              %tky   = ls_req-%tky
              %param = VALUE #(
                success = abap_true
                message = 'Approved and applied successfully'
              )
            ) TO result.

          ELSE.
            APPEND VALUE #(
              %tky   = ls_req-%tky
              %param = VALUE #(
                success = abap_false
                message = |DB operation failed (sy-subrc = { sy-subrc })|
              )
            ) TO result.
          ENDIF.

        CATCH cx_root INTO DATA(lx_error).
          APPEND VALUE #(
            %tky   = ls_req-%tky
            %param = VALUE #(
              success = abap_false
              message = lx_error->get_text( )
            )
          ) TO result.
      ENDTRY.

    ENDLOOP.
  ENDMETHOD.

  METHOD reject.
    READ ENTITIES OF zi_aprvl_request IN LOCAL MODE
      ENTITY aprvlrequest
        FIELDS ( aprvlid status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests INTO DATA(ls_req).

      IF ls_req-status <> 'PENDING'.
        APPEND VALUE #(
          %tky   = ls_req-%tky
          %param = VALUE #(
            success = abap_false
            message = |Request { ls_req-aprvlid } is not in PENDING status|
          )
        ) TO result.
        CONTINUE.
      ENDIF.

      READ TABLE keys INTO DATA(ls_key)
        WITH KEY primary_key COMPONENTS %tky = ls_req-%tky.

      DATA(lv_remarks) = COND string(
        WHEN ls_key-%param-remarks IS NOT INITIAL
        THEN ls_key-%param-remarks
        ELSE 'Rejected by admin'
      ).

      zcl_aprvl_util=>update_status(
        iv_aprvl_id = ls_req-aprvlid
        iv_status   = 'REJECTED'
        iv_remarks  = lv_remarks
      ).

      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky   = ls_req-%tky
          %param = VALUE #(
            success = abap_true
            message = |Request rejected: { lv_remarks }|
          )
        ) TO result.
      ELSE.
        APPEND VALUE #(
          %tky   = ls_req-%tky
          %param = VALUE #(
            success = abap_false
            message = |Update status failed (sy-subrc = { sy-subrc })|
          )
        ) TO result.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
