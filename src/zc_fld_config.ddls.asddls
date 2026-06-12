@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for Field Config'
@Metadata.ignorePropagatedAnnotations: false
@UI.headerInfo: {
  typeName: 'Field Config',
  typeNamePlural: 'Field Configs',
  title: { type: #STANDARD, value: 'FieldName' }
}
define view entity ZC_FLD_CONFIG
  as projection on ZI_FLD_CONFIG
{
  @UI.facet: [{
    id: 'GeneralData',
    type: #IDENTIFICATION_REFERENCE,
    label: 'General Data',
    position: 10
  }]
  @UI.lineItem: [{ position: 10, label: 'Table Name' }]
  @UI.identification: [{ position: 10, label: 'Table Name' }]
  key TableName,

  @UI.lineItem: [{ position: 20, label: 'Field Name' }]
  @UI.identification: [{ position: 20, label: 'Field Name' }]
  key FieldName,

  @UI.hidden: true
      ConfigUuid,

  @UI.lineItem: [{ position: 30, label: 'Field Type' }]
  @UI.identification: [{ position: 30, label: 'Field Type' }]
      FieldType,

  @UI.lineItem: [{ position: 40, label: 'Label Text' }]
  @UI.identification: [{ position: 40, label: 'Label Text' }]
      LabelText,

  @UI.lineItem: [{ position: 50, label: 'Display Order' }]
  @UI.identification: [{ position: 50, label: 'Display Order' }]
      DisplayOrder,

  @UI.lineItem: [{ position: 60, label: 'Key Field' }]
  @UI.identification: [{ position: 60, label: 'Key Field' }]
      IsKeyField,

  @UI.lineItem: [{ position: 70, label: 'Mandatory' }]
  @UI.identification: [{ position: 70, label: 'Mandatory' }]
      MandatoryFlag,

  @UI.lineItem: [{ position: 80, label: 'Readonly' }]
  @UI.identification: [{ position: 80, label: 'Readonly' }]
      ReadonlyFlag,

  @UI.lineItem: [{ position: 90, label: 'Hidden' }]
  @UI.identification: [{ position: 90, label: 'Hidden' }]
      HiddenFlag,

  @UI.lineItem: [{ position: 100, label: 'Domain Name' }]
  @UI.identification: [{ position: 100, label: 'Domain Name' }]
      DomainName,

      _TblConfig : redirected to parent ZC_TBL_CONFIG
}
