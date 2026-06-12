CLASS zcl_audit_logger DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS:
      log_change
        IMPORTING
          iv_table_name  TYPE ztde_table_name
          iv_record_key  TYPE ztde_record_key
          iv_field_name  TYPE ztde_field_name OPTIONAL
          iv_old_value   TYPE string OPTIONAL
          iv_new_value   TYPE string OPTIONAL
          iv_action_type TYPE ztde_action_type.

ENDCLASS.

CLASS zcl_audit_logger IMPLEMENTATION.

  METHOD log_change.
    TRY.
        DATA(lv_audit_id) = cl_system_uuid=>create_uuid_c32_static( ).

        INSERT ztbl_audit FROM @(
          VALUE ztbl_audit(
            audit_id    = lv_audit_id
            table_name  = iv_table_name
            record_key  = iv_record_key
            field_name  = iv_field_name
            old_value   = CONV #( iv_old_value )
            new_value   = CONV #( iv_new_value )
            changed_by  = sy-uname
            changed_at  = utclong_current( )
            action_type = iv_action_type
          )
        ).

      CATCH cx_uuid_error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
