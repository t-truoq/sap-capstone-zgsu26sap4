@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
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
  @Consumption.valueHelpDefinition: [{
    entity: {
      name: 'ZI_YESNO_VH',
      element: 'FlagValue'
    },
    useForValidation: true
  }]
      CanView,

  @UI.lineItem: [{ position: 30, label: 'Create' }]
  @UI.identification: [{ position: 30, label: 'Create' }]
  @Consumption.valueHelpDefinition: [{
    entity: {
      name: 'ZI_YESNO_VH',
      element: 'FlagValue'
    },
    useForValidation: true
  }]
      CanCreate,

  @UI.lineItem: [{ position: 40, label: 'Update' }]
  @UI.identification: [{ position: 40, label: 'Update' }]
  @Consumption.valueHelpDefinition: [{
    entity: {
      name: 'ZI_YESNO_VH',
      element: 'FlagValue'
    },
    useForValidation: true
  }]
      CanUpdate,

  @UI.lineItem: [{ position: 50, label: 'Delete' }]
  @UI.identification: [{ position: 50, label: 'Delete' }]
  @Consumption.valueHelpDefinition: [{
    entity: {
      name: 'ZI_YESNO_VH',
      element: 'FlagValue'
    },
    useForValidation: true
  }]
      CanDelete,

  @Consumption.hidden: true
      _AdminAccess
}
