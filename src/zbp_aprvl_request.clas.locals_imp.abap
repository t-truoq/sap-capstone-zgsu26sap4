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
    IF zcl_auth_helper=>is_admin( ) <> abap_true.
      LOOP AT keys INTO DATA(ls_auth_key).
        APPEND VALUE #(
          %tky            = ls_auth_key-%tky
          %action-approve = if_abap_behv=>auth-unauthorized
          %action-reject  = if_abap_behv=>auth-unauthorized
        ) TO result.
      ENDLOOP.
      RETURN.
    ENDIF.

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
    IF zcl_auth_helper=>is_admin( ) <> abap_true.
      DATA(lv_msg_approve_admin) = |Action APPROVE chỉ dành cho ADMIN| ##NO_TEXT.
      LOOP AT keys INTO DATA(ls_approve_key).
        APPEND VALUE #(
          %tky = ls_approve_key-%tky
          %param = VALUE #(
            success = abap_false
            message = lv_msg_approve_admin )
        ) TO result.
      ENDLOOP.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_aprvl_request IN LOCAL MODE
      ENTITY aprvlrequest
        FIELDS ( aprvlid tablename actiontype newdata olddata recordkey status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests INTO DATA(ls_request).
      IF ls_request-status <> 'PENDING'.
        DATA(lv_msg_not_pending_a) = |Request { ls_request-aprvlid } is not in PENDING status| ##NO_TEXT.
        APPEND VALUE #(
          %tky = ls_request-%tky
          %param = VALUE #(
            success = abap_false
            message = lv_msg_not_pending_a )
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
          DATA(lv_msg_unsupported) = |Unsupported approval action { ls_request-actiontype }| ##NO_TEXT.
          ls_apply_result = VALUE #(
            success = abap_false
            message = lv_msg_unsupported ).
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
    IF zcl_auth_helper=>is_admin( ) <> abap_true.
      DATA(lv_msg_reject_admin) = |Action REJECT chỉ dành cho ADMIN| ##NO_TEXT.
      LOOP AT keys INTO DATA(ls_reject_key).
        APPEND VALUE #(
          %tky = ls_reject_key-%tky
          %param = VALUE #(
            success = abap_false
            message = lv_msg_reject_admin )
        ) TO result.
      ENDLOOP.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_aprvl_request IN LOCAL MODE
      ENTITY aprvlrequest
        FIELDS ( aprvlid recordkey status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    DATA(lv_default_reject_remark) = 'Rejected by admin' ##NO_TEXT.

    LOOP AT lt_requests INTO DATA(ls_request).
      IF ls_request-status <> 'PENDING'.
        DATA(lv_msg_not_pending_r) = |Request { ls_request-aprvlid } is not in PENDING status| ##NO_TEXT.
        APPEND VALUE #(
          %tky = ls_request-%tky
          %param = VALUE #(
            success = abap_false
            message = lv_msg_not_pending_r )
        ) TO result.
        CONTINUE.
      ENDIF.

      READ TABLE keys INTO DATA(ls_key)
        WITH KEY primary_key COMPONENTS %tky = ls_request-%tky ##PRIMKEY[ID].

      DATA(lv_remarks) = COND string(
        WHEN sy-subrc = 0 AND ls_key-%param-remarks IS NOT INITIAL
        THEN ls_key-%param-remarks
        ELSE lv_default_reject_remark ).

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

      DATA(lv_msg_rejected) = |Request rejected: { lv_remarks }| ##NO_TEXT.
      APPEND VALUE #(
        %tky = ls_request-%tky
        %param = VALUE #(
          success = abap_true
          message = lv_msg_rejected )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
