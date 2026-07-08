"! <p class="shorttext synchronized">Conflicting pending approval exists</p>
"! Raise khi đã có pending approval cho TABLE_NAME + RECORD_KEY bởi user khác.
CLASS zcx_pending_exists DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING previous      LIKE previous OPTIONAL
                iv_text        TYPE string   OPTIONAL
                iv_submitted_by TYPE syuname  OPTIONAL.

    METHODS get_text REDEFINITION.

    DATA mv_submitted_by TYPE syuname READ-ONLY.

  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.


CLASS zcx_pending_exists IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    mv_text         = iv_text.
    mv_submitted_by = iv_submitted_by.
  ENDMETHOD.

  METHOD get_text.
    result = COND #( WHEN mv_text IS NOT INITIAL
                     THEN mv_text
                     ELSE super->get_text( ) ).
  ENDMETHOD.

ENDCLASS.

