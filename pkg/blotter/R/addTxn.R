#' Add transactions to a portfolio.
#' 
#' When a trade or adjustment is made to the Portfolio, the addTxn function 
#' calculates the value and average cost of the transaction,  the change in 
#' position, the resulting positions average cost, and any realized profit 
#' or loss (net of fees) from the transaction. Then it stores the transaction 
#' and calculations in the Portfolio object.
#'
#' Fees are indicated as negative values and will be
#' subtracted from the transaction value. TxnFees can either
#' be a fixed numeric amount, or a function (or charavcter
#' name of a function) in which case the function is
#' evaluated to determine the fee amount.
#'
#' The \code{\link{pennyPerShare}} function provides a simple
#' example of a transaction cost function.
#'
#' Transactions which would cross the position through zero
#' will be split into two transactions, one to flatten the
#' position, and another to initiate a new position on the
#' opposite side of the market.  The new (split) transaction
#' will have its timestamp incremented by \code{eps} to
#' preserve ordering.
#'
#' This transaction splitting vastly simplifies realized P&L
#' calculations elsewhere in the code. Such splitting also
#' mirrors many execution platforms and brokerage
#' requirements in particular asset classes where the side
#' of a trade needs to be specified with the order.
#'
#' The \code{addTxns} function allows you to add multiple
#' transactions to the portfolio, which is much faster than
#' adding them one at a time. The \code{TxnData} object must
#' have "TxnQty" and "TxnPrice" columns, while the "TxnFees"
#' column is optional.
#' 
#' @param Portfolio  A portfolio name that points to a portfolio object structured with \code{initPortf()}
#' @param Symbol An instrument identifier for a symbol included in the portfolio, e.g., "IBM"
#' @param TxnDate  Transaction date as ISO 8601, e.g., '2008-09-01' or '2010-01-05 09:54:23.12345'
#' @param TxnQty Total units (such as shares or contracts) transacted.  Positive values indicate a 'buy'; negative values indicate a 'sell'
#' @param TxnPrice  Price at which the transaction was done
#' @param \dots Any other passthrough parameters
#' @param TxnFees Fees associated with the transaction, e.g. commissions., See Details
#' @param ConMult Contract/instrument multiplier for the Symbol if it is not defined in an instrument specification
#' @param verbose If TRUE (default) the function prints the elements of the transaction in a line to the screen, e.g., "2007-01-08 IBM 50 @@ 77.6". Suppress using FALSE.
#' @param eps value to add to force unique indices
#' @param TxnData  An xts object containing all required txn fields (for addTxns)
#' @note 
#' The addTxn function will eventually also handle other transaction types, 
#' such as adjustments for corporate actions or expire/assign for options. 
#' See \code{\link{addDiv}} 
#'
#' @seealso \code{\link{addTxns}}, \code{\link{pennyPerShare}}, \code{\link{initPortf}}
#' @author Peter Carl, Brian G. Peterson
#' @export addTxn
#' @export addTxns
addTxn <- function(Portfolio, Symbol, TxnDate, TxnQty, TxnPrice, ..., TxnFees=0, ConMult=NULL, verbose=TRUE, eps=1e-06)
{ 

    pname <- Portfolio
    PrevPosQty = getPosQty(pname, Symbol, TxnDate)
    
    if(!is.timeBased(TxnDate) ){
        TxnDate<-as.POSIXct(TxnDate)
    }
    
    # split transactions that would cross through zero
    if(PrevPosQty!=0 && sign(PrevPosQty+TxnQty)!=sign(PrevPosQty) && PrevPosQty!=-TxnQty){
        txnFeeQty=TxnFees/abs(TxnQty) # calculate fees pro-rata by quantity
        addTxn(Portfolio=pname, Symbol=Symbol, TxnDate=TxnDate, TxnQty=-PrevPosQty, TxnPrice=TxnPrice, ..., 
                TxnFees = txnFeeQty*abs(PrevPosQty), ConMult = ConMult, verbose = verbose, eps=eps)
        TxnDate=TxnDate+2*eps #transactions need unique timestamps, so increment a bit
        TxnQty=TxnQty+PrevPosQty
        PrevPosQty=0
        TxnFees=txnFeeQty*abs(TxnQty+PrevPosQty)
    }
    
    Portfolio<-get(paste("portfolio",pname,sep='.'),envir=.blotter)

    if(is.null(ConMult) | !hasArg(ConMult)){
        tmp_instr<-try(getInstrument(Symbol), silent=TRUE)
        if(inherits(tmp_instr,"try-error") | !is.instrument(tmp_instr)){
            warning(paste("Instrument",Symbol," not found, using contract multiplier of 1"))
            ConMult<-1
        } else {
            ConMult<-tmp_instr$multiplier
        }
    }

  	#If there is no table for the symbol then create a new one
  	if (is.null(Portfolio$symbols[[Symbol]])){ 
  		addPortfInstr(Portfolio=pname, symbols=Symbol)
  		Portfolio<-get(paste("portfolio",pname,sep='.'),envir=.blotter)
  	}


    # FUNCTION
    # Coerce the transaction fees to a function if a string was supplied
    
    if(is.character(TxnFees)) {
        TF <- try(match.fun(TxnFees), silent=TRUE)
        if (!inherits(TF,"try-error")) TxnFees<-TF
    }
    # Compute transaction fees if a function was supplied
    if (is.function(TxnFees)) txnfees <- TxnFees(TxnQty, TxnPrice) else txnfees<- as.numeric(TxnFees)

    if(is.null(txnfees) | is.na(txnfees)) txnfees = 0
    if(txnfees>0) warning('Positive Transaction Fees should only be used in the case of broker/exchange rebates for TxnFees ',TxnFees,'. See Documentation.')
    
    # Calculate the value and average cost of the transaction
    TxnValue = .calcTxnValue(TxnQty, TxnPrice, 0, ConMult) # Gross of Fees
    TxnAvgCost = .calcTxnAvgCost(TxnValue, TxnQty, ConMult)

    # Calculate the change in position
    PosQty = PrevPosQty + TxnQty


    # Calculate the resulting position's average cost
    PrevPosAvgCost = .getPosAvgCost(pname, Symbol, TxnDate)
    PosAvgCost = .calcPosAvgCost(PrevPosQty, PrevPosAvgCost, TxnValue, PosQty, ConMult)

	
    # Calculate any realized profit or loss (net of fees) from the transaction
    GrossTxnRealizedPL = TxnQty * ConMult * (PrevPosAvgCost - TxnAvgCost)

  	# if the previous position is zero, RealizedPL = 0
  	# if previous position is positive and position is larger, RealizedPL =0
  	# if previous position is negative and position is smaller, RealizedPL =0
  	if(abs(PrevPosQty) < abs(PosQty) | (PrevPosQty = 0))
  		GrossTxnRealizedPL = 0
	
	  NetTxnRealizedPL = GrossTxnRealizedPL + txnfees

    # Store the transaction and calculations
    NewTxn = xts(t(c(TxnQty, TxnPrice, TxnValue, TxnAvgCost, PosQty, PosAvgCost, GrossTxnRealizedPL, txnfees, NetTxnRealizedPL, ConMult)), order.by=TxnDate)
    #colnames(NewTxns) = c('Txn.Qty', 'Txn.Price', 'Txn.Value', 'Txn.Avg.Cost', 'Pos.Qty', 'Pos.Avg.Cost', 'Gross.Txn.Realized.PL', 'Txn.Fees', 'Net.Txn.Realized.PL', 'Con.Mult')
    Portfolio$symbols[[Symbol]]$txn<-rbind(Portfolio$symbols[[Symbol]]$txn, NewTxn)

    if(verbose)
      # print(paste(TxnDate, Symbol, TxnQty, "@",TxnPrice, sep=" "))
      print(paste(format(TxnDate, "%Y-%m-%d %H:%M:%S"), Symbol, TxnQty, "@",TxnPrice, sep=" "))
      #print(Portfolio$symbols[[Symbol]]$txn)
    
    #portfolio is already an environment, it's been updated in place
    #assign(paste("portfolio",pname,sep='.'),Portfolio,envir=.blotter)
}

#' Example TxnFee cost function
#' @param TxnQty total units (such as shares or contracts) transacted.  Positive values indicate a 'buy'; negative values indicate a 'sell'
#' This is an example intended to demonstrate how a cost function could be used in place of a flat numeric fee.
#' @export
pennyPerShare <- function(TxnQty) {
    return(abs(TxnQty) * -0.01)
}

#' @rdname addTxn
#' @export
addTxns<- function(Portfolio, Symbol, TxnData , verbose=FALSE, ..., ConMult=NULL, eps=1e-06)
{
    pname<-Portfolio
    Portfolio<-get(paste("portfolio",pname,sep='.'),envir=.blotter)

    if(is.null(ConMult) | !hasArg(ConMult)){
        tmp_instr<-try(getInstrument(Symbol), silent=TRUE)
        if(inherits(tmp_instr,"try-error") | !is.instrument(tmp_instr)){
            warning(paste("Instrument",Symbol," not found, using contract multiplier of 1"))
            ConMult<-1
        } else {
            ConMult<-tmp_instr$multiplier
        }  
    }

    # initialize new transaction object
    NewTxns <- xts(matrix(NA_real_, nrow(TxnData), 10L), index(TxnData))
    colnames(NewTxns) <- c('Txn.Qty', 'Txn.Price', 'Txn.Value', 'Txn.Avg.Cost', 'Pos.Qty', 'Pos.Avg.Cost', 'Gross.Txn.Realized.PL', 'Txn.Fees', 'Net.Txn.Realized.PL', 'Con.Mult')

    NewTxns$Txn.Qty <- as.numeric(TxnData$TxnQty)
    NewTxns$Txn.Price <- as.numeric(TxnData$TxnPrice)
    if("TxnFees" %in% colnames(TxnData)) {
      NewTxns$Txn.Fees <- as.numeric(TxnData$TxnFees)
    } else {
      NewTxns$Txn.Fees <- 0
    }
    # split transactions that would cross through zero
    Pos <- drop(cumsum(NewTxns$Txn.Qty))
    Pos <- merge(Qty=Pos, PrevQty=lag(Pos))
    PosCrossZero <- Pos$PrevQty!= 0 & sign(Pos$PrevQty+NewTxns$Txn.Qty) != sign(Pos$PrevQty) & Pos$PrevQty!= -NewTxns$Txn.Qty
    PosCrossZero[1] <- FALSE
    if(any(PosCrossZero)) {
        # subset position object
        Pos <- Pos[PosCrossZero,]
        # subset transactions we need to split, and initialize objects we can alter
        flatTxns <- initTxns <- NewTxns[PosCrossZero,]
        # set quantity for flat and initiating transactions
        flatTxns$Txn.Qty <- -Pos$PrevQty
        initTxns$Txn.Qty <- initTxns$Txn.Qty + Pos$PrevQty
        # calculate fees pro-rata by quantity
        txnFeeQty <- NewTxns$Txn.Fees/abs(NewTxns$Txn.Qty)
        flatTxns$Txn.Fees <- txnFeeQty * abs(flatTxns$Txn.Qty)
        initTxns$Txn.Fees <- txnFeeQty * abs(initTxns$Txn.Qty)
        # transactions need unique timestamps, so increment initiating transaction index
        .index(initTxns) <- .index(initTxns) + 2*eps
        # remove split transactions from NewTxns, add flat and initiating transactions
        NewTxns <- rbind(NewTxns[!PosCrossZero,], flatTxns, initTxns)
        rm(flatTxns, initTxns, txnFeeQty)  # clean up
    }
    rm(Pos, PosCrossZero)  # clean up
    # calculate transaction values
    NewTxns$Txn.Value <- .calcTxnValue(NewTxns$Txn.Qty, NewTxns$Txn.Price, NewTxns$Txn.Fees, ConMult)
    NewTxns$Txn.Avg.Cost <- .calcTxnAvgCost(NewTxns$Txn.Value, NewTxns$Txn.Qty, ConMult)
    # intermediate objects to aid in vectorization; only first element is non-zero
    initPosQty <- initPosAvgCost <- numeric(nrow(NewTxns))
    initPosQty[1] <- getPosQty(pname, Symbol, start(NewTxns))
    initPosAvgCost[1] <- .getPosAvgCost(pname, Symbol, start(NewTxns))
    # cumulative sum of transaction qty + initial position qty
    NewTxns$Pos.Qty <- cumsum(initPosQty + NewTxns$Txn.Qty)
    # only pass non-zero initial position qty and average cost
    NewTxns$Pos.Avg.Cost <- .calcPosAvgCost_C(initPosQty[1], initPosAvgCost[1], NewTxns$Txn.Value, NewTxns$Pos.Qty, ConMult)
    # need lagged position average cost
    lagPosAvgCost <- c(initPosAvgCost[1], NewTxns$Pos.Avg.Cost[-nrow(NewTxns)])
    NewTxns$Gross.Txn.Realized.PL <- NewTxns$Txn.Qty * ConMult * (lagPosAvgCost - NewTxns$Txn.Avg.Cost)
    NewTxns$Net.Txn.Realized.PL <- NewTxns$Gross.Txn.Realized.PL - NewTxns$Txn.Fees
    NewTxns$Con.Mult <- ConMult

    # update portfolio with new transactions
    Portfolio$symbols[[Symbol]]$txn <- rbind(Portfolio$symbols[[Symbol]]$txn, NewTxns) 

    if(verbose) print(NewTxns)

    #portfolio is already an environment, it's been updated in place
    # assign(paste("portfolio",pname,sep='.'),Portfolio,envir=.blotter)    
}

#' Add cash dividend transactions to a portfolio.
#' 
#' Adding a cash dividend does not affect position quantity, like a split would.
#' 
#' @param Portfolio  A portfolio name that points to a portfolio object structured with \code{\link{initPortf}}.
#' @param Symbol An instrument identifier for a symbol included in the portfolio, e.g., IBM.
#' @param TxnDate  Transaction date as ISO 8601, e.g., '2008-09-01' or '2010-01-05 09:54:23.12345'.
#' @param DivPerShare The amount of the cash dividend paid per share or per unit quantity.
#' @param \dots Any other passthrough parameters.
#' @param TxnFees Fees associated with the transaction, e.g. commissions. See Details.
#' @param verbose If TRUE (default) the function prints the elements of the transaction in a line to the screen, e.g., "2007-01-08 IBM 50 @@ 77.6". Suppress using FALSE.
#' @param ConMult Contract or instrument multiplier for the Symbol if it is not defined in an instrument specification.
#' @export
#' @note
#' # TODO add TxnTypes to $txn table
#' 
#' # TODO add AsOfDate 
#' 
addDiv <- function(Portfolio, Symbol, TxnDate, DivPerShare, ..., TxnFees=0, ConMult=NULL, verbose=TRUE)
{ # @author Peter Carl
    pname<-Portfolio
    Portfolio<-get(paste("portfolio",pname,sep='.'),envir=.blotter)

    if(is.null(ConMult) | !hasArg(ConMult)){
        tmp_instr<-try(getInstrument(Symbol), silent=TRUE)
        if(inherits(tmp_instr,"try-error") | !is.instrument(tmp_instr)){
            warning(paste("Instrument",Symbol," not found, using contract multiplier of 1"))
            ConMult<-1
        } else {
            ConMult<-tmp_instr$multiplier
        }
    }

    # FUNCTION
    # 
    TxnQty = 0
    TxnPrice = 0
#     TxnType = "Dividend"
# TODO add TxnTypes to $txn table

    # Get the current position quantity
    PrevPosQty = getPosQty(pname, Symbol, TxnDate)
    PosQty = PrevPosQty # no change to position, but carry it forward
    # Calculate the value and average cost of the transaction
    # The -1 multiplier allows a positive DivPerShare value to create a
    # positive realized gain
    TxnValue = -1 * PrevPosQty * DivPerShare * ConMult # Calc total dividend paid
    TxnAvgCost = DivPerShare

    # No change to the the resulting position's average cost
    PrevPosAvgCost = .getPosAvgCost(pname, Symbol, TxnDate)
    PosAvgCost = PrevPosAvgCost # but carry it forward in $txn

    # Calculate any realized profit or loss (net of fees) from the transaction
    GrossTxnRealizedPL = PrevPosQty * DivPerShare * ConMult
    NetTxnRealizedPL = GrossTxnRealizedPL + TxnFees

    # Store the transaction and calculations
    NewTxn = xts(t(c(TxnQty, TxnPrice, TxnValue, TxnAvgCost, PosQty, PosAvgCost, GrossTxnRealizedPL, TxnFees, NetTxnRealizedPL, ConMult)), order.by=as.POSIXct(TxnDate))
    #colnames(NewTxns) = c('Txn.Qty', 'Txn.Price', 'Txn.Value', 'Txn.Avg.Cost', 'Pos.Qty', 'Pos.Avg.Cost', 'Gross.Txn.Realized.PL', 'Txn.Fees', 'Net.Txn.Realized.PL', 'Con.Mult')
    Portfolio$symbols[[Symbol]]$txn<-rbind(Portfolio$symbols[[Symbol]]$txn, NewTxn)

    if(verbose)
        print(paste(TxnDate, Symbol, "Dividend", DivPerShare, "on", PrevPosQty, "shares:", -TxnValue, sep=" "))
        #print(Portfolio$symbols[[Symbol]]$txn)

    #portfolio is already an environment, it's been updated in place
    #assign(paste("portfolio",pname,sep='.'),Portfolio,envir=.blotter)
}
###############################################################################
# Blotter: Tools for transaction-oriented trading systems development
# for R (see http://r-project.org/)
# Copyright (c) 2008-2011 Peter Carl and Brian G. Peterson
#
# This library is distributed under the terms of the GNU Public License (GPL)
# for full details see the file COPYING
#
# $Id$
#
###############################################################################
