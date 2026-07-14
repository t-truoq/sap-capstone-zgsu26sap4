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

      IF ls_req-recordkey = 'BULK'.
        DATA(ls_bulk_result) = zcl_excel_bulk_aprvl=>approve_bulk( ls_req-aprvlid ).

        APPEND VALUE #(
          %tky   = ls_req-%tky
          %param = VALUE #(
            success = ls_bulk_result-success
            message = ls_bulk_result-message
          )
        ) TO result.

        CONTINUE.
      ENDIF.

      TRY.
          DATA ls_apply_result TYPE zcl_dyn_record_handler=>ty_result.

          CASE ls_req-actiontype.
            WHEN 'C'.
              ls_apply_result = zcl_dyn_record_handler=>create_record(
                iv_table_name  = ls_req-tablename
                iv_record_data = ls_req-newdata
              ).

            WHEN 'U'.
              ls_apply_result = zcl_dyn_record_handler=>update_record(
                iv_table_name  = ls_req-tablename
                iv_record_data = ls_req-newdata
              ).

            WHEN 'D'.
              ls_apply_result = zcl_dyn_record_handler=>delete_record(
                iv_table_name = ls_req-tablename
                iv_record_key = ls_req-recordkey
              ).

            WHEN OTHERS.
              ls_apply_result = VALUE #(
                success = abap_false
                message = |Unsupported action type { ls_req-actiontype }|
              ).
          ENDCASE.

          IF ls_apply_result-success = abap_true.
            zcl_aprvl_util=>update_status(
              iv_aprvl_id = ls_req-aprvlid
              iv_status   = 'APPROVED'
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
                message = ls_apply_result-message
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
        FIELDS ( aprvlid recordkey status )
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

      IF ls_req-recordkey = 'BULK'.
        DATA(ls_bulk_reject) = zcl_excel_bulk_aprvl=>reject_bulk(
          iv_aprvl_id = ls_req-aprvlid
          iv_remarks  = lv_remarks ).

        APPEND VALUE #(
          %tky   = ls_req-%tky
          %param = VALUE #(
            success = ls_bulk_reject-success
            message = ls_bulk_reject-message
          )
        ) TO result.

        CONTINUE.
      ENDIF.

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
