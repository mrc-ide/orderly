##' Migrate source code from orderly2 (version 1.99.81 and previous)
##' to refer to orderly (version 1.99.82 and subsequent).  This is a
##' one-off and will not exist in the package for long, get it while
##' it's hot.  This function does a very simple-minded replacement of
##' `orderly2` with `orderly` in R files (extension `.R` or `.r`),
##' markdown (`.md`), R markdown (`.Rmd`) and quarto (`.qmd`).  It
##' requires a clean git status before it is run, and will be best to
##' run against a fresh clone of a repository.  After running, review
##' changes (if any) with `git diff` and then commit.
##'
##' @title Migrate orderly2 sources
##'
##' @param path Path to the repo.  We will not change anything here
##'   unless the path is under source control, and unless the git
##'   status is "up to date" (i.e., no local unsaved modifications or
##'   untracked files).  It is recommended to run this against a fresh
##'   clone.
##'
##' @param dry_run Logical, indicating if no changes would be made,
##'   but just print information about the changes that would be made.
##'
##' @return Primarily called for side effects, but returns (invisibly)
##'   `TRUE` if any changes were made, `FALSE` otherwise.
##'
##' @export
orderly_migrate_source_from_orderly2 <- function(path = ".", dry_run = FALSE) {
  status <- tryCatch(
    gert::git_status(repo = path),
    error = function(e) {
      cli::cli_abort(
        "Not migrating '{path}' as it does not appear to be version controlled")
    })
  if (nrow(status) != 0 && !dry_run) {
    cli::cli_abort(
      c("Not migrating '{path}' as 'git status' is not clean",
        i = "Try running this in a fresh clone"))
  }
  root <- gert::git_info(repo = path)$path
  files <- dir(root, pattern = "\\.(R|Rmd|qmd|md)$",
               recursive = TRUE, ignore.case = TRUE)
  cli::cli_alert_info("Checking {length(files)} file{?s} in '{root}'")
  changed <- 0
  for (i in seq_along(files)) {
    changed <- changed + orderly_migrate_file(root, files[[i]], dry_run)
  }
  changed <- changed +
    update_minimum_orderly_version(
      file.path(path, "orderly_config.yml"),
      ORDERLY_MINIMUM_VERSION,
      dry_run)
  any_changed <- changed > 0
  if (!any_changed) {
    cli::cli_alert_success("Nothing to change!")
  } else if (dry_run) {
    cli::cli_alert_info("Would change {sum(changed)} file{?s}")
  } else {
    cli::cli_alert_success("Changed {changed} file{?s}")
    cli::cli_alert_info("Please add and commit these to git")
  }
  invisible(any_changed)
}


orderly_migrate_file <- function(path, file, dry_run) {
  filename <- file.path(path, file)
  prev <- txt <- readLines(filename, warn = FALSE)
  txt <- sub("orderly2::", "orderly::", txt, fixed = TRUE)
  txt <- sub("library(orderly2)", "library(orderly)", txt, fixed = TRUE)
  n <- sum(txt != prev)
  changed <- n > 0
  if (changed) {
    if (dry_run) {
      cli::cli_alert_info("Would update {n} line{?s} in {file}")
    } else {
      cli::cli_alert_info("Updated {n} line{?s} in {file}")
      writeLines(txt, filename)
    }
  }
  changed
}




load_orderly2_support <- function() {
  if (!orderly2_compat_enabled()) {
    cli::cli_abort(
      paste("Not loading orderly2 support, as this is disabled by the option",
            "'orderly.disable_orderly2_compat'"))
  }
  if (isTRUE(cache$orderly2_support_is_loaded)) {
    return(invisible())
  }
  correct <- read.dcf(orderly_file("orderly2/DESCRIPTION"), "Version")
  if (isNamespaceLoaded("orderly2")) {
    if (getNamespaceVersion("orderly2") != correct) {
      cli::cli_abort(
        c("Can't load orderly2 compatibility as orderly2 is loaded",
          i = paste("You have an old version of 'orderly2' installed and",
                    "loaded; please try again in a fresh session, perhaps",
                    "after removing 'orderly2'"),
          i = 'Try {.code remove.packages("orderly2")}'))
    }
  } else {
    installed_version <-
      tryCatch(utils::packageVersion("orderly2"), error = function(e) NULL)
    if (!is.null(installed_version) && installed_version == correct) {
      ## The user has installed our dummy version of orderly2, so just
      ## load that.  Some shennanigans required here to keep QA happy,
      ## because orderly2 is not really a package that we need or want
      ## in the DESCRIPTION
      load_namespace("orderly2")
    } else {
      ## Load our bundled version with pkgload (if that is installed)
      pkgload::load_all(orderly_file("orderly2"),
                        export_all = FALSE,
                        export_imports = FALSE,
                        attach = FALSE,
                        helpers = FALSE,
                        attach_testthat = FALSE,
                        quiet = TRUE)
    }
  }
  cache$orderly2_support_is_loaded <- TRUE
  invisible()
}


## This does not really need to be in the package, but because it
## interacts with the package cache it feels reasonable.  We'll use
## this in tests only.
unload_orderly2_support <- function() {
  if (isTRUE(cache$orderly2_support_is_loaded)) {
    unloadNamespace("orderly2")
    cache$orderly2_support_is_loaded <- FALSE
  }
  invisible()
}


orderly2_compat_enabled <- function() {
  !isTRUE(getOption("orderly.disable_orderly2_compat", FALSE))
}
