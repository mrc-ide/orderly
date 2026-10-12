# Compare the metadata and contents of two packets.

Insignificant differences in the metadata (e.g., different dates and
packet IDs) are excluded from the comparison.

## Usage

``` r
orderly_compare_packets(
  target,
  current,
  location = NULL,
  allow_remote = NULL,
  fetch_metadata = FALSE,
  root = NULL
)
```

## Arguments

- target:

  The id of the packet to use in the comparison.

- current:

  The id of the other packet against which to compare.

- location:

  Optional vector of locations to pull from. We might in future expand
  this to allow wildcards or exceptions.

- allow_remote:

  Logical, indicating if we should allow packets to be found that are
  not currently unpacked (i.e., are known only to a location that we
  have metadata from). If this is `TRUE`, then in conjunction with
  [`orderly_dependency()`](https://mrc-ide.github.io/orderly/reference/orderly_dependency.md)
  you might pull a large quantity of data. The default is `NULL`. This
  is `TRUE` if remote locations are listed explicitly as a character
  vector in the `location` argument, or if you have specified
  `fetch_metadata = TRUE`, otherwise `FALSE`.

- fetch_metadata:

  Logical, indicating if we should pull metadata immediately before the
  search. If `location` is given, then we will pass this through to
  [`orderly_location_fetch_metadata()`](https://mrc-ide.github.io/orderly/reference/orderly_location_fetch_metadata.md)
  to filter locations to update. If pulling many packets in sequence,
  you *will* want to update this option to `FALSE` after the first pull,
  otherwise it will update the metadata between every packet, which will
  be needlessly slow.

- root:

  The path to the root directory, or `NULL` (the default) to search for
  one from the current working directory. This function does not require
  that the directory is configured for orderly, and can be any `outpack`
  root (see
  [`orderly_init()`](https://mrc-ide.github.io/orderly/reference/orderly_init.md)
  for details).

## Value

An object of class orderly_comparison. The object can be printed to get
a summary description of the differences, or passed to
[`orderly_comparison_explain()`](https://mrc-ide.github.io/orderly/reference/orderly_comparison_explain.md)
to display more details.

## Examples

``` r

# Here are two packets that are equivalent, differing only in id
# and times:
path <- orderly_example()
#> ✔ Created orderly root at '/tmp/RtmpG21yn4/orderly_ex_19981acdd038'
id1 <- orderly_run("data", root = path)
#> ℹ Starting packet 'data' `20261012-154759-bebabd79` at 2026-10-12 15:47:59.748844
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154759-bebabd79 at 2026-10-12 15:47:59.807539 (0.05869508 secs)
id2 <- orderly_run("data", root = path)
#> ℹ Starting packet 'data' `20261012-154759-d4b6ba8d` at 2026-10-12 15:47:59.834381
#> > orderly_description(
#> +   display = "A demo data set")
#> > x <- jitter(1:30)
#> > y <- 0.4 * x + 5 + rnorm(length(x), sd = 2)
#> > d <- data.frame(x, y)
#> > orderly_artefact("data.rds", description = "A synthetic dataset")
#> > saveRDS(d, "data.rds")
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154759-d4b6ba8d at 2026-10-12 15:47:59.956871 (0.1224899 secs)
orderly_compare_packets(id1, id2, root = path)
#> ℹ Comparing packets 20261012-154759-bebabd79 and 20261012-154759-d4b6ba8d...
#> ℹ The following attributes are different across the two packets:
#> • files
#> ℹ Use `orderly_comparison_explain(...)` to examine the differences in more detail.

# A more interesting comparison:
id1 <- orderly_run("parameters", list(max_cyl = 6), root = path)
#> ℹ Starting packet 'parameters' `20261012-154800-00c52860` at 2026-10-12 15:48:00.007288
#> ℹ Parameters:
#> • max_cyl: 6
#> > # This declares that this orderly report accepts one parameter
#> > # 'max_cyl' with no default (i.e., it is required).
#> > pars <- orderly_parameters(max_cyl = NULL)
#> > orderly_artefact("data.rds", description = "Final data")
#> > # We can use the parameter by subsetting 'pars'; unlike regular R
#> > # lists you will get an error if you try and access a non-existent
#> > # element.
#> > data <- mtcars[mtcars$cyl <= pars$max_cyl, ]
#> > saveRDS(data, "data.rds")
#> ✔ Finished running parameters.R
#> ℹ Finished 20261012-154800-00c52860 at 2026-10-12 15:48:00.036791 (0.02950311 secs)
id2 <- orderly_run("parameters", list(max_cyl = 4), root = path)
#> ℹ Starting packet 'parameters' `20261012-154800-0f099e3e` at 2026-10-12 15:48:00.062747
#> ℹ Parameters:
#> • max_cyl: 4
#> > # This declares that this orderly report accepts one parameter
#> > # 'max_cyl' with no default (i.e., it is required).
#> > pars <- orderly_parameters(max_cyl = NULL)
#> > orderly_artefact("data.rds", description = "Final data")
#> > # We can use the parameter by subsetting 'pars'; unlike regular R
#> > # lists you will get an error if you try and access a non-existent
#> > # element.
#> > data <- mtcars[mtcars$cyl <= pars$max_cyl, ]
#> > saveRDS(data, "data.rds")
#> ✔ Finished running parameters.R
#> ℹ Finished 20261012-154800-0f099e3e at 2026-10-12 15:48:00.092645 (0.02989721 secs)
cmp <- orderly_compare_packets(id1, id2, root = path)
cmp
#> ℹ Comparing packets 20261012-154800-00c52860 and 20261012-154800-0f099e3e...
#> ℹ The following attributes are different across the two packets:
#> • parameters
#> • files
#> ℹ Use `orderly_comparison_explain(...)` to examine the differences in more detail.

# A verbose comparison will show differences in the constituent
# components of each packet:
orderly_comparison_explain(cmp, verbose = TRUE)
#> ℹ Comparing packets 20261012-154800-00c52860 and 20261012-154800-0f099e3e...
#> ℹ Comparing attribute `parameters`
#> < 20261012-154800-00c52860$parameters
#> > 20261012-154800-0f099e3e$parameters
#> @@ 1,3 / 1,3 @@  
#>   $max_cyl       
#> < [1] 6          
#> > [1] 4          
#>                  
#> ! The following files differ across packets, but could not be compared as their content is binary:
#>   • data.rds
```
