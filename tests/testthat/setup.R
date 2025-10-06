tests_schema_validate <- function() {
  opt <- getOption("orderly.schema_validate", NULL)
  if (!is.null(opt)) {
    return(opt)
  }
  if (isTRUE(as.logical(Sys.getenv("CI", "false")))) {
    return(TRUE)
  }
  requireNamespace("jsonvalidate", quietly = TRUE)
}


withr::local_options(
  orderly.index_progress = FALSE,
  orderly.schema_validate = tests_schema_validate(),
  .local_envir = teardown_env())
