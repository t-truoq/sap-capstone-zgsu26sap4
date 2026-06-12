@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for Table Config'
@Metadata.ignorePropagatedAnnotations: false
@UI.headerInfo: {
  typeName: 'Table Config',
  typeNamePlural: 'Table Configs',
  title: { type: #STANDARD, value: 'TableName' }
}
define root view entity ZC_TBL_CONFIG
  provider contract transactional_query
  as projection on ZI_TBL_CONFIG
{
  @UI.facet: [
    {
      id: 'GeneralData',
      type: #IDENTIFICATION_REFERENCE,
      label: 'General Information',
      position: 10
    },
    {
      id: 'FieldConfig',
      type: #LINEITEM_REFERENCE,
      label: 'Field Configuration',
      position: 20,
      targetElement: '_FieldConfig'
    }
  ]
  @UI.hidden: true
  key ConfigUuid,

  @UI.lineItem: [{ position: 10, label: 'Table Name' }]
  @UI.selectionField: [{ position: 10 }]
  @UI.identification: [{ position: 10, label: 'Table Name' }]
  @Consumption.valueHelpDefinition: [{
    entity: {
      name: 'ZI_SH_TABLE_NAME',
      element: 'TableName'
    },
    label: 'Table Name',
    useForValidation: true
  }]
      TableName,

  @UI.lineItem: [{ position: 20, label: 'Description' }]
  @UI.identification: [{ position: 20, label: 'Description' }]
      Description,

  @UI.lineItem: [{ position: 30, label: 'Approval Required' }]
  @UI.identification: [{ position: 30, label: 'Approval Required' }]
      ApprovalRequired,

  @UI.lineItem: [{ position: 40, label: 'Active Flag' }]
  @UI.identification: [{ position: 40, label: 'Active Flag' }]
      ActiveFlag,

      _FieldConfig : redirected to composition child ZC_FLD_CONFIG
}
