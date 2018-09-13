#' Boolean search filtering
#' @description A function to filter a data.frame, tibble or dplyr database connection table using boolean logical queries
#' @param db_tbl response variables - a special argument for the names of fields to include/omit in the response. e.g. return only "resp_vars=Species,Sepal.Length" or omit "resp_vars=-Species"
#' @param col variables to query - e.g. "col=Species"
#' @param qry Boolean search query - e.g. "qry=Sep OR Set"
#' @param case_sens Case-sensitive querying (default FALSE) - e.g. "case_sens=TRUE"
#' @param print_call Print the resulting sequal query to console (default FALSE)
#' @export
#' @example examples/bool_filter_examples.R
bool_filter <- function(db_tbl, col, qry, case_sens=FALSE, print_call=FALSE){
  ops <- c(AND = '&', `&` = '&', OR = '|', `|` = '|', `(` = '(', `)` = ')')  # boolean operators
  # add spaces around parentheses;
  qry <- qry %>% stringr::str_trim() %>% stringr::str_replace_all(stringr::fixed('('), '( ') %>%
    stringr::str_replace_all(stringr::fixed(')'), ' )') %>% stringr::str_replace_all("'", '"') %>% # enforce double quotes
    stringr::str_replace_all('(?<="[^ ]{0,100}) (?=[^ ]+")', '\u00A0') # sub spaces in quoted text for a unicode space

  # split elements by ascii space character
  comps <- strsplit(qry, '[ ]+')[[1]] %>% stringr::str_replace_all('\u00A0', ' ') %>% stringr::str_remove_all('"')

  comp_ops <- comps %in% names(ops)  # identify operators from query terms

  # construct string for a composite logical call to evaluate
  to_negate <- stringr::str_detect(comps[!comp_ops], '^-') # args to negate (NOT)
  qry_neg <- comps[!comp_ops] %>% stringr::str_replace('^-', '')
  qry_neg <- paste0("'", qry_neg, "'")

  # case sensitivity
  col_arg <- dplyr::if_else(case_sens, col, paste0('tolower(', col, ')'))
  qry_arg <- list(paste0('tolower(', qry_neg, ')'), qry_neg)[[case_sens+1]] # i.e. ifelse supporting vectors out

  # build a str_detect command for each argument, negated as required
  comps[!comp_ops] <- paste0(c('','!')[to_negate+1], 'str_detect(', col_arg, ', ', qry_arg, ')')
  comps[comp_ops] <- ops[comps[comp_ops]]

  qry_final <- paste0('dplyr::filter(', deparse(substitute(db_tbl)), ', ', paste(comps, collapse = ' '), ')')
  if(print_call) message(qry_final)

  eval(parse(text = qry_final))
}
