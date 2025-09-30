test_that("Configuration must be empty", {
  tmp <- tempfile()
  on.exit(fs::dir_delete(tmp))
  fs::dir_create(tmp)
  filename <- file.path(tmp, "orderly_config.json")
  writeLines('{"minimum_orderly_version": "1.99.0", "a": 1}', filename)
  expect_error(orderly_config_read(filename),
               "Unknown field in .+")
})


test_that("Configuration must exist", {
  tmp <- tempfile()
  on.exit(fs::dir_delete(tmp))
  fs::dir_create(tmp)
  outpack_init_no_orderly(tmp)
  expect_error(orderly_config_read(file.path(tmp, "orderly_config.json")),
               "Orderly configuration does not exist: 'orderly_config.json'")
})


test_that("error of opening an outpack root that is not an orderly root", {
  tmp <- withr::local_tempfile()
  root <- outpack_init_no_orderly(tmp)

  err <- expect_error(
    withr::with_dir(tmp, root_open(".", require_orderly = TRUE)),
    "Did not find 'orderly_config.json' in '.",
    fixed = TRUE)
  expect_equal(
    err$body,
    c(x = paste("Your directory has an '.outpack/' path, so is a valid",
                "outpack root, but does not contain 'orderly_config.json' so",
                "cannot be used as an orderly root"),
      i = 'Please run orderly::orderly_init(".") to initialise',
      i = "See ?orderly_init for more arguments to this function"))
})


test_that("pass back a root", {
  path_outpack <- withr::local_tempfile()
  root_outpack <- outpack_init_no_orderly(path_outpack)
  path_orderly <- test_prepare_orderly_example(character())
  root_orderly <- root_open(path_orderly, require_orderly = TRUE)

  expect_identical(root_open(root_orderly, require_orderly = FALSE),
                   root_orderly)
  expect_identical(root_open(root_orderly, require_orderly = TRUE),
                   root_orderly)
  expect_identical(root_open(root_outpack, require_orderly = FALSE),
                   root_outpack)
  expect_error(
    root_open(root_outpack, require_orderly = TRUE),
    sprintf("Did not find 'orderly_config.json' in '%s'", root_outpack$path))
})


test_that("can silently detect that git setup is ok", {
  root <- create_temporary_root()
  info <- helper_add_git(root$path)
  expect_false(file.exists(file.path(root$path, ".outpack", "r", "git_ok")))
  expect_silent(root_check_git(root, NULL))
  expect_true(file.exists(file.path(root$path, ".outpack", "r", "git_ok")))
})


test_that("don't try and open root if git has been checked", {
  skip_if_not_installed("mockery")
  mock_git_open <- mockery::mock()
  mockery::stub(root_check_git, "git_open", mock_git_open)
  root <- create_temporary_root()
  dir.create(file.path(root$path, ".outpack", "r"))
  file.create(file.path(root$path, ".outpack", "r", "git_ok"))
  expect_silent(root_check_git(root, NULL))
  mockery::expect_called(mock_git_open, 0)
})


test_that("can silently notice that git is not used", {
  root <- create_temporary_root()
  expect_false(file.exists(file.path(root$path, ".outpack", "r", "git_ok")))
  expect_silent(root_check_git(root, NULL))
  expect_false(file.exists(file.path(root$path, ".outpack", "r", "git_ok")))
  expect_false(file.exists(file.path(root$path, ".gitignore")))
})


test_that("can add gitignore if git setup is ok, but not present", {
  root <- create_temporary_root()
  info <- helper_add_git(root$path)
  fs::file_delete(file.path(root$path, ".gitignore"))
  expect_false(file.exists(file.path(root$path, ".outpack", "r", "git_ok")))
  expect_message(root_check_git(root, NULL), "Wrote '.gitignore'")
  expect_true(file.exists(file.path(root$path, ".outpack", "r", "git_ok")))
  expect_true(file.exists(file.path(root$path, ".gitignore")))
})


test_that("can error with instructions if files are added to git", {
  ## Make sure that these are never set for the tests
  withr::local_options(
    orderly_git_error_is_warning = NULL,
    orderly_git_error_ignore = NULL)

  root <- create_temporary_root()
  info <- helper_add_git(root$path)
  id <- create_random_packet(root$path)

  ## Need to do some work here to make this fail now:
  fs::file_delete(file.path(root$path, ".gitignore"))
  fs::file_delete(file.path(root$path, ".outpack", "r", "git_ok"))

  gert::git_add(".", repo = root$path)
  user <- "author <author@example.com>"
  gert::git_commit("add everything", author = user, committer = user,
                   repo = root$path)
  err <- expect_error(root_check_git(root, NULL),
                      "Detected \\d+ outpack files committed to git")
  expect_false(file.exists(file.path(root$path, ".outpack", "r", "git_ok")))
  expect_equal(err$body[[1]],
               "Detected files were found in '.outpack/' and 'archive/'")
  expect_match(err$body[[2]],
               "For tips on resolving this, please see .+troubleshooting.html")
  expect_match(err$body[[3]], "^Found: ")
  expect_match(err$body[[4]],
               "To turn this into a warning and continue anyway")

  expect_error(create_random_packet(root$path), err$message, fixed = TRUE)

  path_ok <- file.path(root$path, ".outpack", "r", "git_ok")

  ## Can ignore the warning entirely:
  expect_silent(
    withr::with_options(list(orderly_git_error_ignore = TRUE),
                        root_check_git(root, NULL)))

  withr::with_options(
    list(orderly_git_error_is_warning = TRUE),
    expect_warning(id1 <- create_random_packet(root$path),
                   err$message, fixed = TRUE))
  expect_type(id1, "character")

  withr::with_options(
    list(orderly_git_error_is_warning = TRUE),
    expect_warning(id2 <- create_random_packet(root$path), NA)) # no warning

  expect_type(id2, "character")

  expect_false(file_exists(path_ok))
})


test_that("can do git check in subdir", {
  ## Make sure that these are never set for the tests
  withr::local_options(
    orderly_git_error_is_warning = NULL,
    orderly_git_error_ignore = NULL)

  path <- withr::local_tempdir()
  root <- file.path(path, "root")
  suppressMessages(orderly_init(root))

  info <- helper_add_git(path)

  expect_warning(
    root_check_git(list(path = root), NULL),
    "Can't check if files are correctly gitignored")
})


test_that("can identify a plain source root", {
  info <- test_prepare_orderly_example_separate("explicit")
  expect_equal(normalise_path(orderly_src_root(info$src, FALSE)),
               normalise_path(info$src))
  expect_error(
    orderly_src_root(file.path(info$src, "src", "explicit")),
    "Did not find existing orderly (or outpack) root in", fixed = TRUE)

  p <- file.path(info$outpack, "a", "b", "c")
  fs::dir_create(p)

  err <- expect_error(
    orderly_src_root(info$outpack),
    "Did not find 'orderly_config.json' in",
    fixed = TRUE)
})


test_that("error for plain source root with two configurations", {
  info <- test_prepare_orderly_example_separate("explicit")
  file.create(file.path(info$src, "orderly_config.yml"))
  expect_error(
    orderly_src_root(info$src),
    "Both 'orderly_config.json' and 'orderly_config.yml' found")
})



test_that("can identify a plain source root from a full root", {
  path <- test_prepare_orderly_example("explicit")
  root <- root_open(path, FALSE)
  expect_equal(orderly_src_root(root$path, FALSE), root$path)
  expect_equal(orderly_src_root(root, FALSE), root$path)
})


test_that("can use ORDERLY_ROOT to control the working directory", {
  a <- create_temporary_root()
  b <- create_temporary_root()
  c <- create_temporary_root()
  path_a <- normalise_path(a$path)
  path_b <- normalise_path(b$path)
  path_c <- normalise_path(b$path)

  withr::with_envvar(c(ORDERLY_ROOT = NA_character_), {
    withr::with_dir(path_a, {
      expect_equal(root_open(NULL, FALSE)$path, path_a)
      expect_equal(root_open(path_b, FALSE)$path, path_b)
    })
  })

  withr::with_envvar(c(ORDERLY_ROOT = path_c), {
    withr::with_dir(path_a, {
      expect_equal(root_open(NULL, FALSE)$path, path_c)
      expect_equal(root_open(path_b, FALSE)$path, path_b)
    })
  })
})


test_that("Error if both configurations found", {
  tmp <- withr::local_tempdir()
  orderly_init_quietly(tmp)
  file.create(file.path(tmp, "orderly_config.yml"))
  err <- expect_error(
    withr::with_dir(tmp, root_open(NULL, require_orderly = TRUE)),
    "Both 'orderly_config.json' and 'orderly_config.yml' found",
    fixed = TRUE)
})


test_that("can find root in subdirectory with old configuration", {
  path <- suppressMessages(orderly_example())
  from <- file.path(path, "src")
  res1 <- orderly_find_root_locate(from)

  write_old_version_marker(path, "1.99.82")
  res2 <- orderly_find_root_locate(from)
  expect_equal(basename(res1$path_orderly), "orderly_config.yml")

  expect_equal(res1$path, res2$path)
})
