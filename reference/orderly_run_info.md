# Information about currently running report

Fetch information about the actively running report. This allows you to
reflect information about your report back as part of the report, for
example embedding the current report id, or information about computed
dependencies. This information is in a slightly different format to
orderly version 1.x and does not (currently) include information about
dependencies when run outside of
[`orderly_run()`](https://mrc-ide.github.io/orderly/reference/orderly_run.md),
but this was never reliable previously.

## Usage

``` r
orderly_run_info()
```

## Value

A list with elements

- `name`: The name of the current report

- `id`: The id of the current report, `NA` if running interactively

- `root`: The orderly root path

- `depends`: A data frame with information about the dependencies (not
  available interactively)

  - `index`: an integer sequence along calls to
    [`orderly_dependency()`](https://mrc-ide.github.io/orderly/reference/orderly_dependency.md)

  - `name`: the name of the dependency

  - `query`: the query used to find the dependency

  - `id`: the computed id of the included packet

  - `filename`: the file used from the packet

  - `as`: the filename used locally

## Examples

``` r
# An example from the orderly examples
orderly_example_show("run_info")
#> 
#> ── src/run_info/run_info.R ─────────────────────────────────────────────────────
#> orderly_dependency("data", "latest", c("xy.rds" = "data.rds"))
#> xy <- readRDS("xy.rds")
#>  
#> info <- orderly_run_info()
#> print(info)
#>  
#> orderly_artefact("plot.png", description = "A plot of data")
#> png("plot.png")
#> plot(xy)
#> dev.off()

# Prepare to run
path <- orderly_example()
#> ✔ Created orderly root at '/tmp/RtmpG21yn4/orderly_ex_1998619b8d51'
orderly_run("data", root = path, echo = FALSE)
#> ℹ Starting packet 'data' `20261012-154815-b251e794` at 2026-10-12 15:48:15.69999
#> ✔ Finished running data.R
#> ℹ Finished 20261012-154815-b251e794 at 2026-10-12 15:48:15.73699 (0.03699994 secs)
#> [1] "20261012-154815-b251e794"

# Here, see the printed information from a real running report
orderly_run("run_info", root = path)
#> ℹ Starting packet 'run_info' `20261012-154815-c136b22d` at 2026-10-12 15:48:15.75821
#> > orderly_dependency("data", "latest", c("xy.rds" = "data.rds"))
#> ℹ Depending on data @ `20261012-154815-b251e794` (via latest(name == "data"))
#> > xy <- readRDS("xy.rds")
#> > info <- orderly_run_info()
#> > print(info)
#> $name
#> [1] "run_info"
#> 
#> $id
#> [1] "20261012-154815-c136b22d"
#> 
#> $root
#> [1] "/tmp/RtmpG21yn4/orderly_ex_1998619b8d51"
#> 
#> $depends
#>   index name                  query                       id    there   here
#> 1     1 data latest(name == "data") 20261012-154815-b251e794 data.rds xy.rds
#> 
#> > orderly_artefact("plot.png", description = "A plot of data")
#> > png("plot.png")
#> > plot(xy)
#> > dev.off()
#> agg_record_19984f1fbb92 
#>                       2 
#> ✔ Finished running run_info.R
#> ℹ Finished 20261012-154815-c136b22d at 2026-10-12 15:48:15.805357 (0.04714751 secs)
#> [1] "20261012-154815-c136b22d"
```
