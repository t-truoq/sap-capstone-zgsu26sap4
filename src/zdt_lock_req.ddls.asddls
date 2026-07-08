@EndUserText.label: 'Lock Action Request'
define abstract entity ZDT_LOCK_REQ
{
  session_id  : sysuuid_c32;
  lock_scope  : ztde_lock_scope;
  record_key  : ztde_record_key;
  lock_reason : ztde_lock_reason;
  ttl_seconds : abap.int4;
}
