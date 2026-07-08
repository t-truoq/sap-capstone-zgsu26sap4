"! <p class="shorttext synchronized">No authority for action</p>
"! Raise khi user không đủ quyền thực hiện action (permission / admin action).
CLASS zcx_04_no_auth DEFINITION
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


CLASS zcx_04_no_auth IMPLEMENTATION.

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

