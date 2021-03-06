\name{sigTimestamp}
\alias{sigTimestamp}
\title{generate a signal on a timestamp}
\usage{
  sigTimestamp(label, data = mktdata, timestamp,
    on = "days")
}
\arguments{
  \item{label}{text label to apply to the output}

  \item{data}{data to apply formula to}

  \item{timestamp}{either a POSIXct-based object, or a
  character string denoting a 24-hour time (e.g. 09:00,
  16:00)}

  \item{on}{only used if \code{timestamp} is character;
  passed to \code{\link[xts]{split.xts}}, therefore
  \code{on} may be a character describing the time period
  as listed in \code{\link[xts]{endpoints}}, or a vector
  coercible to factor (e.g. \code{\link[xts]{.indexday}})}
}
\description{
  This will generate a signal on a specific timestamp or at
  a specific time every day, week, weekday, etc.
}

