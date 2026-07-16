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
  @UI.lineItem: [
    { position: 10, label: 'Audit ID' },
    { type: #FOR_ACTION, dataAction: 'rollback', label: 'Rollback', position: 100 }
  ]
  @UI.selectionField: [{ position: 10 }]
  key AuditId,

  @UI.lineItem: [{ position: 20, label: 'Table Name' }]
  @UI.selectionField: [{ position: 20 }]
      TableName,

  @UI.lineItem: [{ position: 30, label: 'Record Key' }]
      RecordKey,

  @UI.lineItem: [{ position: 40, label: 'Field Name' }]
  @UI.selectionField: [{ position: 40 }]
      FieldName,

  @UI.lineItem: [{ position: 50, label: 'Old Value' }]
      OldValue,

  @UI.lineItem: [{ position: 60, label: 'New Value' }]
      NewValue,

  @UI.lineItem: [{ position: 70, label: 'Changed By' }]
  @UI.selectionField: [{ position: 70 }]
      ChangedBy,

  @UI.lineItem: [{ position: 80, label: 'Changed At' }]
      ChangedAt,

  @UI.lineItem: [{ position: 90, label: 'Action Type' }]
  @UI.selectionField: [{ position: 90 }]
      ActionType
}
