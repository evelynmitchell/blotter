\name{TSCov}
\Rdversion{1.1}
\alias{TSCov}
\title{ Two time scale covariance estimation }

\description{

Function returns the two time scale covariance matrix proposed in Zhang et al (2005) and Zhang (2010).
By the use of two time scales, this covariance estimate 
is robust to microstructure noise and non-synchronic trading.

}


\usage{
TSCov(pdata, cor=FALSE, K = 300 , J = 1,  makePsd = FALSE);
}
 
\arguments{
\item{pdata}{ a list. Each list-item i contains an xts object with the intraday price data 
of stock i for day t.}
\item{cor}{ boolean, in case it is TRUE, the correlation is returned. FALSE by default.}
\item{K}{positive integer, slow time scale returns are computed on prices that are K steps apart.}
\item{J}{positive integer, fast time scale returns are computed on prices that are J steps apart.}
\item{makePsd}{ boolean, in case it is TRUE, the positive definite version of RTSCov is returned. FALSE by default.}
}

\value{
an \eqn{N x N} matrix
}

\details{
The TSCov requires the tick-by-tick transaction prices. (Co)variances are then computed using log-returns calculated on a rolling basis 
on stock prices that are \eqn{K} (slow time scale) and \eqn{J} (fast time scale) steps apart.     


The diagonal elements of the TSCov matrix are the variances, computed for log-price series \eqn{X} with \eqn{n} price observations 
 at times \eqn{  \tau_1,\tau_2,\ldots,\tau_n} as follows: 

\deqn{(1-\frac{\overline{n}_K}{\overline{n}_J})^{-1}([X,X]_T^{(K)}-
\frac{\overline{n}_K}{\overline{n}_J}[X,X]_T^{(J))}}

where \eqn{\overline{n}_K=(n-K+1)/K},  \eqn{\overline{n}_J=(n-J+1)/J} and 
\deqn{[X,X]_T^{(K)} =\frac{1}{K}\sum_{i=1}^{n-K+1}(X_{t_{i+K}}-X_{t_i})^2.} 

The extradiagonal elements of the TSCov are the covariances. 
For their calculation, the data is first synchronized by the refresh time method proposed by Harris et al (1995).
It uses the function \code{\link{refreshTime}} to collect first the so-called refresh times at which all assets have traded at least once 
since the last refresh time point. Suppose we have two log-price series:  \eqn{X} and \eqn{Y}. Let \eqn{ \Gamma =\{ \tau_1,\tau_2,\ldots,\tau_{N^{\mbox{\tiny X}}_{\mbox{\tiny T}}}\}} and 
\eqn{\Theta=\{\theta_1,\theta_2,\ldots,\theta_{N^{\mbox{\tiny Y}}_{\mbox{\tiny T}}}\}} 
be the set of transaction times of these assets. 
The first refresh time corresponds to the first time at which both stocks have traded, i.e. 
\eqn{\phi_1=\max(\tau_1,\theta_1)}. The subsequent refresh time is defined as the first time when both stocks have again traded, i.e.
\eqn{\phi_{j+1}=\max(\tau_{N^{\mbox{\tiny{X}}}_{\phi_j}+1},\theta_{N^{\mbox{\tiny{Y}}}_{\phi_j}+1})}. The
 complete refresh time sample grid is 
 \eqn{\Phi=\{\phi_1,\phi_2,...,\phi_{M_N+1}\}}, where \eqn{M_N} is the total number of paired returns.  The
sampling points of asset \eqn{X} and \eqn{Y} are defined to be
\eqn{t_i=\max\{\tau\in\Gamma:\tau\leq \phi_i\}} and
\eqn{s_i=\max\{\theta\in\Theta:\theta\leq \phi_i\}}.


Given these refresh times, the covariance is computed as follows: 
\deqn{
c_{N}( [X,Y]^{(K)}_T-\frac{\overline{n}_K}{\overline{n}_J}[X,Y]^{(J)}_T ),
}

where
\deqn{[X,Y]^{(K)}_T =\frac{1}{K} \sum_{i=1}^{M_N-K+1} (X_{t_{i+K}}-X_{t_{i}})(Y_{s_{i+K}}-Y_{s_{i}}).}

Unfortunately, the TSCov is not always positive semidefinite.  
By setting the argument makePsd = TRUE, the function  \code{\link{makePsd}} is used to return a positive semidefinite
matrix. This function replaces the negative eigenvalues with zeroes. 


}

\references{
Harris, F., T. McInish, G. Shoesmith, and R. Wood (1995). Cointegration, error
correction, and price discovery on infomationally linked security markets. Journal
of Financial and Quantitative Analysis 30, 563-581.

Zhang, L., P. A. Mykland, and Y. Ait-Sahalia (2005). A tale of two time scales:
Determining integrated volatility with noisy high-frequency data. Journal of the
American Statistical Association 100, 1394-1411.

Zhang, L. (2010). Estimating covariation: Epps effect, microstructure noise. Journal
of Econometrics, forthcoming.
}

\author{ Jonathan Cornelissen and Kris Boudt}

\keyword{ volatility }
