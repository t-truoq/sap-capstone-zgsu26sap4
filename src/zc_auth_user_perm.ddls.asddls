@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Auth Admin - User Permissions'
@Metadata.ignorePropagatedAnnotations: false
@UI.headerInfo: {
  typeName: 'User Permission',
  typeNamePlural: 'User Permissions',
  title: { type: #STANDARD, value: 'Username' },
  description: { type: #STANDARD, value: 'TableName' }
}
define root view entity ZC_AUTH_USER_PERM
  provider contract transactional_query
  as projection on ZI_AUTH_USER_PERM
{
  @UI.facet: [
    {
      id: 'General',
      type: #IDENTIFICATION_REFERENCE,
      label: 'Permission',
      position: 10
    }
  ]
  @UI.lineItem: [{ position: 10, label: 'User' }]
  @UI.selectionField: [{ position: 10 }]
  @UI.identification: [{ position: 10, label: 'User' }]
  key Username,

  @UI.lineItem: [{ position: 20, label: 'Table' }]
  @UI.selectionField: [{ position: 20 }]
  @UI.identification: [{ position: 20, label: 'Table' }]
  key TableName,

  @UI.lineItem: [{ position: 30, label: 'View' }]
  @UI.identification: [{ position: 30, label: 'View' }]
      CanView,

  @UI.lineItem: [{ position: 40, label: 'Create' }]
  @UI.identification: [{ position: 40, label: 'Create' }]
      CanCreate,

  @UI.lineItem: [{ position: 50, label: 'Update' }]
  @UI.identification: [{ position: 50, label: 'Update' }]
      CanUpdate,

  @UI.lineItem: [{ position: 60, label: 'Delete' }]
  @UI.identification: [{ position: 60, label: 'Delete' }]
      CanDelete,

  @UI.lineItem: [{ position: 70, label: 'Upload' }]
  @UI.identification: [{ position: 70, label: 'Upload' }]
      CanUpload
}
