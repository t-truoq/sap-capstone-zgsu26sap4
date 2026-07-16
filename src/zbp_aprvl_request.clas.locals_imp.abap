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

    LOOP AT lt_data INTO DATA(ls_data).
      APPEND VALUE #(
        %tky            = ls_data-%tky
        %action-approve = zcl_auth_helper=>get_auth_by_status( ls_data-status )
        %action-reject  = zcl_auth_helper=>get_auth_by_status( ls_data-status )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD approve.
    READ ENTITIES OF zi_aprvl_request IN LOCAL MODE
      ENTITY aprvlrequest
        FIELDS ( aprvlid tablename actiontype newdata olddata recordkey status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests INTO DATA(ls_request).
      IF ls_request-status <> 'PENDING'.
        APPEND VALUE #(
          %tky = ls_request-%tky
          %param = VALUE #(
            success = abap_false
            message = |Request { ls_request-aprvlid } is not in PENDING status| )
        ) TO result.
        CONTINUE.
      ENDIF.

      IF ls_request-recordkey = 'BULK'.
        DATA(ls_bulk_result) = zcl_excel_bulk_aprvl=>approve_bulk(
          iv_aprvl_id = ls_request-aprvlid ).

        APPEND VALUE #(
          %tky = ls_request-%tky
          %param = VALUE #(
            success = ls_bulk_result-success
            message = ls_bulk_result-message )
        ) TO result.
        CONTINUE.
      ENDIF.

      DATA ls_apply_result TYPE zcl_dyn_record_handler=>ty_result.

      CASE ls_request-actiontype.
        WHEN zcl_excel_types=>c_action-create.
          ls_apply_result = zcl_dyn_record_handler=>create_record(
            iv_table_name = CONV tabname( ls_request-tablename )
            iv_record_data = ls_request-newdata ).

        WHEN zcl_excel_types=>c_action-update.
          ls_apply_result = zcl_dyn_record_handler=>update_record(
            iv_table_name = CONV tabname( ls_request-tablename )
            iv_record_data = ls_request-newdata ).

        WHEN zcl_excel_types=>c_action-delete.
          ls_apply_result = zcl_dyn_record_handler=>delete_record(
            iv_table_name = CONV tabname( ls_request-tablename )
            iv_record_key = ls_request-recordkey ).

        WHEN OTHERS.
          ls_apply_result = VALUE #(
            success = abap_false
            message = |Unsupported approval action { ls_request-actiontype }| ).
      ENDCASE.

      IF ls_apply_result-success = abap_true.
        zcl_aprvl_util=>update_status(
          iv_aprvl_id = ls_request-aprvlid
          iv_status = 'APPROVED' ).

        UPDATE ztbl_aprvl_item
          SET status = 'APPROVED',
              message = @ls_apply_result-message
          WHERE aprvl_id = @ls_request-aprvlid
            AND status = 'PENDING'.
      ENDIF.

      APPEND VALUE #(
        %tky = ls_request-%tky
        %param = VALUE #(
          success = ls_apply_result-success
          message = ls_apply_result-message )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD reject.
    READ ENTITIES OF zi_aprvl_request IN LOCAL MODE
      ENTITY aprvlrequest
        FIELDS ( aprvlid recordkey status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests INTO DATA(ls_request).
      IF ls_request-status <> 'PENDING'.
        APPEND VALUE #(
          %tky = ls_request-%tky
          %param = VALUE #(
            success = abap_false
            message = |Request { ls_request-aprvlid } is not in PENDING status| )
        ) TO result.
        CONTINUE.
      ENDIF.

      READ TABLE keys INTO DATA(ls_key)
        WITH KEY primary_key COMPONENTS %tky = ls_request-%tky.

      DATA(lv_remarks) = COND string(
        WHEN sy-subrc = 0 AND ls_key-%param-remarks IS NOT INITIAL
        THEN ls_key-%param-remarks
        ELSE 'Rejected by admin' ).

      IF ls_request-recordkey = 'BULK'.
        DATA(ls_bulk_result) = zcl_excel_bulk_aprvl=>reject_bulk(
          iv_aprvl_id = ls_request-aprvlid
          iv_remarks = lv_remarks ).

        APPEND VALUE #(
          %tky = ls_request-%tky
          %param = VALUE #(
            success = ls_bulk_result-success
            message = ls_bulk_result-message )
        ) TO result.
        CONTINUE.
      ENDIF.

      zcl_aprvl_util=>update_status(
        iv_aprvl_id = ls_request-aprvlid
        iv_status = 'REJECTED'
        iv_remarks = lv_remarks ).

      UPDATE ztbl_aprvl_item
        SET status = 'REJECTED',
            message = @lv_remarks
        WHERE aprvl_id = @ls_request-aprvlid
          AND status = 'PENDING'.

      APPEND VALUE #(
        %tky = ls_request-%tky
        %param = VALUE #(
          success = abap_true
          message = |Request rejected: { lv_remarks }| )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
