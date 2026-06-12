"! <p class="shorttext synchronized">Exception cho Excel Pipeline</p>
"! Exception đơn giản, mang theo message text tự do.
CLASS zcx_excel_pipeline DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING previous LIKE previous OPTIONAL
                iv_text  TYPE string   OPTIONAL.

    METHODS get_text REDEFINITION.

  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.


CLASS zcx_excel_pipeline IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    mv_text = iv_text.
  ENDMETHOD.

  METHOD get_text.
    result = COND #( WHEN mv_text IS NOT INITIAL
                     THEN mv_text
                     ELSE super->get_text( ) ).
  ENDMETHOD.

ENDCLASS.

