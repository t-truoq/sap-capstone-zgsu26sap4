CLASS lhc_tblconfig DEFINITION INHERITING FROM cl_abap_behavior_handler.
 PRIVATE SECTION.

 "── TblConfig handlers ──
 METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
 IMPORTING REQUEST requested_authorizations FOR tblconfig RESULT result.
 METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
 IMPORTING keys REQUEST requested_authorizations FOR tblconfig RESULT result.
 METHODS validatetablename FOR VALIDATE ON SAVE
 IMPORTING keys FOR tblconfig~validatetablename.
 METHODS validatefldconfig FOR VALIDATE ON SAVE
 IMPORTING keys FOR tblconfig~validatefldconfig.
 METHODS filldescription FOR DETERMINE ON MODIFY
 IMPORTING keys FOR tblconfig~filldescription.
 METHODS fillfieldconfig FOR DETERMINE ON MODIFY
 IMPORTING keys FOR tblconfig~fillfieldconfig.
 METHODS ensuretablepermission FOR DETERMINE ON SAVE
 IMPORTING keys FOR tblconfig~ensuretablepermission.

 "── Dynamic CRUD actions ──
 METHODS getfieldmeta FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~getfieldmeta RESULT result.
 METHODS gettabledata FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~gettabledata RESULT result.
 METHODS createrecord FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~createrecord RESULT result.
 METHODS updaterecord FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~updaterecord RESULT result.
 METHODS deleterecord FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~deleterecord RESULT result.
 METHODS getdomainvalues FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~getdomainvalues RESULT result.

 "── Repository Inventory action (NEW) ──
 METHODS getrepositoryinfo FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~getrepositoryinfo RESULT result.
 METHODS acquirelock FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~acquirelock RESULT result.
 METHODS heartbeat FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~heartbeat RESULT result.
 METHODS releaselock FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~releaselock RESULT result.
 METHODS forceunlock FOR MODIFY
 IMPORTING keys FOR ACTION tblconfig~forceunlock RESULT result.

 "── FldConfig handlers ──
 METHODS validatedisplayorder FOR VALIDATE ON SAVE
 IMPORTING keys FOR fldconfig~validatedisplayorder.
 METHODS validatedomainname FOR VALIDATE ON SAVE
 IMPORTING keys FOR fldconfig~validatedomainname.
 METHODS filllabeltext FOR DETERMINE ON MODIFY
 IMPORTING keys FOR fldconfig~filllabeltext.

 "── Private helper ──
 METHODS get_label_from_dd04t
 IMPORTING iv_rollname TYPE rollname
 RETURNING VALUE(rv_label) TYPE dd04t-reptext.

 METHODS getfkvalues FOR MODIFY
  IMPORTING keys FOR ACTION tblconfig~getfkvalues RESULT result.

  "Ai helper
  METHODS getaidescription FOR MODIFY
  IMPORTING keys FOR ACTION tblconfig~getaidescription RESULT result.

ENDCLASS.

CLASS lhc_tblconfig IMPLEMENTATION.

 METHOD ensuretablepermission.
     READ ENTITIES OF zi_tbl_config IN LOCAL MODE
       ENTITY tblconfig
       FIELDS ( tablename activeflag )
       WITH CORRESPONDING #( keys )
       RESULT DATA(lt_configs).

   LOOP AT lt_configs INTO DATA(ls_config).
     IF ls_config-tablename IS INITIAL.
       CONTINUE.
     ENDIF.

     IF ls_config-activeflag <> abap_true.
       DELETE FROM ztbl_table_perm
         WHERE table_name = @ls_config-tablename.
       DELETE FROM ztbl_user_perm
         WHERE table_name = @ls_config-tablename.
       CONTINUE.
     ENDIF.

     SELECT SINGLE table_name, can_view, can_create, can_update, can_delete
     FROM ztbl_table_perm
     WHERE table_name = @ls_config-tablename
     INTO @DATA(ls_table_policy).

     IF sy-subrc <> 0.
       ls_table_policy = VALUE #(
         table_name = ls_config-tablename
         can_view   = abap_true
         can_create = abap_true
         can_update = abap_true
         can_delete = abap_true ).

       INSERT ztbl_table_perm FROM @( VALUE ztbl_table_perm(
         client     = sy-mandt
         table_name = ls_config-tablename
         can_view   = abap_true
         can_create = abap_true
         can_update = abap_true
         can_delete = abap_true ) ).
     ENDIF.

     "Every active USER must have an explicit row.  Authorization must not
     "fall back to the table policy when a user-specific row is missing.
     SELECT username
       FROM ztbl_user_master
       WHERE role_type   = 'USER'
         AND active_flag = @abap_true
       INTO TABLE @DATA(lt_users).

     LOOP AT lt_users INTO DATA(ls_user).
       SELECT SINGLE @abap_true
         FROM ztbl_user_perm
         WHERE username   = @ls_user-username
           AND table_name = @ls_config-tablename
         INTO @DATA(lv_user_perm_exists).

       IF sy-subrc <> 0.
         INSERT ztbl_user_perm FROM @( VALUE ztbl_user_perm(
           client     = sy-mandt
           username   = ls_user-username
           table_name = ls_config-tablename
           can_view   = ls_table_policy-can_view
           can_create = ls_table_policy-can_create
           can_update = ls_table_policy-can_update
           can_delete = ls_table_policy-can_delete ) ).
       ENDIF.
     ENDLOOP.
   ENDLOOP.
 ENDMETHOD.

 METHOD validatedomainname.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY fldconfig
 FIELDS ( tablename fieldname fieldtype domainname )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_fields).

 LOOP AT lt_fields INTO DATA(ls_field).
 IF ls_field-fieldtype = 'DOMAIN' AND ls_field-domainname IS INITIAL.
 APPEND VALUE #( %tky = ls_field-%tky ) TO failed-fldconfig.
 APPEND VALUE #(
 %tky = ls_field-%tky
 %msg = new_message(
   id       = 'Z_GSU26SAP04'
   number   = '048'
   severity = if_abap_behv_message=>severity-error )
 %element = VALUE #( domainname = if_abap_behv=>mk-on )
 ) TO reported-fldconfig.
 ENDIF.
 ENDLOOP.
 ENDMETHOD.

 METHOD validatefldconfig.
 ENDMETHOD.

 METHOD get_instance_authorizations.
 DATA(lv_admin) = zcl_auth_helper=>is_admin( ).

 LOOP AT keys INTO DATA(ls_key).
   APPEND VALUE #(
     %tky    = ls_key-%tky
     %update = COND #( WHEN lv_admin = abap_true
                       THEN if_abap_behv=>auth-allowed
                       ELSE if_abap_behv=>auth-unauthorized )
     %delete = COND #( WHEN lv_admin = abap_true
                       THEN if_abap_behv=>auth-allowed
                       ELSE if_abap_behv=>auth-unauthorized )
   ) TO result.
 ENDLOOP.
 ENDMETHOD.

 METHOD get_global_authorizations.
   IF requested_authorizations-%create = if_abap_behv=>mk-on.
     result-%create = COND #(
       WHEN zcl_auth_helper=>is_admin( ) = abap_true
       THEN if_abap_behv=>auth-allowed
       ELSE if_abap_behv=>auth-unauthorized ).
   ENDIF.
 ENDMETHOD.

 METHOD validatetablename.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename configuuid )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).

 IF ls_config-tablename IS INITIAL.
 APPEND VALUE #( %tky = ls_config-%tky ) TO failed-tblconfig.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %msg = new_message(
   id       = 'Z_GSU26SAP04'
   number   = '023'
   severity = if_abap_behv_message=>severity-error )
 %element = VALUE #( tablename = if_abap_behv=>mk-on )
 ) TO reported-tblconfig.
 CONTINUE.
 ENDIF.

 IF ls_config-tablename(1) <> 'Z' AND ls_config-tablename(1) <> 'Y'.
 APPEND VALUE #( %tky = ls_config-%tky ) TO failed-tblconfig.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %msg = new_message(
   id       = 'Z_GSU26SAP04'
   number   = '024'
   v1       = ls_config-tablename
   severity = if_abap_behv_message=>severity-error )
 %element = VALUE #( tablename = if_abap_behv=>mk-on )
 ) TO reported-tblconfig.
 CONTINUE.
 ENDIF.

 SELECT SINGLE tabname FROM dd02l
 WHERE tabname = @ls_config-tablename
 AND tabclass = 'TRANSP'
 AND as4local = 'A'
 INTO @DATA(lv_tabname).

 IF sy-subrc <> 0.
 APPEND VALUE #( %tky = ls_config-%tky ) TO failed-tblconfig.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %msg = new_message(
   id       = 'Z_GSU26SAP04'
   number   = '025'
   v1       = ls_config-tablename
   severity = if_abap_behv_message=>severity-error )
 %element = VALUE #( tablename = if_abap_behv=>mk-on )
 ) TO reported-tblconfig.
 CONTINUE.
 ENDIF.

 SELECT SINGLE table_name FROM ztbl_config
 WHERE table_name = @ls_config-tablename
 AND config_uuid <> @ls_config-configuuid
 INTO @DATA(lv_existing).

 IF sy-subrc = 0.
 APPEND VALUE #( %tky = ls_config-%tky ) TO failed-tblconfig.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %msg = new_message(
   id       = 'Z_GSU26SAP04'
   number   = '046'
   v1       = ls_config-tablename
   severity = if_abap_behv_message=>severity-error )
 %element = VALUE #( tablename = if_abap_behv=>mk-on )
 ) TO reported-tblconfig.
 ENDIF.

 ENDLOOP.
 ENDMETHOD.

 METHOD validatedisplayorder.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY fldconfig
 FIELDS ( tablename fieldname displayorder )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_fields).

 LOOP AT lt_fields INTO DATA(ls_field).
 IF ls_field-displayorder IS INITIAL. CONTINUE. ENDIF.

 SELECT SINGLE field_name FROM zfld_config
 WHERE table_name = @ls_field-tablename
 AND display_order = @ls_field-displayorder
 AND field_name <> @ls_field-fieldname
 INTO @DATA(lv_exists).

 IF sy-subrc = 0.
 APPEND VALUE #( %tky = ls_field-%tky ) TO failed-fldconfig.
 APPEND VALUE #(
 %tky = ls_field-%tky
 %msg = new_message(
   id       = 'Z_GSU26SAP04'
   number   = '047'
   v1       = |{ ls_field-displayorder }|
   v2       = ls_field-tablename
   severity = if_abap_behv_message=>severity-error )
 %element = VALUE #( displayorder = if_abap_behv=>mk-on )
 ) TO reported-fldconfig.
 ENDIF.
 ENDLOOP.
 ENDMETHOD.

 METHOD get_label_from_dd04t.
 SELECT SINGLE reptext FROM dd04t
 WHERE rollname = @iv_rollname
 AND ddlanguage = @sy-langu
 INTO @rv_label.
 IF rv_label IS NOT INITIAL. RETURN. ENDIF.

 IF sy-langu <> 'E'.
 SELECT SINGLE reptext FROM dd04t
 WHERE rollname = @iv_rollname
 AND ddlanguage = 'E'
 INTO @rv_label.
 IF rv_label IS NOT INITIAL. RETURN. ENDIF.
 ENDIF.

 SELECT SINGLE reptext FROM dd04t
 WHERE rollname = @iv_rollname
 INTO @rv_label.
 ENDMETHOD.

 METHOD createrecord.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 TRY.
 zcl_auth_helper=>check_permission(
 iv_table_name = CONV #( ls_config-tablename )
 iv_action     = zcl_auth_helper=>c_action-create ).
 CATCH zcx_excel_pipeline INTO DATA(lx_auth_create).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_false message = lx_auth_create->get_text( ) )
 ) TO result.
 CONTINUE.
 ENDTRY.

 READ TABLE keys INTO DATA(ls_key)
 WITH KEY primary_key COMPONENTS %tky = ls_config-%tky.
 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(lv_record_data) = ls_key-%param-record_data.
 IF lv_record_data IS INITIAL.
 lv_record_data = ls_key-%param-records_data.
 ENDIF.

 IF lv_record_data IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
   table_name = ls_config-tablename
   success    = abap_false
   message    = NEW zcx_error( textid = zcx_error=>record_data_empty )->get_text( ) )
 ) TO result.
 CONTINUE.
 ENDIF.

 TRY.
 DATA(lo_desc_create) = CAST cl_abap_structdescr(
 cl_abap_typedescr=>describe_by_name( ls_config-tablename )
 ).
 CATCH cx_root.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
   table_name = ls_config-tablename
   success    = abap_false
   message    = NEW zcx_error(
                   textid       = zcx_error=>invalid_table
                iv_table_name = CONV #( ls_config-tablename ) )->get_text( ) )
                 ) TO result.
 CONTINUE.
 ENDTRY.

 DATA(lv_payload) = lv_record_data.
 SHIFT lv_payload LEFT DELETING LEADING space.

 IF lv_payload CP '[*'.
 TRY.
 DATA(lt_batch_refs) = zcl_dyn_record_handler=>deserialize_batch(
 iv_table_name = ls_config-tablename
 iv_json_array = lv_record_data ).

 IF lt_batch_refs IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
   table_name = ls_config-tablename
   success    = abap_false
   message    = NEW zcx_error( textid = zcx_error=>records_data_empty_or_invalid )->get_text( ) )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA lt_batch_items TYPE zcl_excel_pipeline=>tt_item.

 LOOP AT lt_batch_refs INTO DATA(lr_batch_record).
 DATA(lv_batch_item_no) = sy-tabix.

 DATA(lv_batch_validation_msg) =
   zcl_dyn_record_handler=>validate_record_values(
     iv_table_name = ls_config-tablename
     ir_record     = lr_batch_record ).
 IF lv_batch_validation_msg IS NOT INITIAL.
   RAISE EXCEPTION TYPE zcx_excel_pipeline
     EXPORTING iv_text = NEW zcx_error(
                            textid     = zcx_error=>row_validation_failed
                            iv_item_no = |{ lv_batch_item_no }|
                            iv_message = lv_batch_validation_msg )->get_text( ).
 ENDIF.

 zcl_dyn_record_handler=>on_create(
 iv_table_name = ls_config-tablename
 ir_record     = lr_batch_record ).

 DATA(lt_batch_keys) = zcl_dyn_record_handler=>get_key_fields(
 iv_table_name = ls_config-tablename ).
 DATA(lv_batch_key) = zcl_dyn_record_handler=>build_key_json(
 it_key_fields = lt_batch_keys
 ir_record = lr_batch_record ).

 IF lv_batch_key IS INITIAL.
 RAISE EXCEPTION TYPE zcx_excel_pipeline
 EXPORTING iv_text = NEW zcx_error(
                       textid     = zcx_error=>cannot_build_crud_key
                       iv_item_no = |{ lv_batch_item_no }| )->get_text( ).
 ENDIF.

 ASSIGN lr_batch_record->* TO FIELD-SYMBOL(<ls_batch_record>).

 APPEND VALUE #(
 item_no = lv_batch_item_no
 table_name = ls_config-tablename
 record_key = CONV #( lv_batch_key )
 action_type = 'C'
 new_data = zcl_dyn_record_handler=>serialize( <ls_batch_record> )
 old_data = ''
 ) TO lt_batch_items.
 ENDLOOP.

 DATA ls_batch_item TYPE zcl_excel_pipeline=>ty_item.
 IF zcl_aprvl_util=>is_approval_required( ls_config-tablename ) = abap_true.
 DATA lt_batch_submit_items TYPE zcl_excel_pipeline=>tt_item.
 DATA(lv_batch_skipped) = 0.
 DATA(lv_batch_skip_msg) = VALUE string( ).

 LOOP AT lt_batch_items INTO ls_batch_item.
 TRY.
 zcl_aprvl_util=>assert_no_conflicting_pending(
 iv_table_name = ls_batch_item-table_name
 iv_record_key = ls_batch_item-record_key ).
 APPEND ls_batch_item TO lt_batch_submit_items.
CATCH zcx_excel_pipeline INTO DATA(lx_batch_pending).
 lv_batch_skipped = lv_batch_skipped + 1.
 DATA(lv_skip_text) = NEW zcx_error(
                         textid     = zcx_error=>skipped_row
                         iv_item_no = |{ ls_batch_item-item_no }|
                         iv_message = lx_batch_pending->get_text( ) )->get_text( ).
 IF lv_batch_skip_msg IS INITIAL.
 lv_batch_skip_msg = lv_skip_text.
 ELSE.
 lv_batch_skip_msg = |{ lv_batch_skip_msg } { lv_skip_text }|.
 ENDIF.
 ENDTRY.
 ENDLOOP.

 IF lt_batch_submit_items IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_false message = lv_batch_skip_msg )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(ls_batch_submit) = zcl_excel_pipeline=>submit_bulk(
 iv_table_name = CONV #( ls_config-tablename )
 it_items = lt_batch_submit_items ).

 IF lv_batch_skipped > 0.
 ls_batch_submit-message = |{ ls_batch_submit-message } { lv_batch_skipped } row(s) skipped. { lv_batch_skip_msg }|.
 ENDIF.

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = ls_batch_submit-success message = ls_batch_submit-message )
 ) TO result.
 ELSE.
 DATA(lv_batch_success) = abap_true.
 DATA(lv_batch_message) = VALUE string( ).
 DATA(lv_parent_audit_id) = cl_system_uuid=>create_uuid_c32_static( ).

 LOOP AT lt_batch_items INTO ls_batch_item.
 DATA(ls_batch_create) = zcl_dyn_record_handler=>create_record(
 iv_table_name = ls_config-tablename
 iv_record_data = ls_batch_item-new_data
 iv_parent_audit_id = lv_parent_audit_id ).
 IF ls_batch_create-success <> abap_true.
 lv_batch_success = abap_false.
 lv_batch_message = |{ lv_batch_message }{ NEW zcx_error(
                       textid     = zcx_error=>item_error
                       iv_item_no = |{ ls_batch_item-item_no }|
                       iv_message = ls_batch_create-message )->get_text( ) } |.
 ENDIF.
 ENDLOOP.

IF lv_batch_success = abap_true.
 lv_batch_message = NEW zcx_error(
                       textid   = zcx_error=>created_n_records
                       iv_count = |{ lines( lt_batch_items ) }| )->get_text( ).
 ENDIF.

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = lv_batch_success message = lv_batch_message )
 ) TO result.
 ENDIF.

 CATCH cx_root INTO DATA(lx_batch_create).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_false message = lx_batch_create->get_text( ) )
 ) TO result.
 ENDTRY.
 CONTINUE.
 ENDIF.

 DATA lo_create TYPE REF TO data.
 CREATE DATA lo_create TYPE HANDLE lo_desc_create.
 ASSIGN lo_create->* TO FIELD-SYMBOL(<ls_create>).

 TRY.
 zcl_dyn_record_handler=>deserialize(
 EXPORTING iv_json = lv_record_data
 CHANGING ca_record = lo_create
 ).

 DATA(lv_create_validation_msg) =
   zcl_dyn_record_handler=>validate_record_values(
     iv_table_name = ls_config-tablename
     ir_record     = lo_create ).
 IF lv_create_validation_msg IS NOT INITIAL.
   APPEND VALUE #(
     %tky = ls_config-%tky
     %param = VALUE #(
       table_name = ls_config-tablename
       success    = abap_false
       message    = lv_create_validation_msg )
   ) TO result.
   CONTINUE.
 ENDIF.

 zcl_dyn_record_handler=>on_create(
 iv_table_name = ls_config-tablename
 ir_record     = lo_create
 ).

 DATA(lt_create_keys) = zcl_dyn_record_handler=>get_key_fields(
   iv_table_name = ls_config-tablename ).
 DATA(lv_create_key) = zcl_dyn_record_handler=>build_key_json(
 it_key_fields = lt_create_keys
 ir_record     = lo_create
 ).

 lv_record_data = zcl_dyn_record_handler=>serialize( <ls_create> ).

 CATCH cx_root INTO DATA(lx_create).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_false message = lx_create->get_text( ) )
 ) TO result.
 CONTINUE.
 ENDTRY.

 DATA ls_aprvl TYPE zcl_aprvl_util=>ty_result.

 TRY.
 ls_aprvl = zcl_aprvl_util=>check_and_submit(
 iv_table_name  = ls_config-tablename
 iv_action_type = 'C'
 iv_record_key  = CONV #( lv_create_key )
 iv_new_data    = lv_record_data
 ).
 CATCH zcx_excel_pipeline INTO DATA(lx_pending_create).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_false message = lx_pending_create->get_text( ) )
 ) TO result.
 CONTINUE.
 ENDTRY.

 IF ls_aprvl-needs_approval = abap_true.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_true message = ls_aprvl-message )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(ls_res) = zcl_dyn_record_handler=>create_record(
 iv_table_name  = ls_config-tablename
 iv_record_data = lv_record_data
 ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = ls_res-success message = ls_res-message )
 ) TO result.

 ENDLOOP.
 ENDMETHOD.

 METHOD updaterecord.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 TRY.
 zcl_auth_helper=>check_permission(
 iv_table_name = CONV #( ls_config-tablename )
 iv_action     = zcl_auth_helper=>c_action-update ).
 CATCH zcx_excel_pipeline INTO DATA(lx_auth_update).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = lx_auth_update->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDTRY.

 READ TABLE keys INTO DATA(ls_key)
 WITH KEY primary_key COMPONENTS %tky = ls_config-%tky.
 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(lv_record_data) = ls_key-%param-record_data.
 IF lv_record_data IS INITIAL.
 lv_record_data = ls_key-%param-records_data.
 ENDIF.
 DATA(lv_payload) = lv_record_data.
 SHIFT lv_payload LEFT DELETING LEADING space.

 TRY.
 DATA(lo_desc) = CAST cl_abap_structdescr(
 cl_abap_typedescr=>describe_by_name( ls_config-tablename )
 ).
 CATCH cx_root.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = NEW zcx_error(
             textid       = zcx_error=>invalid_table
            iv_table_name = CONV #( ls_config-tablename ) )->get_text( )
             )
 ) TO result.
 CONTINUE.
 ENDTRY.

 IF lv_payload CP '[*'.
 TRY.
 DATA(lt_batch_refs) = zcl_dyn_record_handler=>deserialize_batch(
 iv_table_name = ls_config-tablename
 iv_json_array = lv_record_data ).

 IF lt_batch_refs IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = NEW zcx_error( textid = zcx_error=>records_data_empty_or_invalid )->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA lt_batch_items TYPE zcl_excel_pipeline=>tt_item.
 LOOP AT lt_batch_refs INTO DATA(lr_batch_record).
 DATA(lv_batch_item_no) = sy-tabix.

 DATA(lv_batch_update_validation_msg) =
   zcl_dyn_record_handler=>validate_record_values(
     iv_table_name = ls_config-tablename
     ir_record     = lr_batch_record ).
 IF lv_batch_update_validation_msg IS NOT INITIAL.
   RAISE EXCEPTION TYPE zcx_excel_pipeline
     EXPORTING iv_text = NEW zcx_error(
                            textid     = zcx_error=>row_validation_failed
                            iv_item_no = |{ lv_batch_item_no }|
                            iv_message = lv_batch_update_validation_msg )->get_text( ).
 ENDIF.

 DATA(lt_batch_keys) = zcl_dyn_record_handler=>get_key_fields(
 iv_table_name = ls_config-tablename ).
 DATA(lv_batch_where) = zcl_dyn_record_handler=>build_where_clause(
 it_key_fields = lt_batch_keys
 ir_record = lr_batch_record ).
 DATA(lv_batch_key) = zcl_dyn_record_handler=>build_key_json(
 it_key_fields = lt_batch_keys
 ir_record = lr_batch_record ).

 IF lv_batch_where IS INITIAL OR lv_batch_key IS INITIAL.
 RAISE EXCEPTION TYPE zcx_excel_pipeline
 EXPORTING iv_text = NEW zcx_error(
                       textid     = zcx_error=>cannot_build_crud_key
                       iv_item_no = |{ lv_batch_item_no }| )->get_text( ).
 ENDIF.

 DATA(lr_batch_old) = zcl_dyn_record_handler=>get_single_record(
 iv_table_name = ls_config-tablename
 iv_where = lv_batch_where ).
 ASSIGN lr_batch_old->* TO FIELD-SYMBOL(<ls_batch_old>).
 ASSIGN lr_batch_record->* TO FIELD-SYMBOL(<ls_batch_record>).

 APPEND VALUE #(
 item_no = lv_batch_item_no
 table_name = ls_config-tablename
 record_key = CONV #( lv_batch_key )
 action_type = 'U'
 new_data = zcl_dyn_record_handler=>serialize( <ls_batch_record> )
 old_data = zcl_dyn_record_handler=>serialize( <ls_batch_old> )
 ) TO lt_batch_items.
 ENDLOOP.

 DATA ls_batch_item TYPE zcl_excel_pipeline=>ty_item.
 IF zcl_aprvl_util=>is_approval_required( ls_config-tablename ) = abap_true.
 DATA lt_batch_submit_items TYPE zcl_excel_pipeline=>tt_item.
 DATA(lv_batch_skipped) = 0.
 DATA(lv_batch_skip_msg) = VALUE string( ).

 LOOP AT lt_batch_items INTO ls_batch_item.
 TRY.
 zcl_aprvl_util=>assert_no_conflicting_pending(
 iv_table_name = ls_batch_item-table_name
 iv_record_key = ls_batch_item-record_key ).
 APPEND ls_batch_item TO lt_batch_submit_items.
CATCH zcx_excel_pipeline INTO DATA(lx_batch_pending).
 lv_batch_skipped = lv_batch_skipped + 1.
 lv_batch_skip_msg = |{ lv_batch_skip_msg }{ NEW zcx_error(
                       textid     = zcx_error=>skipped_row
                       iv_item_no = |{ ls_batch_item-item_no }|
                       iv_message = lx_batch_pending->get_text( ) )->get_text( ) } |.
 ENDTRY.
 ENDLOOP.

 IF lt_batch_submit_items IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = lv_batch_skip_msg
 )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(ls_batch_submit) = zcl_excel_pipeline=>submit_bulk(
 iv_table_name = CONV #( ls_config-tablename )
 it_items = lt_batch_submit_items ).

 IF lv_batch_skipped > 0.
 ls_batch_submit-message = |{ ls_batch_submit-message } { lv_batch_skipped } row(s) skipped. { lv_batch_skip_msg }|.
 ENDIF.

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = ls_batch_submit-success
 message = ls_batch_submit-message
 )
 ) TO result.
 ELSE.
 DATA(lv_batch_success) = abap_true.
 DATA(lv_batch_message) = VALUE string( ).
 DATA(lv_parent_audit_id) = cl_system_uuid=>create_uuid_c32_static( ).
 LOOP AT lt_batch_items INTO ls_batch_item.
 DATA(ls_batch_update) = zcl_dyn_record_handler=>update_record(
 iv_table_name = ls_config-tablename
 iv_record_data = ls_batch_item-new_data
 iv_parent_audit_id = lv_parent_audit_id ).
IF ls_batch_update-success <> abap_true.
 lv_batch_success = abap_false.
 lv_batch_message = |{ lv_batch_message }{ NEW zcx_error(
                       textid     = zcx_error=>item_error
                       iv_item_no = |{ ls_batch_item-item_no }|
                       iv_message = ls_batch_update-message )->get_text( ) } |.
 ENDIF.
 ENDLOOP.

IF lv_batch_success = abap_true.
 lv_batch_message = NEW zcx_error(
                       textid   = zcx_error=>updated_n_records
                       iv_count = |{ lines( lt_batch_items ) }| )->get_text( ).
 ENDIF.

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = lv_batch_success
 message = lv_batch_message
 )
 ) TO result.
 ENDIF.

 CATCH cx_root INTO DATA(lx_batch_update).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = lx_batch_update->get_text( )
 )
 ) TO result.
 ENDTRY.
 CONTINUE.
 ENDIF.

 IF lv_record_data IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = NEW zcx_error( textid = zcx_error=>record_data_empty )->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA lo_new TYPE REF TO data.
 CREATE DATA lo_new TYPE HANDLE lo_desc.
 ASSIGN lo_new->* TO FIELD-SYMBOL(<ls_new>).

 zcl_dyn_record_handler=>deserialize(
 EXPORTING iv_json = lv_record_data
 CHANGING ca_record = lo_new
 ).

 DATA(lv_update_validation_msg) =
   zcl_dyn_record_handler=>validate_record_values(
     iv_table_name = ls_config-tablename
     ir_record     = lo_new ).
 IF lv_update_validation_msg IS NOT INITIAL.
   APPEND VALUE #(
     %tky = ls_config-%tky
     %param = VALUE #(
       table_name = ls_config-tablename
       success    = abap_false
       message    = lv_update_validation_msg )
   ) TO result.
   CONTINUE.
 ENDIF.

 DATA(lt_keys) = zcl_dyn_record_handler=>get_key_fields(
   iv_table_name = ls_config-tablename ).
 DATA(lv_where) = zcl_dyn_record_handler=>build_where_clause(
 it_key_fields = lt_keys
 ir_record = lo_new
 ).

 DATA lo_old TYPE REF TO data.
 CREATE DATA lo_old TYPE HANDLE lo_desc.
 ASSIGN lo_old->* TO FIELD-SYMBOL(<ls_old>).

 SELECT SINGLE * FROM (ls_config-tablename)
 WHERE (lv_where)
 INTO @<ls_old>.

 DATA(lv_old_json) = COND string(
 WHEN sy-subrc = 0 THEN zcl_dyn_record_handler=>serialize( <ls_old> )
 ELSE space
 ).

 DATA(lv_record_key) = zcl_dyn_record_handler=>build_key_json(
 it_key_fields = lt_keys
 ir_record = lo_new
 ).

 DATA ls_aprvl TYPE zcl_aprvl_util=>ty_result.

 TRY.
 ls_aprvl = zcl_aprvl_util=>check_and_submit(
 iv_table_name = ls_config-tablename
 iv_action_type = 'U'
 iv_record_key = CONV #( lv_record_key )
 iv_new_data = lv_record_data
 iv_old_data = lv_old_json
 ).
 CATCH zcx_excel_pipeline INTO DATA(lx_pending_update).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = lx_pending_update->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDTRY.

 IF ls_aprvl-needs_approval = abap_true.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_true
 message = ls_aprvl-message
 )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(lv_etag_field) = CONV string( ls_key-%param-etag_field ).
 DATA(lv_etag_value) = CONV string( ls_key-%param-etag_value ).

 DATA(ls_res) = zcl_dyn_record_handler=>update_record(
 iv_table_name = ls_config-tablename
 iv_record_data = lv_record_data
 iv_etag_field = lv_etag_field
 iv_etag_value = lv_etag_value
 ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = ls_res-success
 message = ls_res-message
 )
 ) TO result.

 ENDLOOP.
 ENDMETHOD.

 METHOD deleterecord.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 TRY.
 zcl_auth_helper=>check_permission(
 iv_table_name = CONV #( ls_config-tablename )
 iv_action     = zcl_auth_helper=>c_action-delete ).
 CATCH zcx_excel_pipeline INTO DATA(lx_auth_delete).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = lx_auth_delete->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDTRY.

 READ TABLE keys INTO DATA(ls_key)
 WITH KEY primary_key COMPONENTS %tky = ls_config-%tky.
 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(lv_record_key) = ls_key-%param-record_key.
 IF lv_record_key IS INITIAL.
 lv_record_key = CONV ztde_record_key( ls_key-%param-records_data ).
 ENDIF.

 DATA(lv_del_payload) = CONV string( lv_record_key ).
 SHIFT lv_del_payload LEFT DELETING LEADING space.

 IF lv_del_payload IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = NEW zcx_error( textid = zcx_error=>record_key_empty )->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDIF.

 TRY.
 DATA(lo_desc) = CAST cl_abap_structdescr(
 cl_abap_typedescr=>describe_by_name( ls_config-tablename )
 ).
 CATCH cx_root.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = NEW zcx_error(
             textid       = zcx_error=>invalid_table
            iv_table_name = CONV #( ls_config-tablename ) )->get_text( )
             )
 ) TO result.
 CONTINUE.
 ENDTRY.

 IF lv_del_payload CP '[*'.
 TRY.
 DATA(lt_batch_refs) = zcl_dyn_record_handler=>deserialize_batch(
 iv_table_name = ls_config-tablename
 iv_json_array = lv_del_payload ).

 IF lt_batch_refs IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
   table_name = ls_config-tablename
   success    = abap_false
   message    = NEW zcx_error( textid = zcx_error=>record_key_data_invalid )->get_text( ) )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA lt_batch_items TYPE zcl_excel_pipeline=>tt_item.

 LOOP AT lt_batch_refs INTO DATA(lr_batch_record).
 DATA(lv_batch_item_no) = sy-tabix.

 DATA(lt_batch_keys) = zcl_dyn_record_handler=>get_key_fields(
 iv_table_name = ls_config-tablename ).
 DATA(lv_batch_where) = zcl_dyn_record_handler=>build_where_clause(
 it_key_fields = lt_batch_keys
 ir_record = lr_batch_record ).
 DATA(lv_batch_key) = zcl_dyn_record_handler=>build_key_json(
 it_key_fields = lt_batch_keys
 ir_record = lr_batch_record ).

 IF lv_batch_where IS INITIAL OR lv_batch_key IS INITIAL.
 RAISE EXCEPTION TYPE zcx_excel_pipeline
 EXPORTING iv_text = NEW zcx_error(
                       textid     = zcx_error=>cannot_build_crud_key
                       iv_item_no = |{ lv_batch_item_no }| )->get_text( ).
 ENDIF.

 DATA(lv_batch_fk_error) = zcl_dyn_record_handler=>check_foreign_key(
 iv_table_name = ls_config-tablename
 iv_record_key = CONV #( lv_batch_key ) ).
 IF lv_batch_fk_error IS NOT INITIAL.
 RAISE EXCEPTION TYPE zcx_excel_pipeline
 EXPORTING iv_text = NEW zcx_error(
                       textid     = zcx_error=>row_validation_failed
                       iv_item_no = |{ lv_batch_item_no }|
                       iv_message = lv_batch_fk_error )->get_text( ).
 ENDIF.

 DATA(lr_batch_old) = zcl_dyn_record_handler=>get_single_record(
 iv_table_name = ls_config-tablename
 iv_where = lv_batch_where ).
 ASSIGN lr_batch_old->* TO FIELD-SYMBOL(<ls_batch_old>).

 APPEND VALUE #(
 item_no = lv_batch_item_no
 table_name = ls_config-tablename
 record_key = CONV #( lv_batch_key )
 action_type = 'D'
 new_data = ''
 old_data = zcl_dyn_record_handler=>serialize( <ls_batch_old> )
 ) TO lt_batch_items.
 ENDLOOP.

 DATA ls_batch_item TYPE zcl_excel_pipeline=>ty_item.
 IF zcl_aprvl_util=>is_approval_required( ls_config-tablename ) = abap_true.
 DATA lt_batch_submit_items TYPE zcl_excel_pipeline=>tt_item.
 DATA(lv_batch_skipped) = 0.
 DATA(lv_batch_skip_msg) = VALUE string( ).

 LOOP AT lt_batch_items INTO ls_batch_item.
 TRY.
 zcl_aprvl_util=>assert_no_conflicting_pending(
 iv_table_name = ls_batch_item-table_name
 iv_record_key = ls_batch_item-record_key ).
 APPEND ls_batch_item TO lt_batch_submit_items.
CATCH zcx_excel_pipeline INTO DATA(lx_batch_pending).
 lv_batch_skipped = lv_batch_skipped + 1.
 lv_batch_skip_msg = |{ lv_batch_skip_msg }{ NEW zcx_error(
                       textid     = zcx_error=>skipped_row
                       iv_item_no = |{ ls_batch_item-item_no }|
                       iv_message = lx_batch_pending->get_text( ) )->get_text( ) } |.
 ENDTRY.
 ENDLOOP.

 IF lt_batch_submit_items IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_false message = lv_batch_skip_msg )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(ls_batch_submit) = zcl_excel_pipeline=>submit_bulk(
 iv_table_name = CONV #( ls_config-tablename )
 it_items = lt_batch_submit_items ).

 IF lv_batch_skipped > 0.
 ls_batch_submit-message = |{ ls_batch_submit-message } { lv_batch_skipped } row(s) skipped. { lv_batch_skip_msg }|.
 ENDIF.

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = ls_batch_submit-success message = ls_batch_submit-message )
 ) TO result.
 ELSE.
 DATA(lv_batch_success) = abap_true.
 DATA(lv_batch_message) = VALUE string( ).
 DATA(lv_parent_audit_id) = cl_system_uuid=>create_uuid_c32_static( ).

 LOOP AT lt_batch_items INTO ls_batch_item.
 DATA(ls_batch_delete) = zcl_dyn_record_handler=>delete_record(
 iv_table_name = ls_config-tablename
 iv_record_key = CONV #( ls_batch_item-record_key )
 iv_parent_audit_id = lv_parent_audit_id ).
IF ls_batch_delete-success <> abap_true.
 lv_batch_success = abap_false.
 lv_batch_message = |{ lv_batch_message }{ NEW zcx_error(
                       textid     = zcx_error=>item_error
                       iv_item_no = |{ ls_batch_item-item_no }|
                       iv_message = ls_batch_delete-message )->get_text( ) } |.
 ENDIF.
 ENDLOOP.

IF lv_batch_success = abap_true.
 lv_batch_message = NEW zcx_error(
                       textid   = zcx_error=>deleted_n_records
                       iv_count = |{ lines( lt_batch_items ) }| )->get_text( ).
 ENDIF.

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = lv_batch_success message = lv_batch_message )
 ) TO result.
 ENDIF.

 CATCH cx_root INTO DATA(lx_batch_delete).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( table_name = ls_config-tablename success = abap_false message = lx_batch_delete->get_text( ) )
 ) TO result.
 ENDTRY.
 CONTINUE.
 ENDIF.

 DATA lo_rec TYPE REF TO data.
 CREATE DATA lo_rec TYPE HANDLE lo_desc.
 ASSIGN lo_rec->* TO FIELD-SYMBOL(<ls_rec>).

 zcl_dyn_record_handler=>deserialize(
 EXPORTING iv_json = CONV string( lv_record_key )
 CHANGING ca_record = lo_rec
 ).

 DATA(lt_keys) = zcl_dyn_record_handler=>get_key_fields(
   iv_table_name = ls_config-tablename ).
 DATA(lv_where) = zcl_dyn_record_handler=>build_where_clause(
 it_key_fields = lt_keys
 ir_record = lo_rec
 ).

 DATA lo_old TYPE REF TO data.
 CREATE DATA lo_old TYPE HANDLE lo_desc.
 ASSIGN lo_old->* TO FIELD-SYMBOL(<ls_old>).

 SELECT SINGLE * FROM (ls_config-tablename)
 WHERE (lv_where)
 INTO @<ls_old>.

 DATA(lv_old_json) = COND string(
 WHEN sy-subrc = 0 THEN zcl_dyn_record_handler=>serialize( <ls_old> )
 ELSE space
 ).

 DATA ls_aprvl TYPE zcl_aprvl_util=>ty_result.

 TRY.
 ls_aprvl = zcl_aprvl_util=>check_and_submit(
 iv_table_name = ls_config-tablename
 iv_action_type = 'D'
 iv_record_key = lv_record_key
 iv_old_data = lv_old_json
 ).
 CATCH zcx_excel_pipeline INTO DATA(lx_pending_delete).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = lx_pending_delete->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDTRY.

 IF ls_aprvl-needs_approval = abap_true.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_true
 message = ls_aprvl-message
 )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(ls_res) = zcl_dyn_record_handler=>delete_record(
 iv_table_name = ls_config-tablename
 iv_record_key = lv_record_key
 ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = ls_res-success
 message = ls_res-message
 )
 ) TO result.

 ENDLOOP.
 ENDMETHOD.

 METHOD filldescription.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 SELECT SINGLE ddtext FROM dd02t
 WHERE tabname = @ls_config-tablename
 AND ddlanguage = 'E'
 INTO @DATA(lv_ddtext).

 IF sy-subrc <> 0 OR lv_ddtext IS INITIAL.
 SELECT SINGLE ddtext FROM dd02t
 WHERE tabname = @ls_config-tablename
 INTO @lv_ddtext.
 ENDIF.

 IF sy-subrc = 0 AND lv_ddtext IS NOT INITIAL.
 MODIFY ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 UPDATE FIELDS ( description )
 WITH VALUE #( (
 %tky = ls_config-%tky
 description = lv_ddtext
 ) ).
 ENDIF.
 ENDLOOP.
 ENDMETHOD.

 METHOD fillfieldconfig.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename configuuid )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL OR ls_config-configuuid IS INITIAL. CONTINUE. ENDIF.

 SELECT fieldname, position, keyflag, inttype, rollname, domname, leng
 FROM dd03l
 WHERE tabname = @ls_config-tablename
 AND as4local = 'A'
 AND fieldname NOT LIKE '.%'
 INTO TABLE @DATA(lt_fields).

 SORT lt_fields BY position.

 SELECT field_name FROM zfld_config
 WHERE table_name = @ls_config-tablename
 INTO TABLE @DATA(lt_existing_fields).

 LOOP AT lt_fields INTO DATA(ls_field).
 READ TABLE lt_existing_fields TRANSPORTING NO FIELDS
 WITH KEY table_line = ls_field-fieldname.
 IF sy-subrc = 0. CONTINUE. ENDIF.

 DATA(lv_field_type) = SWITCH #( ls_field-inttype
 WHEN 'D' THEN 'DATE'
 WHEN 'X' THEN
 COND ztde_field_type(
 WHEN ls_field-domname CS 'UUID' THEN 'TEXT'
 WHEN ls_field-domname CS 'SYSUUID' THEN 'TEXT'
 WHEN ls_field-leng = 16 THEN 'TEXT'
 ELSE 'CHECK'
 )
 WHEN 'P' THEN 'TEXT'
 WHEN 'I' THEN 'TEXT'
 WHEN 'N' THEN 'TEXT'
 ELSE COND #(
 WHEN ls_field-domname IS NOT INITIAL THEN 'DOMAIN'
 ELSE 'TEXT'
 )
 ).

 DATA(lv_label) = CONV dd04t-reptext( '' ).
 IF ls_field-rollname IS NOT INITIAL.
 lv_label = get_label_from_dd04t( ls_field-rollname ).
 ENDIF.
 IF lv_label IS INITIAL. lv_label = ls_field-fieldname. ENDIF.

 TRY.
 INSERT zfld_config FROM @(
 VALUE zfld_config(
 table_name = ls_config-tablename
 field_name = ls_field-fieldname
 config_uuid = ls_config-configuuid
 field_type = lv_field_type
 domain_name = ls_field-domname
 mandatory_flag = ls_field-keyflag
 display_order = ls_field-position
 label_text = lv_label
 is_key_field = ls_field-keyflag
 )
 ).
 CATCH cx_sy_open_sql_db.
 ENDTRY.
 ENDLOOP.
 ENDLOOP.
 ENDMETHOD.

 METHOD filllabeltext.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY fldconfig
 FIELDS ( tablename fieldname labeltext )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_fields).

 LOOP AT lt_fields INTO DATA(ls_field).
 IF ls_field-labeltext IS NOT INITIAL. CONTINUE. ENDIF.

 SELECT SINGLE rollname FROM dd03l
 WHERE tabname = @ls_field-tablename
 AND fieldname = @ls_field-fieldname
 AND as4local = 'A'
 INTO @DATA(lv_rollname).

 IF sy-subrc <> 0 OR lv_rollname IS INITIAL. CONTINUE. ENDIF.

 DATA(lv_label) = get_label_from_dd04t( lv_rollname ).

 IF lv_label IS NOT INITIAL.
 MODIFY ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY fldconfig
 UPDATE FIELDS ( labeltext )
 WITH VALUE #( ( %tky = ls_field-%tky labeltext = lv_label ) ).
 ENDIF.
 ENDLOOP.
 ENDMETHOD.

 METHOD getdomainvalues.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 READ TABLE keys INTO DATA(ls_key)
 WITH KEY primary_key COMPONENTS %tky = ls_config-%tky.
 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(lv_domain_name) = ls_key-%param-domain_name.

 IF lv_domain_name IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
   domain_name = lv_domain_name
   error_msg   = NEW zcx_error( textid = zcx_error=>domain_name_empty )->get_text( ) )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(lt_values) = zcl_table_inspector=>get_domain_values( lv_domain_name ).

 IF lt_values IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 domain_name = lv_domain_name
 error_msg = NEW zcx_error(
               textid        = zcx_error=>no_values_found_for_domain
              iv_domain_name = CONV #( lv_domain_name ) )->get_text( )
               )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(lv_json) = /ui2/cl_json=>serialize(
 data = lt_values
 pretty_name = /ui2/cl_json=>pretty_mode-none
 ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #( domain_name = lv_domain_name values_json = lv_json )
 ) TO result.
 ENDLOOP.
 ENDMETHOD.

 METHOD getfieldmeta.

  READ ENTITIES OF zi_tbl_config IN LOCAL MODE
    ENTITY tblconfig
      FIELDS ( tablename )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_config).

  LOOP AT lt_config INTO DATA(ls_config).

    IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

    SELECT fieldname, position, keyflag, inttype, leng, decimals, rollname, domname
      FROM dd03l
      WHERE tabname  = @ls_config-tablename
        AND as4local = 'A'
        AND fieldname NOT LIKE '.%'
      ORDER BY position
      INTO TABLE @DATA(lt_dd03l).

    IF lt_dd03l IS INITIAL.

      APPEND VALUE #(
        %tky   = ls_config-%tky
        %param = VALUE #(
          table_name = ls_config-tablename
          error_msg  = NEW zcx_error(
                         textid        = zcx_error=>no_fields_found_for_table
                         iv_table_name = CONV #( ls_config-tablename ) )->get_text( ) )
      ) TO result.
      CONTINUE.
    ENDIF.

    SELECT field_name, label_text, hidden_flag, display_order, field_type, domain_name
      FROM zfld_config
      WHERE table_name = @ls_config-tablename
      INTO TABLE @DATA(lt_fld_config).

    " 1 SELECT cho toàn bộ FK field mappings của bảng, không SELECT trong loop
    " JOIN DD08L + DD05S (active):
    "   DD08L: TABNAME=bảng con, FIELDNAME=tên FK relationship, CHECKTABLE=bảng cha
    "   DD05S: FORKEY=field bên bảng con, FORTABLE=bảng cha
    SELECT DISTINCT dd05s~forkey, dd08l~checktable AS fortable
      FROM dd08l
      INNER JOIN dd05s
        ON  dd05s~tabname   = dd08l~tabname
        AND dd05s~fieldname = dd08l~fieldname
        AND dd05s~as4local  = dd08l~as4local
      WHERE dd08l~tabname    = @ls_config-tablename
        AND dd08l~as4local   = 'A'
        AND dd08l~checktable IS NOT INITIAL
      INTO TABLE @DATA(lt_fk_fields).

    TYPES: BEGIN OF ty_field_meta,
             field_name    TYPE string,
             abap_type     TYPE string,
             fe_type       TYPE string,   " 'fk_select' nếu FK key -> FE render dropdown
             length        TYPE i,
             decimals      TYPE i,
             is_key        TYPE abap_bool,
             is_mandatory  TYPE abap_bool,
             label         TYPE string,
             domain_name   TYPE string,
             display_order TYPE i,
             is_hidden     TYPE abap_bool,
             is_fk_key     TYPE abap_bool, " true -> FE gọi gettabledata(fk_ref_table)
             fk_ref_table  TYPE string,    " tên bảng cha (vd: ZTPC_HEADER)
           END OF ty_field_meta.

    DATA lt_meta TYPE TABLE OF ty_field_meta.

    LOOP AT lt_dd03l INTO DATA(ls_dd).

      IF ls_dd-fieldname = 'CLIENT' OR ls_dd-fieldname = 'MANDT'. CONTINUE. ENDIF.

      READ TABLE lt_fld_config INTO DATA(ls_fld_cfg)
        WITH KEY field_name = ls_dd-fieldname.
      DATA(lv_has_cfg) = COND abap_bool( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).

      DATA(lv_fe_type) = SWITCH string( ls_dd-inttype
        WHEN 'D' THEN 'date'
        WHEN 'T' THEN 'time'
        WHEN 'I' THEN 'integer'
        WHEN 'F' THEN 'decimal'
        WHEN 'P' THEN 'decimal'
        WHEN 'X' THEN COND string( WHEN ls_dd-leng = 1  THEN 'boolean'
                                   WHEN ls_dd-leng = 16 THEN 'uuid'
                                   ELSE 'text' )
        ELSE COND string( WHEN ls_dd-domname IS NOT INITIAL THEN 'domain'
                          ELSE 'text' )
      ).

      DATA lv_label TYPE string.
      IF lv_has_cfg = abap_true AND ls_fld_cfg-label_text IS NOT INITIAL.
        lv_label = ls_fld_cfg-label_text.
      ELSEIF ls_dd-rollname IS NOT INITIAL.
        lv_label = get_label_from_dd04t( ls_dd-rollname ).
      ENDIF.
      IF lv_label IS INITIAL. lv_label = ls_dd-fieldname. ENDIF.

      " FK lookup từ lt_fk_fields đã JOIN sẵn ở trên (không SELECT lại trong loop)
      DATA lv_is_fk_key    TYPE abap_bool VALUE abap_false.
      DATA lv_fk_ref_table TYPE string.

      IF ls_dd-keyflag = 'X'.
        READ TABLE lt_fk_fields INTO DATA(ls_fk)
          WITH KEY forkey = ls_dd-fieldname.
        IF sy-subrc = 0.
          lv_is_fk_key    = abap_true.
          lv_fk_ref_table = CONV string( ls_fk-fortable ).
          lv_fe_type      = 'fk_select'.
        ENDIF.
      ENDIF.

      APPEND VALUE ty_field_meta(
        field_name    = ls_dd-fieldname
        abap_type     = ls_dd-inttype
        fe_type       = lv_fe_type
        length        = ls_dd-leng
        decimals      = ls_dd-decimals
        is_key        = ls_dd-keyflag
        is_mandatory  = ls_dd-keyflag
        label         = lv_label
        domain_name   = COND #( WHEN lv_fe_type = 'domain' THEN ls_dd-domname ELSE `` )
        display_order = COND i( WHEN lv_has_cfg = abap_true THEN ls_fld_cfg-display_order
                                ELSE ls_dd-position )
        is_hidden     = COND abap_bool( WHEN lv_has_cfg = abap_true THEN ls_fld_cfg-hidden_flag
                                        ELSE abap_false )
        is_fk_key     = lv_is_fk_key
        fk_ref_table  = lv_fk_ref_table
      ) TO lt_meta.

    ENDLOOP.

    SORT lt_meta BY display_order.

    DATA(lv_meta_json) = /ui2/cl_json=>serialize(
      data        = lt_meta
      pretty_name = /ui2/cl_json=>pretty_mode-none
    ).

    APPEND VALUE #(
      %tky   = ls_config-%tky
      %param = VALUE #( table_name = ls_config-tablename
                        meta_json  = lv_meta_json )
    ) TO result.

  ENDLOOP.

ENDMETHOD.

 METHOD gettabledata.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 TRY.
 zcl_auth_helper=>check_permission(
 iv_table_name = CONV #( ls_config-tablename )
 iv_action     = zcl_auth_helper=>c_action-view ).
 CATCH zcx_excel_pipeline INTO DATA(lx_auth_view).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 error_msg = lx_auth_view->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDTRY.

 IF zcl_table_inspector=>table_exists( ls_config-tablename ) = abap_false.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 error_msg = NEW zcx_error(
               textid        = zcx_error=>table_not_found
              iv_table_name = CONV #( ls_config-tablename ) )->get_text( )
               )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(lt_fields) = zcl_table_inspector=>get_field_list( ls_config-tablename ).

 DATA lv_field_list TYPE string.
 LOOP AT lt_fields INTO DATA(ls_field).
 IF ls_field-hidden_flag = 'X'. CONTINUE. ENDIF.
 IF lv_field_list IS INITIAL.
 lv_field_list = ls_field-field_name.
 ELSE.
 lv_field_list = lv_field_list && ',' && ls_field-field_name.
 ENDIF.
 ENDLOOP.

 IF lv_field_list IS INITIAL.
 SELECT fieldname FROM dd03l
 WHERE tabname = @ls_config-tablename
 AND as4local = 'A'
 AND fieldname NOT LIKE '.%'
 ORDER BY position
 INTO TABLE @DATA(lt_dd03l_fields).

 LOOP AT lt_dd03l_fields INTO DATA(lv_dd03l_field).
 IF lv_field_list IS INITIAL.
 lv_field_list = CONV string( lv_dd03l_field ).
 ELSE.
 lv_field_list = lv_field_list && ',' && CONV string( lv_dd03l_field ).
 ENDIF.
 ENDLOOP.
 ENDIF.

 TRY.
 DATA(lo_data) = zcl_dyn_record_handler=>get_table_data(
 iv_table_name = ls_config-tablename
 iv_max_rows = 100
 ).

 ASSIGN lo_data->* TO FIELD-SYMBOL(<lt_data>).

 DATA(lv_json) = zcl_dyn_record_handler=>serialize( <lt_data> ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 field_list = lv_field_list
 data_json = lv_json
 total_rows = lines( <lt_data> )
 )
 ) TO result.

 CATCH cx_sy_dynamic_osql_error INTO DATA(lx_error).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 error_msg = lx_error->get_text( )
 )
 ) TO result.
 ENDTRY.

 ENDLOOP.
 ENDMETHOD.

 "───────────────────────────────────────────────────────────────────────
 " getrepositoryinfo — delegate sang zcl_repo_inventory
 "───────────────────────────────────────────────────────────────────────
 METHOD acquirelock.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 READ TABLE keys INTO DATA(ls_key)
 WITH KEY primary_key COMPONENTS %tky = ls_config-%tky.
 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(ls_param) = ls_key-%param.
 DATA(lv_scope) = COND ztde_lock_scope(
 WHEN ls_param-lock_scope IS INITIAL THEN zcl_table_lock=>c_scope-table
 ELSE ls_param-lock_scope ).
 DATA(lv_reason) = COND ztde_lock_reason(
 WHEN ls_param-lock_reason IS INITIAL THEN 'CRUD'
 ELSE ls_param-lock_reason ).
 DATA(lv_ttl) = COND i(
 WHEN ls_param-ttl_seconds > 0 THEN ls_param-ttl_seconds
 ELSE zcl_table_lock=>c_default_ttl_seconds ).
 DATA(lv_session_id) = ls_param-session_id.

 TRY.
 IF lv_session_id IS INITIAL.
 lv_session_id = cl_system_uuid=>create_uuid_c32_static( ).
 ENDIF.

 zcl_table_lock=>acquire_lock(
 iv_table_name  = CONV #( ls_config-tablename )
 iv_session_id  = lv_session_id
 iv_reason      = lv_reason
 iv_lock_scope  = lv_scope
 iv_record_key  = CONV #( ls_param-record_key )
 iv_ttl_seconds = lv_ttl ).

 SELECT SINGLE locked_by, expires_at
 FROM ztbl_lock
 WHERE table_name = @ls_config-tablename
 AND lock_scope = @lv_scope
 AND record_key = @ls_param-record_key
 AND session_id = @lv_session_id
 INTO @DATA(ls_lock).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 session_id = lv_session_id
 success = abap_true
message = NEW zcx_error( textid = zcx_error=>lock_acquired )->get_text( ) locked_by = ls_lock-locked_by
 expires_at = ls_lock-expires_at )
 ) TO result.


 CATCH zcx_excel_pipeline INTO DATA(lx_lock).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 session_id = lv_session_id
 success = abap_false
 message = lx_lock->get_text( )
 locked_by = lx_lock->mv_locked_by )
 ) TO result.
 CATCH cx_uuid_error INTO DATA(lx_uuid).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 session_id = lv_session_id
 success = abap_false
 message = lx_uuid->get_text( ) )
 ) TO result.
 ENDTRY.

 ENDLOOP.
 ENDMETHOD.

 METHOD heartbeat.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 READ TABLE keys INTO DATA(ls_key)
 WITH KEY primary_key COMPONENTS %tky = ls_config-%tky.
 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(ls_param) = ls_key-%param.
 DATA(lv_scope) = COND ztde_lock_scope(
 WHEN ls_param-lock_scope IS INITIAL THEN zcl_table_lock=>c_scope-table
 ELSE ls_param-lock_scope ).
 DATA(lv_ttl) = COND i(
 WHEN ls_param-ttl_seconds > 0 THEN ls_param-ttl_seconds
 ELSE zcl_table_lock=>c_default_ttl_seconds ).

 TRY.
 zcl_table_lock=>heartbeat(
 iv_table_name  = CONV #( ls_config-tablename )
 iv_session_id  = ls_param-session_id
 iv_lock_scope  = lv_scope
 iv_record_key  = CONV #( ls_param-record_key )
 iv_ttl_seconds = lv_ttl ).

 SELECT SINGLE locked_by, expires_at
 FROM ztbl_lock
 WHERE table_name = @ls_config-tablename
 AND lock_scope = @lv_scope
 AND record_key = @ls_param-record_key
 AND session_id = @ls_param-session_id
 INTO @DATA(ls_lock).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 session_id = ls_param-session_id
 success = abap_true
message = NEW zcx_error( textid = zcx_error=>lock_heartbeat_updated )->get_text( ) locked_by = ls_lock-locked_by
 expires_at = ls_lock-expires_at )
 ) TO result.

 CATCH zcx_excel_pipeline INTO DATA(lx_lock).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 session_id = ls_param-session_id
 success = abap_false
 message = lx_lock->get_text( )
 locked_by = lx_lock->mv_locked_by )
 ) TO result.
 ENDTRY.

 ENDLOOP.
 ENDMETHOD.

 METHOD releaselock.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 READ TABLE keys INTO DATA(ls_key)
 WITH KEY primary_key COMPONENTS %tky = ls_config-%tky.
 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(ls_param) = ls_key-%param.
 DATA(lv_scope) = COND ztde_lock_scope(
 WHEN ls_param-lock_scope IS INITIAL THEN zcl_table_lock=>c_scope-table
 ELSE ls_param-lock_scope ).

 TRY.
 zcl_table_lock=>release_lock(
 iv_table_name = CONV #( ls_config-tablename )
 iv_session_id = ls_param-session_id
 iv_lock_scope = lv_scope
 iv_record_key = CONV #( ls_param-record_key ) ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 session_id = ls_param-session_id
 success = abap_true
message = NEW zcx_error( textid = zcx_error=>lock_released )->get_text( ) )
 ) TO result.

 CATCH zcx_excel_pipeline INTO DATA(lx_lock).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 session_id = ls_param-session_id
 success = abap_false
 message = lx_lock->get_text( )
 locked_by = lx_lock->mv_locked_by )
 ) TO result.
 ENDTRY.

 ENDLOOP.
 ENDMETHOD.

 METHOD forceunlock.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL. CONTINUE. ENDIF.

 TRY.
 zcl_table_lock=>force_release(
 iv_table_name = CONV #( ls_config-tablename ) ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_true
 message = NEW zcx_error( textid = zcx_error=>locks_force_released )->get_text( ) )
 ) TO result.

 CATCH zcx_excel_pipeline INTO DATA(lx_auth).
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_config-tablename
 success = abap_false
 message = lx_auth->get_text( ) )
 ) TO result.
 ENDTRY.

 ENDLOOP.
 ENDMETHOD.

 METHOD getrepositoryinfo.
 READ ENTITIES OF zi_tbl_config IN LOCAL MODE
 ENTITY tblconfig
 FIELDS ( tablename )
 WITH CORRESPONDING #( keys )
 RESULT DATA(lt_config).

 LOOP AT lt_config INTO DATA(ls_config).
 IF ls_config-tablename IS INITIAL.
 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ''
 error_msg = NEW zcx_error( textid = zcx_error=>table_name_empty_on_config )->get_text( )
 )
 ) TO result.
 CONTINUE.
 ENDIF.

 DATA(ls_inv) = zcl_repo_inventory=>get_inventory( ls_config-tablename ).

 APPEND VALUE #(
 %tky = ls_config-%tky
 %param = VALUE #(
 table_name = ls_inv-table_name
 data_elements_json = ls_inv-data_elements_json
 search_helps_json = ls_inv-search_helps_json
 function_modules_json = ls_inv-function_modules_json
 cds_views_json = ls_inv-cds_views_json
 foreign_keys_json = ls_inv-foreign_keys_json
 error_msg = ls_inv-error_msg
 )
 ) TO result.
 ENDLOOP.
 ENDMETHOD.
METHOD getfkvalues.

  LOOP AT keys INTO DATA(ls_key).

    DATA(lv_child_table) = CONV tabname( ls_key-%param-table_name ).
    DATA(lv_fk_field)    = CONV fieldname( ls_key-%param-field_name ).

    IF lv_child_table IS INITIAL OR lv_fk_field IS INITIAL.
      APPEND VALUE #(
        %tky   = ls_key-%tky
        %param = VALUE #( error_msg = NEW zcx_error( textid = zcx_error=>table_field_name_required )->get_text( ) )
      ) TO result.
      CONTINUE.
    ENDIF.

    " ── Bước 1: Tra DD08L + DD05S tìm bảng cha ──────────────────────────
    DATA lv_ref_table TYPE tabname.

    SELECT SINGLE dd08l~checktable
      FROM dd08l
      INNER JOIN dd05s
        ON  dd05s~tabname   = dd08l~tabname
        AND dd05s~fieldname = dd08l~fieldname
        AND dd05s~as4local  = dd08l~as4local
      WHERE dd08l~tabname    = @lv_child_table
        AND dd08l~as4local   = 'A'
        AND dd08l~checktable IS NOT INITIAL
        AND dd05s~forkey     = @lv_fk_field
      INTO @lv_ref_table.

    IF sy-subrc <> 0 OR lv_ref_table IS INITIAL.
      APPEND VALUE #(
        %tky   = ls_key-%tky
        %param = VALUE #(
              error_msg = NEW zcx_error(
              textid        = zcx_error=>field_not_fk_in_table
              iv_field_name = CONV #( lv_fk_field )
              iv_table_name = CONV #( lv_child_table ) )->get_text( )
        )
      ) TO result.
      CONTINUE.
    ENDIF.

    " ── Bước 2: Tìm key_field (FORSTRING = field tương ứng bên bảng cha) ─
    DATA lv_key_field TYPE string.
    DATA lv_child_domain TYPE dd03l-domname.
    DATA lv_key_field_exists TYPE abap_bool.

    SELECT SINGLE dd05s~forstring
      FROM dd05s
      INNER JOIN dd08l
        ON  dd08l~tabname   = dd05s~tabname
        AND dd08l~fieldname = dd05s~fieldname
        AND dd08l~as4local  = dd05s~as4local
      WHERE dd05s~tabname   = @lv_child_table
        AND dd05s~as4local  = 'A'
        AND dd05s~forkey    = @lv_fk_field
      INTO @DATA(lv_forstring).

    IF sy-subrc = 0 AND lv_forstring IS NOT INITIAL.
      lv_key_field = lv_forstring.
      CLEAR lv_key_field_exists.
      SELECT SINGLE @abap_true
        FROM dd03l
        WHERE tabname   = @lv_ref_table
          AND fieldname = @lv_key_field
          AND as4local  = 'A'
        INTO @lv_key_field_exists.
      IF lv_key_field_exists <> abap_true.
        CLEAR lv_key_field.
      ENDIF.
    ENDIF.

    IF lv_key_field IS INITIAL.
      CLEAR lv_child_domain.
      SELECT SINGLE dd04l~domname
        FROM dd03l
        INNER JOIN dd04l
          ON  dd04l~rollname = dd03l~rollname
          AND dd04l~as4local = dd03l~as4local
        WHERE dd03l~tabname   = @lv_child_table
          AND dd03l~fieldname = @lv_fk_field
          AND dd03l~as4local  = 'A'
        INTO @lv_child_domain.

      IF lv_child_domain IS NOT INITIAL.
        SELECT SINGLE dd03l~fieldname
          FROM dd03l
          INNER JOIN dd04l
            ON  dd04l~rollname = dd03l~rollname
            AND dd04l~as4local = dd03l~as4local
          WHERE dd03l~tabname   = @lv_ref_table
            AND dd03l~keyflag   = 'X'
            AND dd03l~as4local  = 'A'
            AND dd03l~fieldname <> 'MANDT'
            AND dd03l~fieldname <> 'CLIENT'
            AND dd04l~domname   = @lv_child_domain
          INTO @lv_key_field.
      ENDIF.
    ENDIF.

    IF lv_key_field IS INITIAL.
      DATA(lt_pk) = zcl_dyn_record_handler=>get_key_fields(
        iv_table_name = lv_ref_table ).
      LOOP AT lt_pk INTO DATA(lv_pk_field).
        IF lv_pk_field = 'MANDT' OR lv_pk_field = 'CLIENT'.
          CONTINUE.
        ENDIF.
        lv_key_field = lv_pk_field.
        EXIT.
      ENDLOOP.
    ENDIF.

    " ── Bước 3: Tìm display_field ────────────────────────────────────────
    DATA lv_display_field TYPE string.

    SELECT fieldname, inttype, leng
      FROM dd03l
      WHERE tabname   = @lv_ref_table
        AND as4local  = 'A'
        AND keyflag   = ''
        AND fieldname <> 'CLIENT'
        AND fieldname <> 'MANDT'
        AND fieldname NOT LIKE '.%'
      ORDER BY position
      INTO TABLE @DATA(lt_ref_fields).

    LOOP AT lt_ref_fields INTO DATA(ls_ref).
      IF ls_ref-inttype = 'C' AND ls_ref-leng <> 32.
        lv_display_field = ls_ref-fieldname.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_display_field IS INITIAL AND lt_ref_fields IS NOT INITIAL.
      lv_display_field = lt_ref_fields[ 1 ]-fieldname.
    ENDIF.

    " ── Bước 4: Đọc data từ bảng cha ────────────────────────────────────
    TRY.
        DATA(lo_data) = zcl_dyn_record_handler=>get_table_data(
          iv_table_name = lv_ref_table
          iv_max_rows   = 200
        ).

        ASSIGN lo_data->* TO FIELD-SYMBOL(<lt_data>).
        DATA(lv_json) = zcl_dyn_record_handler=>serialize( <lt_data> ).

        APPEND VALUE #(
          %tky   = ls_key-%tky
          %param = VALUE #(
            table_name    = ls_key-%param-table_name
            field_name    = ls_key-%param-field_name
            ref_table     = CONV string( lv_ref_table )
            data_json     = lv_json
            display_field = lv_display_field
            key_field     = lv_key_field
          )
        ) TO result.

      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        APPEND VALUE #(
          %tky   = ls_key-%tky
          %param = VALUE #( error_msg = lx_sql->get_text( ) )
        ) TO result.

      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE #(
          %tky   = ls_key-%tky
          %param = VALUE #( error_msg = lx_root->get_text( ) )
        ) TO result.
    ENDTRY.

  ENDLOOP.

ENDMETHOD.



METHOD getaidescription.

  LOOP AT keys INTO DATA(ls_key).

    DATA(lv_table) = CONV tabname( ls_key-%param-table_name ).

    IF lv_table IS INITIAL.
      APPEND VALUE #(
        %tky   = ls_key-%tky
        %param = VALUE #( error_msg = NEW zcx_error( textid = zcx_error=>table_name_required )->get_text( ) )
      ) TO result.
      CONTINUE.
    ENDIF.

    " Kiểm tra bảng có tồn tại không
    IF zcl_table_inspector=>table_exists( lv_table ) = abap_false.
      APPEND VALUE #(
        %tky   = ls_key-%tky
        %param = VALUE #(
        " table_not_found
error_msg = NEW zcx_error(
              textid       = zcx_error=>table_not_found
              iv_table_name = CONV #( lv_table ) )->get_text( )
        )
      ) TO result.
      CONTINUE.
    ENDIF.

    TRY.
        " Gọi AI để lấy mô tả
        DATA(lt_descriptions) = zcl_ai_field_describer=>describe_table( lv_table ).

        IF lt_descriptions IS INITIAL.
          APPEND VALUE #(
            %tky   = ls_key-%tky
            %param = VALUE #( error_msg = NEW zcx_error( textid = zcx_error=>ai_returned_empty_response )->get_text( ) )
          ) TO result.
          CONTINUE.
        ENDIF.

        " Serialize thành JSON trả về FE
        DATA(lv_json) = /ui2/cl_json=>serialize(
          data        = lt_descriptions
          pretty_name = /ui2/cl_json=>pretty_mode-none
        ).

        APPEND VALUE #(
          %tky   = ls_key-%tky
          %param = VALUE #(
            table_name  = ls_key-%param-table_name
            result_json = lv_json
          )
        ) TO result.

      CATCH cx_root INTO DATA(lx).
        APPEND VALUE #(
          %tky   = ls_key-%tky
          %param = VALUE #( error_msg = lx->get_text( ) )
        ) TO result.
    ENDTRY.

  ENDLOOP.

ENDMETHOD.
ENDCLASS.
