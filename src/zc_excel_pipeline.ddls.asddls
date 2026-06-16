@EndUserText.label: 'Excel Pipeline'
@UI.headerInfo: { typeName: 'Excel Pipeline', typeNamePlural: 'Excel Pipeline' }
define root view entity ZC_EXCEL_PIPELINE
  provider contract transactional_query
  as projection on ZI_EXCEL_PIPELINE
{
      @UI.facet: [ { id:       'Actions',
                     purpose:  #STANDARD,
                     type:     #IDENTIFICATION_REFERENCE,
                     label:    'Excel Actions',
                     position: 10 } ]

      @UI: { lineItem: [ { position: 10, label: 'Stub' },
                         { type: #FOR_ACTION, dataAction: 'downloadExcel', label: 'Download Excel' },
                         { type: #FOR_ACTION, dataAction: 'uploadExcel',   label: 'Upload Excel' },
                         { type: #FOR_ACTION, dataAction: 'confirmImport', label: 'Confirm Import' } ],
             identification: [ { position: 10, label: 'Stub' },
                         { type: #FOR_ACTION, dataAction: 'downloadExcel', label: 'Download Excel' },
                         { type: #FOR_ACTION, dataAction: 'uploadExcel',   label: 'Upload Excel' },
                         { type: #FOR_ACTION, dataAction: 'confirmImport', label: 'Confirm Import' } ] }
  key StubId
}
