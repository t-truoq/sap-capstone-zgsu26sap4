@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for Aprvl Request'
@Metadata.ignorePropagatedAnnotations: true

@UI.headerInfo: {
  typeName: 'Approval Request',
  typeNamePlural: 'Approval Requests',
  title: { value: 'TableName' },
  description: { value: 'ActionType' }
}

define root view entity ZC_APRVL_REQUEST
  provider contract transactional_query
  as projection on ZI_APRVL_REQUEST
{
  @UI.facet: [
    {
      id:       'General',
      type:     #IDENTIFICATION_REFERENCE,
      label:    'Request Detail',
      position: 10
    }
  ]

  @UI.lineItem: [
    { position: 10, label: 'Aprvl ID' },
    { type: #FOR_ACTION, dataAction: 'approve', label: 'Approve', position: 80, emphasized: true },
    { type: #FOR_ACTION, dataAction: 'reject',  label: 'Reject',  position: 90 }
  ]
  @UI.identification: [
    { position: 10 },
    { type: #FOR_ACTION, dataAction: 'approve', label: 'Approve', position: 20, emphasized: true },
    { type: #FOR_ACTION, dataAction: 'reject',  label: 'Reject',  position: 30 }
  ]
  @UI.selectionField: [{ position: 10 }]
  key AprvlId,

  @UI.lineItem:       [{ position: 20, label: 'Table Name' }]
  @UI.selectionField: [{ position: 20 }]
      TableName,

  @UI.lineItem:       [{ position: 30, label: 'Action' }]
  @UI.identification: [{ position: 10, label: 'Record Key' }]
      RecordKey,

  @UI.lineItem:       [{ position: 40, label: 'Action Type' }]
      ActionType,

  @UI.lineItem:       [{ position: 50, label: 'Status' }]
  @UI.selectionField: [{ position: 40 }]
      Status,

  @UI.lineItem:       [{ position: 60, label: 'Submitted By' }]
      SubmittedBy,

  @UI.lineItem:       [{ position: 70, label: 'Submitted At' }]
      SubmittedAt,

  @UI.identification: [
    { position: 20, label: 'New Data (JSON)' }
  ]
      NewData,

  @UI.identification: [{ position: 30, label: 'Old Data (JSON)' }]
      OldData,

  -- Nút Approve + Reject trên detail page
  @UI.identification: [
    { type: #FOR_ACTION, dataAction: 'approve', label: 'Approve',
      position: 70, emphasized: true },
    { type: #FOR_ACTION, dataAction: 'reject',  label: 'Reject',
      position: 80 }
  ]
      ApprovedBy,

  @UI.identification: [{ position: 50, label: 'Approved At' }]
      ApprovedAt,

  @UI.identification: [{ position: 60, label: 'Comment' }]
      AprvlComment
}
