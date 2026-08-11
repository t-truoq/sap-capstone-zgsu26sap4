CLASS zcx_error DEFINITION
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
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
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
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_data_read_failed,

      BEGIN OF excel_build_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '027',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
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
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
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
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_assignment_failed,

      BEGIN OF generated_record_key_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '032',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF generated_record_key_invalid,

      BEGIN OF copy_db_row_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '033',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
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
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
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
      END OF lock_not_held_by_caller,

      BEGIN OF table_not_active,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '042',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_not_active,

      BEGIN OF table_not_enabled_for_action,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '043',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_ACTION',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_not_enabled_for_action,

      BEGIN OF excel_save_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '044',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_save_failed,

      BEGIN OF new_data_missing_req_field,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '045',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF new_data_missing_req_field,

      BEGIN OF table_already_registered,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '046',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_already_registered,

      BEGIN OF display_order_already_used,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '047',
        attr1 TYPE scx_attrname VALUE 'MV_DISPLAY_ORDER',
        attr2 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF display_order_already_used,

      BEGIN OF domain_name_required,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '048',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF domain_name_required,

      BEGIN OF record_data_empty,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '049',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_data_empty,

      BEGIN OF records_data_empty_or_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '050',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF records_data_empty_or_invalid,

      BEGIN OF invalid_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '051',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_table,

      BEGIN OF record_key_empty,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '052',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_key_empty,

      BEGIN OF record_key_data_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '053',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_key_data_invalid,

      BEGIN OF domain_name_empty,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '054',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF domain_name_empty,

      BEGIN OF no_values_found_for_domain,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '055',
        attr1 TYPE scx_attrname VALUE 'MV_DOMAIN_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_values_found_for_domain,

      BEGIN OF no_fields_found_for_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '056',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_fields_found_for_table,

      BEGIN OF table_field_name_required,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '057',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_field_name_required,

      BEGIN OF field_not_fk_in_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '058',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_not_fk_in_table,

      BEGIN OF table_name_required,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '059',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_name_required,

      BEGIN OF ai_returned_empty_response,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '060',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF ai_returned_empty_response,

      BEGIN OF table_name_empty_on_config,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '061',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_name_empty_on_config,

      "── lock + bulk status messages ──
      BEGIN OF lock_acquired,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '062',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_acquired,

      BEGIN OF lock_heartbeat_updated,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '063',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_heartbeat_updated,

      BEGIN OF lock_released,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '064',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_released,

      BEGIN OF locks_force_released,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '065',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF locks_force_released,

      BEGIN OF created_n_records,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '066',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF created_n_records,

      BEGIN OF updated_n_records,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '067',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF updated_n_records,

      BEGIN OF deleted_n_records,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '068',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF deleted_n_records,

      BEGIN OF skipped_row,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '069',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF skipped_row,

      BEGIN OF item_error,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '070',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_error,

      "══════════════════════════════════════════════════════
      "── NEW: zcl_excel_pipeline free-text -> T100 migration (071-124) ──
      "══════════════════════════════════════════════════════

      "-- submit_bulk --
      BEGIN OF no_records_to_submit,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '071',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_records_to_submit,

      BEGIN OF item_skipped_duplicate,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '072',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_skipped_duplicate,

      BEGIN OF item_skipped_pending,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '073',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_skipped_pending,

      BEGIN OF bulk_approval_summary,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '074',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_approval_summary,

      BEGIN OF item_submitted,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '075',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_submitted,

      BEGIN OF bulk_submitted_ok,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '076',
        attr1 TYPE scx_attrname VALUE 'MV_APRVL_ID',
        attr2 TYPE scx_attrname VALUE 'MV_COUNT',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_submitted_ok,

      BEGIN OF bulk_partial_skip,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '077',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_partial_skip,

      "-- approve_bulk --
      BEGIN OF bulk_request_not_found,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '078',
        attr1 TYPE scx_attrname VALUE 'MV_APRVL_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_request_not_found,

      BEGIN OF bulk_request_not_pending,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '079',
        attr1 TYPE scx_attrname VALUE 'MV_APRVL_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_request_not_pending,

      BEGIN OF bulk_request_no_items,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '080',
        attr1 TYPE scx_attrname VALUE 'MV_APRVL_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_request_no_items,

      BEGIN OF applied_successfully,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '081',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF applied_successfully,

      BEGIN OF bulk_approved_ok,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '082',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_approved_ok,

      BEGIN OF bulk_approve_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '083',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_approve_failed,

      "-- reject_bulk --
      BEGIN OF rejected_by_admin,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '084',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF rejected_by_admin,

      BEGIN OF bulk_reject_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '085',
        attr1 TYPE scx_attrname VALUE 'MV_APRVL_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_reject_failed,

      BEGIN OF bulk_rejected_ok,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '086',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_rejected_ok,

      "-- build_diff --
      BEGIN OF duplicate_key_in_file,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '087',
        attr1 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr2 TYPE scx_attrname VALUE 'MV_COUNT',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF duplicate_key_in_file,

      BEGIN OF invalid_action_value,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '088',
        attr1 TYPE scx_attrname VALUE 'MV_ACTION',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_action_value,

      BEGIN OF cannot_identify_delete_row,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '089',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cannot_identify_delete_row,

      BEGIN OF record_marked_delete,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '090',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_marked_delete,

      BEGIN OF delete_row_not_matching,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '091',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF delete_row_not_matching,

      BEGIN OF missing_key_value_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '092',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_key_value_table,

      BEGIN OF cannot_identify_target_row,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '093',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cannot_identify_target_row,

      BEGIN OF entity_id_not_found,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '094',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF entity_id_not_found,

      BEGIN OF db_read_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '095',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF db_read_failed,

      BEGIN OF no_changes_detected,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '096',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_changes_detected,

      "-- get_key_problem --
      BEGIN OF entity_id_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '097',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF entity_id_invalid,

      BEGIN OF missing_fk_key_value,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '098',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_fk_key_value,

      BEGIN OF table_key_mismatch,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '099',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_MISSING_KEYS',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_key_mismatch,

      BEGIN OF missing_key_values,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '100',
        attr1 TYPE scx_attrname VALUE 'MV_MISSING_KEYS',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_key_values,

      "-- validate_row --
      BEGIN OF field_required,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '101',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_required,

      BEGIN OF field_exceeds_length,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '102',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_COUNT',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_exceeds_length,

      BEGIN OF field_invalid_date,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '103',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_invalid_date,

      BEGIN OF field_invalid_domain,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '104',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE 'MV_DOMAIN_NAME',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_invalid_domain,

      BEGIN OF field_fk_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '105',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_fk_invalid,

      BEGIN OF date_range_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '106',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_FIELD_NAME2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF date_range_invalid,

      "-- apply_diff_import --
      BEGIN OF no_commit_groups_built,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '107',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_commit_groups_built,

      BEGIN OF no_diff_rows_for_commit,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '108',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_diff_rows_for_commit,

      BEGIN OF no_valid_rows_submitted,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '109',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_valid_rows_submitted,

      BEGIN OF bulk_commit_summary,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '110',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE 'MV_COUNT2',
        attr3 TYPE scx_attrname VALUE 'MV_COUNT3',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_commit_summary,

      BEGIN OF row_no_valid_field_update,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '111',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF row_no_valid_field_update,

      BEGIN OF row_delete_blocked,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '112',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF row_delete_blocked,

      BEGIN OF row_record_not_found_delete,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '113',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF row_record_not_found_delete,

      BEGIN OF commit_done_summary,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '114',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE 'MV_COUNT2',
        attr3 TYPE scx_attrname VALUE 'MV_COUNT3',
        attr4 TYPE scx_attrname VALUE '',
      END OF commit_done_summary,

      "-- submit_groups --
      BEGIN OF row_submit_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '115',
        attr1 TYPE scx_attrname VALUE 'MV_ITEM_NO',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE 'MV_MESSAGE2',
        attr4 TYPE scx_attrname VALUE '',
      END OF row_submit_failed,

      BEGIN OF no_valid_row_to_submit,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '116',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_valid_row_to_submit,

      BEGIN OF bulk_submit_failed,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '117',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bulk_submit_failed,

      "-- map_columns --
      BEGIN OF column_duplicate_map,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '118',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_FIELD_NAME2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF column_duplicate_map,

      BEGIN OF column_not_in_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '119',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF column_not_in_table,

      BEGIN OF column_readonly_hidden,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '120',
        attr1 TYPE scx_attrname VALUE 'MV_FIELD_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_FIELD_NAME2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF column_readonly_hidden,

      "-- parse_excel --
      BEGIN OF excel_no_data_rows,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '121',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_no_data_rows,

      BEGIN OF cell_ignored_wrong_table,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '122',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cell_ignored_wrong_table,

      BEGIN OF cell_ignored_outside_header,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '123',
        attr1 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cell_ignored_outside_header,

      BEGIN OF excel_parsed_rows,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '124',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF excel_parsed_rows,

      "-- download_excel / upload_excel / run_confirm_import --
      BEGIN OF download_ok,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '125',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF download_ok,

      BEGIN OF upload_parsed_info,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '126',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF upload_parsed_info,

      BEGIN OF commit_ok_summary,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '127',
        attr1 TYPE scx_attrname VALUE 'MV_COUNT',
        attr2 TYPE scx_attrname VALUE 'MV_COUNT2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF commit_ok_summary,

      BEGIN OF record_created_ok,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '128',
        attr1 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_created_ok,

      BEGIN OF insert_failed_subrc,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '129',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE 'MV_MESSAGE',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF insert_failed_subrc,

      BEGIN OF record_updated_ok,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '130',
        attr1 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_updated_ok,

      BEGIN OF record_still_referenced,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '131',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_still_referenced,

      BEGIN OF record_deleted_ok,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '132',
        attr1 TYPE scx_attrname VALUE 'MV_RECORD_KEY',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF record_deleted_ok,

      BEGIN OF json_array_invalid,
        msgid TYPE symsgid VALUE 'Z_GSU26SAP04',
        msgno TYPE symsgno VALUE '133',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF json_array_invalid.

    METHODS constructor
      IMPORTING
        textid                LIKE if_t100_message=>t100key OPTIONAL
        previous              LIKE previous OPTIONAL
        iv_text               TYPE string  OPTIONAL
        iv_rollback_audit_id  TYPE string  OPTIONAL
        iv_preflight_error    TYPE string  OPTIONAL
        iv_item_no            TYPE string  OPTIONAL
        iv_message             TYPE string  OPTIONAL
        iv_submitted_by         TYPE syuname OPTIONAL
        iv_username              TYPE syuname OPTIONAL
        iv_action                TYPE string  OPTIONAL
        iv_table_name            TYPE string  OPTIONAL
        iv_where_clause          TYPE string  OPTIONAL
        iv_action_type           TYPE string  OPTIONAL
        iv_record_key            TYPE string  OPTIONAL
        iv_missing_keys          TYPE string  OPTIONAL
        iv_source_table          TYPE string  OPTIONAL
        iv_current_table         TYPE string  OPTIONAL
        iv_locked_by             TYPE syuname OPTIONAL
        iv_display_order         TYPE string  OPTIONAL
        iv_domain_name           TYPE string  OPTIONAL
        iv_field_name            TYPE string  OPTIONAL
        iv_count                 TYPE string  OPTIONAL
        "── NEW params for 071-127 ──
        iv_aprvl_id               TYPE string  OPTIONAL
        iv_field_name2            TYPE string  OPTIONAL
        iv_message2               TYPE string  OPTIONAL
        iv_count2                 TYPE string  OPTIONAL
        iv_count3                 TYPE string  OPTIONAL.

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
    DATA mv_display_order     TYPE string  READ-ONLY.
    DATA mv_domain_name       TYPE string  READ-ONLY.
    DATA mv_field_name        TYPE string  READ-ONLY.
    DATA mv_count             TYPE string  READ-ONLY.
    "── NEW attributes ──
    DATA mv_aprvl_id          TYPE string  READ-ONLY.
    DATA mv_field_name2       TYPE string  READ-ONLY.
    DATA mv_message2          TYPE string  READ-ONLY.
    DATA mv_count2            TYPE string  READ-ONLY.
    DATA mv_count3            TYPE string  READ-ONLY.

  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.


CLASS zcx_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    mv_text               = iv_text.
    mv_rollback_audit_id  = iv_rollback_audit_id.
    mv_preflight_error    = iv_preflight_error.
    mv_item_no            = iv_item_no.
    mv_message             = iv_message.
    mv_submitted_by         = iv_submitted_by.
    mv_username             = iv_username.
    mv_action               = iv_action.
    mv_table_name           = iv_table_name.
    mv_where_clause         = iv_where_clause.
    mv_action_type          = iv_action_type.
    mv_record_key           = iv_record_key.
    mv_missing_keys         = iv_missing_keys.
    mv_source_table         = iv_source_table.
    mv_current_table        = iv_current_table.
    mv_locked_by            = iv_locked_by.
    mv_display_order        = iv_display_order.
    mv_domain_name          = iv_domain_name.
    mv_field_name           = iv_field_name.
    mv_count                = iv_count.
    "── NEW ──
    mv_aprvl_id              = iv_aprvl_id.
    mv_field_name2           = iv_field_name2.
    mv_message2              = iv_message2.
    mv_count2                = iv_count2.
    mv_count3                = iv_count3.

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


