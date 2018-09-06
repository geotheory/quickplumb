# Quick Plumber API

This package provides a single function that generates a highly flexible plumber API for any R data.frame, tibble, or DBI-compatible database (`dbplyr::src_dbi`) with just a couple of lines.  The aim is to extend `dplyr`'s tidy data manipulation capabilities to the front-end client by providing an API syntax that mirrors that of dplyr - so you can _filter_, _group_, _summarise_ and _arrange_ - via API call - data that is located in a PostgreSQL database.

#### Installation

    devtools::install_github('geotheory/quickplumb')


### Usage

Create the following file:

    # plumber.R

    require(quickplumb)
    require(plumber)
    require(dplyr)
    require(RPostgreSQL)

    drv <<- dbDriver("PostgreSQL")
    sapply(dbListConnections(drv), dbDisconnect)
    con <<- dbConnect(drv, dbname = "mydb", host = "localhost",
                     port = 5432, user = "username")

    #' redirect root to your Swagger API documentation page
    #' @get /
    #' @html
    function(){'<meta http-equiv="refresh" content="0; URL=\'./__swagger__/\'" />'}

    # To create iris db table run following line once:
    # copy_to(con, iris, "iris", temporary = FALSE)

    iris_pg <<- tbl(con, "iris")
    iris_pg_names = names(collect(head(iris_pg, 1)))

    #' iris dataset for demo & testing
    #' @param all_params See documentation
    #' @get /iris
    quick_plumb(tbl = iris_pg, tbl_names = iris_pg_names, def_max_records = 100, hard_max_records = 150)

To start the API navigate R to the `plumber.R` directory and run:

    plumber::plumb()$run(port = 4444)


### API Arguments

- `...` A placeholder for any field name in the dataset to query and filter by.
  - **Numerical** arguments are identified by starting with one of <, >, ~  characters (~ changes to =), e.g: `Sepal.Length=>~7.1` is interpreted as ">=" (i.e. greater than or equal to). While described as _numerical_ this syntax also works with equivalent string comparisons.
  - **String** arguments (not starting ~/</>) are parsed with a boolean logic interpreter (using upper-case AND/OR operators) e.g: `Paris AND Berlin` or `Paris OR Berlin`; and recognises negation with "-" hyphen, e.g: `Species=-setosa`.

- `_select`: Fields to return - equivalent to `dplyr::select`. e.g. return only `_select=Species,Sepal.Length` or omit `_select=-Species`

- `_group_by`: Fields to group by for aggregations - equivalent to `dplyr::group_by`. Must be used together with `_summarise`  and/or `_count`

- `_summarise`: Aggregate fields by a function - equivalent to `dplyr::summarise`. e.g.  `_group_by=Species&_summarise=mean:Sepal.Length`. Accepts multiple formulae (separate by +) in the format `fun:field1,field2,..` where aggregate function `fun` is piped directly to dplyr::filter.  Functions tested include `max`,`min`,`mean`, and `sum`.  Other desirables such as `mode`, `median`, `dplyr::first/last` are not currently supported, but hopefully will be soon.

- `_count`: Count records - equivalent to `dplyr::count` but requires any grouping to be done by `_group_by`. e.g. `_group_by=Species&_count=yes` or just `_count=yes` to count all records

- `_arrange_by`: Sort resulting table by specific field(s) - equivalent to `dplyr::arrange`. e.g. `_arrange_by=Species,Sepal.Length`

- `max_records`: Maximum data rows to return. e.g. `max_records=1000`

- `case_sen`: case-sensitivity - boolean querying ignores case by default. Providing this argument over-rides, e.g. `case_sen=true`


### Example API calls

- API root endpoint

    http://127.0.0.1:4444/iris

- a boolean logical query (URL spaces are replaced by '%20' by the browser)

    [http://127.0.0.1:4444/iris?Species=setosa OR virginica](http://127.0.0.1:4444/iris?Species=setosa%20OR%20virginica)

- a NOT query - i.e. omit setosa

    http://127.0.0.1:4444/iris?Species=-setosa

- a numerical comparative filter (tilde ~ becomes '=', so this example shows _greater-than-and-equal-to_ and _less-than_ usage)

    [http://127.0.0.1:4444/iris?Sepal.Length=>~7.0&Sepal.Length=<7.5](http://127.0.0.1:4444/iris%3fSepal.Length%3d%3e~7.0%26Sepal.Length%3d%3c7.5)

- return specified fields only

    http://127.0.0.1:4444/iris?_select=Sepal.Length,Sepal.Width

- return all fields except specified

    http://127.0.0.1:4444/iris?_select=-Species

- sort matching data by field(s)

    http://127.0.0.1:4444/iris?_arrange_by=Petal.Length,Petal.Width

- number of records to return (unless overridden by `quick_plumb(hard_max_records=...)`)

    http://127.0.0.1:4444/iris?max_records=10

- count rows by variable

    http://127.0.0.1:4444/iris?_group_by=Species&_count=yes

- aggregate data by variable(s)

    http://127.0.0.1:4444/iris?_group_by=Species&_summarise=mean:Sepal.Length,Sepal.Width+max:Petal.Length,Petal.Width

- for an idea of more complex query, create an API for ggplot2::diamonds at `/diamonds` and call:

    [http://127.0.0.1:4444/diamonds?carat=%3E2&_group_by=cut,color&_summarise=mean:price+sum:price&_count=yes&_arrange_by=-price_mean](http://127.0.0.1:4444/diamonds?carat=%3E2&_group_by=cut,color&_summarise=mean:price+sum:price&_count=yes&_arrange_by=-price_mean)
