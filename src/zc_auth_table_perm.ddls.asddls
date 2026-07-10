@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Auth Admin - Table Permissions'
@Metadata.ignorePropagatedAnnotations: false
@UI.headerInfo: {
  typeName: 'Table Permission',
  typeNamePlural: 'Table Permissions',
  title: { type: #STANDARD, value: 'TableName' }
}
define root view entity ZC_AUTH_TABLE_PERM
  provider contract transactional_query
  as projection on ZI_AUTH_TABLE_PERM
{
  @UI.facet: [
    {
      id: 'General',
      type: #IDENTIFICATION_REFERENCE,
      label: 'Table Permission',
      position: 10
    }
  ]
  @UI.lineItem: [{ position: 10, label: 'Table' }]
  @UI.selectionField: [{ position: 10 }]
  @UI.identification: [{ position: 10, label: 'Table' }]
  key TableName,

  @UI.lineItem: [{ position: 20, label: 'View' }]
  @UI.identification: [{ position: 20, label: 'View' }]
      CanView,

  @UI.lineItem: [{ position: 30, label: 'Create' }]
  @UI.identification: [{ position: 30, label: 'Create' }]
      CanCreate,

  @UI.lineItem: [{ position: 40, label: 'Update' }]
  @UI.identification: [{ position: 40, label: 'Update' }]
      CanUpdate,

  @UI.lineItem: [{ position: 50, label: 'Delete' }]
  @UI.identification: [{ position: 50, label: 'Delete' }]
      CanDelete,

  @UI.lineItem: [{ position: 60, label: 'Upload' }]
  @UI.identification: [{ position: 60, label: 'Upload' }]
      CanUpload,

  @Consumption.hidden: true
      _AdminAccess
}
