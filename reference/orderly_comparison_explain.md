# Print the details of a packet comparison.

This function allows to select what part of the packet to compare, and
in how much details.

## Usage

``` r
orderly_comparison_explain(cmp, attributes = NULL, verbose = FALSE)
```

## Arguments

- cmp:

  An orderly_comparison object, as returned by
  [`orderly_compare_packets()`](https://mrc-ide.github.io/orderly/reference/orderly_compare_packets.md).

- attributes:

  A character vector of attributes to include in the comparison. The
  values are keys of the packets' metadata, such as `parameters` or
  `files`. If NULL, the default, all attributes are compared, except
  those that differ in trivial way (i.e., `id` and `time`).

- verbose:

  Control over how much information is printed. It can either be a
  logical, or a character scalar `silent` or `summary`.

## Value

Invisibly, a logical indicating whether the packets are equivalent, up
to the given attributes.

## Examples

``` r
path <- orderly_example()
#> ✔ Created orderly root at '/tmp/RtmpG21yn4/orderly_ex_19986d5eab2a'
id1 <- orderly_run("parameters", list(max_cyl = 6), root = path)
#> ℹ Starting packet 'parameters' `20261012-154800-8db128a1` at 2026-10-12 15:48:00.556977
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
#> ℹ Finished 20261012-154800-8db128a1 at 2026-10-12 15:48:00.581539 (0.02456212 secs)
id2 <- orderly_run("parameters", list(max_cyl = 4), root = path)
#> ℹ Starting packet 'parameters' `20261012-154800-9905da8a` at 2026-10-12 15:48:00.601174
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
#> ℹ Finished 20261012-154800-9905da8a at 2026-10-12 15:48:00.626642 (0.02546883 secs)
cmp <- orderly_compare_packets(id1, id2, root = path)

orderly_comparison_explain(cmp)
#> ℹ Comparing packets 20261012-154800-8db128a1 and 20261012-154800-9905da8a...
#> ℹ Comparing attribute `parameters`
#> < 20261012-154800-8db128a1$parameters
#> > 20261012-154800-9905da8a$parameters
#> @@ 1,3 / 1,3 @@  
#>   $max_cyl       
#> < [1] 6          
#> > [1] 4          
#>                  
#> ℹ The following files exist in both packets but have different contents:
#>   • data.rds
#> ℹ Use `orderly_comparison_explain(..., "files", verbose = TRUE)` to compare the files' contents.
orderly_comparison_explain(cmp, verbose = TRUE)
#> ℹ Comparing packets 20261012-154800-8db128a1 and 20261012-154800-9905da8a...
#> ℹ Comparing attribute `parameters`
#> < 20261012-154800-8db128a1$parameters
#> > 20261012-154800-9905da8a$parameters
#> @@ 1,3 / 1,3 @@  
#>   $max_cyl       
#> < [1] 6          
#> > [1] 4          
#>                  
#> ! The following files differ across packets, but could not be compared as their content is binary:
#>   • data.rds
orderly_comparison_explain(cmp, "parameters", verbose = TRUE)
#> ℹ Comparing packets 20261012-154800-8db128a1 and 20261012-154800-9905da8a...
#> ℹ Comparing attribute `parameters`
#> < 20261012-154800-8db128a1$parameters
#> > 20261012-154800-9905da8a$parameters
#> @@ 1,3 / 1,3 @@  
#>   $max_cyl       
#> < [1] 6          
#> > [1] 4          
#>                  
```
