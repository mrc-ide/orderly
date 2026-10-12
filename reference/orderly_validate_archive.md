# Validate unpacked packets.

Validate unpacked packets. Over time, expect this function to become
more fully featured, validating more.

## Usage

``` r
orderly_validate_archive(
  expr = NULL,
  name = NULL,
  action = "inform",
  root = NULL
)
```

## Arguments

- expr:

  The query expression. A `NULL` expression matches everything.

- name:

  Optionally, the name of the packet to scope the query on. This will be
  intersected with `scope` arg and is a shorthand way of running
  `scope = list(name = "name")`

- action:

  The action to take on finding an invalid packet. See Details.

- root:

  The path to the root directory, or `NULL` (the default) to search for
  one from the current working directory. This function does not require
  that the directory is configured for orderly, and can be any `outpack`
  root (see
  [`orderly_init()`](https://mrc-ide.github.io/orderly/reference/orderly_init.md)
  for details).

## Value

Invisibly, a character vector of repaired (or invalid) packets.

## Details

The actions that we can take on finding an invalid packet are:

- `inform` (the default): just print information about the problem

- `orphan`: mark the packet as orphaned within the metadata, but do not
  touch the files in your archive (by default the directory
  `archive/`) - this is a safe option and will leave you in a consistent
  state without deleting anything.

- `delete`: in addition to marking the packet as an orphan, also delete
  the files from your archive.

Later, we will add a "repair" option to try and fix broken packets.

The validation interacts with the option `core.require_complete_tree`;
if this option is `TRUE`, then a packet is only valid if all its
(recursive) dependencies are also valid, so the action will apply to
packets that have also had their upstream dependencies invalidated. This
validation will happen even if the query implied by `...` does not
include these packets if a complete tree is required.

The validation will also interact with `core.use_file_store` once repair
is supported, as this becomes trivial.

## Examples

``` r
# Start with an archive containing 4 simple packets
path <- orderly_example()
#> ✔ Created orderly root at '/tmp/RtmpG21yn4/orderly_ex_199813e7dc1a'
ids <- vapply(1:4, function(i) orderly_run("data", root = path), "")
#> ℹ Starting packet 'data' `20261012-154817-07fbadab` at 2026-10-12 15:48:17.034628
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154817-07fbadab at 2026-10-12 15:48:17.054537 (0.01990867 secs)
#> ℹ Starting packet 'data' `20261012-154817-16977ece` at 2026-10-12 15:48:17.091536
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154817-16977ece at 2026-10-12 15:48:17.111415 (0.0198791 secs)
#> ℹ Starting packet 'data' `20261012-154817-20d466dd` at 2026-10-12 15:48:17.131606
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154817-20d466dd at 2026-10-12 15:48:17.15126 (0.0196538 secs)
#> ℹ Starting packet 'data' `20261012-154817-2b3a6e45` at 2026-10-12 15:48:17.172185
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154817-2b3a6e45 at 2026-10-12 15:48:17.192091 (0.01990604 secs)

# Suppose someone corrupts a packet by deleting a file:
fs::file_delete(file.path(path, "archive", "data", ids[[3]], "data.rds"))

# We can check all packets, and report on validity
orderly_validate_archive(root = path)
#> ✔ 20261012-154817-07fbadab (data) is valid
#> ✔ 20261012-154817-16977ece (data) is valid
#> ✖ 20261012-154817-20d466dd (data) is invalid due to its files
#> ✔ 20261012-154817-2b3a6e45 (data) is valid

# Alternatively, we can take action and orphan the invalid packet:
orderly_validate_archive(action = "orphan", root = path)
#> ✔ 20261012-154817-07fbadab (data) is valid
#> ✔ 20261012-154817-16977ece (data) is valid
#> ✖ 20261012-154817-20d466dd (data) is invalid due to its files
#> ✔ 20261012-154817-2b3a6e45 (data) is valid

# At which point the validation will not find this packet anymore
orderly_validate_archive(root = path)
#> ✔ 20261012-154817-07fbadab (data) is valid
#> ✔ 20261012-154817-16977ece (data) is valid
#> ✔ 20261012-154817-2b3a6e45 (data) is valid

# The orphaned packet will no longer be found in most operations:
orderly_search(root = path)
#> [1] "20261012-154817-07fbadab" "20261012-154817-16977ece"
#> [3] "20261012-154817-2b3a6e45"
```
