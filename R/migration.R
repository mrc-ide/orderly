##' Migrate source code for an orderly project.  Periodically, we may
##' make changes to how orderly works that require you to update your
##' source code sooner or later.  This function can be used to
##' automate (or at least accelerate) that process by trying to
##' rewrite the R code within your project.  See below for details of
##' migrations and triggers for them.
##'
##' This function acts as an interface for rewriting the source code
##' that will be used to create new packets, it does not migrate any
##' data from packets that have been run.  The idea here is that if we
##' make changes to how orderly works that require some repetitive and
##' relatively simple changes to your code, we can write a script that
##' will do a reasonable (if not perfect) job of this, and you can run
##' this over your code, check the results and if you like it commit
##' the changes to your repository, rather than you having to go
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
##' version that this would increase your source repository to.
##'
##' Currently, we do not *enforce* these changes must be present in a
##' repository that declares it uses a recent orderly version, but
##' this may happen at any time, without further warning!
##'
##' ## 1.99.82
##'
##' Removes references to `orderly2`, replacing them with `orderly`.
##' This affects namespaced calls (e.g.,
##' `orderly2::orderly_parameter`) and calls to `library` (e.g.,
##' `library(orderly2)`)
##'
##' ## 1.99.88
##'
##' Renames '<name>/orderly.R' files to '<name>/<name>.R', a change
##' that we introduced in early 2024 (version 1.99.13).
##'
##' ## Future migrations
##'
##' We have some old changes to enable here:
##'
##' * enforcing named arguments to `orderly_artefact`
##'
##' We would like to enforce changes to `orderly_parameter` but have
##' not worked out a general best practice way of doing this.
##'
##' # Migration process
##'
##' This function requires a clean git status before it is run, and
##' will typically be best to run against a fresh clone of a
##' repository (though this is not enforced).  After running, review
##' changes (if any) with `git diff` and then commit.  You cannot run
##' this function against source code that is not version controlled
##' with git.
##'
##' # Migration of very old sources
##'
##' If you have old yaml-based orderly sources, you should consult
##' `vignette("migrating")` as the migration path is not automatic and
##' a bit more involved.  You will need to install the helper package
##' `outpack.orderly` and migrate your source and your archive
##' separately.
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
##'   we migrate from the version indicated in your orderly
##'   configuration and assume that all older migrations have been
##'   applied.  You can specify a lower version here if you want to
##'   force migrations that would otherwise be skipped because they
##'   are assumed to be applied.  Pass `"0"` (as a string) to match
##'   all previous versions.
##'
##' @param to Optional maximum version to migrate to.  If `NULL` we
##'   apply all possible migrations.  With `dry_run = TRUE` you may
##'   not want to use this, because we do not write any files,
##'   therefore each migration does not see the results of applying
##'   the previous migration.
##'
##' @return Primarily called for side effects, but returns (invisibly)
##'   `TRUE` if any changes were made (or would be made if `dry_run`
##'   was `TRUE`) and `FALSE` otherwise.
##'
##' @export
##' @examples
##' # If a project already has made the migration from orderly2 to
##' # orderly, then the migration does nothing:
##' path <- orderly_example()
##' orderly_migrate_source(path, dry_run = TRUE)
orderly_migrate_source <- function(path = ".", dry_run = FALSE, from = NULL,
                                   to = NULL) {
  current <- orderly_migrate_read_version(path)
  dat <- migrations(current, from, to)
  if (length(dat) == 0) {
    cli::cli_alert_success("No migrations to apply")
    return(invisible(FALSE))
  }
  from <- max(numeric_version(from %||% current), numeric_version("1.99.0"))
  to <- numeric_version(max(names(dat)))

  migrate_check_git_status(path, dry_run)

  changed <- character()
  for (v in names(dat)) {
    cli::cli_alert_info("Migrating from {from} to {v}")
    ## Once there is more than one set of migrations, warn here if
    ##
    ## > any(changed) && dry_run
    ##
    ## that this migration is being run against files that have not
    ## had the previous migrations applied, and that the user might
    ## consider passing 'to = "{current}' to migrate a bit at a time.
    ## This will be hard toapply until we really need it though.
    changed <- union(changed, dat[[v]](path, dry_run))
    from <- v
  }

  ## Update the minimum version; this will never decrease the number
  ## in the file, so should always be safe to attempt.
  n <- length(changed) + update_minimum_orderly_version(path, to, dry_run)

  any_changed <- n > 0
  if (!any_changed) {
    cli::cli_alert_success("Nothing to change!")
  } else if (dry_run) {
    cli::cli_alert_info("Would change {n} file{?s}")
  } else {
    cli::cli_alert_success("Changed {n} file{?s}")
    cli::cli_alert_info("Please review, then add and commit these to git")
  }

  invisible(any_changed)
}


migrate_check_git_status <- function(path, dry_run) {
  status <- tryCatch(
    gert::git_status(repo = path),
    error = function(e) NULL)

  if (is.null(status)) {
    if (dry_run) {
      cli::cli_alert_warning(
        paste("The path '{path}' does not appear to be under version control",
              "You will not be able to migrate your files, but we will still",
              "show what needs changing, as you have used 'dry_run = TRUE'"))
    } else {
      cli::cli_abort(
        "Not migrating '{path}' as it does not appear to be version controlled")
    }
  } else {
    if (nrow(status) > 0 && !dry_run) {
      cli::cli_abort(
        c("Not migrating '{path}' as 'git status' is not clean",
          i = "Try running this in a fresh clone"))
    }
  }
}


migrations <- function(current, from, to) {
  possible <- list("1.99.82" = migrate_1_99_82,
                   "1.99.88" = migrate_1_99_88,
                   "1.99.90" = migrate_1_99_90)
  v <- numeric_version(names(possible))
  possible[(v > from %||% current) & (v <= to %||% ORDERLY_MINIMUM_VERSION)]
}


migrate_1_99_82 <- function(path, dry_run) {
  files <- dir(path, pattern = "\\.(R|Rmd|qmd|md)$",
               recursive = TRUE, ignore.case = TRUE)
  cli::cli_alert_info("Checking {length(files)} file{?s} in '{path}'")
  changed <- logical(length(files))
  for (i in seq_along(files)) {
    changed[[i]] <- migrate_1_99_82_file(path, files[[i]], dry_run)
  }
  files[changed]
}


## Much of what is in here can no doubt be generalised, we'll not try
## and do that yet.  Not all migrations will follow this pattern as
## some will also change the name of the file (e.g., the migration
## away from orderly.R to <name>/<name>.R
migrate_1_99_82_file <- function(path, file, dry_run) {
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


migrate_1_99_88 <- function(path, dry_run) {
  path_src <- file.path(path, "src")
  dirs <- fs::dir_ls(path_src, type = "directory")
  changed <- character()
  for (p in dirs) {
    name <- basename(p)
    path_old <- file.path(p, "orderly.R")
    if (file.exists(path_old)) {
      path_new <- file.path(p, paste0(name, ".R"))
      if (file.exists(path_new)) {
        cli::cli_alert_danger(
          paste("Deleting 'src/{name}/orderly.R' as '{name}' also contains",
                "'{name}.R' - {.strong please check carefully}"))
        fs::file_delete(path_old)
      } else {
        if (dry_run) {
          cli::cli_alert_info(
            "Would rename '{name}/orderly.R' to '{name}/{name}.R'")
        } else {
          cli::cli_alert_info(
            "Renaming '{name}/orderly.R' to '{name}/{name}.R'")
          fs::file_move(path_old, path_new)
        }
      }
      changed <- c(changed, path_old)
    }
  }
  changed
}


migrate_1_99_90 <- function(path, dry_run) {
  path_config_yml <- file.path(path, "orderly_config.yml")
  path_config_json <- file.path(path, "orderly_config.json")

  if (!file.exists(path_config_yml)) {
    cli::cli_alert_info("No old-style yaml configuration found")
    return(FALSE)
  }

  dat <- yaml_load(read_lines(path_config_yml, warn = FALSE))
  if (!identical(names(dat), "minimum_orderly_version")) {
    cli::cli_abort(
      c("Can't migrate nontrivial orderly configuration",
        i = "Please reconfigure this yourself, using json"))
  }
  if (dry_run) {
    cli::cli_alert_info(
      "Would translate 'orderly_config.yml' to 'orderly_config.json'")
  } else {
    cli::cli_alert_info(
      "Translating 'orderly_config.yml' to 'orderly_config.json'")
    jsonlite::write_json(dat, path_config_json, auto_unbox = TRUE)
    fs::file_delete(path_config_yml)
  }

  TRUE
}


update_minimum_orderly_version <- function(path, version, dry_run) {
  path_config <- orderly_find_root(path,
                                   require_orderly = TRUE,
                                   require_outpack = FALSE)$path_orderly
  ext <- fs::path_ext(path_config)
  if (ext == "yml") {
    update_minimum_orderly_version_yml(path_config, version, dry_run)
  } else {
    update_minimum_orderly_version_json(path_config, version, dry_run)
  }
}


update_minimum_orderly_version_json <- function(filename, version, dry_run) {
  ## json is quite annoying to roundtrip, but we can get a long way
  ## with regular expressions, and avoid deserialisation entirely.
  txt <- paste(readLines(filename, warn = FALSE), collapse = "\n")
  pattern <- '^(.+"minimum_orderly_version"\\s*:\\s*")([0-9.]+)(".+)$'

  if (!grepl(pattern, txt)) {
    cli::cli_abort(
      c("Failed to find key 'minimum_orderly_version' in orderly config",
        i = "Looked in '{filename}'",
        i = "Please edit this file yourself"))
  }
  existing <- sub(pattern, "\\2", txt)
  if (numeric_version(existing) >= version) {
    cli::cli_alert_success(
      "Minimum orderly version already at {existing}")
    return(FALSE)
  }

  txt <- sub(pattern, sprintf("\\1%s\\3", version), txt)
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


update_minimum_orderly_version_yml <- function(filename, version, dry_run) {
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


orderly_migrate_read_version <- function(path, call = parent.frame()) {
  ## We don't use 'orderly_config_read' here because this is
  ## eventually going to be made more relaxed about reading yaml, and
  ## because we want to be quite explicit about paths (never looking
  ## up the tree), and because we're going to start playing silly
  ## business about the yaml vs a json configuration soon, and because
  ## we don't want to error based on obsolete version numbers being
  ## loaded.
  path_config <- orderly_find_root(path,
                                   require_orderly = TRUE,
                                   require_outpack = FALSE,
                                   call = call)$path_orderly
  dat <- read_config_data(path_config)
  value <- dat$minimum_orderly_version
  if (is.null(value)) {
    cli::cli_abort(paste("Invalid orderly configuration does not have key",
                         "'minimum_orderly_version'"))
  }
  assert_not_orderly1_project(value)
  numeric_version(value)
}
