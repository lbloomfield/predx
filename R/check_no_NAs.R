#' Check for NA entries
#'
#' @param object
#'
#' @return  TRUE or error message
#'
check_no_NAs <- function(object) {
  if (all(!is.na(object))) TRUE
  else "NA(s) found in entry"
}
