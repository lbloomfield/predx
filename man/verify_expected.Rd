% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/verify_expected.R
\name{verify_expected}
\alias{verify_expected}
\title{Verify inclusion of expected predictions}
\usage{
verify_expected(x, expected_list, return_df = FALSE, print_output = !return_df)
}
\arguments{
\item{x}{predx_df}

\item{expected_list}{list of lists (see Note)}

\item{return_df}{if \code{TRUE} (default is \code{FALSE}) will return a list of missing predictions}

\item{print_output}{if \code{TRUE} (default) prints results}
}
\value{
If any predictions in \code{expected_list} are not found or if additional predictions are found, the function will print the missing and/or additional rows (\code{print_out = TRUE}) or return a data frame with a status designation for each missing and/or additional row (\code{return_df = TRUE}).
}
\description{
Function to check a set of predictions for a set of expected predictions
(e.g. targets, locations)
}
\note{
\code{expected_list} is a two-level list of sets of expected predictions.
The lower level (e.g. \code{expected_list[[1]]}) is a list of named character vectors
with specific expected predictions. The names should match column names
in \code{x}. The function checks that all combinations of those elements are
present in \code{x}. A named vector \code{predx_class} may be used to check
predx types.
}
\examples{
predx_demo <- as.predx_df(list(
  location = c("Mercury", "Venus", "Earth"),
  target = "habitability",
  predx = list(Binary(1e-4), Binary(1e-4), Binary(1))
))

expected_demo <- list(
  list(
    location = c("Mercury", "Venus", "Earth"),
    target = "habitability",
    predx_class = "Binary"
  )
)


expected_demo2 <- list(
  list(
    location = c("Mercury", "Mars"),
    target = "habitability",
    predx_class = "Binary"
  )
)

verify_expected(predx_demo, expected_demo)
verify_expected(predx_demo, expected_demo2)
}
