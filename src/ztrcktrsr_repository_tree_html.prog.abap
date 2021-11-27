REPORT ztrcktrsr_repository_tree_html.

" goal
" export/ display the se80 repository tree for a package including sub packages
" for documentation purposes


PARAMETERS p_devc TYPE devclass DEFAULT 'SABP_UNIT_CORE_API'.
PARAMETERS p_sthl TYPE n DEFAULT 1.
PARAMETERS p_dis  RADIOBUTTON GROUP mode DEFAULT 'X'.
PARAMETERS p_exp  RADIOBUTTON GROUP mode.
PARAMETERS p_path TYPE string DEFAULT 'C:\temp\'.

CLASS repo DEFINITION.
  PUBLIC SECTION.
    TYPES: BEGIN OF ts_function,
             name TYPE string,
             text TYPE string,
           END OF ts_function,
           tt_functions TYPE STANDARD TABLE OF ts_function WITH DEFAULT KEY.
    METHODS export_header.
    METHODS go
      IMPORTING
        package     TYPE devclass
      RETURNING
        VALUE(html) TYPE string_table.
    METHODS constructor
      IMPORTING
        start_header_level TYPE numc1.
  PROTECTED SECTION.
    DATA repo_nodes TYPE STANDARD TABLE OF snodetext WITH DEFAULT KEY.
    DATA start_header_level TYPE n LENGTH 1.
    DATA html_result TYPE string_table.
    METHODS add
      IMPORTING
        html_line TYPE clike.
    METHODS add_table
      IMPORTING
        html_table TYPE string_table.
    METHODS get_functions
      IMPORTING
        function            TYPE any
      RETURNING
        VALUE(rt_functions) TYPE tt_functions.

ENDCLASS.

CLASS repo IMPLEMENTATION.
  METHOD constructor.
    me->start_header_level = start_header_level.
  ENDMETHOD.

  METHOD get_functions.
    DATA lt_functions TYPE STANDARD TABLE OF rs38l_incl WITH DEFAULT KEY.
    DATA lt_function_texts TYPE STANDARD TABLE OF tftit WITH DEFAULT KEY.
    DATA ls_function_text TYPE tftit.
    DATA lt_ptfdir TYPE STANDARD TABLE OF  tfdir.
    DATA lt_pfunct TYPE STANDARD TABLE OF  funct.
    DATA lt_penlfdir TYPE STANDARD TABLE OF  enlfdir.
    DATA lt_ptrdir TYPE STANDARD TABLE OF  trdir.
    DATA lt_pfupararef TYPE STANDARD TABLE OF  sfupararef.
    DATA lt_uincl TYPE STANDARD TABLE OF  abaptxt255.

    CALL FUNCTION 'RS_FUNCTION_POOL_CONTENTS'
      EXPORTING
        function_pool           = CONV rs38l_area( function )
      TABLES
        functab                 = lt_functions
      EXCEPTIONS
        function_pool_not_found = 1
        OTHERS                  = 2.
    IF sy-subrc = 0.
      LOOP AT lt_functions INTO DATA(ls_function).
        CALL FUNCTION 'FUNC_GET_OBJECT'
          EXPORTING
            funcname           = CONV rs38l_fnam( ls_function-funcname )
          TABLES
            ptfdir             = lt_ptfdir
            ptftit             = lt_function_texts
            pfunct             = lt_pfunct
            penlfdir           = lt_penlfdir
            ptrdir             = lt_ptrdir
            pfupararef         = lt_pfupararef
            uincl              = lt_uincl
          EXCEPTIONS
            function_not_exist = 1
            version_not_found  = 2
            OTHERS             = 3.
        IF sy-subrc = 0.
          TRY.
              APPEND VALUE #( name = ls_function-funcname  text = lt_function_texts[ spras = sy-langu ]-stext ) TO rt_functions.
            CATCH cx_sy_itab_line_not_found.
              APPEND VALUE #( name = ls_function-funcname  text = lt_function_texts[ 1 ]-stext ) TO rt_functions.
          ENDTRY.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD export_header.

    DATA header_level TYPE n LENGTH 1.

    LOOP AT repo_nodes INTO DATA(ls_node).

      header_level = ls_node-tlevel+1(1) + start_header_level - 1.

      CASE ls_node-type.
        WHEN 'OF'. "Function groups
          add( |<h{ header_level }>{ ls_node-text1 } { ls_node-text2 }</h{ header_level }>| ).
          DATA(lt_functions) = get_functions( ls_node-text1 ).
          IF lt_functions IS NOT INITIAL.
            add( |<h{ header_level }>{ TEXT-001 }<h{ header_level }>| ).
            ADD 1 TO header_level.
            LOOP AT lt_functions INTO DATA(ls_function).
              add( |<h{ header_level }> { ls_function-name } { ls_function-text }<h{ header_level }>| ).
            ENDLOOP.
          ENDIF.
        WHEN 'OK'. "sub package
          IF ls_node-tlevel = 1.
            add( |<h{ header_level }>{ ls_node-text1 } { ls_node-text2 }</h{ header_level }>| ).
          ELSE.
            add_table( NEW repo( header_level )->go( CONV #( ls_node-text1 ) ) ).
          ENDIF.
        WHEN OTHERS.
          add( |<h{ header_level }>{ ls_node-text1 } { ls_node-text2 }</h{ header_level }>| ).

      ENDCASE.

    ENDLOOP.
  ENDMETHOD.

  METHOD go.
    CALL FUNCTION 'WB_TREE_RETURN_OBJECT_LIST'
      EXPORTING
        treename     = CONV eu_t_name( |EU_{ package }| )
        with_root    = abap_true
        refresh      = abap_true
      TABLES
        nodetab      = repo_nodes
      EXCEPTIONS
        not_existing = 1
        OTHERS       = 2.
    export_header( ).
    html = html_result.
  ENDMETHOD.

  METHOD add.
    APPEND html_line TO html_result.
  ENDMETHOD.

  METHOD add_table.
    APPEND LINES OF html_table TO html_result.
  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.

  "read repository tree and prepare output
  DATA(repo_app) = NEW repo( p_sthl ).
  DATA(html) = repo_app->go( p_devc ).

  CASE 'X'.
    WHEN p_dis.
      "display html

      IF p_sthl > 1.
        "add dummy titles to keep html structure clean
        DO p_sthl - 1 TIMES.
          INSERT |<h{ sy-index ALIGN = LEFT WIDTH = 1 }>Dummy title { sy-index }</h{ sy-index ALIGN = LEFT WIDTH = 1 }>| INTO html INDEX sy-index.
        ENDDO.
      ENDIF.

      "add html identifier and header numbering style to html
      INSERT LINES OF VALUE string_table(
       ( `<html><head><style>` )
       ( `body {counter-reset: ebene1;}` )
       ( `h1:before {` )
       ( `    content: counter(ebene1) " ";` )
       ( `    counter-increment: ebene1;}` )
       ( `h1 {counter-reset: ebene2;}` )
       ( `h2:before {` )
       ( `    content: counter(ebene1) "." counter(ebene2) " ";` )
       ( `    counter-increment: ebene2;}` )
       ( `h2 {counter-reset: ebene3;}` )
       ( `h3:before {` )
       ( `    content: counter(ebene1) "." counter(ebene2) "." counter(ebene3) " ";` )
       ( `    counter-increment: ebene3;}` )
       ( `h3 {counter-reset: ebene4;}` )
       ( `h4:before {` )
       ( `    content: counter(ebene1) "." counter(ebene2) "." counter(ebene3) "." counter(ebene4) " ";` )
       ( `    counter-increment: ebene4;}` )
       ( `</style></head><body>` )
       ) INTO html INDEX 1.

      "close html document
      APPEND `</body></html>` TO html.

      DATA(html_string) = REDUCE string_value(
        INIT str = `` FOR line IN html
          NEXT str = str && line ).

      cl_demo_output=>display_html( html_string ).


    WHEN p_exp.
      "export generated html to local file
      DATA(filename) = p_path && p_devc && '.html'.
      cl_gui_frontend_services=>gui_download(
        EXPORTING
          filename                  = filename
          filetype                  = 'ASC'                " File type (ASCII, binary ...)
        CHANGING
          data_tab                  = html
        EXCEPTIONS
          file_write_error          = 1                    " Cannot write to file
          no_batch                  = 2                    " Cannot execute front-end function in background
          gui_refuse_filetransfer   = 3                    " Incorrect Front End
          invalid_type              = 4                    " Invalid value for parameter FILETYPE
          no_authority              = 5                    " No Download Authorization
          unknown_error             = 6                    " Unknown error
          header_not_allowed        = 7                    " Invalid header
          separator_not_allowed     = 8                    " Invalid separator
          filesize_not_allowed      = 9                    " Invalid file size
          header_too_long           = 10                   " Header information currently restricted to 1023 bytes
          dp_error_create           = 11                   " Cannot create DataProvider
          dp_error_send             = 12                   " Error Sending Data with DataProvider
          dp_error_write            = 13                   " Error Writing Data with DataProvider
          unknown_dp_error          = 14                   " Error when calling data provider
          access_denied             = 15                   " Access to File Denied
          dp_out_of_memory          = 16                   " Not enough memory in data provider
          disk_full                 = 17                   " Storage medium is full.
          dp_timeout                = 18                   " Data provider timeout
          file_not_found            = 19                   " Could not find file
          dataprovider_exception    = 20                   " General Exception Error in DataProvider
          control_flush_error       = 21                   " Error in Control Framework
          not_supported_by_gui      = 22                   " GUI does not support this
          error_no_gui              = 23                   " GUI not available
          OTHERS                    = 24 ).
      IF sy-subrc <> 0.
        MESSAGE |error download. subrc={ sy-subrc }| TYPE 'I'.
      ELSE.
        MESSAGE |data saved| TYPE 'S'.
      ENDIF.
  ENDCASE.
