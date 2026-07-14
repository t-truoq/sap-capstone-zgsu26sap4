CLASS zcl_repo_inventory DEFINITION
 PUBLIC
 FINAL
 CREATE PUBLIC.

 PUBLIC SECTION.

 TYPES:
 BEGIN OF ty_result,
 table_name TYPE string,
 data_elements_json TYPE string,
 search_helps_json TYPE string,
 function_modules_json TYPE string,
 cds_views_json TYPE string,
 foreign_keys_json TYPE string,
 error_msg TYPE string,
 END OF ty_result.

 CLASS-METHODS get_inventory
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rs_result) TYPE ty_result.

 CLASS-METHODS get_data_elements
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rt_json) TYPE string.

 CLASS-METHODS get_search_helps
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rt_json) TYPE string.

 CLASS-METHODS get_function_modules
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rt_json) TYPE string.

 CLASS-METHODS get_cds_views
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rt_json) TYPE string.

 CLASS-METHODS get_foreign_keys
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rt_json) TYPE string.

 PRIVATE SECTION.

 CLASS-METHODS get_devclass_of_table
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rv_devclass) TYPE devclass.

 CLASS-METHODS table_exists_chk
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rv_exists) TYPE abap_bool.

 CLASS-METHODS scan_fugr_for_table
 IMPORTING iv_table_name TYPE tabname
 RETURNING VALUE(rt_objs) TYPE string_table.

ENDCLASS.


CLASS zcl_repo_inventory IMPLEMENTATION.

 METHOD get_inventory.
 rs_result-table_name = iv_table_name.

 TRY.
 IF table_exists_chk( iv_table_name ) = abap_false.
 rs_result-error_msg = |Table { iv_table_name } does not exist|.
 RETURN.
 ENDIF.

 rs_result-data_elements_json = get_data_elements( iv_table_name ).
 rs_result-search_helps_json = get_search_helps( iv_table_name ).
 rs_result-function_modules_json = get_function_modules( iv_table_name ).
 rs_result-cds_views_json = get_cds_views( iv_table_name ).
 rs_result-foreign_keys_json = get_foreign_keys( iv_table_name ).

 CATCH cx_root INTO DATA(lx).
 rs_result-error_msg = lx->get_text( ).
 ENDTRY.
 ENDMETHOD.


 METHOD get_data_elements.
 DATA: BEGIN OF ls_de,
 rollname TYPE char30,
 domname TYPE char30,
 inttype TYPE char1,
 keyflag TYPE char1,
 mandatory TYPE char1,
 leng TYPE n LENGTH 6,
 decimals TYPE n LENGTH 6,
 label_short TYPE char10,
 label_med TYPE char20,
 label_long TYPE char40,
 rep_text TYPE char30,
 dd_text TYPE char60,
 END OF ls_de.
 DATA lt_de LIKE TABLE OF ls_de.

 SELECT a~rollname, a~domname, a~inttype, a~keyflag, a~mandatory,
 a~leng, a~decimals,
 t~scrtext_s, t~scrtext_m, t~scrtext_l, t~reptext, t~ddtext
 FROM dd03l AS a
 LEFT JOIN dd04l AS d ON d~rollname = a~rollname AND d~as4local = 'A'
 LEFT JOIN dd04t AS t ON t~rollname = a~rollname AND t~ddlanguage = 'E' AND t~as4local = 'A'
 WHERE a~tabname = @iv_table_name
 AND a~as4local = 'A'
 AND a~position > '00000'
 ORDER BY a~position
 INTO TABLE @DATA(lt_raw).

 LOOP AT lt_raw INTO DATA(ls_raw).
 MOVE-CORRESPONDING ls_raw TO ls_de.
 APPEND ls_de TO lt_de.
 ENDLOOP.

 rt_json = zcl_dyn_record_handler=>serialize( lt_de ).
 ENDMETHOD.


 METHOD get_search_helps.
 "── SH chỉ có ở DD04L (Data Element level), join qua rollname của DD03L ──"
 DATA: BEGIN OF ls_sh,
 fieldname TYPE char30,
 rollname TYPE char30,
 shlpname TYPE char30,
 shlpfield TYPE char30,
 END OF ls_sh.
 DATA lt_sh LIKE TABLE OF ls_sh.

 SELECT a~fieldname, a~rollname, d~shlpname, d~shlpfield
 FROM dd03l AS a
 LEFT JOIN dd04l AS d ON d~rollname = a~rollname AND d~as4local = 'A'
 WHERE a~tabname = @iv_table_name
 AND a~as4local = 'A'
 AND a~position > '00000'
 AND d~shlpname IS NOT NULL
 ORDER BY a~position
 INTO TABLE @DATA(lt_raw).

 LOOP AT lt_raw INTO DATA(ls_raw).
 MOVE-CORRESPONDING ls_raw TO ls_sh.
 APPEND ls_sh TO lt_sh.
 ENDLOOP.

 rt_json = zcl_dyn_record_handler=>serialize( lt_sh ).
 ENDMETHOD.


 METHOD get_function_modules.
 DATA(lt_fm_refs) = scan_fugr_for_table( iv_table_name ).
 IF lt_fm_refs IS INITIAL.
 rt_json = '[]'.
 RETURN.
 ENDIF.

 DATA: BEGIN OF ls_fm,
 funcname TYPE char30,
 fnarea TYPE char26,
 global TYPE char1,
 END OF ls_fm.
 DATA lt_fm LIKE TABLE OF ls_fm.

 DATA lt_fm_keys TYPE TABLE OF funcname.
 lt_fm_keys = lt_fm_refs.

 SELECT f~funcname, e~area, e~global
 FROM tfdir AS f
 INNER JOIN enlfdir AS e ON e~funcname = f~funcname
 FOR ALL ENTRIES IN @lt_fm_keys
 WHERE f~funcname = @lt_fm_keys-table_line
 INTO TABLE @DATA(lt_raw).

 LOOP AT lt_raw INTO DATA(ls_raw).
 MOVE-CORRESPONDING ls_raw TO ls_fm.
 APPEND ls_fm TO lt_fm.
 ENDLOOP.

 SORT lt_fm BY fnarea funcname.

 rt_json = zcl_dyn_record_handler=>serialize( lt_fm ).
 ENDMETHOD.


 METHOD get_cds_views.
 DATA(lv_pkg) = get_devclass_of_table( iv_table_name ).
 IF lv_pkg IS INITIAL.
 rt_json = '[]'.
 RETURN.
 ENDIF.

 DATA: BEGIN OF ls_cds,
 obj_name TYPE char40,
 object TYPE char4,
 devclass TYPE char30,
 author TYPE char12,
 END OF ls_cds.
 DATA lt_cds LIKE TABLE OF ls_cds.

 SELECT obj_name, object, devclass, author
 FROM tadir
 WHERE pgmid = 'R3TR'
 AND object IN ('DDLS', 'PROG', 'CLAS')
 AND devclass = @lv_pkg
 ORDER BY obj_name
 INTO TABLE @DATA(lt_raw).

 LOOP AT lt_raw INTO DATA(ls_raw).
 MOVE-CORRESPONDING ls_raw TO ls_cds.
 APPEND ls_cds TO lt_cds.
 ENDLOOP.

 rt_json = zcl_dyn_record_handler=>serialize( lt_cds ).
 ENDMETHOD.


 METHOD get_foreign_keys.
 DATA: BEGIN OF ls_fk,
 tabname TYPE char30,
 fieldname TYPE char30,
 checktable TYPE char30,
 checkfield TYPE char30,
 frkart TYPE char1,
 END OF ls_fk.
 DATA lt_fk LIKE TABLE OF ls_fk.

 "── DD08L đã có fieldname + checktable, DD05Q cần join để lấy checkfield ──"
 SELECT fk~tabname, fk~fieldname, fk~checktable,
 m~checkfield, fk~frkart
 FROM dd08l AS fk
 LEFT JOIN dd05q AS m ON m~tabname = fk~tabname AND m~fieldname = fk~fieldname
 WHERE fk~as4local = 'A'
 AND fk~checktable = @iv_table_name
 ORDER BY fk~tabname, fk~fieldname
 INTO TABLE @DATA(lt_raw).

 LOOP AT lt_raw INTO DATA(ls_raw).
 MOVE-CORRESPONDING ls_raw TO ls_fk.
 APPEND ls_fk TO lt_fk.
 ENDLOOP.

 rt_json = zcl_dyn_record_handler=>serialize( lt_fk ).
 ENDMETHOD.


 METHOD get_devclass_of_table.
 SELECT SINGLE devclass FROM tadir
 WHERE pgmid = 'R3TR'
 AND object = 'TABL'
 AND obj_name = @iv_table_name
 INTO @rv_devclass.
 ENDMETHOD.


 METHOD table_exists_chk.
 SELECT SINGLE tabname FROM dd02l
 WHERE tabname = @iv_table_name
 AND as4local = 'A'
 AND tabclass = 'TRANSP'
 INTO @DATA(lv_tabname).
 rv_exists = xsdbool( sy-subrc = 0 ).
 ENDMETHOD.


 METHOD scan_fugr_for_table.
 DATA(lv_pkg) = get_devclass_of_table( iv_table_name ).
 IF lv_pkg IS INITIAL. RETURN. ENDIF.

 DATA lt_fugrs TYPE TABLE OF char26.

 SELECT e~area
 FROM tadir AS t
 INNER JOIN enlfdir AS e ON e~area = t~obj_name
 WHERE t~pgmid = 'R3TR'
 AND t~object = 'FUGR'
 AND t~devclass = @lv_pkg
 INTO TABLE @lt_fugrs.

 IF lt_fugrs IS INITIAL. RETURN. ENDIF.

 "── Scan source từng FUGR, tìm FM reference ──"
 LOOP AT lt_fugrs INTO DATA(lv_fugr).
 DATA lt_src TYPE string_table.

 TRY.
 READ REPORT lv_fugr INTO lt_src.
 CATCH cx_root.
 CONTINUE.
 ENDTRY.

 IF sy-subrc <> 0. CONTINUE. ENDIF.

 DATA(lv_text) = concat_lines_of( lt_src ).
 DATA(lv_pattern) = 'FROM ' && iv_table_name.

 FIND REGEX lv_pattern IN lv_text IGNORING CASE.
 CHECK sy-subrc = 0.

 DATA lt_fm_temp TYPE TABLE OF funcname.

 SELECT funcname FROM tfdir
 WHERE funcname IN (
 SELECT funcname FROM enlfdir WHERE area = @lv_fugr
 )
 INTO TABLE @lt_fm_temp.

 LOOP AT lt_fm_temp INTO DATA(lv_fm).
 APPEND lv_fm TO rt_objs.
 ENDLOOP.
 ENDLOOP.
 ENDMETHOD.

ENDCLASS.

