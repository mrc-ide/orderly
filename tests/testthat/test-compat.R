test_that("Do nothing while migrating up-to-date sources", {
  path <- suppressMessages(orderly_example())
  info <- helper_add_git(path)
  res <- evaluate_promise(orderly_migrate_source_from_orderly2(path))
  expect_length(res$messages, 3)
  expect_match(res$message[[1]], "Checking \\d+ files in")
  expect_match(res$message[[2]], "Minimum orderly version already at")
  expect_match(res$message[[3]], "Nothing to change")
  expect_false(res$result)
})


test_that("refuse to migrate sources that are not under version control", {
  path <- suppressMessages(orderly_example())
  expect_error(
    orderly_migrate_source_from_orderly2(path),
    "Not migrating")
})


test_that("refuse to migrate unclean repo", {
  path <- suppressMessages(orderly_example())
  info <- helper_add_git(path)
  file.create(file.path(path, "some-file"))
  err <- expect_error(
    orderly_migrate_source_from_orderly2(path),
    "Not migrating")
  expect_match(conditionMessage(err), "Try running this in a fresh clone")
})


test_that("allow dry run on unclean repo", {
  path <- suppressMessages(orderly_example())
  info <- helper_add_git(path)
  file.create(file.path(path, "some-file"))
  res <- evaluate_promise(
    orderly_migrate_source_from_orderly2(path, dry_run = TRUE))
  expect_false(res$result)
})


test_that("don't change up-to yml", {
  path <- withr::local_tempfile()
  writeLines(empty_config_contents(), path)
  res <- evaluate_promise(
    update_minimum_orderly_version(path, ORDERLY_MINIMUM_VERSION, FALSE))
  expect_false(res$result)
  expect_match(res$messages, "Minimum orderly version already at")
})


test_that("can increase version if required", {
  path <- withr::local_tempfile()
  writeLines(empty_config_contents(), path)
  res <- evaluate_promise(
    update_minimum_orderly_version(path, "9.9.9", FALSE))
  expect_true(res$result)
  expect_match(res$messages,
               "Updated minimum orderly version from .+ to 9.9.9")
  expect_equal(yaml::read_yaml(path),
               list("minimum_orderly_version" = "9.9.9"))
})


test_that("error if no minimum version key found", {
  path <- withr::local_tempfile()
  file.create(path)
  expect_error(
    update_minimum_orderly_version(path, "2.0.0", FALSE),
    "Failed to find key 'minimum_orderly_version' in orderly config")
})


test_that("cope with malformed yaml", {
  path <- withr::local_tempfile()
  writeLines(rep(empty_config_contents(), 2), path)
  expect_error(
    update_minimum_orderly_version(path, ORDERLY_MINIMUM_VERSION, FALSE),
    "Found more than one key 'minimum_orderly_version' in orderly config")
})


test_that("leave other yaml alone when updating", {
  path <- withr::local_tempfile()
  txt <- '# a comment\nminimum_orderly_version: "0.0.1"'
  writeLines(txt, path)
  res <- evaluate_promise(
    update_minimum_orderly_version(path, "9.9.9", FALSE))
  expect_equal(readLines(path),
               c("# a comment", 'minimum_orderly_version: "9.9.9"'))
})


test_that("can migrate source file", {
  path <- withr::local_tempdir()
  file <- "foo.R"
  filename <- file.path(path, file)
  txt <- c("# some comment", "orderly2::orderly_parameter(a = 1)")
  writeLines(txt, filename)

  res <- evaluate_promise(orderly_migrate_file(path, file, TRUE))
  expect_true(res$result)
  expect_match(res$messages, "Would update 1 line in foo.R")
  expect_equal(readLines(filename), txt)

  res <- evaluate_promise(orderly_migrate_file(path, file, FALSE))
  expect_true(res$result)
  expect_match(res$messages, "Updated 1 line in foo.R")
  expect_equal(readLines(filename), sub("orderly2", "orderly", txt))
})


test_that("can migrate old sources", {
  path <- suppressMessages(orderly_example())
  writeLines(
    'minimum_orderly_version: "1.99.0"',
    file.path(path, "orderly_config.yml"))

  filename <- file.path(path, "src", "data", "data.R")
  txt <- readLines(filename)
  writeLines(sub("^orderly_", "orderly2::orderly_", txt),
             filename)

  info <- helper_add_git(path)

  res <- evaluate_promise(
    orderly_migrate_source_from_orderly2(path, dry_run = TRUE))
  expect_length(res$messages, 4)
  expect_match(res$message[[1]], "Checking \\d+ files in")
  expect_match(res$message[[2]], "Would update 2 lines in src/data/data.R")
  expect_match(res$message[[3]], "Would update minimum orderly version")
  expect_match(res$message[[4]], "Would change 2 files")
  expect_true(res$result)

  expect_equal(nrow(gert::git_status(repo = path)), 0)

  res <- evaluate_promise(
    orderly_migrate_source_from_orderly2(path))
  expect_length(res$messages, 5)
  expect_match(res$message[[1]], "Checking \\d+ files in")
  expect_match(res$message[[2]], "Updated 2 lines in src/data/data.R")
  expect_match(res$message[[3]], "Updated minimum orderly version")
  expect_match(res$message[[4]], "Changed 2 files")
  expect_match(res$message[[5]], "Please add and commit these to git")
  expect_true(res$result)

  expect_equal(nrow(gert::git_status(repo = path)), 2)
})


test_that("don't load package if option disables it", {
  unload_orderly2_support()
  withr::local_options(orderly.disable_orderly2_compat = TRUE)
  expect_error(
    load_orderly2_support(),
    "Not loading orderly2 support")
})


test_that("load bundled version if orderly2 not installed", {
  skip_if_not_installed("mockery")
  withr::defer(unload_orderly2_support())
  unload_orderly2_support()
  withr::local_options(orderly.disable_orderly2_compat = NULL)

  mock_load_ns <- mockery::mock()
  mock_load_all <- mockery::mock()
  mockery::stub(load_orderly2_support, "isNamespaceLoaded", FALSE)
  mockery::stub(load_orderly2_support, "packageVersion",
                mockery::mock(stop("not installed")))
  mockery::stub(load_orderly2_support, "load_namespace", mock_load_ns)
  mockery::stub(load_orderly2_support, "pkgload::load_all", mock_load_all)

  load_orderly2_support()

  expect_true(cache$orderly2_support_is_loaded)
  mockery::expect_called(mock_load_all, 1)
  mockery::expect_called(mock_load_ns, 0)
  args <- mockery::mock_args(mock_load_all)[[1]]
  expect_equal(args[[1]], orderly_file("orderly2"))
  expect_false(args$export_all)
})


test_that("load library version if orderly2 installed and correct", {
  skip_if_not_installed("mockery")
  withr::defer(unload_orderly2_support())
  unload_orderly2_support()
  withr::local_options(orderly.disable_orderly2_compat = NULL)

  mock_load_ns <- mockery::mock()
  mock_load_all <- mockery::mock()
  mockery::stub(load_orderly2_support, "isNamespaceLoaded", FALSE)
  mockery::stub(load_orderly2_support, "utils::packageVersion", "1.99.99")
  mockery::stub(load_orderly2_support, "load_namespace", mock_load_ns)
  mockery::stub(load_orderly2_support, "pkgload::load_all", mock_load_all)

  load_orderly2_support()

  expect_true(cache$orderly2_support_is_loaded)
  mockery::expect_called(mock_load_all, 0)
  mockery::expect_called(mock_load_ns, 1)
  expect_equal(mockery::mock_args(mock_load_ns)[[1]], list("orderly2"))
})


test_that("load bundled version if orderly2 installed but incorrect", {
  skip_if_not_installed("mockery")
  withr::defer(unload_orderly2_support())
  unload_orderly2_support()
  withr::local_options(orderly.disable_orderly2_compat = NULL)

  mock_load_ns <- mockery::mock()
  mock_load_all <- mockery::mock()
  mockery::stub(load_orderly2_support, "isNamespaceLoaded", FALSE)
  mockery::stub(load_orderly2_support, "utils::packageVersion", "1.99.98")
  mockery::stub(load_orderly2_support, "load_namespace", mock_load_ns)
  mockery::stub(load_orderly2_support, "pkgload::load_all", mock_load_all)

  load_orderly2_support()

  expect_true(cache$orderly2_support_is_loaded)
  mockery::expect_called(mock_load_all, 1)
  mockery::expect_called(mock_load_ns, 0)
})


test_that("error if orderly2 loaded but incorrect", {
  skip_if_not_installed("mockery")
  withr::defer(unload_orderly2_support())
  unload_orderly2_support()
  withr::local_options(orderly.disable_orderly2_compat = NULL)

  mock_load_ns <- mockery::mock()
  mock_load_all <- mockery::mock()
  mockery::stub(load_orderly2_support, "isNamespaceLoaded", TRUE)
  mockery::stub(load_orderly2_support, "getNamespaceVersion", "1.99.98")
  mockery::stub(load_orderly2_support, "load_namespace", mock_load_ns)
  mockery::stub(load_orderly2_support, "pkgload::load_all", mock_load_all)

  expect_error(
    load_orderly2_support(),
    "Can't load orderly2 compatibility as orderly2 is loaded")

  expect_false(cache$orderly2_support_is_loaded)
  mockery::expect_called(mock_load_all, 0)
  mockery::expect_called(mock_load_ns, 0)
})


test_that("don't reload after initial load", {
  skip_if_not_installed("mockery")
  withr::defer(unload_orderly2_support())
  unload_orderly2_support()
  withr::local_options(orderly.disable_orderly2_compat = NULL)

  mock_load_ns <- mockery::mock()
  mock_load_all <- mockery::mock()
  mockery::stub(load_orderly2_support, "isNamespaceLoaded", FALSE)
  mockery::stub(load_orderly2_support, "utils::packageVersion", "1.99.99")
  mockery::stub(load_orderly2_support, "load_namespace", mock_load_ns)
  mockery::stub(load_orderly2_support, "pkgload::load_all", mock_load_all)

  load_orderly2_support()
  load_orderly2_support()
  expect_true(cache$orderly2_support_is_loaded)
  mockery::expect_called(mock_load_all, 0)
  mockery::expect_called(mock_load_ns, 1)
})


test_that("can run old orderly sources directly", {
  unload_orderly2_support()
  withr::defer(unload_orderly2_support())
  path <- suppressMessages(orderly_example())
  writeLines(
    'minimum_orderly_version: "1.99.0"',
    file.path(path, "orderly_config.yml"))

  filename <- file.path(path, "src", "data", "data.R")
  txt <- readLines(filename)
  writeLines(sub("^orderly_", "orderly2::orderly_", txt),
             filename)
  envir <- new.env()
  id <- orderly_run_quietly("data", root = path, envir = envir)
  expect_true("orderly2" %in% loadedNamespaces())
  expect_true(cache$orderly2_support_is_loaded)
  meta <- orderly_metadata(id, root = path)
  expect_true("orderly" %in% meta$custom$orderly$session$packages$package)
  expect_true("orderly2" %in% meta$custom$orderly$session$packages$package)
})
