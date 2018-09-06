#' Quick Plumb API
#' @description A wrapper for the plumber API package that makes a quick but powerul and flexible API pipeline with just a few lines
#' @param tbl A postgres or similar database connection
#' @param tbl_names A vector or the column names of tbl
#' @param def_max_records The default maximum number of matching records to return if not overriden
#' @param hard_max_records The maximum number of matching records to return, regardless of any other argument
#' @export
#' @example examples/quick_plumb_examples.R
quick_plumb = function(tbl, tbl_names, def_max_records = 100, hard_max_records = 1000){
  suppressMessages(require(dplyr))
  function(...){
    # arguments
    dots0 <<- list(...)
    verbose <- 'verbose' %in% names(dots0)
    dots <<- dots0[!names(dots0) %in% c('res','req','verbose','_select','_arrange_by','_group_by','_summarise','_count','max_records','case_sen')]
    if(verbose) print(dots0)

    # test argument var names are correct
    testthat::expect_true(names(dots) %in% tbl_names %>% all, info = 'Please check that your (Case-Sensitive) variable names are correct')

    dat_sel <<- tbl

    # Filtering operations
    if(length(dots)>0) for(i in seq_along(dots)){
      for(j in seq_along(dots[[i]])){                               # multiple arguments for same variable are combined in the same list item
        ops <- stringr::str_extract(dots[[i]][j], '^[<>~]+')        # numerical operators
        if(is.na(ops)) ops <- 'q'                                   # i.e. denotes string query, not numerical

        # test operator is valid
        testthat::expect_true(ops %in% c('q','>','<','~','~~','>~','<~'), info = "Comparative operator should be one of: <, >, ~, >~, <~ (i.e. <, >, =, >=, <=)")

        if(ops != 'q'){                                             # parse numerical query
          ops <- stringr::str_replace_all(ops, '[~]+', '=')         # '~' denotes '=' char
          if(ops == '=') ops <- '=='                                # equality case
          str_arg <- stringr::str_extract(dots[[i]][j], '[^<>~].*') # extract query
          str_arg <- ifelse(suppressWarnings(is.na(as.numeric(str_arg))), paste0("'",str_arg,"'"), str_arg)  # enable </> string comparisons
          str_qry <- paste('dat_sel <<- dat_sel %>% dplyr::filter(', names(dots[i]), ops, str_arg, ')')      # regex captures everything after+inc first non comparative operator char
          eval(parse(text = str_qry))
        } else{                         # parse string query
          dat_sel <<- bool_filter(dat_sel, col = names(dots[i]), qry = dots[[i]][j], case_sens = !is.null(dots0[['case_sen']]))
        }
      }
    }

    # Aggregation and data handling variables
    p_select     <- dots0[['_select']]
    p_arrange_by <- dots0[['_arrange_by']]
    p_group_by   <- dots0[['_group_by']]
    p_summarise  <- dots0[['_summarise']]
    p_count      <- dots0[['_count']]
    p_max_recs   <- dots0[['max_records']]

    # Aggregation
    if(!is.null(p_group_by) | !is.null(p_summarise) | !is.null(p_count)){
      testthat::expect_true(!is.null(p_summarise) | !is.null(p_count), info = '"_group_by" requires "_summarise" and/or "_count" arguments to be supplied')
      # parse individual aggregation sub-arguments
      summarise_args <- ''
      if(!is.null(p_summarise)) {
        na_funs <- c('sum', 'mean', 'max', 'min')
        summarise_args <- strsplit(p_summarise, '[+;]')[[1]] %>%
          purrr::map_chr(~ {
            key_vals <- strsplit(.x, ':')[[1]]
            ind_vals <- strsplit(key_vals[2], ',')[[1]]
            ind_vals_init <- paste(ind_vals, key_vals[1], sep='_')
            na_arg <- ifelse(key_vals[1] %in% na_funs, ', na.rm=TRUE', '')
            ind_vals_init %>% paste0(' = ', key_vals[1], '(', ind_vals, na_arg, ')') %>% paste(collapse = ', ')
          }) %>% paste(collapse = ', ')
      }
      # count argument is handled separately
      if(!is.null(p_count)) summarise_args <- paste(summarise_args, 'n = n()', sep=',') %>% stringr::str_remove('^,')

      # build full dplyr summarise command and execute
      summarise_call = paste0('dat_sel <<- dat_sel %>% dplyr::group_by(', p_group_by, ') %>% dplyr::summarise(', summarise_args, ')')
      eval(parse(text = summarise_call))
      if(class(dat_sel)[1] == 'tbl_dbi') dat_sel <<- dat_sel %>% dplyr::collect()
    }

    # output ordering
    if(!is.null(p_arrange_by)){
      testthat::expect_length(p_arrange_by, 1) # test no duplicate args
      eval(parse(text = paste0('dat_sel <<- dplyr::arrange(dat_sel, ', p_arrange_by, ')'))) # specific fields to sort by
    }

    # output field specification
    if(!is.null(p_select)){
      testthat::expect_length(p_select, 1)     # test no duplicate args
      eval(parse(text = paste0('dat_sel <<- dplyr::select(dat_sel, ', p_select, ')'))) # specific fields to include/omit
    }

    # max records
    if(!is.null(p_max_recs)){
      dat_sel <<- head(dat_sel, min(hard_max_records, as.numeric(p_max_recs)))
    } else dat_sel <<- head(dat_sel, def_max_records)

    # final output
    if(class(dat_sel)[1] == 'tbl_dbi') dat_sel <<- dat_sel %>% dplyr::collect()
    if(verbose) if(class(dat_sel)[1] != 'list') message(nrow(dat_sel), ' rows matched')
    return(dat_sel)
  }
}
