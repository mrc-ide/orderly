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
