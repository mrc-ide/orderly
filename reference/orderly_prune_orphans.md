# Prune orphan packet metadata

Prune orphan packets from your metadata store. This function can be used
to remove references to packets that are no longer reachable; this could
have happened because you deleted a packet manually from the archive and
ran
[`orderly_validate_archive()`](https://mrc-ide.github.io/orderly/reference/orderly_validate_archive.md)
or because you removed a location.

## Usage

``` r
orderly_prune_orphans(root = NULL)
```

## Arguments

- root:

  The path to the root directory, or `NULL` (the default) to search for
  one from the current working directory. This function does not require
  that the directory is configured for orderly, and can be any `outpack`
  root (see
  [`orderly_init()`](https://mrc-ide.github.io/orderly/reference/orderly_init.md)
  for details).

## Value

Invisibly, a character vector of orphaned packet ids

## Details

If an orphan packet is not used anywhere, then we can easily drop it -
it's as if it never existed. If it is referenced by metadata that you
know about from elsewhere but not locally, then that is a problem for
the upstream location (and one that should not happen). If you have
referenced it in a packet that you have run locally, the the metadata is
not deleted.

We expose this function mostly for users who want to expunge permanently
any reference to previously run packets. We hope that there should never
need to really be a reason to run it.

## Examples

``` r
# The same example as orderly_validate_archive; a corrupted
# archive due to the local deletion of a file
# Start with an archive containing 4 simple packets
path <- orderly_example()
#> ✔ Created orderly root at '/tmp/RtmpG21yn4/orderly_ex_199846ba7c74'
ids <- vapply(1:4, function(i) orderly_run("data", root = path), "")
#> ℹ Starting packet 'data' `20261012-154813-25f0c186` at 2026-10-12 15:48:13.151796
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154813-25f0c186 at 2026-10-12 15:48:13.172537 (0.02074146 secs)
#> ℹ Starting packet 'data' `20261012-154813-3027b124` at 2026-10-12 15:48:13.191542
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154813-3027b124 at 2026-10-12 15:48:13.211477 (0.01993418 secs)
#> ℹ Starting packet 'data' `20261012-154813-3e75d9ff` at 2026-10-12 15:48:13.247564
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154813-3e75d9ff at 2026-10-12 15:48:13.268017 (0.02045274 secs)
#> ℹ Starting packet 'data' `20261012-154813-49400c33` at 2026-10-12 15:48:13.289648
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154813-49400c33 at 2026-10-12 15:48:13.310559 (0.0209105 secs)
fs::file_delete(file.path(path, "archive", "data", ids[[3]], "data.rds"))

# Validate the archive ands orphan corrupt packets:
orderly_validate_archive(action = "orphan", root = path)
#> ✔ 20261012-154813-25f0c186 (data) is valid
#> ✔ 20261012-154813-3027b124 (data) is valid
#> ✖ 20261012-154813-3e75d9ff (data) is invalid due to its files
#> ✔ 20261012-154813-49400c33 (data) is valid

# Prune our orphans:
orderly_prune_orphans(root = path)
#> ℹ Pruning 1 orphan packet
```
