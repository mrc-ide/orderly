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
  unlink(file.path(path, "orderly_config.json"))
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


test_that("library orderly2 will load orderly support", {
  skip_if_not_installed("mockery")
  mock_load <- mockery::mock()
  mockery::stub(orderly_read_expr, "load_orderly2_support", mock_load)

  expect_equal(
    orderly_read_expr(quote(library(orderly)), character()),
    list(is_orderly = FALSE, expr = quote(library(orderly))))
  mockery::expect_called(mock_load, 0)

  expect_equal(
    orderly_read_expr(quote(library(orderly2)), character()),
    list(is_orderly = FALSE, expr = quote(library(orderly2))))
  mockery::expect_called(mock_load, 1)
  expect_equal(mockery::mock_args(mock_load)[[1]], list())
})
