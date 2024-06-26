#' @title Effect size statistics for anova
#' @name anova_stats
#' @description Returns the (partial) eta-squared, (partial) omega-squared,
#'   epsilon-squared statistic or Cohen's F for all terms in an anovas.
#'   \code{anova_stats()} returns a tidy summary, including all these statistics
#'   and power for each term.
#'
#' @param model A fitted anova-model of class \code{aov} or \code{anova}. Other
#'   models are coerced to \code{\link[stats]{anova}}.
#' @param digits Amount of digits for returned values.
#'
#' @return A data frame with all statistics is returned (excluding confidence intervals).
#'
#' @references Levine TR, Hullett CR (2002): Eta Squared, Partial Eta Squared, and Misreporting of Effect Size in Communication Research.
#'   \cr \cr
#'   Tippey K, Longnecker MT (2016): An Ad Hoc Method for Computing Pseudo-Effect Size for Mixed Model.
#'
#' @examplesIf requireNamespace("car")
#' # load sample data
#' data(efc)
#'
#' # fit linear model
#' fit <- aov(
#'   c12hour ~ as.factor(e42dep) + as.factor(c172code) + c160age,
#'   data = efc
#' )
#' anova_stats(car::Anova(fit, type = 2))
#' @export
anova_stats <- function(model, digits = 3) {
  # .Deprecated("effectsize::effectsize()", package = "effectsize")

  # get tidy summary table
  aov.sum <- aov_stat_summary(model)

  # compute all model statistics
  etasq <- aov_stat_core(aov.sum, type = "eta")
  partial.etasq <- aov_stat_core(aov.sum, type = "peta")
  omegasq <- aov_stat_core(aov.sum, type = "omega")
  partial.omegasq <- aov_stat_core(aov.sum, type = "pomega")
  epsilonsq <- aov_stat_core(aov.sum, type = "epsilon")

  # compute power for each estimate
  cohens.f <- sqrt(partial.etasq / (1 - partial.etasq))

  # bind as data frame
  anov_stat <- rbind(
    data.frame(etasq, partial.etasq, omegasq, partial.omegasq, epsilonsq, cohens.f),
    data.frame(etasq = NA, partial.etasq = NA, omegasq = NA, partial.omegasq = NA, epsilonsq = NA, cohens.f = NA)
  )
  anov_stat <- cbind(anov_stat, data.frame(aov.sum))

  # get nr of terms
  nt <- nrow(anov_stat) - 1

  # finally, compute power
  as_power <- tryCatch(
    c(.calculate_power(
        df1 = anov_stat$df[1:nt],
        df2 = anov_stat$df[nrow(anov_stat)],
        effect_size = anov_stat$cohens.f[1:nt]^2
      ),
      NA
    ),
    error = function(x) {
      NA
    }
  )

  out <- cbind(anov_stat, data.frame(power = as_power))
  out[] <- lapply(out, function(i) {
    if (is.numeric(i)) {
      round(i, digits)
    } else {
      i
    }
  })

  class(out) <- c("sj_anova_stat", class(out))
  out
}


aov_stat <- function(model, type) {
  aov.sum <- aov_stat_summary(model)
  aov.res <- aov_stat_core(aov.sum, type)

  if (obj_has_name(aov.sum, "stratum"))
    attr(aov.res, "stratum") <- aov.sum[["stratum"]]

  aov.res
}


aov_stat_summary <- function(model) {
  insight::check_if_installed("parameters")
  # check if we have a mixed model
  mm <- is_merMod(model)
  ori.model <- model

  # check that model inherits from correct class
  # else, try to coerce to anova table
  if (!inherits(model, c("Gam", "aov", "anova", "anova.rms", "aovlist")))
    model <- stats::anova(model)

  # get summary table
  aov.sum <- insight::standardize_names(as.data.frame(parameters::model_parameters(model)), style = "broom")

  # for mixed models, add information on residuals
  if (mm) {
    res <- stats::residuals(ori.model)
    aov.sum <- rbind(
      aov.sum,
      data_frame(
        term = "Residuals",
        df = length(res) - sum(aov.sum[["df"]]),
        sumsq = sum(res^2, na.rm = TRUE),
        meansq = mse(ori.model),
        statistic = NA
      )
    )
  }


  # check if object has sums of square
  if (!obj_has_name(aov.sum, "sumsq")) {
    stop("Model object has no sums of squares. Cannot compute effect size statistic.", call. = FALSE)
  }


  # need special handling for rms-anova
  if (inherits(model, "anova.rms"))
    colnames(aov.sum) <- c("term", "df", "sumsq", "meansq", "statistic", "p.value")

  # for car::Anova, the meansq-column might be missing, so add it manually
  if (!obj_has_name(aov.sum, "meansq")) {
    pos_sumsq <- which(colnames(aov.sum) == "sumsq")
    aov.sum <- cbind(
      aov.sum[1:pos_sumsq],
      data.frame(meansq = aov.sum$sumsq / aov.sum$df),
      aov.sum[(pos_sumsq + 1):ncol(aov.sum)]
    )
  }

  intercept <- .which_intercept(aov.sum$term)
  if (length(intercept) > 0) {
    aov.sum <- aov.sum[-intercept, ]
  }

  aov.sum
}



aov_stat_core <- function(aov.sum, type) {
  intercept <- .which_intercept(aov.sum$term)
  if (length(intercept) > 0) {
    aov.sum <- aov.sum[-intercept, ]
  }

  # get mean squared of residuals
  meansq.resid <- aov.sum[["meansq"]][nrow(aov.sum)]
  # get total sum of squares
  ss.total <- sum(aov.sum[["sumsq"]])
  # get sum of squares of residuals
  ss.resid <- aov.sum[["sumsq"]][nrow(aov.sum)]

  # number of terms in model
  n_terms <- nrow(aov.sum) - 1

  # number of observations
  N <- sum(aov.sum[["df"]]) + 1


  aovstat <- switch(type,
    # compute omega squared for each model term
    omega = unlist(lapply(1:n_terms, function(x) {
      ss.term <- aov.sum[["sumsq"]][x]
      df.term <- aov.sum[["df"]][x]
      (ss.term - df.term * meansq.resid) / (ss.total + meansq.resid)
    })),
    # compute partial omega squared for each model term
    pomega = unlist(lapply(1:n_terms, function(x) {
      df.term <- aov.sum[["df"]][x]
      meansq.term <- aov.sum[["meansq"]][x]
      (df.term * (meansq.term - meansq.resid)) / (df.term * meansq.term + (N - df.term) * meansq.resid)
    })),
    # compute epsilon squared for each model term
    epsilon = unlist(lapply(1:n_terms, function(x) {
      ss.term <- aov.sum[["sumsq"]][x]
      df.term <- aov.sum[["df"]][x]
      (ss.term - df.term * meansq.resid) / ss.total
    })),
    # compute eta squared for each model term
    eta = unlist(lapply(1:n_terms, function(x) {
      aov.sum[["sumsq"]][x] / sum(aov.sum[["sumsq"]])
    })),
    # compute partial eta squared for each model term
    cohens.f = ,
    peta = unlist(lapply(1:n_terms, function(x) {
      aov.sum[["sumsq"]][x] / (aov.sum[["sumsq"]][x] + ss.resid)
    }))
  )

  # compute Cohen's F
  if (type == "cohens.f") aovstat <- sqrt(aovstat / (1 - aovstat))

  # give values names of terms
  names(aovstat) <- aov.sum[["term"]][1:n_terms]

  aovstat
}



.which_intercept <- function(x) {
  which(tolower(x) %in% c("(intercept)_zi", "intercept (zero-inflated)", "intercept", "zi_intercept", "(intercept)", "b_intercept", "b_zi_intercept"))
}


.calculate_power <- function(df1, df2, effect_size) {
  if (any(effect_size < 0)) {
    return(NA)
  }
  if (!is.null(df1) && any(df1 < 1)) {
    return(NA)
  }
  if (!is.null(df2) && any(df2 < 1)) {
    return(NA)
  }
  lambda <- effect_size * (df1 + df2 + 1)
  stats::pf(
    stats::qf(0.05, df1 = df1, df2 = df2, lower.tail = FALSE),
    df1 = df1,
    df2 = df2,
    ncp = lambda,
    lower.tail = FALSE
  )
}
