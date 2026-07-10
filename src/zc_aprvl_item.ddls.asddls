@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval Request Items'
@Metadata.ignorePropagatedAnnotations: true

@UI.headerInfo: {
  typeName: 'Approval Item',
  typeNamePlural: 'Approval Items',
  title: { value: 'ItemNo' },
  description: { value: 'ActionType' }
}

define view entity ZC_APRVL_ITEM
  as projection on ZI_APRVL_ITEM
{
  @UI.facet: [
    {
      id:       'ItemDetail',
      type:     #IDENTIFICATION_REFERENCE,
      label:    'Approval Item Detail',
      position: 10
    }
  ]

  @UI.identification: [{ position: 10, label: 'Approval ID' }]
  key AprvlId,

  @UI.lineItem: [{ position: 10, label: 'Item' }]
  @UI.identification: [{ position: 20, label: 'Item' }]
  key ItemNo,

  @UI.lineItem: [{ position: 20, label: 'Action' }]
  @UI.identification: [{ position: 40, label: 'Action Type' }]
      ActionType,

  @UI.identification: [{ position: 30, label: 'Table Name' }]
      TableName,

  @UI.lineItem: [{ position: 30, label: 'Record Key' }]
  @UI.identification: [{ position: 50, label: 'Record Key' }]
      RecordKey,

  @UI.lineItem: [{ position: 40, label: 'Status' }]
  @UI.identification: [{ position: 60, label: 'Status' }]
      Status,

  @UI.lineItem: [{ position: 50, label: 'Message' }]
  @UI.identification: [{ position: 90, label: 'Message' }]
      Message,

  @EndUserText.label: 'Old Data (JSON)'
  @UI.lineItem: [{ position: 60, label: 'Old Data (JSON)' }]
  @UI.identification: [{ position: 70, label: 'Old Data (JSON)' }]
      OldData,

  @EndUserText.label: 'New Data (JSON)'
  @UI.lineItem: [{ position: 70, label: 'New Data (JSON)' }]
  @UI.identification: [{ position: 80, label: 'New Data (JSON)' }]
      NewData,

  _AprvlRequest : redirected to parent ZC_APRVL_REQUEST
}
