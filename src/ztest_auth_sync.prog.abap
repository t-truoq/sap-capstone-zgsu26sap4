REPORT ztest_auth_sync.

DATA(lv_count) = zcl_auth_permission_sync=>sync_all_users_from_db( ).

COMMIT WORK.

WRITE: / |Synced authorization permissions for { lv_count } users.|.
