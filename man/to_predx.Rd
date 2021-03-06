% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/to_predx.R
\name{to_predx}
\alias{to_predx}
\title{Helper function for creating lists of \code{predx} objects (e.g. a column in a data frame containing a variety of \code{predx} objects)}
\usage{
to_predx(x, class)
}
\arguments{
\item{x}{A list of data.frames.}

\item{class}{A character vector of \code{predx} class names}
}
\value{
A list of \code{predx} objects with error messages for failed conversions.
}
\description{
This function converts a data.frame or list of data frames (with appropriate columns and/or attributes as required for each predx class) and a vector of predx class names to a list of predx objects with (hopefully helpful) errors should any conversions fail.
}
