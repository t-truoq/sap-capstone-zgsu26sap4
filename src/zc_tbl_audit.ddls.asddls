@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for Audit Log'
@Metadata.ignorePropagatedAnnotations: false
@UI.headerInfo: {
  typeName: 'Audit Log',
  typeNamePlural: 'Audit Logs',
  title: { type: #STANDARD, value: 'AuditId' }
}
define root view entity ZC_TBL_AUDIT
  provider contract transactional_query
  as projection on ZI_TBL_AUDIT
{
  @UI.facet: [
    {
      id: 'Detail',
      type: #IDENTIFICATION_REFERENCE,
      label: 'Audit Detail',
      position: 10
    },
    {
      id: 'Items',
      type: #LINEITEM_REFERENCE,
      label: 'Audit Items',
      position: 20,
      targetElement: '_Items'
    }
  ]
  @UI.lineItem: [
    { position: 10, label: 'Audit ID' },
    { type: #FOR_ACTION, dataAction: 'rollback', label: 'Rollback', position: 100 }
  ]
  @UI.identification: [
    { position: 10, label: 'Audit ID' },
    { type: #FOR_ACTION, dataAction: 'rollback', label: 'Rollback', position: 100, emphasized: true }
  ]
  @UI.selectionField: [{ position: 10 }]
  key AuditId,

  @UI.lineItem: [{ position: 20, label: 'Table Name' }]
  @UI.identification: [{ position: 20, label: 'Table Name' }]
  @UI.selectionField: [{ position: 20 }]
      TableName,

  @UI.lineItem: [{ position: 30, label: 'Record Key' }]
  @UI.identification: [{ position: 30, label: 'Record Key' }]
      RecordKey,

  @UI.lineItem: [{ position: 40, label: 'Field Name' }]
  @UI.identification: [{ position: 40, label: 'Field Name' }]
  @UI.selectionField: [{ position: 40 }]
      FieldName,

  @UI.lineItem: [{ position: 50, label: 'Old Value' }]
  @UI.identification: [{ position: 50, label: 'Old Value' }]
      OldValue,

  @UI.lineItem: [{ position: 60, label: 'New Value' }]
  @UI.identification: [{ position: 60, label: 'New Value' }]
      NewValue,

  @UI.lineItem: [{ position: 70, label: 'Changed By' }]
  @UI.identification: [{ position: 70, label: 'Changed By' }]
  @UI.selectionField: [{ position: 70 }]
      ChangedBy,

  @UI.lineItem: [{ position: 80, label: 'Changed At' }]
  @UI.identification: [{ position: 80, label: 'Changed At' }]
      ChangedAt,

  @UI.lineItem: [{ position: 90, label: 'Action Type' }]
  @UI.identification: [{ position: 90, label: 'Action Type' }]
  @UI.selectionField: [{ position: 90 }]
      ActionType,

  @UI.lineItem: [{ position: 95, label: 'Rollback Audit ID' }]
  @UI.identification: [{ position: 95, label: 'Rollback Audit ID' }]
      RollbackAuditId,

      _Items : redirected to composition child ZC_TBL_AUDIT_ITEM
}
