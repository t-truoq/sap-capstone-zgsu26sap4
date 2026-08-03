
CLASS zcx_excel_pipeline DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.

    CONSTANTS:
      BEGIN OF rollback_already_done,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '000',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF rollback_already_done,

      BEGIN OF already_rolled_back_by,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_ROLLBACK_AUDIT_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF already_rolled_back_by,

      BEGIN OF preflight_check_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE 'MV_PREFLIGHT_ERROR',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF preflight_check_failed,

      BEGIN OF row_validation_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF row_validation_failed,

      BEGIN OF cannot_build_crud_key,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cannot_build_crud_key,

      BEGIN OF pending_approval_conflict,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE 'MV_SUBMITTED_BY',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pending_approval_conflict,

      BEGIN OF user_not_found_or_inactive,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE 'MV_USERNAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF user_not_found_or_inactive,

      BEGIN OF no_permission_on_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '007',
        attr1 TYPE scx_attrname VALUE 'MV_USERNAME',
        attr2 TYPE scx_attrname VALUE 'MV_ACTION',
        attr3 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_permission_on_table,

      BEGIN OF action_admin_only,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '008',
        attr1 TYPE scx_attrname VALUE 'MV_ACTION',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF action_admin_only,

      BEGIN OF no_record_found,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '009',
        attr1 TYPE scx_attrname VALUE 'MV_WHERE_CLAUSE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_record_found,

      BEGIN OF unsupported_bulk_action,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE 'MV_ACTION_TYPE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF unsupported_bulk_action,

      BEGIN OF bulk_item_error,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_item_error,

      BEGIN OF table_not_configured,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '012',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_not_configured,

      BEGIN OF no_importable_key_field,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '013',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_importable_key_field,

      BEGIN OF record_created_after_preview,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '014',
        attr1 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_created_after_preview,

      BEGIN OF record_no_longer_exists,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '015',
        attr1 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_no_longer_exists,

      BEGIN OF record_changed_after_preview,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '016',
        attr1 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_changed_after_preview,

      BEGIN OF snapshot_read_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '017',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF snapshot_read_failed,

      BEGIN OF excel_read_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '018',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_read_failed,

      BEGIN OF excel_table_mismatch,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '019',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_table_mismatch,

      BEGIN OF excel_missing_key_columns,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_MISSING_KEYS',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_missing_key_columns,

      BEGIN OF excel_wrong_source_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE 'MV_SOURCE_TABLE',
        attr2 TYPE scx_attrname VALUE 'MV_CURRENT_TABLE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_wrong_source_table,

      BEGIN OF excel_file_empty,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '022',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_file_empty,

      BEGIN OF table_name_empty,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '023',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_name_empty,

      BEGIN OF only_z_tables_allowed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '024',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF only_z_tables_allowed,

      BEGIN OF table_not_found,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '025',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_not_found,

      BEGIN OF table_data_read_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '026',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_data_read_failed,

      BEGIN OF excel_build_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '027',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_build_failed,

      BEGIN OF diff_json_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '028',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF diff_json_invalid,

      BEGIN OF record_key_json_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '029',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_key_json_invalid,

      BEGIN OF where_from_record_key_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '030',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF where_from_record_key_failed,

      BEGIN OF field_assignment_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '031',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_assignment_failed,

      BEGIN OF generated_record_key_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '032',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF generated_record_key_invalid,

      BEGIN OF copy_db_row_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '033',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF copy_db_row_failed,

      BEGIN OF approval_data_empty,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '034',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF approval_data_empty,

      BEGIN OF approval_deserialize_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '035',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF approval_deserialize_failed,
      BEGIN OF approval_data_field_mismatch,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '036',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF approval_data_field_mismatch,

      BEGIN OF table_locked_by,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '037',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_LOCKED_BY',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_locked_by,

      BEGIN OF lock_session_missing,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '038',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_session_missing,

      BEGIN OF lock_owned_by_other_user,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '039',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_LOCKED_BY',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_owned_by_other_user,

      BEGIN OF lock_expired_or_missing,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '040',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_expired_or_missing,

      BEGIN OF lock_not_held_by_caller,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '041',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_not_held_by_caller.

    METHODS constructor
      IMPORTING
        textid                LIKE if_t100_message=>t100key OPTIONAL
        previous              LIKE previous OPTIONAL
        iv_text               TYPE string  OPTIONAL
        iv_rollback_audit_id  TYPE string  OPTIONAL
        iv_preflight_error    TYPE string  OPTIONAL
        iv_item_no            TYPE string  OPTIONAL
        iv_message            TYPE string  OPTIONAL
        iv_submitted_by       TYPE syuname OPTIONAL
        iv_username           TYPE syuname OPTIONAL
        iv_action              TYPE string  OPTIONAL
        iv_table_name          TYPE string  OPTIONAL
        iv_where_clause        TYPE string  OPTIONAL
        iv_action_type         TYPE string  OPTIONAL
        iv_record_key          TYPE string  OPTIONAL
        iv_missing_keys        TYPE string  OPTIONAL
        iv_source_table        TYPE string  OPTIONAL
        iv_current_table       TYPE string  OPTIONAL
        iv_locked_by           TYPE syuname OPTIONAL.

    METHODS get_text REDEFINITION.

    DATA mv_submitted_by      TYPE syuname READ-ONLY.
    DATA mv_locked_by         TYPE syuname READ-ONLY.
    DATA mv_rollback_audit_id TYPE string  READ-ONLY.
    DATA mv_preflight_error   TYPE string  READ-ONLY.
    DATA mv_item_no           TYPE string  READ-ONLY.
    DATA mv_message           TYPE string  READ-ONLY.
    DATA mv_username          TYPE syuname READ-ONLY.
    DATA mv_action            TYPE string  READ-ONLY.
    DATA mv_table_name        TYPE string  READ-ONLY.
    DATA mv_where_clause      TYPE string  READ-ONLY.
    DATA mv_action_type       TYPE string  READ-ONLY.
    DATA mv_record_key        TYPE string  READ-ONLY.
    DATA mv_missing_keys      TYPE string  READ-ONLY.
    DATA mv_source_table      TYPE string  READ-ONLY.
    DATA mv_current_table     TYPE string  READ-ONLY.

  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.


CLASS zcx_excel_pipeline IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    mv_text               = iv_text.
    mv_rollback_audit_id  = iv_rollback_audit_id.
    mv_preflight_error    = iv_preflight_error.
    mv_item_no            = iv_item_no.
    mv_message            = iv_message.
    mv_submitted_by       = iv_submitted_by.
    mv_username           = iv_username.
    mv_action             = iv_action.
    mv_table_name         = iv_table_name.
    mv_where_clause       = iv_where_clause.
    mv_action_type        = iv_action_type.
    mv_record_key         = iv_record_key.
    mv_missing_keys       = iv_missing_keys.
    mv_source_table       = iv_source_table.
    mv_current_table      = iv_current_table.
    mv_locked_by          = iv_locked_by.

    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

  METHOD get_text.
    result = COND #( WHEN mv_text IS NOT INITIAL
                     THEN mv_text
                     ELSE super->get_text( ) ).
  ENDMETHOD.

ENDCLASS.
