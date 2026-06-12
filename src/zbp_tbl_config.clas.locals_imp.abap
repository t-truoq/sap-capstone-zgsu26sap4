CLASS lhc_tblconfig DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "── TblConfig handlers ── (giữ nguyên khai báo)
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

    "── FldConfig handlers ── (giữ nguyên khai báo)
    METHODS validatedisplayorder FOR VALIDATE ON SAVE
      IMPORTING keys FOR fldconfig~validatedisplayorder.
    METHODS validatedomainname FOR VALIDATE ON SAVE
      IMPORTING keys FOR fldconfig~validatedomainname.
    METHODS filllabeltext FOR DETERMINE ON MODIFY
      IMPORTING keys FOR fldconfig~filllabeltext.

    "── Private helper còn lại (chỉ cái chưa tách) ──
    METHODS get_label_from_dd04t
      IMPORTING iv_rollname    TYPE rollname
      RETURNING VALUE(rv_label) TYPE dd04t-reptext.

ENDCLASS.

CLASS lhc_tblconfig IMPLEMENTATION.

  "═══════════════════════════════════════════════════════════════════════
  " Các method giữ nguyên hoàn toàn (copy từ code cũ):
  "   get_instance_authorizations, validatefldconfig, validatetablename,
  "   filldescription, fillfieldconfig, getfieldmeta, gettabledata,
  "   getdomainvalues, validatedisplayorder, validatedomainname,
  "   filllabeltext, get_label_from_dd04t
  "═══════════════════════════════════════════════════════════════════════
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
          %tky     = ls_field-%tky
          %msg     = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = 'Domain Name is required when Field Type is DOMAIN' )
          %element = VALUE #( domainname = if_abap_behv=>mk-on )
        ) TO reported-fldconfig.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD validatefldconfig.
  ENDMETHOD.
  METHOD get_instance_authorizations.
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
          %tky     = ls_config-%tky
          %msg     = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = 'Table Name cannot be empty' )
          %element = VALUE #( tablename = if_abap_behv=>mk-on )
        ) TO reported-tblconfig.
        CONTINUE.
      ENDIF.

      IF ls_config-tablename(1) <> 'Z' AND ls_config-tablename(1) <> 'Y'.
        APPEND VALUE #( %tky = ls_config-%tky ) TO failed-tblconfig.
        APPEND VALUE #(
          %tky     = ls_config-%tky
          %msg     = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = 'Only Z/Y tables are allowed' )
          %element = VALUE #( tablename = if_abap_behv=>mk-on )
        ) TO reported-tblconfig.
        CONTINUE.
      ENDIF.

      SELECT SINGLE tabname FROM dd02l
        WHERE tabname  = @ls_config-tablename
          AND tabclass = 'TRANSP'
          AND as4local = 'A'
        INTO @DATA(lv_tabname).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_config-%tky ) TO failed-tblconfig.
        APPEND VALUE #(
          %tky     = ls_config-%tky
          %msg     = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Table { ls_config-tablename } does not exist| )
          %element = VALUE #( tablename = if_abap_behv=>mk-on )
        ) TO reported-tblconfig.
        CONTINUE.
      ENDIF.

      SELECT SINGLE table_name FROM ztbl_config
        WHERE table_name  = @ls_config-tablename
          AND config_uuid <> @ls_config-configuuid
        INTO @DATA(lv_existing).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls_config-%tky ) TO failed-tblconfig.
        APPEND VALUE #(
          %tky     = ls_config-%tky
          %msg     = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Table { ls_config-tablename } is already registered| )
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
        WHERE table_name    = @ls_field-tablename
          AND display_order = @ls_field-displayorder
          AND field_name   <> @ls_field-fieldname
        INTO @DATA(lv_exists).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls_field-%tky ) TO failed-fldconfig.
        APPEND VALUE #(
          %tky     = ls_field-%tky
          %msg     = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Display Order { ls_field-displayorder } already used in { ls_field-tablename }| )
          %element = VALUE #( displayorder = if_abap_behv=>mk-on )
        ) TO reported-fldconfig.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


 METHOD get_label_from_dd04t.
    SELECT SINGLE reptext FROM dd04t
      WHERE rollname   = @iv_rollname
        AND ddlanguage = @sy-langu
      INTO @rv_label.
    IF rv_label IS NOT INITIAL. RETURN. ENDIF.

    IF sy-langu <> 'E'.
      SELECT SINGLE reptext FROM dd04t
        WHERE rollname   = @iv_rollname
          AND ddlanguage = 'E'
        INTO @rv_label.
      IF rv_label IS NOT INITIAL. RETURN. ENDIF.
    ENDIF.

    SELECT SINGLE reptext FROM dd04t
      WHERE rollname = @iv_rollname
      INTO @rv_label.
  ENDMETHOD.

  "───────────────────────────────────────────────────────────────────────
  " createrecord — delegate sang zcl_approval_guard + zcl_dyn_record_handler
  "───────────────────────────────────────────────────────────────────────
  METHOD createrecord.
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

      DATA(lv_record_data) = ls_key-%param-record_data.

      IF lv_record_data IS INITIAL.
        APPEND VALUE #(
          %tky   = ls_config-%tky
          %param = VALUE #(
            table_name = ls_config-tablename
            success    = abap_false
            message    = 'Record data is empty'
          )
        ) TO result.
        CONTINUE.
      ENDIF.

      "── Approval check ──
      DATA(ls_aprvl) = zcl_approval_guard=>check_and_submit(
        iv_table_name  = ls_config-tablename
        iv_action_type = 'C'
        iv_record_key  = ''
        iv_new_data    = lv_record_data
      ).

      IF ls_aprvl-needs_approval = abap_true.
        APPEND VALUE #(
          %tky   = ls_config-%tky
          %param = VALUE #(
            table_name = ls_config-tablename
            success    = abap_true
            message    = ls_aprvl-message
          )
        ) TO result.
        CONTINUE.
      ENDIF.

      "── Ghi DB trực tiếp ──
      DATA(ls_res) = zcl_dyn_record_handler=>create_record(
        iv_table_name  = ls_config-tablename
        iv_record_data = lv_record_data
      ).

      APPEND VALUE #(
        %tky   = ls_config-%tky
        %param = VALUE #(
          table_name = ls_config-tablename
          success    = ls_res-success
          message    = ls_res-message
        )
      ) TO result.

    ENDLOOP.
  ENDMETHOD.

  "───────────────────────────────────────────────────────────────────────
  " updaterecord — delegate sang zcl_approval_guard + zcl_dyn_record_handler
  "───────────────────────────────────────────────────────────────────────
  METHOD updaterecord.
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

    DATA(lv_record_data) = ls_key-%param-record_data.

    " ── 1. Đọc old record TRƯỚC KHI gọi approval ──
    TRY.
      DATA(lo_desc) = CAST cl_abap_structdescr(
        cl_abap_typedescr=>describe_by_name( ls_config-tablename )
      ).
    CATCH cx_root.
      APPEND VALUE #(
        %tky   = ls_config-%tky
        %param = VALUE #(
          table_name = ls_config-tablename
          success    = abap_false
          message    = 'Invalid table'
        )
      ) TO result.
      CONTINUE.
    ENDTRY.

    " Deserialize record để lấy key
    DATA lo_new TYPE REF TO data.
    CREATE DATA lo_new TYPE HANDLE lo_desc.
    ASSIGN lo_new->* TO FIELD-SYMBOL(<ls_new>).

    zcl_json_helper=>deserialize(
      EXPORTING iv_json   = lv_record_data
      CHANGING  ca_record = lo_new
    ).

    " Build WHERE clause từ key fields
    DATA(lt_keys) = zcl_dynamic_table_reader=>get_key_fields( ls_config-tablename ).
    DATA(lv_where) = zcl_record_key_builder=>build_where_clause(
      it_key_fields = lt_keys
      ir_record     = lo_new
    ).

    " Select old record
    DATA lo_old TYPE REF TO data.
    CREATE DATA lo_old TYPE HANDLE lo_desc.
    ASSIGN lo_old->* TO FIELD-SYMBOL(<ls_old>).

    SELECT SINGLE * FROM (ls_config-tablename)
      WHERE (lv_where)
      INTO @<ls_old>.

    DATA(lv_old_json) = COND string(
      WHEN sy-subrc = 0 THEN zcl_json_helper=>serialize( <ls_old> )
      ELSE space
    ).

    " Build record_key
    DATA(lv_record_key) = zcl_record_key_builder=>build_key_json(
      it_key_fields = lt_keys
      ir_record     = lo_new
    ).

    " ── 2. Gọi approval với đủ old_data + new_data ──
    DATA(ls_aprvl) = zcl_approval_guard=>check_and_submit(
      iv_table_name  = ls_config-tablename
      iv_action_type = 'U'
      iv_record_key  = CONV #( lv_record_key )
      iv_new_data    = lv_record_data
      iv_old_data    = lv_old_json
    ).

    IF ls_aprvl-needs_approval = abap_true.
      APPEND VALUE #(
        %tky   = ls_config-%tky
        %param = VALUE #(
          table_name = ls_config-tablename
          success    = abap_true
          message    = ls_aprvl-message
        )
      ) TO result.
      CONTINUE.
    ENDIF.

    " ── 3. Ghi DB trực tiếp (không cần approval) ──
    DATA(lv_etag_field) = CONV string( ls_key-%param-etag_field ).
    DATA(lv_etag_value) = CONV string( ls_key-%param-etag_value ).

    DATA(ls_res) = zcl_dyn_record_handler=>update_record(
      iv_table_name  = ls_config-tablename
      iv_record_data = lv_record_data
      iv_etag_field  = lv_etag_field
      iv_etag_value  = lv_etag_value
    ).

    APPEND VALUE #(
      %tky   = ls_config-%tky
      %param = VALUE #(
        table_name = ls_config-tablename
        success    = ls_res-success
        message    = ls_res-message
      )
    ) TO result.

  ENDLOOP.
ENDMETHOD.

  "───────────────────────────────────────────────────────────────────────
  " deleterecord — delegate sang zcl_approval_guard + zcl_dyn_record_handler
  "───────────────────────────────────────────────────────────────────────
 METHOD deleterecord.
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

    DATA(lv_record_key) = ls_key-%param-record_key.

    " ── 1. Đọc old record TRƯỚC KHI gọi approval ──
    TRY.
      DATA(lo_desc) = CAST cl_abap_structdescr(
        cl_abap_typedescr=>describe_by_name( ls_config-tablename )
      ).
    CATCH cx_root.
      APPEND VALUE #(
        %tky   = ls_config-%tky
        %param = VALUE #(
          table_name = ls_config-tablename
          success    = abap_false
          message    = 'Invalid table'
        )
      ) TO result.
      CONTINUE.
    ENDTRY.

    " Deserialize record_key để lấy key fields
    DATA lo_rec TYPE REF TO data.
    CREATE DATA lo_rec TYPE HANDLE lo_desc.
    ASSIGN lo_rec->* TO FIELD-SYMBOL(<ls_rec>).

    zcl_json_helper=>deserialize(
      EXPORTING iv_json   = CONV string( lv_record_key )
      CHANGING  ca_record = lo_rec
    ).

    " Build WHERE clause
    DATA(lt_keys) = zcl_dynamic_table_reader=>get_key_fields( ls_config-tablename ).
    DATA(lv_where) = zcl_record_key_builder=>build_where_clause(
      it_key_fields = lt_keys
      ir_record     = lo_rec
    ).

    " Select old record cho approval
    DATA lo_old TYPE REF TO data.
    CREATE DATA lo_old TYPE HANDLE lo_desc.
    ASSIGN lo_old->* TO FIELD-SYMBOL(<ls_old>).

    SELECT SINGLE * FROM (ls_config-tablename)
      WHERE (lv_where)
      INTO @<ls_old>.

    DATA(lv_old_json) = COND string(
      WHEN sy-subrc = 0 THEN zcl_json_helper=>serialize( <ls_old> )
      ELSE space
    ).

    " ── 2. Gọi approval với old_data ──
    DATA(ls_aprvl) = zcl_approval_guard=>check_and_submit(
      iv_table_name  = ls_config-tablename
      iv_action_type = 'D'
      iv_record_key  = lv_record_key
      iv_old_data    = lv_old_json
    ).

    IF ls_aprvl-needs_approval = abap_true.
      APPEND VALUE #(
        %tky   = ls_config-%tky
        %param = VALUE #(
          table_name = ls_config-tablename
          success    = abap_true
          message    = ls_aprvl-message
        )
      ) TO result.
      CONTINUE.
    ENDIF.

    " ── 3. Ghi DB trực tiếp (không cần approval) ──
    DATA(ls_res) = zcl_dyn_record_handler=>delete_record(
      iv_table_name = ls_config-tablename
      iv_record_key = lv_record_key
    ).

    APPEND VALUE #(
      %tky   = ls_config-%tky
      %param = VALUE #(
        table_name = ls_config-tablename
        success    = ls_res-success
        message    = ls_res-message
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
        WHERE tabname    = @ls_config-tablename
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
              %tky        = ls_config-%tky
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
        WHERE tabname  = @ls_config-tablename
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
              WHEN ls_field-domname CS 'UUID'    THEN 'TEXT'
              WHEN ls_field-domname CS 'SYSUUID' THEN 'TEXT'
              WHEN ls_field-leng    =  16        THEN 'TEXT'
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
                table_name     = ls_config-tablename
                field_name     = ls_field-fieldname
                config_uuid    = ls_config-configuuid
                field_type     = lv_field_type
                domain_name    = ls_field-domname
                mandatory_flag = ls_field-keyflag
                display_order  = ls_field-position
                label_text     = lv_label
                is_key_field   = ls_field-keyflag
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
        WHERE tabname   = @ls_field-tablename
          AND fieldname = @ls_field-fieldname
          AND as4local  = 'A'
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
          %tky   = ls_config-%tky
          %param = VALUE #( domain_name = lv_domain_name error_msg = 'Domain name is empty' )
        ) TO result.
        CONTINUE.
      ENDIF.

      DATA(lt_values) = zcl_table_inspector=>get_domain_values( lv_domain_name ).

      IF lt_values IS INITIAL.
        APPEND VALUE #(
          %tky   = ls_config-%tky
          %param = VALUE #(
            domain_name = lv_domain_name
            error_msg   = |No values found for domain { lv_domain_name }|
          )
        ) TO result.
        CONTINUE.
      ENDIF.

      " Domain values chỉ gồm CHAR fields → serialize thẳng
      DATA(lv_json) = /ui2/cl_json=>serialize(
        data        = lt_values
        pretty_name = /ui2/cl_json=>pretty_mode-none
      ).

      APPEND VALUE #(
        %tky   = ls_config-%tky
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

      " ── Đọc DD03L — giống SM30 đọc table structure trước khi render ──
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
            error_msg  = |No fields found for table { ls_config-tablename }|
          )
        ) TO result.
        CONTINUE.
      ENDIF.

      " ── Đọc field config (label, hidden, display order) từ zfld_config ──
      SELECT field_name, label_text, hidden_flag, display_order, field_type, domain_name
        FROM zfld_config
        WHERE table_name = @ls_config-tablename
        INTO TABLE @DATA(lt_fld_config).

      " ── Build metadata cho từng field ──
      " Dùng string để serialize vì metadata chỉ gồm CHAR/INT fields
      " → /ui2/cl_json serialize hoàn toàn clean, không cần zcl_json_helper
      TYPES: BEGIN OF ty_field_meta,
               field_name    TYPE string,
               abap_type     TYPE string,   " C, D, X, N, P, I, F...
               fe_type       TYPE string,   " text | date | uuid | boolean | decimal | integer | domain
               length        TYPE i,
               decimals      TYPE i,
               is_key        TYPE abap_bool,
               is_mandatory  TYPE abap_bool,
               label         TYPE string,
               domain_name   TYPE string,
               display_order TYPE i,
               is_hidden     TYPE abap_bool,
             END OF ty_field_meta.
      DATA lt_meta TYPE TABLE OF ty_field_meta.

      LOOP AT lt_dd03l INTO DATA(ls_dd).
        " Skip CLIENT field — giống SM30 không show Mandant field
        IF ls_dd-fieldname = 'CLIENT' OR ls_dd-fieldname = 'MANDT'. CONTINUE. ENDIF.

        " Lấy config từ zfld_config nếu có
        READ TABLE lt_fld_config INTO DATA(ls_fld_cfg)
          WITH KEY field_name = ls_dd-fieldname.
        DATA(lv_has_cfg) = COND abap_bool( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).

        " ── Map ABAP inttype → fe_type ──
        " SM30 approach: type_kind quyết định cách render, không guess
        DATA(lv_fe_type) = SWITCH string( ls_dd-inttype
          WHEN 'D' THEN 'date'
          WHEN 'T' THEN 'time'
          WHEN 'I' THEN 'integer'
          WHEN 'F' THEN 'decimal'
          WHEN 'P' THEN 'decimal'
          WHEN 'X' THEN
            COND string(
              WHEN ls_dd-leng = 1  THEN 'boolean'  " X(1) = checkbox
              WHEN ls_dd-leng = 16 THEN 'uuid'      " RAW16 = UUID
              ELSE                      'text'       " RAW khác → hex string
            )
          ELSE COND string(
            WHEN ls_dd-domname IS NOT INITIAL THEN 'domain'
            ELSE                                   'text'
          )
        ).

        " Lấy label: ưu tiên zfld_config → DD04T → fieldname
        DATA lv_label TYPE string.
        IF lv_has_cfg = abap_true AND ls_fld_cfg-label_text IS NOT INITIAL.
          lv_label = ls_fld_cfg-label_text.
        ELSEIF ls_dd-rollname IS NOT INITIAL.
          lv_label = get_label_from_dd04t( ls_dd-rollname ).
        ENDIF.
        IF lv_label IS INITIAL. lv_label = ls_dd-fieldname. ENDIF.

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
        ) TO lt_meta.
      ENDLOOP.

      " Sort theo display_order (giống SM30 sort fields by position)
      SORT lt_meta BY display_order.

      " Serialize metadata — chỉ gồm CHAR/INT/BOOL, không có RAW
      " → /ui2/cl_json serialize thẳng, không cần zcl_json_helper
      DATA(lv_meta_json) = /ui2/cl_json=>serialize(
        data        = lt_meta
        pretty_name = /ui2/cl_json=>pretty_mode-none
      ).

      APPEND VALUE #(
        %tky   = ls_config-%tky
        %param = VALUE #(
          table_name = ls_config-tablename
          meta_json  = lv_meta_json
        )
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

      IF zcl_table_inspector=>table_exists( ls_config-tablename ) = abap_false.
        APPEND VALUE #(
          %tky   = ls_config-%tky
          %param = VALUE #(
            table_name = ls_config-tablename
            error_msg  = |Table { ls_config-tablename } does not exist|
          )
        ) TO result.
        CONTINUE.
      ENDIF.

      DATA(lt_fields) = zcl_table_inspector=>get_field_list( ls_config-tablename ).

      " Build field list (bỏ hidden fields)
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
          WHERE tabname  = @ls_config-tablename
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
          DATA(lo_data) = zcl_dynamic_table_reader=>get_table_data(
            iv_table_name = ls_config-tablename
            iv_max_rows   = 100
          ).

          ASSIGN lo_data->* TO FIELD-SYMBOL(<lt_data>).

          " zcl_json_helper đảm bảo UUID/RAW → hex string UPPERCASE cho FE
          DATA(lv_json) = zcl_json_helper=>serialize( <lt_data> ).

          APPEND VALUE #(
            %tky   = ls_config-%tky
            %param = VALUE #(
              table_name = ls_config-tablename
              field_list = lv_field_list
              data_json  = lv_json
              total_rows = lines( <lt_data> )
            )
          ) TO result.

        CATCH cx_sy_dynamic_osql_error INTO DATA(lx_error).
          APPEND VALUE #(
            %tky   = ls_config-%tky
            %param = VALUE #(
              table_name = ls_config-tablename
              error_msg  = lx_error->get_text( )
            )
          ) TO result.
      ENDTRY.

    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
