@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Audit Log Items'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: {
  typeName: 'Audit Item',
  typeNamePlural: 'Audit Items',
  title: { value: 'ItemNo' },
  description: { value: 'ActionType' }
}
define view entity ZC_TBL_AUDIT_ITEM
  as projection on ZI_TBL_AUDIT_ITEM
{
  @UI.facet: [
    {
      id: 'ItemDetail',
      type: #IDENTIFICATION_REFERENCE,
      label: 'Audit Item Detail',
      position: 10
    }
  ]

  @UI.identification: [{ position: 10, label: 'Audit ID' }]
  key AuditId,

  @UI.lineItem: [{ position: 10, label: 'Item' }]
  @UI.identification: [{ position: 20, label: 'Item' }]
  key ItemNo,

  @UI.lineItem: [{ position: 20, label: 'Action' }]
  @UI.identification: [{ position: 30, label: 'Action' }]
      ActionType,

  @UI.lineItem: [{ position: 30, label: 'Record Key' }]
  @UI.identification: [{ position: 40, label: 'Record Key' }]
      RecordKey,

  @UI.lineItem: [{ position: 40, label: 'Field' }]
  @UI.identification: [{ position: 50, label: 'Field' }]
      FieldName,

  @UI.lineItem: [{ position: 50, label: 'Old Value' }]
  @UI.identification: [{ position: 60, label: 'Old Value' }]
      OldValue,

  @UI.lineItem: [{ position: 60, label: 'New Value' }]
  @UI.identification: [{ position: 70, label: 'New Value' }]
      NewValue,

      TableName,

      _AuditLog : redirected to parent ZC_TBL_AUDIT
}
