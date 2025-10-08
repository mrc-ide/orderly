##' Initialise an empty orderly repository, or initialise a source
##' copy of an orderly repository (see Details). An orderly repository
##' is defined by the presence of a file `orderly_config.json` (or
##' `orderly_config.yml`) at its root, along with a directory
##' `.outpack/` at the same level.
##'
##' It is expected that `orderly_config.json` will be saved in version
##' control, but that `.outpack` will be excluded from version
##' control; this means that for every clone of your project you will
##' need to call `orderly::orderly_init()` to initialise the
##' `.outpack` directory. If you forget to do this, an error will be
##' thrown reminding you of what you need to do.
##'
##' You can safely call `orderly::orderly_init()` on an
##' already-initialised directory, however, any arguments passed
##' through must exactly match the configuration of the current root,
##' otherwise an error will be thrown. Please use
##' [orderly_config_set()] to change the configuration within
##' `.outpack`, as this ensures that the change in configuration is
##' possible. If configuration options are given but match those that
##' the directory already uses, then nothing happens.  You can safely
##' edit `orderly_config.json` yourself, at least for now.
##'
##' If the repository that you call `orderly::orderly_init()` on is
##' already initialised with an `.outpack` directory but not an
##' `orderly_config.json` file, then we will write that file too.
##'
##' @title Initialise an orderly repository
##'
##' @param root The path to initialise the repository root at.  If the
##'   repository is already initialised, this operation checks that
##'   the options passed in are the same as those set in the
##'   repository (erroring if not), but otherwise does nothing.  The
##'   default path is the current working directory.
##'
##' @param path_archive Path to the archive directory, used to store
##'   human-readable copies of packets.  If `NULL`, no such copy is
##'   made, and `file_store` must be `TRUE`
##'
##' @param use_file_store Logical, indicating if we should use a
##'   content-addressable file-store as the source of truth for
##'   packets.  If `archive` is non-`NULL`, the file-store will be
##'   used as the source of truth and the duplicated files in archive
##'   exist only for convenience.
##'
##' @param require_complete_tree Logical, indicating if we require a
##'   complete tree of packets.  This currently affects
##'   [orderly_location_pull()], by requiring that it
##'   always operates in recursive mode.  This is `FALSE` by default,
##'   but set to `TRUE` if you want your archive to behave well as a
##'   location; if `TRUE` you will always have all the packets that
##'   you hold metadata about.
##'
##' @param force Logical, indicating if we should initialise orderly
##'   even if the directory is not empty.
##'
##' @return The full, normalised, path to the root,
##'   invisibly. Typically this is called only for its side effect.
##'
##' @export
##' @examples
##' # We'll use an automatically cleaned-up directory for the root:
##' path <- withr::local_tempdir()
##'
##' # Initialise a new repository, setting an option:
##' orderly_init(path, use_file_store = TRUE)
##'
##' fs::dir_tree(path, all = TRUE)
orderly_init <- function(root = ".",
                         path_archive = "archive",
                         use_file_store = FALSE,
                         require_complete_tree = FALSE,
                         force = FALSE) {
  assert_scalar_character(root)
  path_orderly <- file.path(root, "orderly_config.json")
  has_orderly <- file.exists(path_orderly)

  path_orderly_old <- file.path(root, "orderly_config.yml")
  has_orderly_old <- file.exists(path_orderly_old)
  if (has_orderly_old) {
    if (has_orderly) {
      error_both_configurations(root)
    }
    path_orderly <- path_orderly_old
    has_orderly <- has_orderly_old
  }

  if (!has_orderly && file.exists(root)) {
    if (!is_directory(root)) {
      cli::cli_abort("'root' exists but is not a directory")
    }
    if (!file.exists(file.path(root, ".outpack")) && !force) {
      allowed <- c(".outpack",
                   ".git", ".gitignore",
                   ".vscode",
                   ".Rhistory", ".RData", "*.Rproj", ".Rproj.user")
      contents <- dir(root, all.files = TRUE, no.. = TRUE)
      m <- vapply(utils::glob2rx(allowed), grepl, logical(length(contents)),
                  contents)
      if (!is.matrix(m)) { # exactly one file to compare
        m <- rbind(m)
      }
      err <- contents[!apply(m, 1, any)]
      if (length(err) > 0) {
        cli::cli_abort(c(
          "'root' exists but is not empty, or an outpack archive",
          x = "Found existing file{?s}: {.file {err}}",
          i = "Use 'force = TRUE' to initialise anyway"))
      }
    }
  }

  config <- config_new(path_archive, use_file_store, require_complete_tree,
                       call = environment())

  path_outpack <- file.path(root, ".outpack")
  if (file.exists(path_outpack)) {
    root <- root_open(root, require_orderly = FALSE)
    root_validate_same_configuration(match.call(), config, root, environment())
  } else {
    fs::dir_create(path_outpack)
    fs::dir_create(file.path(path_outpack, "metadata"))
    fs::dir_create(file.path(path_outpack, "location"))
    config_write(config, root)
    root <- outpack_root$new(root, NULL)
    cli::cli_alert_success("Created orderly root at '{root$path}'")
  }

  if (!has_orderly) {
    writeLines(empty_config_contents(), path_orderly)
  }

  root <- root_open(root, require_orderly = TRUE)

  invisible(root$path)
}


ORDERLY_MINIMUM_VERSION <- "2.0.0"  # nolint


empty_config_contents <- function() {
  sprintf('{"minimum_orderly_version": "%s"}', ORDERLY_MINIMUM_VERSION)
}


root_open <- function(path, require_orderly, call = parent.frame()) {
  if (inherits(path, "outpack_root")) {
    root <- path # make this much easier to read
    if (!require_orderly || !is.null(root$config$orderly)) {
      return(root)
    }
    ## This is going to error, but the error later will do.
    path <- root$path
  }

  dat <- orderly_find_root(path,
                           require_orderly = require_orderly,
                           require_outpack = TRUE,
                           call = call)

  root <- outpack_root$new(dat$path, dat$path_orderly)
  root_check_git(root, call)

  root
}


## This is similar to root_open but operates looking for orderly
## signifiers of the root, and not outpack, because it operates on the
## source tree.  Returns just the root directory.
orderly_src_root <- function(path, call = parent.frame()) {
  if (inherits(path, "outpack_root")) {
    path <- path$path
  }
  dat <- orderly_find_root(path,
                           require_orderly = TRUE,
                           require_outpack = FALSE,
                           call = call)
  dat$path
}


## This is pretty unpleasant, but does the trick.
root_validate_same_configuration <- function(args, config, root, call) {
  argmap <- list(
    path_archive = c("core", "path_archive"),
    use_file_store = c("core", "use_file_store"),
    require_complete_tree = c("core", "require_complete_tree"))
  check <- intersect(names(argmap), names(args))
  if (length(check) > 0) {
    cmp <- lapply(check, function(nm) {
      current <- root$config[[argmap[[nm]]]]
      given <- config[[argmap[[nm]]]]
      changed <- !identical(current, given)
      list(changed = changed, name = nm, current = current, given = given)
    })
    err <- vlapply(cmp, "[[", "changed")
    if (any(err)) {
      err_str <- sprintf(
        "%s: was '%s' but was given '%s'",
        vcapply(cmp[err], "[[", "name"),
        vcapply(cmp[err], function(x) as.character(x$current)),
        vcapply(cmp[err], function(x) as.character(x$given)))
      cli::cli_abort(
        c("Trying to change configuration when re-initialising",
          set_names(err_str, rep("x", length(err_str))),
          i = "Use 'orderly::orderly_config_set()' to change configuration"),
        call = call)
    }
  }
}


root_check_git <- function(root, call) {
  if (isTRUE(getOption("orderly.git_error_ignore", FALSE))) {
    return()
  }

  path_ok <- file.path(root$path, ".outpack", "r", "git_ok")
  if (file.exists(path_ok)) {
    return()
  }
  git_root <- git_open(root$path)
  if (is.null(git_root)) {
    return()
  }

  files <- gert::git_ls(git_root)$path

  path_root_git <- gert::git_info(git_root)$path
  special <- paste0(c(".outpack", "draft", root$config$core$path_archive), "/")

  hint_disable <- paste(
    "To disable this check, set the option",
    "'orderly.git_error_ignore' to TRUE by running",
    "{.code options(orderly.git_error_ignore = TRUE)}")

  ## This is easiest to do if the outpack rep is at the git root,
  ## which is the most common situation.
  path_rel <- fs::path_rel(root$path, path_root_git)
  if (path_rel != ".") {
    cli::cli_warn(
      c("Can't check if files are correctly gitignored",
        i = paste("Your outpack repo is in a subdirectory '{path_rel}'",
                  "of your git repo"),
        i = hint_disable))
    return()
  }

  ## Allow draft/README.md and archive/README.md, which are present in
  ## orderly1 and might be generally ok
  files <- setdiff(files, file.path(special[-1], "README.md"))

  ## We'd like to use fs::path_has_parent here but it's very slow with
  ## a few thousand files, so we do this with string comparison which
  ## is muich faster.  For montagu this was taking about 1.3s, vs
  ## <0.001 with this approach.
  err <- vapply(special, function(p) startsWith(files, p),
                logical(length(files)))

  ## Avoid paranoid case of a single file to check not being a matrix.
  dim(err) <- c(length(files), length(special))

  is_ok <- !any(err)

  if (!is_ok) {
    files_err <- files[rowSums(err) > 0]
    types_err <- special[colSums(err) > 0]
    url <- "https://mrc-ide.github.io/orderly/articles/troubleshooting.html"
    warn_only <- getOption("orderly.git_error_is_warning", FALSE)
    msg <- c("Detected {length(files_err)} outpack file{?s} committed to git",
             x = "Detected files were found in {squote(types_err)}",
             i = "For tips on resolving this, please see {.url {url}}",
             x = "Found: {files_err}")
    if (warn_only) {
      cli::cli_warn(msg, call = call, .frequency = "once",
                    .frequency_id = paste0("orderly_git_warning-", root$path))
    } else {
      hint_warn_only <- paste(
        "To turn this into a warning and continue anyway",
        "set the option 'orderly.git_error_is_warning' to TRUE",
        "by running {.code options(orderly.git_error_is_warning = TRUE)}")
      cli::cli_abort(c(msg, i = hint_warn_only, i = hint_disable), call = call)
    }
  }

  do_orderly_gitignore_update("(root)", root$path)

  if (is_ok) {
    fs::dir_create(dirname(path_ok))
    fs::file_create(path_ok)
  }
}


## Finding the root and sorting out the various paths is quite
## tedious, this function trys to centralise it all before we add an
## additional complication with the presence of a json configuration.
orderly_find_root <- function(path, require_orderly, require_outpack,
                              call = NULL) {
  path <- path %||% Sys.getenv("ORDERLY_ROOT", NA_character_)
  locate <- is.na(path)

  if (locate) {
    ret <- orderly_find_root_locate(getwd(), call)
  } else {
    ret <- orderly_find_root_here(path, call)
  }

  if (require_orderly && is.null(ret$path_orderly)) {
    cli::cli_abort(
      c("Did not find 'orderly_config.json' in '{path}'",
        x = paste("Your directory has an '.outpack/' path, so is a valid",
                  "outpack root, but does not contain 'orderly_config.json' so",
                  "cannot be used as an orderly root"),
        i = 'Please run orderly::orderly_init("{path}") to initialise',
        i = "See ?orderly_init for more arguments to this function"),
      call = call)
  }

  if (require_outpack && is.null(ret$path_outpack)) {
    cli::cli_abort(
      c(sprintf("orderly directory '%s' not initialised", path),
        x = "Did not find an '.outpack' directory within path",
        i = 'Please run orderly::orderly_init("{path}") to initialise',
        i = "See ?orderly_init for more arguments to this function"),
      call = call)
  }

  ret
}


orderly_find_root_locate <- function(path, call = NULL) {
  path_outpack <- find_file_descend(".outpack", path)
  path_orderly <- find_file_descend("orderly_config.json", path)
  path_orderly_old <- find_file_descend("orderly_config.yml", path)

  has_outpack <- !is.null(path_outpack)
  has_orderly <- !is.null(path_orderly)
  has_orderly_old <- !is.null(path_orderly_old)

  if (has_orderly_old) {
    if (has_orderly) {
      # This is slightly more involved than error_both_configurations
      # to cope with the possibility that the the configurations are
      # in different directories (since we search) even though this is
      # very unlikely and probably just not going to be nicely
      # resolvable.
      cli::cli_abort( # - TODO: test
        c("Both 'orderly_config.json' and 'orderly_config.yml' found",
          i = "Looked within '{path}'",
          i = "Found new configuration: '{path_orderly}'",
          i = "Found old configuration: '{path_orderly_old}'",
          i = "Delete '{path_orderly_old}' and try again"),
        call = call)
    }
    path_orderly <- path_orderly_old
    has_orderly <- has_orderly_old
  }

  err_nesting <- has_outpack && has_orderly &&
    dirname(path_outpack) != dirname(path_orderly)
  if (err_nesting) {
    dirs <- c(outpack = dirname(path_outpack), orderly = dirname(path_orderly))
    if (fs::path_has_parent(dirs[[1]], dirs[[2]])) {
      dirs <- dirs[2:1]
    }
    cli::cli_abort(c(
      "Found incorrectly nested orderly and outpack directories",
      i = "{names(dirs)[[1]]} was found at '{dirs[[1]]}'",
      i = "{names(dirs)[[2]]} was found at '{dirs[[2]]}'",
      x = paste("{names(dirs)[[2]]} is nested within {names(dirs)[[1]]}",
                "at {fs::path_rel(dirs[[2]], dirs[[1]])}"),
      i = "How did you even do this? Please let us know!"),
      call = call)
  }

  if (!has_outpack && !has_orderly) {
    cli::cli_abort(
      c("Did not find existing orderly (or outpack) root in '{path}'",
        i = paste("Expected to find file 'orderly_config.yml'",
                  "or directory '.outpack/'"),
        i = "Looked in parents of this path without success"),
      call = call)
  }

  list(path = dirname(path_outpack %||% path_orderly),
       path_outpack = path_outpack,
       path_orderly = path_orderly)
}


orderly_find_root_here <- function(path, call) {
  assert_scalar_character(path, call = call)
  assert_is_directory(path, call = call)

  path_outpack <- file.path(path, ".outpack")
  path_orderly <- file.path(path, "orderly_config.json")
  path_orderly_old <- file.path(path, "orderly_config.yml")

  has_outpack <- file_exists(path_outpack)
  has_orderly <- file_exists(path_orderly)
  has_orderly_old <- file_exists(path_orderly_old)

  if (has_orderly_old) {
    if (has_orderly) {
      error_both_configurations(path, call) # TODO: test
    }
    path_orderly <- path_orderly_old
    has_orderly <- has_orderly_old
  }

  if (!has_outpack && !has_orderly) {
    cli::cli_abort(
      c("Did not find existing orderly (or outpack) root in '{path}'",
        i = paste("Expected to find file 'orderly_config.yml'",
                  "or directory '.outpack/'")),
      call = call)
  }

  list(path = path,
       path_outpack = if (has_outpack) path_outpack,
       path_orderly = if (has_orderly) path_orderly)
}


error_both_configurations <- function(path, call = parent.frame()) {
  cli::cli_abort(
    c("Both 'orderly_config.json' and 'orderly_config.yml' found",
      i = "Looked within '{path}'",
      i = "Delete 'orderly_config.yml' and try again"),
    call = call)
}
