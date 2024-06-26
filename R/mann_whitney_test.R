#' @title Mann-Whitney test
#' @name mann_whitney_test
#' @description This function performs a Mann-Whitney test (or Wilcoxon rank
#' sum test for _unpaired_ samples). Unlike the underlying base R function
#' `wilcox.test()`, this function allows for weighted tests and automatically
#' calculates effect sizes. For _paired_ (dependent) samples, or for one-sample
#' tests, please use the `wilcoxon_test()` function.
#'
#' A Mann-Whitney test is a non-parametric test for the null hypothesis that two
#' _independent_ samples have identical continuous distributions. It can be used
#' for ordinal scales or when the two continuous variables are not normally
#' distributed. For large samples, or approximately normally distributed variables,
#' the `t_test()` function can be used.
#'
#' @param data A data frame.
#' @param select Name(s) of the continuous variable(s) (as character vector)
#' to be used as samples for the test. `select` can be one of the following:
#'
#' - `select` can be used in combination with `by`, in which case `select` is
#'   the name of the continous variable (and `by` indicates a grouping factor).
#' - `select` can also be a character vector of length two or more (more than
#'   two names only apply to `kruskal_wallis_test()`), in which case the two
#'   continuous variables are treated as samples to be compared. `by` must be
#'   `NULL` in this case.
#' - If `select` select is of length **two** and `paired = TRUE`, the two samples
#'   are considered as *dependent* and a paired test is carried out.
#' - If `select` specifies **one** variable and `by = NULL`, a one-sample test
#'   is carried out (only applicable for `t_test()` and `wilcoxon_test()`)
#' - For `chi_squared_test()`, if `select` specifies **one** variable and
#'   both `by` and `probabilities` are `NULL`, a one-sample test against given
#'   probabilities is automatically conducted, with equal probabilities for
#'   each level of `select`.
#' @param by Name of the variable indicating the groups. Required if `select`
#' specifies only one variable that contains all samples to be compared in the
#' test. If `by` is not a factor, it will be coerced to a factor. For
#' `chi_squared_test()`, if `probabilities` is provided, `by` must be `NULL`.
#' @param weights Name of an (optional) weighting variable to be used for the test.
#' @param alternative A character string specifying the alternative hypothesis,
#' must be one of `"two.sided"` (default), `"greater"` or `"less"`. See `?t.test`
#' and `?wilcox.test`.
#' @param mu The hypothesized difference in means (for `t_test()`) or location
#' shift (for `wilcoxon_test()` and `mann_whitney_test()`). The default is 0.
#' @param ... Additional arguments passed to `wilcox.test()` (for unweighted
#' tests, i.e. when `weights = NULL`).
#'
#' @section Which test to use:
#' The following table provides an overview of which test to use for different
#' types of data. The choice of test depends on the scale of the outcome
#' variable and the number of samples to compare.
#'
#' | **Samples**     | **Scale of Outcome**   | **Significance Test**           |
#' |-----------------|------------------------|---------------------------------|
#' | 1               | binary / nominal       | `chi_squared_test()`            |
#' | 1               | continuous, not normal | `wilcoxon_test()`               |
#' | 1               | continuous, normal     | `t_test()`                      |
#' | 2, independent  | binary / nominal       | `chi_squared_test()`            |
#' | 2, independent  | continuous, not normal | `mann_whitney_test()`           |
#' | 2, independent  | continuous, normal     | `t_test()`                      |
#' | 2, dependent    | binary (only 2x2)      | `chi_squared_test(paired=TRUE)` |
#' | 2, dependent    | continuous, not normal | `wilcoxon_test()`               |
#' | 2, dependent    | continuous, normal     | `t_test(paired=TRUE)`           |
#' | >2, independent | continuous, not normal | `kruskal_wallis_test()`         |
#' | >2, independent | continuous,     normal | `datawizard::means_by_group()`  |
#' | >2, dependent   | continuous, not normal | _not yet implemented_ (1)       |
#' | >2, dependent   | continuous,     normal | _not yet implemented_ (2)       |
#'
#' (1) More than two dependent samples are considered as _repeated measurements_.
#'     For ordinal or not-normally distributed outcomes, these samples are
#'     usually tested using a [`friedman.test()`], which requires the samples
#'     in one variable, the groups to compare in another variable, and a third
#'     variable indicating the repeated measurements (subject IDs).
#'
#' (2) More than two dependent samples are considered as _repeated measurements_.
#'     For normally distributed outcomes, these samples are usually tested using
#'     a ANOVA for repeated measurements. A more sophisticated approach would
#'     be using a linear mixed model.
#'
#' @seealso
#' - [`t_test()`] for parametric t-tests of dependent and independent samples.
#' - [`mann_whitney_test()`] for non-parametric tests of unpaired (independent)
#'   samples.
#' - [`wilcoxon_test()`] for Wilcoxon rank sum tests for non-parametric tests
#'   of paired (dependent) samples.
#' - [`kruskal_wallis_test()`] for non-parametric tests with more than two
#'   independent samples.
#' - [`chi_squared_test()`] for chi-squared tests (two categorical variables,
#'   dependent and independent).
#'
#' @return A data frame with test results. The function returns p and Z-values
#' as well as effect size r and group-rank-means.
#'
#' @references
#' - Ben-Shachar, M.S., Patil, I., Thériault, R., Wiernik, B.M.,
#'   Lüdecke, D. (2023). Phi, Fei, Fo, Fum: Effect Sizes for Categorical Data
#'   That Use the Chi‑Squared Statistic. Mathematics, 11, 1982.
#'   \doi{10.3390/math11091982}
#'
#' - Bender, R., Lange, S., Ziegler, A. Wichtige Signifikanztests.
#'   Dtsch Med Wochenschr 2007; 132: e24–e25
#'
#' - du Prel, J.B., Röhrig, B., Hommel, G., Blettner, M. Auswahl statistischer
#'   Testverfahren. Dtsch Arztebl Int 2010; 107(19): 343–8
#'
#' @details This function is based on [`wilcox.test()`] and [`coin::wilcox_test()`]
#' (the latter to extract effect sizes). The weighted version of the test is
#' based on [`survey::svyranktest()`].
#'
#' Interpretation of the effect size **r**, as a rule-of-thumb:
#'
#' - small effect >= 0.1
#' - medium effect >= 0.3
#' - large effect >= 0.5
#'
#' **r** is calcuated as \eqn{r = \frac{|Z|}{\sqrt{n1 + n2}}}.
#'
#' @examplesIf requireNamespace("coin") && requireNamespace("survey")
#' data(efc)
#' # Mann-Whitney-U tests for elder's age by elder's sex.
#' mann_whitney_test(efc, "e17age", by = "e16sex")
#' # base R equivalent
#' wilcox.test(e17age ~ e16sex, data = efc)
#'
#' # when data is in wide-format, specify all relevant continuous
#' # variables in `select` and omit `by`
#' set.seed(123)
#' wide_data <- data.frame(scale1 = runif(20), scale2 = runif(20))
#' mann_whitney_test(wide_data, select = c("scale1", "scale2"))
#' # base R equivalent
#' wilcox.test(wide_data$scale1, wide_data$scale2)
#' # same as if we had data in long format, with grouping variable
#' long_data <- data.frame(
#'   scales = c(wide_data$scale1, wide_data$scale2),
#'   groups = as.factor(rep(c("A", "B"), each = 20))
#' )
#' mann_whitney_test(long_data, select = "scales", by = "groups")
#' # base R equivalent
#' wilcox.test(scales ~ groups, long_data)
#' @export
mann_whitney_test <- function(data,
                              select = NULL,
                              by = NULL,
                              weights = NULL,
                              mu = 0,
                              alternative = "two.sided",
                              ...) {
  insight::check_if_installed("datawizard")
  alternative <- match.arg(alternative, choices = c("two.sided", "less", "greater"))

  # sanity checks
  .sanitize_htest_input(data, select, by, weights, test = "mann_whitney_test")

  # alternative only if weights are NULL
  if (!is.null(weights) && alternative != "two.sided") {
    insight::format_error("Argument `alternative` must be `two.sided` if `weights` are specified.")
  }

  # does select indicate more than one variable?
  if (length(select) > 1) {
    # we convert the data into long format, and create a grouping variable
    data <- datawizard::data_to_long(data[select], names_to = "group", values_to = "scale")
    by <- select[2]
    select <- select[1]
    # after converting to long, we have the "grouping" variable first in the data
    colnames(data) <- c(by, select)
  }

  # get data
  dv <- data[[select]]
  grp <- data[[by]]

  # coerce to factor
  grp <- datawizard::to_factor(grp)

  # only two groups allowed
  if (insight::n_unique(grp) > 2) {
    insight::format_error("Only two groups are allowed for Mann-Whitney test. Please use `kruskal_wallis_test()` for more than two groups.") # nolint
  }

  # value labels
  group_labels <- names(attr(data[[by]], "labels", exact = TRUE))
  if (is.null(group_labels)) {
    group_labels <- levels(droplevels(grp))
  }

  if (is.null(weights)) {
    .calculate_mwu(dv, grp, alternative, mu, group_labels, ...)
  } else {
    .calculate_weighted_mwu(dv, grp, data[[weights]], group_labels)
  }
}


# Mann-Whitney-Test for two groups --------------------------------------------

.calculate_mwu <- function(dv, grp, alternative, mu, group_labels, ...) {
  insight::check_if_installed("coin")
  # prepare data
  wcdat <- data.frame(dv, grp)
  # perfom wilcox test
  wt <- coin::wilcox_test(dv ~ grp, data = wcdat)

  # for rank mean
  group_levels <- levels(grp)

  # compute statistics
  u <- as.numeric(coin::statistic(wt, type = "linear"))
  z <- as.numeric(coin::statistic(wt, type = "standardized"))
  r <- abs(z / sqrt(length(dv)))
  htest <- suppressWarnings(stats::wilcox.test(
    dv ~ grp,
    data = wcdat,
    alternative = alternative,
    mu = mu,
    ...
  ))
  w <- htest$statistic
  p <- htest$p.value

  # group means
  dat_gr1 <- stats::na.omit(dv[grp == group_levels[1]])
  dat_gr2 <- stats::na.omit(dv[grp == group_levels[2]])

  rank_mean_1 <- mean(rank(dat_gr1))
  rank_mean_2 <- mean(rank(dat_gr2))

  # compute n for each group
  n_grp1 <- length(dat_gr1)
  n_grp2 <- length(dat_gr2)

  out <- data.frame(
    group1 = group_levels[1],
    group2 = group_levels[2],
    estimate = rank_mean_1 - rank_mean_2,
    u = u,
    w = w,
    z = z,
    r = r,
    p = as.numeric(p),
    mu = mu,
    alternative = alternative
  )
  attr(out, "rank_means") <- stats::setNames(
    c(rank_mean_1, rank_mean_2),
    c("Mean Group 1", "Mean Group 2")
  )
  attr(out, "n_groups") <- stats::setNames(
    c(n_grp1, n_grp2),
    c("N Group 1", "N Group 2")
  )
  attr(out, "group_labels") <- group_labels
  attr(out, "method") <- "wilcoxon"
  attr(out, "weighted") <- FALSE
  class(out) <- c("sj_htest_mwu", "data.frame")

  out
}


# Weighted Mann-Whitney-Test for two groups ----------------------------------

.calculate_weighted_mwu <- function(dv, grp, weights, group_labels) {
  # check if pkg survey is available
  insight::check_if_installed("survey")

  dat <- stats::na.omit(data.frame(dv, grp, weights))
  colnames(dat) <- c("x", "g", "w")

  design <- survey::svydesign(ids = ~0, data = dat, weights = ~w)
  result <- survey::svyranktest(formula = x ~ g, design, test = "wilcoxon")

  # for rank mean
  group_levels <- levels(droplevels(grp))
  # subgroups
  dat_gr1 <- dat[dat$g == group_levels[1], ]
  dat_gr2 <- dat[dat$g == group_levels[2], ]
  dat_gr1$rank_x <- rank(dat_gr1$x)
  dat_gr2$rank_x <- rank(dat_gr2$x)

  # rank means
  design_mean1 <- survey::svydesign(
    ids = ~0,
    data = dat_gr1,
    weights = ~w
  )
  rank_mean_1 <- survey::svymean(~rank_x, design_mean1)

  design_mean2 <- survey::svydesign(
    ids = ~0,
    data = dat_gr2,
    weights = ~w
  )
  rank_mean_2 <- survey::svymean(~rank_x, design_mean2)

  # group Ns
  n_grp1 <- round(sum(dat_gr1$w))
  n_grp2 <- round(sum(dat_gr2$w))

  # statistics and effect sizes
  z <- result$statistic
  r <- abs(z / sqrt(sum(n_grp1, n_grp2)))

  out <- data_frame(
    group1 = group_levels[1],
    group2 = group_levels[2],
    estimate = result$estimate,
    z = z,
    r = r,
    p = as.numeric(result$p.value),
    alternative = "two.sided"
  )

  attr(out, "rank_means") <- stats::setNames(
    c(rank_mean_1, rank_mean_2),
    c("Mean Group 1", "Mean Group 2")
  )
  attr(out, "n_groups") <- stats::setNames(
    c(n_grp1, n_grp2),
    c("N Group 1", "N Group 2")
  )
  attr(out, "group_labels") <- group_labels
  attr(out, "weighted") <- TRUE
  class(out) <- c("sj_htest_mwu", "data.frame")

  out
}


# helper ----------------------------------------------------------------------

.sanitize_htest_input <- function(data, select, by, weights, test = NULL) {
  # check if arguments are NULL
  if (is.null(select)) {
    insight::format_error("Argument `select` is missing.")
  }
  # sanity check - may only specify two variable names
  if (identical(test, "mann_whitney_test") && length(select) > 2) {
    insight::format_error("You may only specify two variables for Mann-Whitney test.")
  }
  if (identical(test, "mann_whitney_test") && length(select) == 1 && is.null(by)) {
    insight::format_error("Only one variable provided in `select`, but none in `by`. You need to specify a second continuous variable in `select`, or a grouping variable in `by` for Mann-Whitney test.") # nolint
  }

  # sanity check - may only specify two variable names
  if (identical(test, "t_test") && length(select) > 2) {
    insight::format_error("You may only specify two variables for Student's t test.")
  }
  if ((!is.null(test) && test %in% c("t_test", "kruskal_wallis_test", "mann_whitney_test")) && length(select) > 1 && !is.null(by)) { # nolint
    insight::format_error("If `select` specifies more than one variable, `by` must be `NULL`.")
  }

  # check if arguments have correct length or are of correct type
  if (!is.character(select)) {
    insight::format_error("Argument `select` must be a character string with the name(s) of the variable(s).")
  }
  if (!is.null(by) && (length(by) != 1 || !is.character(by))) {
    insight::format_error("Argument `by` must be a character string with the name of a single variable.")
  }
  if (!is.null(weights) && (length(weights) != 1 || !is.character(weights))) {
    insight::format_error("Argument `weights` must be a character string with the name of a single variable.")
  }

  # check if "select" is in data
  if (!all(select %in% colnames(data))) {
    not_found <- setdiff(select, colnames(data))[1]
    insight::format_error(
      sprintf("Variable '%s' not found in data frame.", not_found),
      .misspelled_string(colnames(data), not_found, "Maybe misspelled?")
    )
  }
  # check if "by" is in data
  if (!is.null(by) && !by %in% colnames(data)) {
    insight::format_error(
      sprintf("Variable '%s' not found in data frame.", by),
      .misspelled_string(colnames(data), by, "Maybe misspelled?")
    )
  }
  # check if "weights" is in data
  if (!is.null(weights) && !weights %in% colnames(data)) {
    insight::format_error(
      sprintf("Weighting variable '%s' not found in data frame.", weights),
      .misspelled_string(colnames(data), weights, "Maybe misspelled?")
    )
  }

  # select variable type for certain tests
  if (identical(test, "t_test") && !all(vapply(data[select], is.numeric, logical(1)))) {
    insight::format_error("Variable provided in `select` must be numeric for Student's t test.")
  }
}


# methods ---------------------------------------------------------------------

#' @export
print.sj_htest_mwu <- function(x, ...) {
  # fetch attributes
  group_labels <- attributes(x)$group_labels
  rank_means <- attributes(x)$rank_means
  n_groups <- attributes(x)$n_groups
  weighted <- attributes(x)$weighted

  if (weighted) {
    weight_string <- " (weighted)"
  } else {
    weight_string <- ""
  }

  # same width
  group_labels <- format(group_labels)

  # header
  insight::print_color(sprintf("# Mann-Whitney test%s\n\n", weight_string), "blue")

  # group-1-info
  insight::print_color(
    sprintf(
      "  Group 1: %s (n = %i, rank mean = %s)\n",
      group_labels[1], n_groups[1], insight::format_value(rank_means[1], protect_integers = TRUE)
    ), "cyan"
  )

  # group-2-info
  insight::print_color(
    sprintf(
      "  Group 2: %s (n = %i, rank mean = %s)\n",
      group_labels[2], n_groups[2], insight::format_value(rank_means[2], protect_integers = TRUE)
    ), "cyan"
  )

  # alternative hypothesis
  if (!is.null(x$alternative) && !is.null(x$mu)) {
    alt_string <- switch(x$alternative,
      two.sided = "not equal to",
      less = "less than",
      greater = "greater than"
    )
    alt_string <- paste("true location shift is", alt_string, x$mu)
    insight::print_color(sprintf("  Alternative hypothesis: %s\n", alt_string), "cyan")
  }

  if (!is.null(x$w)) {
    w_stat <- paste("W =", insight::format_value(x$w, protect_integers = TRUE), ", ")
  } else {
    w_stat <- ""
  }
  cat(sprintf("\n  %sr = %.2f, Z = %.2f, %s\n\n", w_stat, x$r, x$z, insight::format_p(x$p)))
}
