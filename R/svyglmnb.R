utils::globalVariables("scaled.weights")

#' @title Survey-weighted negative binomial generalised linear model
#' @name svyglm.nb
#' @description \code{svyglm.nb()} is an extension to the \CRANpkg{survey}-package
#'                to fit survey-weighted negative binomial models. It uses
#'                \code{\link[survey]{svymle}} to fit sampling-weighted
#'                maximum likelihood estimates, based on starting values provided
#'                by \code{\link[MASS]{glm.nb}}, as proposed by \emph{Lumley
#'                (2010, pp249)}.
#'
#'
#' @param formula An object of class \code{formula}, i.e. a symbolic description
#'          of the model to be fitted. See 'Details' in \code{\link[stats]{glm}}.
#' @param design An object of class \code{\link[survey]{svydesign}}, providing
#'          a specification of the survey design.
#' @param ... Other arguments passed down to \code{\link[MASS]{glm.nb}}.
#'
#' @return An object of class \code{\link[survey]{svymle}} and \code{svyglm.nb},
#'           with some additional information about the model.
#'
#' @details For details on the computation method, see Lumley (2010), Appendix E
#'   (especially 254ff.)
#'   \cr \cr
#'   \pkg{sjstats} implements following S3-methods for \code{svyglm.nb}-objects:
#'   \code{family()}, \code{model.frame()}, \code{formula()}, \code{print()},
#'   \code{predict()} and \code{residuals()}. However, these functions have some
#'   limitations:
#'   \itemize{
#'     \item{\code{family()} simply returns the family-object from the
#'     underlying \code{\link[MASS]{glm.nb}}-model.}
#'     \item{The \code{predict()}-method just re-fits the \code{svyglm.nb}-model
#'     with \code{\link[MASS]{glm.nb}}, overwrites the \code{$coefficients}
#'     from this model-object with the coefficients from the returned
#'     \code{\link[survey]{svymle}}-object and finally calls
#'     \code{\link[stats]{predict.glm}} to compute the predicted values.}
#'     \item{\code{residuals()} re-fits the \code{svyglm.nb}-model with
#'     \code{\link[MASS]{glm.nb}} and then computes the Pearson-residuals
#'     from the \code{glm.nb}-object.}
#'   }
#'
#'
#' @references Lumley T (2010). Complex Surveys: a guide to analysis using R. Wiley
#'
#' @examples
#' # ------------------------------------------
#' # This example reproduces the results from
#' # Lumley 2010, figure E.7 (Appendix E, p256)
#' # ------------------------------------------
#' if (require("survey")) {
#'   data(nhanes_sample)
#'
#'   # create survey design
#'   des <- svydesign(
#'     id = ~SDMVPSU,
#'     strat = ~SDMVSTRA,
#'     weights = ~WTINT2YR,
#'     nest = TRUE,
#'     data = nhanes_sample
#'   )
#'
#'   # fit negative binomial regression
#'   fit <- svyglm.nb(total ~ factor(RIAGENDR) * (log(age) + factor(RIDRETH1)), des)
#'
#'   # print coefficients and standard errors
#'   fit
#' }
#' @export
svyglm.nb <- function(formula, design, ...) {
  insight::check_if_installed(c("survey", "MASS"))

  # get design weights. we need to scale these weights for the glm.nb() function
  dw <- stats::weights(design)

  # update design with scaled weights
  design <- stats::update(design, scaled.weights = dw / mean(dw, na.rm = TRUE))

  # fit negative binomial model, with scaled design weights
  mod <- MASS::glm.nb(formula, data = stats::model.frame(design), weights = scaled.weights, ...)
  fam <- stats::family(mod)

  # fit survey model, using maximum likelihood estimation
  svyfit <-
    survey::svymle(
      loglike = sjstats_loglik,
      grad = sjstats_score,
      design = design,
      formulas = list(theta = ~1, eta = formula),
      start = c(mod$theta, stats::coef(mod)),
      na.action = "na.omit"
    )


  # add additoinal information
  class(svyfit) <- c("svyglm.nb", class(svyfit))
  attr(svyfit, "nb.terms") <- all.vars(formula)
  attr(svyfit, "nb.formula") <- formula
  attr(svyfit, "family") <- fam
  attr(svyfit, "nb.theta") <- mod[["theta"]]
  attr(svyfit, "nb.theta.se") <- mod[["SE.theta"]]

  svyfit$deviance <- mod$deviance
  svyfit$df.residuals <- mod$df.residuals
  svyfit$df <- length(stats::coef(mod)) + 1
  svyfit$aic <- mod$aic

  svyfit
}


# log-likelihood function used in "svymle()"
sjstats_loglik <- function(y, theta, eta) {
  mu <- exp(eta)
  return(
    lgamma(theta + y) - lgamma(theta) - lgamma(y + 1) + theta * log(theta) + y * log(mu + (y == 0)) - (theta + y) * log(theta + mu)
  )
}

# derivative
sjstats_deta <- function(y, theta, eta) {
  mu <- exp(eta)
  dmu <- y / mu - (theta + y) / (theta + mu)
  dmu * mu
}

# derivative
sjstats_dtheta <- function(y, theta, eta) {
  mu <- exp(eta)
  digamma(theta + y) - digamma(theta) + log(theta) + 1 - log(theta + mu) - (y + theta) / (mu + theta)
}

# score function, combines derivatives
sjstats_score <- function(y, theta, eta) {
  cbind(sjstats_dtheta(y, theta,eta), sjstats_deta(y, theta, eta))
}
