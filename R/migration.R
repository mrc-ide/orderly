##' Migrate source code from orderly2 (version 1.99.81 and previous)
##' to refer to orderly (version 1.99.82 and subsequent).
##'
##' This function acts as an interface for rewriting the source code
##' that will be used to create new packets, it does not migrate any
##' data from packets that have been run.  The idea here is that if we
##' make changes to how orderly works that require some repetitive and
##' relatively simple changes to your code, we can write a script that
##' will do a reasonable (if not perfect) job of this, and you can run
##' this over your code, check the results and if you like it commit
##' the changes to your repository, rather than than you having to go
##' through and change everything by hand.
##'
##' The version of orderly that you support is indicated by the
##' version specified in `orderly_version.yml`; we will change some
##' warnings to errors once you update this, in order to help you keep
##' your code up to date.
##'
##' # Migrations
##'
##' A summary of migrations.  The version number indicates the minimum
##' version that this would increase your source repository to
##'
##' ## 1.99.82
##'
##' Removes references to `orderly2`, replacing them with `orderly`.
##' This affects namespaced calls (e.g.,
##' `orderly2::orderly_parameter`) and calls to `library` (e.g.,
##' `library(orderly2)`)
##'
##' ## Future migrations
##'
##' We have some old changes to enable here:
##'
##' * renaming `<name>/orderly.R` to `<name>/<name>.R`
##' * enforcing named arguments to `orderly_artefact`
##'
##' We would like to enforce changes to `orderly_parameter` but have
##' not worked out a general best practice way of doing this.
##'
##' # Version control
##'
##' @title Migrate orderly source code
##'
##' @param path Path to the repository to migrate
##'
##' @param dry_run Logical, indicating if no changes would be made,
##'   but just print information about the changes that would be made.
##'   If `TRUE`, you can run this function against a repository that
##'   is not under version control.
##'
##' @param from Optional minimum version to migrate from.  If `NULL`,
##'   we migrate from the version indicated in your
##'   `orderly_config.yml`.  You can specify a lower version here if
##'   you want to force migrations that would otherwise be skipped
##'   because they are assumed to be applied.  Pass `"0"` (as a
##'   string) to match all previous versions.
##'
##' @param to Optional maximum version to migrate to.  If `NULL` we
##'   apply all possible migrations.
##'
##' @return Primarily called for side effects, but returns (invisibly)
##'   `TRUE` if any changes were made (or would be made if `dry_run`
##'   was `TRUE`) and `FALSE` otherwise.
##'
##' @export
orderly_migrate_source <- function(path = ".", dry_run = FALSE, from = NULL,
                                   to = NULL) {
  ## TODO: check version is at least orderly2
  current <- numeric_version("1.99.0")

  migrate_check_git_status(path, dry_run)

  dat <- migrations(current, from, to)
  if (length(dat) == 0) {
    cli::cli_alert_success("No migrations to apply")
    return(invisible(FALSE))
  }

  ## If doing a dry run, we can't really run multiple migrations
  ## because we don't hold the correct contents.  Ignore this fact for
  ## now.
  changed <- character()
  for (v in names(dat)) {
    cli::cli_h1("Migrating from {current} to {v}")
    changed <- union(changed, dat[[v]](path, dry_run))
    current <- v
  }

  n <- length(changed)

  ## Update the minimum version; this will never decrease the number
  ## in the file, so should always be safe.
  n <- n + update_minimum_orderly_version(
    file.path(path, "orderly_config.yml"), to, dry_run)

  any_changed <- n > 0
  if (!any_changed) {
    cli::cli_alert_success("Nothing to change!")
  } else if (dry_run) {
    cli::cli_alert_info("Would change {sum(changed)} file{?s}")
  } else {
    cli::cli_alert_success("Changed {changed} file{?s}")
    cli::cli_alert_info("Please review, then add and commit these to git")
  }

  invisible(any_changed)
}


## This is easy enough
migrate_check_git_status <- function(path, dry_run) {
  status <- tryCatch(
    gert::git_status(repo = path),
    error = function(e) {
      if (dry_run) {
        cli::cli_alert_warning(
          "'{path}' does not appear to be version controlled")
        return(NULL)
      }
      cli::cli_abort(
        "Not migrating '{path}' as it does not appear to be version controlled")
    })
  if (!dry_run && nrow(status) != 0) {
    cli::cli_abort(
      c("Not migrating '{path}' as 'git status' is not clean",
        i = "Try running this in a fresh clone"))
  }
}


migrations <- function(current, from, to) {
  possible <- list("1.99.82" = migrate_1_99_82)
  v <- numeric_version(names(possible))
  possible[(v > from %||% current) & (v <= to %||% ORDERLY_MINIMUM_VERSION)]
}


migrate_1_99_82 <- function(path, dry_run) {
  files <- dir(path, pattern = "\\.(R|Rmd|qmd|md)$",
               recursive = TRUE, ignore.case = TRUE)
  changed <- logical(length(files))
  for (i in seq_along(files)) {
    changed[[i]] <- migrate_1_99_82_file(path, files[[i]], dry_run)
  }
  files[changed]
}


## Much of what is in here can no doubt be generalised, we'll not try
## and do that yet.
migrate_file <- function(path, file, dry_run) {
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


update_minimum_orderly_version <- function(filename, version, dry_run) {
  assert_file_exists(filename)
  ## Everything about yaml is terrible.  We would like to edit the
  ## value within the yaml, but we can't easily roundtrip the
  ## contents.  So instead we'll edit the strings that it contains,
  ## which is disgusting.  However, the majority of these that we will
  ## hit are written by us, and are very simple, so in practice this
  ## should be reasonable.
  txt <- readLines(filename, warn = FALSE)
  pattern <- "^minimum_orderly_version\\s*:\\s+(.*?)\\s*$"
  i <- grep(pattern, txt)
  if (length(i) == 0) {
    cli::cli_abort(
      c("Failed to find key 'minimum_orderly_version' in orderly config",
        i = "Looked in '{filename}'",
        i = "Please edit this file yourself"))
  }
  if (length(i) > 1) {
    cli::cli_abort(
      c("Found more than one key 'minimum_orderly_version' in orderly config",
        i = "Looked in '{filename}'",
        x = "This is probably not valid yaml, does this even work for you?"))
  }
  existing <- gsub("[\"']", "", sub(pattern, "\\1", txt[[i]]))
  if (numeric_version(existing) >= version) {
    cli::cli_alert_success(
      "Minimum orderly version already at {existing}")
    return(FALSE)
  }

  txt[[i]] <- sprintf('minimum_orderly_version: "%s"', version)
  if (dry_run) {
    cli::cli_alert_info(
      "Would update minimum orderly version from {existing} to {version}")
  } else {
    writeLines(txt, filename)
    cli::cli_alert_success(
      "Updated minimum orderly version from {existing} to {version}")
  }
  TRUE
}
