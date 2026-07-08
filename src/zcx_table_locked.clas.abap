"! <p class="shorttext synchronized">Table/record is locked</p>
"! Raise khi không acquire được lock (đang bị user/session khác giữ).
CLASS zcx_table_locked DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING previous   LIKE previous OPTIONAL
                iv_text     TYPE string   OPTIONAL
                iv_locked_by TYPE syuname  OPTIONAL.

    METHODS get_text REDEFINITION.

    DATA mv_locked_by TYPE syuname READ-ONLY.

  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.


CLASS zcx_table_locked IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    mv_text      = iv_text.
    mv_locked_by = iv_locked_by.
  ENDMETHOD.

  METHOD get_text.
    result = COND #( WHEN mv_text IS NOT INITIAL
                     THEN mv_text
                     ELSE super->get_text( ) ).
  ENDMETHOD.

ENDCLASS.

