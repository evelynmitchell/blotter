\name{addTxn}
\alias{addTxn}
\alias{addTxns}
\title{Add transactions to a portfolio.}
\usage{
  addTxn(Portfolio, Symbol, TxnDate, TxnQty, TxnPrice, ...,
    TxnFees = 0, ConMult = NULL, verbose = TRUE,
    eps = 1e-06)

  addTxns(Portfolio, Symbol, TxnData, verbose = FALSE, ...,
    ConMult = NULL)
}
\arguments{
  \item{Portfolio}{A portfolio name that points to a
  portfolio object structured with \code{initPortf()}}

  \item{Symbol}{An instrument identifier for a symbol
  included in the portfolio, e.g., "IBM"}

  \item{TxnDate}{Transaction date as ISO 8601, e.g.,
  '2008-09-01' or '2010-01-05 09:54:23.12345'}

  \item{TxnQty}{Total units (such as shares or contracts)
  transacted.  Positive values indicate a 'buy'; negative
  values indicate a 'sell'}

  \item{TxnPrice}{Price at which the transaction was done}

  \item{\dots}{Any other passthrough parameters}

  \item{TxnFees}{Fees associated with the transaction, e.g.
  commissions., See Details}

  \item{ConMult}{Contract/instrument multiplier for the
  Symbol if it is not defined in an instrument
  specification}

  \item{verbose}{If TRUE (default) the function prints the
  elements of the transaction in a line to the screen,
  e.g., "2007-01-08 IBM 50 @ 77.6". Suppress using FALSE.}

  \item{eps}{value to add to force unique indices}

  \item{TxnData}{An xts object containing all required txn
  fields (for addTxns)}
}
\description{
  When a trade or adjustment is made to the Portfolio, the
  addTxn function calculates the value and average cost of
  the transaction, the change in position, the resulting
  positions average cost, and any realized profit or loss
  (net of fees) from the transaction. Then it stores the
  transaction and calculations in the Portfolio object.
}
\details{
  Fees are indicated as negative values and will be
  subtracted from the transaction value. TxnFees can either
  be a fixed numeric amount, or a function (or charavcter
  name of a function) in which case the function is
  evaluated to determine the fee amount.

  The \code{\link{pennyPerShare}} function provides a
  simple example of a transaction cost function.

  Transactions which would cross the position through zero
  will be split into two transactions, one to flatten the
  position, and another to initiate a new position on the
  opposite side of the market.  The new (split) transaction
  will have its timestamp incremented by \code{eps} to
  preserve ordering.

  This transaction splitting vastly simplifies realized P&L
  calculations elsewhere in the code. Such splitting also
  mirrors many execution platforms and brokerage
  requirements in particular asset classes where the side
  of a trade needs to be specified with the order.

  The \code{addTxns} function allows you to add multiple
  transactions to the portfolio, which is much faster than
  adding them one at a time. The \code{TxnData} object must
  have "TxnQty" and "TxnPrice" columns, while the "TxnFees"
  column is optional.
}
\note{
  The addTxn function will eventually also handle other
  transaction types, such as adjustments for corporate
  actions or expire/assign for options. See
  \code{\link{addDiv}}
}
\author{
  Peter Carl, Brian G. Peterson
}
\seealso{
  \code{\link{addTxns}}, \code{\link{pennyPerShare}},
  \code{\link{initPortf}}
}

