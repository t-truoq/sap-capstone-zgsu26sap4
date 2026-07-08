@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Auth Admin - Users'
@Metadata.ignorePropagatedAnnotations: false
@UI.headerInfo: {
  typeName: 'User',
  typeNamePlural: 'Users',
  title: { type: #STANDARD, value: 'Username' }
}
define root view entity ZC_AUTH_USER
  provider contract transactional_query
  as projection on ZI_AUTH_USER
{
  @UI.facet: [
    {
      id: 'General',
      type: #IDENTIFICATION_REFERENCE,
      label: 'User',
      position: 10
    }
  ]
  @UI.lineItem: [{ position: 10, label: 'User' }]
  @UI.selectionField: [{ position: 10 }]
  @UI.identification: [{ position: 10, label: 'User' }]
  key Username,

  @UI.lineItem: [{ position: 20, label: 'Role' }]
  @UI.selectionField: [{ position: 20 }]
  @UI.identification: [{ position: 20, label: 'Role' }]
      RoleType,

  @UI.lineItem: [{ position: 30, label: 'Active' }]
  @UI.identification: [{ position: 30, label: 'Active' }]
      ActiveFlag
}
