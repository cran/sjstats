#' @title Student's t test
#' @name t_test
#' @description This function performs a Student's t test for two independent
#' samples, for paired samples, or for one sample. It's a parametric test for
#' the null hypothesis that the means of two independent samples are equal, or
#' that the mean of one sample is equal to a specified value. The hypothesis
#' can be one- or two-sided.
#'
#' Unlike the underlying base R function `t.test()`, this function allows for
#' weighted tests and automatically calculates effect sizes. Cohen's _d_ is
#' returned for larger samples (n > 20), while Hedges' _g_ is returned for
#' smaller samples.
#'
#' @inheritParams mann_whitney_test
#' @param paired Logical, whether to compute a paired t-test for dependent
#' samples.
#' @inherit mann_whitney_test seealso
#'
#' @inheritSection mann_whitney_test Which test to use
#'
#' @details Interpretation of effect sizes are based on rules described in
#' [`effectsize::interpret_cohens_d()`] and [`effectsize::interpret_hedges_g()`].
#' Use these function directly to get other interpretations, by providing the
#' returned effect size (_Cohen's d_ or _Hedges's g_ in this case) as argument,
#' e.g. `interpret_cohens_d(0.35, rules = "sawilowsky2009")`.
#'
#' @return A data frame with test results. Effectsize Cohen's _d_ is returned
#' for larger samples (n > 20), while Hedges' _g_ is returned for smaller samples.
#'
#' @references
#' - Bender, R., Lange, S., Ziegler, A. Wichtige Signifikanztests.
#'   Dtsch Med Wochenschr 2007; 132: e24–e25
#'
#' - du Prel, J.B., Röhrig, B., Hommel, G., Blettner, M. Auswahl statistischer
#'   Testverfahren. Dtsch Arztebl Int 2010; 107(19): 343–8
#'
#' @examplesIf requireNamespace("effectsize")
#' data(sleep)
#' # one-sample t-test
#' t_test(sleep, "extra")
#' # base R equivalent
#' t.test(extra ~ 1, data = sleep)
#'
#' # two-sample t-test, by group
#' t_test(mtcars, "mpg", by = "am")
#' # base R equivalent
#' t.test(mpg ~ am, data = mtcars)
#'
#' # paired t-test
#' t_test(mtcars, c("mpg", "hp"), paired = TRUE)
#' # base R equivalent
#' t.test(mtcars$mpg, mtcars$hp, data = mtcars, paired = TRUE)
#' @export
t_test <- function(data,
                   select = NULL,
                   by = NULL,
                   weights = NULL,
                   paired = FALSE,
                   mu = 0,
                   alternative = "two.sided") {
  insight::check_if_installed(c("datawizard", "effectsize"))
  alternative <- match.arg(alternative, choices = c("two.sided", "less", "greater"))

  # sanity checks
  .sanitize_htest_input(data, select, by, weights, test = "t_test")
  data_name <- NULL

  # filter and remove NA
  data <- stats::na.omit(data[c(select, by, weights)])

  # does select indicate more than one variable? We than reshape the data
  # to have one continous scale and one grouping variable
  if (length(select) > 1) {
    # paired?
    if (paired) {
      # subtract the two variables for paired t-test, and "set" by to NULL
      data[[select[1]]] <- data[[select[1]]] - data[[select[2]]]
      data_name <- paste(select[1], "and", select[2])
      select <- select[1]
      by <- NULL
    } else {
      # we convert the data into long format, and create a grouping variable
      data <- datawizard::data_to_long(
        data[c(select, weights)],
        select = select,
        names_to = "group",
        values_to = "scale"
      )
      by <- select[2]
      select <- select[1]
      # after converting to long, we have the "grouping" variable first in the data
      colnames(data) <- c(weights, by, select)
    }
  }

  # get data
  dv <- data[[select]]

  # for two-sample t-test...
  if (!is.null(by)) {
    grp <- data[[by]]
    # coerce to factor
    grp <- datawizard::to_factor(grp)
    # only two groups allowed
    if (insight::n_unique(grp) > 2) {
      insight::format_error("Only two groups are allowed for Student's t test.") # nolint
    }
    # value labels
    group_labels <- names(attr(data[[by]], "labels", exact = TRUE))
    if (is.null(group_labels)) {
      group_labels <- levels(droplevels(grp))
    }
    data_name <- paste(select, "by", by)
  } else {
    # one-sample t-test...
    grp <- NULL
    group_labels <- select
    if (is.null(data_name)) {
      data_name <- select
    }
  }

  if (is.null(weights)) {
    .calculate_ttest(dv, grp, mu, paired, alternative, group_labels, data_name)
  } else {
    .calculate_weighted_ttest(dv, grp, mu, paired, alternative, data[[weights]], group_labels, data_name)
  }
}


# Mann-Whitney-Test for two groups --------------------------------------------

.calculate_ttest <- function(dv, grp, mu, paired, alternative, group_labels, data_name) {
  insight::check_if_installed("effectsize")
  # prepare data
  if (is.null(grp)) {
    tdat <- data.frame(dv)
    t_formula <- stats::as.formula("dv ~ 1")
  } else {
    tdat <- data.frame(dv, grp)
    t_formula <- stats::as.formula("dv ~ grp")
  }
  # perfom wilcox test
  htest <- stats::t.test(
    t_formula,
    data = tdat,
    alternative = alternative,
    mu = mu
  )
  test_statistic <- htest$statistic
  if (nrow(tdat) > 20) {
    effect_size <- stats::setNames(
      effectsize::cohens_d(
        t_formula,
        data = tdat,
        alternative = alternative,
        mu = mu
      )$Cohens_d,
      "Cohens_d"
    )
  } else {
    effect_size <- stats::setNames(
      effectsize::hedges_g(
        t_formula,
        data = tdat,
        alternative = alternative,
        mu = mu
      )$Hedges_g,
      "Hedges_g"
    )
  }

  # return result
  out <- data.frame(
    data = data_name,
    statistic_name = "t",
    statistic = test_statistic,
    effect_size_name = names(effect_size),
    effect_size = as.numeric(effect_size),
    p = as.numeric(htest$p.value),
    df = as.numeric(htest$parameter),
    method = ifelse(paired, "Paired t-test", htest$method),
    alternative = alternative,
    mu = mu,
    stringsAsFactors = FALSE
  )
  class(out) <- c("sj_htest_t", "data.frame")
  attr(out, "group_labels") <- group_labels
  attr(out, "means") <- as.numeric(htest$estimate)
  attr(out, "paired") <- isTRUE(paired)
  attr(out, "one_sample") <- is.null(grp)
  attr(out, "weighted") <- FALSE
  if (!is.null(grp)) {
    attr(out, "n_groups") <- stats::setNames(
      c(as.numeric(table(grp))),
      c("N Group 1", "N Group 2")
    )
  }
  out
}


# Weighted Mann-Whitney-Test for two groups ----------------------------------

.calculate_weighted_ttest <- function(dv, grp, mu, paired, alternative, weights, group_labels, data_name) {
  insight::check_if_installed(c("datawizard", "effectsize"))
  if (is.null(grp)) {
    dat <- stats::na.omit(data.frame(dv, weights))
    colnames(dat) <- c("y", "w")
    x_values <- dat$y
    x_weights <- dat$w
    y_values <- NULL
    # group N's
    n_groups <- stats::setNames(round(sum(x_weights)), "N Group 1")
  } else {
    dat <- stats::na.omit(data.frame(dv, grp, weights))
    colnames(dat) <- c("y", "g", "w")
    # unique groups
    groups <- unique(dat$g)
    # values for sample 1
    x_values <- dat$y[dat$g == groups[1]]
    x_weights <- dat$w[dat$g == groups[1]]
    # values for sample 2
    y_values <- dat$y[dat$g == groups[2]]
    y_weights <- dat$w[dat$g == groups[2]]
    # group N's
    n_groups <- stats::setNames(
      c(round(sum(x_weights)), round(sum(y_weights))),
      c("N Group 1", "N Group 2")
    )
  }

  mu_x <- stats::weighted.mean(x_values, x_weights, na.rm = TRUE)
  var_x <- datawizard::weighted_sd(x_values, x_weights)^2
  se_x <- sqrt(var_x / length(x_values))

  if (paired || is.null(y_values)) {
    # paired
    se <- se_x
    dof <- length(x_values) - 1
    test_statistic <- (mu_x - mu) / se
    estimate <- mu_x
    method <- if (paired) "Paired t-test" else "One Sample t-test"
  } else {
    # unpaired t-test
    mu_y <- stats::weighted.mean(y_values, y_weights)
    var_y <- datawizard::weighted_sd(y_values, y_weights)^2
    se_y <- sqrt(var_y / length(y_values))
    se <- sqrt(se_x^2 + se_y^2)
    dof <- se^4 / (se_x^4 / (length(x_values) - 1) + se_y^4 / (length(y_values) - 1))
    test_statistic <- (mu_x - mu_y - mu) / se
    estimate <- c(mu_x, mu_y)
    method <- "Two-Sample t-test"
  }

  # p-values
  if (alternative == "less") {
    pval <- stats::pt(test_statistic, dof)
  } else if (alternative == "greater") {
    pval <- stats::pt(test_statistic, dof, lower.tail = FALSE)
  } else {
    pval <- 2 * stats::pt(-abs(test_statistic), dof)
  }

  # effect size
  dat$y <- dat$y * dat$w
  if (is.null(y_values)) {
    t_formula <- stats::as.formula("y ~ 1")
  } else {
    t_formula <- stats::as.formula("y ~ g")
  }

  if (nrow(dat) > 20) {
    effect_size <- stats::setNames(
      effectsize::cohens_d(
        t_formula,
        data = dat,
        alternative = alternative,
        mu = mu,
        paired = FALSE
      )$Cohens_d,
      "Cohens_d"
    )
  } else {
    effect_size <- stats::setNames(
      effectsize::hedges_g(
        t_formula,
        data = dat,
        alternative = alternative,
        mu = mu,
        paired = FALSE
      )$Hedges_g,
      "Hedges_g"
    )
  }

  # return result
  out <- data.frame(
    data = data_name,
    statistic_name = "t",
    statistic = test_statistic,
    effect_size_name = names(effect_size),
    effect_size = as.numeric(effect_size),
    p = pval,
    df = dof,
    method = method,
    alternative = alternative,
    mu = mu,
    stringsAsFactors = FALSE
  )
  class(out) <- c("sj_htest_t", "data.frame")
  attr(out, "means") <- estimate
  attr(out, "n_groups") <- n_groups
  attr(out, "means") <- estimate
  attr(out, "group_labels") <- group_labels
  attr(out, "paired") <- isTRUE(paired)
  attr(out, "one_sample") <- is.null(y_values) && !isTRUE(paired)
  attr(out, "weighted") <- TRUE
  out
}


# methods ---------------------------------------------------------------------

#' @export
print.sj_htest_t <- function(x, ...) {
  insight::check_if_installed("effectsize")

  # fetch attributes
  group_labels <- attributes(x)$group_labels
  means <- attributes(x)$means
  n_groups <- attributes(x)$n_groups
  weighted <- attributes(x)$weighted
  paired <- isTRUE(attributes(x)$paired)
  one_sample <- isTRUE(attributes(x)$one_sample)

  if (weighted) {
    weight_string <- " (weighted)"
  } else {
    weight_string <- ""
  }

  # same width
  group_labels <- format(group_labels)

  # header
  insight::print_color(sprintf("# %s%s\n\n", x$method, weight_string), "blue")

  # print for paired t-test
  if (paired) {
    # data
    insight::print_color(sprintf(
      "  Data: %s (mean difference = %s)\n",
      x$data,
      insight::format_value(means[1], protect_integers = TRUE)
    ), "cyan")
  } else {
    # data
    insight::print_color(sprintf("  Data: %s\n", x$data), "cyan")

    # group-1-info
    if (is.null(n_groups)) {
      insight::print_color(
        sprintf(
          "  Group 1: %s (mean = %s)\n",
          group_labels[1], insight::format_value(means[1], protect_integers = TRUE)
        ), "cyan"
      )
    } else {
      insight::print_color(
        sprintf(
          "  Group 1: %s (n = %i, mean = %s)\n",
          group_labels[1], n_groups[1], insight::format_value(means[1], protect_integers = TRUE)
        ), "cyan"
      )
    }

    # group-2-info
    if (length(group_labels) > 1) {
      if (is.null(n_groups)) {
        insight::print_color(
          sprintf(
            "  Group 2: %s (mean = %s)\n",
            group_labels[2], insight::format_value(means[2], protect_integers = TRUE)
          ), "cyan"
        )
      } else {
        insight::print_color(
          sprintf(
            "  Group 2: %s (n = %i, mean = %s)\n",
            group_labels[2], n_groups[2], insight::format_value(means[2], protect_integers = TRUE)
          ), "cyan"
        )
      }
    }
  }

  # alternative hypothesis
  alt_string <- switch(x$alternative,
    two.sided = "not equal to",
    less = "less than",
    greater = "greater than"
  )
  if (one_sample) {
    alt_string <- paste("true mean is", alt_string, x$mu)
  } else if (paired) {
    alt_string <- paste("true mean difference is", alt_string, x$mu)
  } else {
    alt_string <- paste("true difference in means is", alt_string, x$mu)
  }
  insight::print_color(sprintf("  Alternative hypothesis: %s\n", alt_string), "cyan")

  # string for effectsizes
  if (x$effect_size_name == "Cohens_d") {
    eff_string <- sprintf(
      "Cohen's d = %.2f (%s effect)",
      x$effect_size,
      effectsize::interpret_cohens_d(x$effect_size)
    )
  } else {
    eff_string <- sprintf(
      "Hedges' g = %.2f (%s effect)",
      x$effect_size,
      effectsize::interpret_hedges_g(x$effect_size)
    )
  }

  cat(sprintf(
    "\n  t = %.2f, %s, df = %s, %s\n\n",
    x$statistic,
    eff_string,
    insight::format_value(x$df, digits = 1, protect_integers = TRUE),
    insight::format_p(x$p)
  ))
}
