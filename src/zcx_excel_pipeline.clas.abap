"! <p class="shorttext synchronized">Exception cho Excel Pipeline</p>
"! Exception đơn giản, mang theo message text tự do.
CLASS zcx_excel_pipeline DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING previous        LIKE previous OPTIONAL
                iv_text         TYPE string   OPTIONAL
                iv_submitted_by TYPE syuname  OPTIONAL
                iv_locked_by    TYPE syuname  OPTIONAL.

    METHODS get_text REDEFINITION.

    DATA mv_submitted_by TYPE syuname READ-ONLY.
    DATA mv_locked_by    TYPE syuname READ-ONLY.

  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.


CLASS zcx_excel_pipeline IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    mv_text         = iv_text.
    mv_submitted_by = iv_submitted_by.
    mv_locked_by    = iv_locked_by.
  ENDMETHOD.

  METHOD get_text.
    result = COND #( WHEN mv_text IS NOT INITIAL
                     THEN mv_text
                     ELSE super->get_text( ) ).
  ENDMETHOD.

ENDCLASS.


