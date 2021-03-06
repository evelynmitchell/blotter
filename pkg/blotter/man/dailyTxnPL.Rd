\name{dailyTxnPL}
\alias{dailyEqPL}
\alias{dailyTxnPL}
\title{generate daily Transaction Realized or Equity Curve P&L by instrument}
\usage{
  dailyTxnPL(Portfolios, Symbols, drop.time = TRUE)

  dailyEqPL(Portfolios, Symbols, drop.time = TRUE)
}
\arguments{
  \item{Portfolios}{portfolio string}

  \item{Symbols}{character vector of symbol strings}

  \item{drop.time}{remove time component of POSIX datestamp
  (if any), default TRUE}
}
\value{
  a multi-column \code{xts} time series, one column per
  symbol, one row per day
}
\description{
  designed to collate information for high frequency
  portfolios
}
\details{
  If you do not pass \code{Symbols}, then all symbols in
  the provided \code{Portfolios} will be used.

  The daily P&L is calculated from
  \code{Net.Txn.Realized.PL} if by \code{dailyTxnPL} and
  from \code{Net.Trading.PL} by \code{dailyEqPL}
}
\author{
  Brian G. Peterson
}
\seealso{
  tradeStats
}

