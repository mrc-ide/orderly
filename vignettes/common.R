## Common support code for vignettes. This will not be echoed to the
## user, so be sure not to define functions here that they might want
## to use.
##
## Typically, include this in the Rmd within a block like:
##
## ```{r, include = FALSE}
## ...
## ```

dir_tree <- function(path, sub = ".", ...) {
  withr::with_dir(path, fs::dir_tree(sub, ...))
}

lang_output <- function(x, lang) {
  writeLines(c(sprintf("```%s", lang), x, "```"))
}
r_output <- function(x) {
  lang_output(x, "r")
}
yaml_output <- function(x) {
  lang_output(x, "yaml")
}
json_output <- function(x) {
  lang_output(x, "json")
}
plain_output <- function(x) {
  lang_output(x, "plain")
}
orderly_file <- function(...) {
  system.file(..., package = "orderly", mustWork = TRUE)
}

inline <- function(x) {
  sprintf("`%s`", format(x))
}

require_or_quit <- function(name) {
  for (nm in name) {
    if (!requireNamespace(nm, quietly = TRUE)) {
      cli::cli_alert_danger(
        "Optional package '{nm}' not available, stopping knitr")
      knitr::knit_exit()
    }
  }
}

knitr::opts_chunk$set(
  collapse = TRUE)

knitr::knit_hooks$set(orderly_root = function(before, options) {
  if (before) {
    Sys.setenv(ORDERLY_ROOT = options$orderly_root)
  } else {
    Sys.unsetenv("ORDERLY_ROOT")
  }
  invisible()
})
