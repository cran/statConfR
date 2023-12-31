#' Fit a static confidence model to data
#'
#' This function fits one static model of decision confidence to empirical data.
#' It calls a corresponding fitting function for the selected model.
#'
#' @param data  a `data.frame` where each row is one trial, containing following
#' variables:
#' * \code{condition} (optional; different levels of discriminability,
#'    should be a factor with levels ordered from hardest to easiest),
#' * \code{rating} (discrete confidence judgments, should be given as factor;
#'    otherwise will be transformed to factor with a warning),
#' * \code{stimulus} (stimulus category in a binary choice task,
#'    should be a factor with two levels, otherwise it will be transformed to
#'    a factor with a warning),
#' * \code{correct} (encoding whether the response was correct; should  be 0 for incorrect responses and 1 for correct responses)
#' @param model `character` of length 1.
#' Models implemented so far: 'WEV', 'SDT', 'Noisy', 'PDA', 'IG', 'ITGc' and 'ITGcm'
#' Alternatively, if `model="all"` (default), all implemented models will be fit.
#' @param nInits `integer`. Number of initial values used for maximum likelihood optimization.
#' Defaults to 5.
#' @param nRestart `integer`. Number of times the optimization is restarted.
#' Defaults to 4.
#' @return Gives data frame with one row and columns for the fitted parameters of the
#' selected model as well as additional information about the fit
#' (`negLogLik` (negative log-likelihood of the final set of parameters),
#' `k` (number of parameters), `N` (number of data rows), `BIC`, `AICc` and `AIC`)
#'
#' @details The fitting routine first performs a coarse grid search to find promising
#' starting values for the maximum likelihood optimization procedure. Then the best \code{nInits}
#' parameter sets found by the grid search are used as the initial values for separate
#' runs of the Nelder-Mead algorithm implemented in \code{\link[stats]{optim}}.
#' Each run is restarted \code{nRestart} times.
#'
#' ## Mathematical description of models
#'
#' The computational models are all based on signal detection theory. It is assumed
#' that participants select a binary discrimination response \eqn{R} about a stimulus \eqn{S}.
#' Both \eqn{S} and \eqn{R} can be either -1 or 1 (although the function outputs
#' use A and B to refer to the two stimulus categories when it is convenient).
#' \eqn{R} is considered correct if \eqn{S=R}.
#' In addition, we assume that there are \eqn{K} different levels of stimulus discriminability
#' in the experiment, i.e. a physical variable that makes the task easier or harder.
#' For each level of discriminability, the function fits a different discrimination
#' sensitivity parameter \eqn{d_k}. The models assume that the stimulus
#' generates normally distributed sensory evidence \eqn{x} with mean \eqn{S\times d_k/2}
#' and variance of 1. The sensory evidence \eqn{x} is compared to a decision
#'  threshold \eqn{\theta} to generate a discrimination response
#' \eqn{R}, which is 1, if \eqn{x} exceeds \eqn{\theta} and -1 else.
#' To generate confidence, it is assumed that the confidence variable \eqn{y} is compared to another
#' set of thresholds \eqn{c_{D,i}, D=A, B,  i=1,...,L-1}, depending on the
#' discrimination decision \eqn{D} to produce a \eqn{L}-step discrete confidence response.
#' The number of thresholds will be inferred from the number of steps in the
#' `rating` column of `data`.
#' The parameters shared between all models are therefore:
#' - sensitivity parameters \eqn{d_1},...,\eqn{d_K} (\eqn{K}: number of difficulty levels)
#' - decision threshold \eqn{\theta}
#' - confidence threshold \eqn{c_{A,1}},...\eqn{c_{A,L-1}},\eqn{c_{B,1}},...
#' \eqn{c_{B,L-1}} (\eqn{L}: number of steps for confidence ratings)
#'
#' How the confidence variable \eqn{y} is computed varies across the different models.
#' The following models have been implemented so far:
#'
#' ### \strong{Signal Detection Rating Model (SDT)}
#' According to the signal detection rating model (Green & Swets, 1966), the same sample of sensory
#' evidence is used to generate response and confidence, i.e.,
#' \eqn{y=x} and the confidence thresholds span from the left and
#' right side of the decision threshold \eqn{\theta}.
#'
#' ### \strong{Gaussian Noise Model (Noisy)}
#' According to the Gaussian noise model (Maniscalco & Lau, 2016), \eqn{y} is subject to
#' additive noise and assumed to be normally distributed around the decision
#' evidence value \eqn{x} with some standard deviation \eqn{\sigma}.
#' \eqn{\sigma} is an additional free parameter.
#'
#' ### \strong{Weighted Evidence and Visibility model (WEV)}
#' WEV assumes that the observer combines evidence about decision-relevant features
#' of the stimulus with the strength of evidence about choice-irrelevant features
#' to generate confidence (Rausch et al., 2018). Thus, the WEV model assumes that \eqn{y} is normally
#' distributed with a mean of \eqn{(1-w)\times x+w \times d_k\times R} and standard deviation \eqn{\sigma}.
#' The standard deviation quantifies the amount of unsystematic variability
#' contributing to confidence judgments but not to the discrimination judgments.
#' The parameter \eqn{w} represents the weight that is put on the choice-irrelevant
#' features in the confidence judgment. \eqn{w} and \eqn{\sigma} are fitted in
#' addition to the common parameters.
#'
#' ### \strong{Post-decisional accumulation model (PDA)}
#' PDA represents the idea of on-going information accumulation after the
#' discrimination choice (Rausch et al., 2018). The parameter \eqn{a} indicates the amount of additional
#' accumulation. The confidence variable is normally distributed with mean
#' \eqn{x+S\times d_k\times a} and variance \eqn{a}.
#' For this model the parameter \eqn{a} is fitted in addition to the common
#' parameters.
#'
#' ### \strong{Independent Gaussian Model (IG)}
#' According to the Independent Gaussian Model, \eqn{y} is sampled independently
#' from \eqn{x} (Rausch & Zehetleitner, 2017). It is normally distributed with a mean of \eqn{a\times d_k} and variance
#' of 1 (again as it would scale with \eqn{a}). The additional parameter \eqn{a}
#' represents the amount of information available for confidence judgment
#' relative to amount of evidence available for the discrimination decision and
#'  can be smaller as well as greater than 1.
#'
#' ### \strong{Independent Truncated Gaussian Model - Version Fleming (ITGc)}
#' According to the version of the Independent Truncated Gaussian Models consistent
#' with the HMetad-method (Fleming, 2017; see Rausch et al., 2023), \eqn{y} is sampled independently
#' from \eqn{x} from a truncated Gaussian distribution with a location parameter
#' of \eqn{S\times d_k \times m/2} and a scale parameter of 1. The Gaussian distribution of \eqn{y}
#' is truncated in a way that it is impossible to sample evidence that contradicts
#' the original decision: If \eqn{R = -1}, the distribution is truncated to the
#' right of \eqn{\theta}. If \eqn{R = 1}, the distribution is truncated to the left
#' of \eqn{\theta}. The additional parameter \eqn{m} represents metacognitive efficiency,
#' i.e., the amount of information available for confidence judgments relative to
#' amount of evidence available for discrimination decisions and  can be smaller
#' as well as greater than 1.
#'
#' ### \strong{Independent Truncated Gaussian Model - Version Maniscalco and Lau (ITGcm)}
#' According to the version of the Independent Truncated Gaussian Models consistent
#' with the original meta-d' method (Maniscalco & Lau, 2012, see Rausch et al., 2023),
#' \eqn{y} is sampled independently
#' from \eqn{x} from a truncated Gaussian distribution with a location parameter
#' of \eqn{S\times d_k \times m/2} and a scale parameter
#' of 1. If \eqn{R = -1}, the distribution is truncated to the right of \eqn{m\times\theta}.
#' If \eqn{R = 1}, the distribution is truncated to the left of  \eqn{m\times\theta}.
#' The additional parameter \eqn{m} represents metacognitive efficiency, i.e.,
#' the amount of information available for confidence judgments relative to
#' amount of evidence available for the discrimination decision and  can be smaller
#' as well as greater than 1.
#'
#' @md
#'
#' @author Sebastian Hellmann, \email{sebastian.hellmann@@ku.de}
#' @author Manuel Rausch, \email{manuel.rausch@@hochschule-rhein-waal.de}
#'
#' @name fitConf
#' @importFrom stats dnorm pnorm qnorm optim integrate
#'
#' @references Fleming, S. M. (2017). HMeta-d: Hierarchical Bayesian estimation of metacognitive efficiency from confidence ratings. Neuroscience of Consciousness, 1, 1–14. doi: 10.1093/nc/nix007
#' @references Green, D. M., & Swets, J. A. (1966). Signal detection theory and psychophysics. Wiley.
#' @references Maniscalco, B., & Lau, H. (2016). The signal processing architecture underlying subjective reports of sensory awareness. Neuroscience of Consciousness, 1, 1–17. doi: 10.1093/nc/niw002
#' @references Rausch, M., Hellmann, S., & Zehetleitner, M. (2018). Confidence in masked orientation judgments is informed by both evidence and visibility. Attention, Perception, and Psychophysics, 80(1), 134–154. doi: 10.3758/s13414-017-1431-5
#' @references Rausch, M., Hellmann, S., & Zehetleitner, M. (2023). Measures of metacognitive efficiency across cognitive models of decision confidence (Preprint). PsyArXiv. doi: 10.31234/osf.io/kdz34
#' @references Rausch, M., & Zehetleitner, M. (2017). Should metacognition be measured by logistic regression? Consciousness and Cognition, 49, 291–312. doi: 10.1016/j.concog.2017.02.007
#'
#' @examples
#' # 1. Select one subject from the masked orientation discrimination experiment
#' data <- subset(MaskOri, participant == 1)
#' head(data)
#'
#' # 2. Use fitting function
#' \donttest{
#'   # Fitting takes some time to run:
#'   FitFirstSbjSDT <- fitConf(data, model=c("SDT"))
#' }
#'
#'

#' @export
fitConf <- function(data, model, nInits = 5, nRestart = 4#, var="constant"
) {
  if (is.null(data$condition)) data$condition <- 1
  if (!is.factor(data$condition)) {
    data$condition <- factor(data$condition)
    warning("condition transformed to a factor!")
  }
  if(length(unique(data$stimulus)) != 2) {
    stop("There must be exactly two different values of stimulus")
  }
  if (!is.factor(data$stimulus)) {
    data$stimulus <- factor(data$stimulus)
    warning("stimulus transformed to a factor!")
  }
  if (!is.factor(data$rating)) {
    data$rating <- factor(data$rating)
    warning("rating  transformed to a factor!")
  }
  if(!all(data$correct %in% c(0,1))) stop("correct should be 1 or 0")

  if (model == "WEV") {
    fitting_fct <- fitCEV
    #if (var=="increasing") fitting_fct <- fitCEVvarS
  } else if (model=="SDT") {
    fitting_fct <- fitSDT
    #if (var=="increasing") fitting_fct <- fitSDTvarS
  } else if (model=="IG") {
    fitting_fct <- fit2Chan
  } else if (model=="ITGc") {
    fitting_fct <- fitITGc
  } else if (model=="ITGcm") {
    fitting_fct <- fitITGcm
  } else if (model=="Noisy") {
    fitting_fct <- fitNoisy
  } else if (model=="PDA") {
    fitting_fct <- fitPDA
  } else stop(paste0("Model: ", model, " not implemented!\nChoose one of: 'WEV', 'SDT','IG', 'ITGc', 'ITGcm,'Noisy', or 'PDA'"))

  fit <- fitting_fct(data$rating, data$stimulus, data$correct, data$condition,
                     nInits = nInits, nRestart = nRestart)
  return(fit)
}
