# This file includes lots of good code that was annoying to write. With the
# `aggregate()` refactor, we no longer need this because we simply re-evaluation
# the call with the `by` argument. We keep this code here for sentimental reasons
# and in case the new way breaks a bunch of things.

















#' Tidy a `slopes` object
#'
#' @param x An object produced by the `slopes` function.
#' @inheritParams marginaleffects
#' @param conf_level numeric value between 0 and 1. Confidence level to use to build a confidence interval. The default `NULL` uses the `conf_level` value used in the original call to `slopes()`.
#' @return A "tidy" `data.frame` of summary statistics which conforms to the
#' `broom` package specification.
#' @details
#' The `tidy` function calculates average marginal effects by taking the mean
#' of all the unit-level marginal effects computed by the `marginaleffects`
#' function.
#'
#' The standard error of the average marginal effects is obtained by 
#' taking the mean of each column of the Jacobian. . Then, we use this
#' "Jacobian at the mean" in the Delta method to obtained standard errors.
#'
#'
#' @family summary
#' @template bayesian 
#' @export
#' @examples
#' mod <- lm(mpg ~ hp * wt + factor(gear), data = mtcars)
#' mfx <- slopes(mod)
#'
#' # average marginal effects
#' tidy(mfx)
tidy.slopes <- function(x,
                        by = NULL,
                        conf_level = NULL,
                        ...) {
    x_dt <- copy(x)
    setnames(x_dt, old = "dydx", new = "comparison", skip_absent = TRUE)
    out <- tidy.comparisons(x_dt,
                            conf_level = conf_level,
                            ...)
    return(out)
}


#' Tidy a `comparisons` object
#'
#' Calculate average contrasts by taking the mean of all the
#' unit-level contrasts computed by the `predictions` function.
#'
#' @param x An object produced by the `comparisons` function.
#' @param transform_avg A function applied to the estimates and confidence intervals *after* the unit-level estimates have been averaged.
#' @param conf_level numeric value between 0 and 1. Confidence level to use to build a confidence interval. The default `NULL` uses the `conf_level` value used in the original call to `comparisons()`.
#' @inheritParams comparisons
#' @inheritParams tidy.slopes
#' @return A "tidy" `data.frame` of summary statistics which conforms to the
#' `broom` package specification.
#' @details
#'
#' To compute standard errors around the average marginaleffects, we begin by applying the
#' mean function to each column of the Jacobian. Then, we use this matrix in the Delta
#' method to obtained standard errors.
#'
#' In Bayesian models (e.g., `brms`), we compute Average Marginal
#' Effects by applying the mean function twice. First, we apply it to all
#' marginal effects for each posterior draw, thereby estimating one Average (or
#' Median) Marginal Effect per iteration of the MCMC chain. Second, we
#' calculate the mean and the `quantile` function to the results of Step 1 to
#' obtain the Average Marginal Effect and its associated interval.
#'
#' @family summary
#' @export
#' @examples
#' mod <- lm(mpg ~ factor(gear), data = mtcars)
#' contr <- comparisons(mod, variables = list(gear = "sequential"))
#' tidy(contr)
tidy.comparisons <- function(x,
                             by = NULL,
                             conf_level = NULL,
                             transform_avg = NULL,
                             ...) {

    # use original conf_level by default
    # before recall()
    if (is.null(conf_level)) {
        conf_level <- attr(x, "conf_level")
    }

    # `by` requires us to re-eval a modified call
    if (!is.null(by)) {
        out <- recall(x, by = by, conf_level = conf_level)
        if (!is.null(out)) {
            # back transformation
            if (!is.null(transform_avg) && !is.null(attr(x, "transform"))) {
                msg <- "Estimates were transformed twice: once during the initial computation, and once more when summarizing the results in `tidy()` or `summary()`."
                insight::format_warning(msg)
            }
            out <- backtransform(out, transform_avg)
            return(out)
        }
    }


    if (identical(attr(x, "comparison"), "lnor")) {
        msg <- 
        'The `tidy()` and `summary()` functions take the average of estimates
        over the whole dataset. However, the unit-level estimates you requested 
        are not collapsible. Please use `comparison="lnoravg"` instead.' 
        stop(msg, call. = FALSE)
    }

    if ("by" %in% names(list(...))) {
        msg <- 
        "The `by` argument is deprecated in this function. You can use `by` in the `comparisons()`, 
        `slopes()`, and `predictions()` functions instead."
        stop(msg, call. = FALSE)
    }

    dots <- list(...)
    conf_level <- sanitize_conf_level(conf_level, ...)

    # transformation
    transform_avg <- deprecation_arg(
        transform_avg,
        newname = "transform_avg",
        oldname = "transform",
        ...)
    transform_avg <- sanitize_transform(transform_avg)

    x_dt <- data.table(x)

    marginaleffects_wts_internal <- attr(x, "weights")

    draws <- attr(x, "posterior_draws")

    idx_by <- c("group", "term", "contrast", 
                grep("^contrast_\\w+", colnames(x_dt), value = TRUE))
    idx_by <- intersect(idx_by, colnames(x_dt))
    idx_na <- is.na(x_dt$comparison)

    # do not use the standard errors if we already have the final number of rows (e.g., lnoravg)
    flag_delta <- nrow(unique(x_dt[, ..idx_by])) != nrow(x_dt)

    if (!is.null(marginaleffects_wts_internal)) {
        x_dt[, "marginaleffects_wts_internal" := marginaleffects_wts_internal]
    }

    # bayesian
    if (!is.null(draws)) {
        ame <- average_draws(
            data = x_dt,
            index = idx_by,
            draws = draws,
            column = "comparisons")
        draws <- attr(ame, "posterior_draws")

    # frequentist
    # empty initial mfx data.frame means there were no numeric variables in the
    # model
    } else if (isTRUE(flag_delta) && is.null(attr(x, "by")) && ("term" %in% colnames(x_dt) || inherits(x, "predictions"))) {

        J <- attr(x, "jacobian")
        V <- attr(x, "vcov")

        # average marginal effects
        if ("marginaleffects_wts_internal" %in% colnames(x_dt)) {
            ame <- x_dt[idx_na == FALSE,
                        .(estimate = stats::weighted.mean(
                            comparison,
                            marginaleffects_wts_internal,
                            na.rm = TRUE)),
                        by = idx_by]
        } else {
            ame <- x_dt[idx_na == FALSE,
                        .(estimate = mean(comparison, na.rm = TRUE)),
                        by = idx_by]
        }

        if (is.matrix(J) && is.matrix(V)) {
            # Jacobian at the group mean
            # use weird colnames to avoid collision
            idx_pad <- x_dt[, ..idx_by]
            idx_col_old <- colnames(idx_pad)
            idx_col_new <- paste0(idx_col_old, "_marginaleffects_index")
            setnames(idx_pad,
                     old = colnames(idx_pad),
                     new = paste0(colnames(idx_pad), "_marginaleffects_index"))

            J <- data.table(idx_pad, J)

            J <- J[idx_na == FALSE, ]
            x_dt <- x_dt[idx_na == FALSE, ]

            tmp <- paste0(idx_by, "_marginaleffects_index")

            if (is.null(marginaleffects_wts_internal)) {
                J_mean <- J[, lapply(.SD, mean, na.rm = TRUE), by = tmp]
            } else {
                J[, "marginaleffects_wts_internal" := marginaleffects_wts_internal]
                J_mean <- J[,
                lapply(.SD,
                        stats::weighted.mean,
                        w = marginaleffects_wts_internal,
                        na.rm = TRUE),
                by = tmp]
            }
            if ("marginaleffects_wts_internal" %in% colnames(J_mean)) {
                tmp <- c("marginaleffects_wts_internal", tmp)
            }
            J_mean <- J_mean[, !..tmp]
            J_mean <- as.matrix(J_mean)

            # HACK: align J_mean and V if they don't match
            if (all(colnames(J_mean) %in% colnames(V))) {
                V <- V[colnames(J_mean), colnames(J_mean)]
            }

            # standard errors at the group mean
            se <- sqrt(colSums(t(J_mean %*% V) * t(J_mean)))
            ame[, std.error := se]
        }

    } else {
        # avoids namespace conflict with `margins`
        ame <- x_dt
        setnames(ame, old = "comparison", new = "estimate", skip_absent = TRUE)
    }

    out <- get_ci(
        ame,
        overwrite = FALSE,
        conf_level = conf_level,
        draws = draws,
        estimate = "estimate",
        model = model,
        ...)

    # remove terms with precise zero estimates. typically the case in
    # multi-equation models where some terms only affect one response
    idx <- out$estimate != 0
    out <- out[idx, , drop = FALSE]
    if (!is.null(draws)) {
        draws <- draws[idx, , drop = FALSE]
    }
    if (exists("drawavg")) {
        drawavg <- drawavg[idx, , drop = FALSE]
    }

    # back transformation
    if (!is.null(transform_avg) && !is.null(attr(x, "transform"))) {
        msg <- "Estimates were transformed twice: once during the initial computation, and once more when summarizing the results in `tidy()` or `summary()`."
        insight::format_warning(msg)
    }
    out <- backtransform(out, transform_avg)

    # sort and subset columns
    cols <- c("type", "group", "term", "contrast",
              attr(x, "by"),
              grep("^contrast_\\w+", colnames(x_dt), value = TRUE),
              "estimate", "std.error", "statistic", "p.value", "conf.low", "conf.high")
    cols <- intersect(cols, colnames(out))
    out <- out[, cols, drop = FALSE, with = FALSE]


    setDF(out)

    attr(out, "conf_level") <- conf_level
    attr(out, "FUN") <- "mean"
    attr(out, "nchains") <- attr(x, "nchains")
    attr(out, "transform_label") <- attr(x, "transform_label")
    attr(out, "transform_average_label") <- names(transform_avg)[1]

    if (exists("drawavg")) {
        class(drawavg) <- c("posterior_draws", class(drawavg))
        attr(out, "posterior_draws") <- drawavg
    } else {
        attr(out, "posterior_draws") <- draws
    }

    if (exists("J_mean")) {
        attr(out, "jacobian") <- J_mean
    }


    return(out)
}





#' Tidy a `predictions` object
#'
#' Calculate average adjusted predictions by taking the mean of all the
#' unit-level adjusted predictions computed by the `predictions` function.
#'
#' @param x An object produced by the `predictions` function.
#' @inheritParams predictions
#' @inheritParams tidy.comparisons
#' @param conf_level numeric value between 0 and 1. Confidence level to use to build a confidence interval. The default `NULL` uses the `conf_level` value used in the original call to `predictions()`.
#' @return A "tidy" `data.frame` of summary statistics which conforms to the
#' `broom` package specification.
#' @family summary
#' @export
#' @examples
#' mod <- lm(mpg ~ hp * wt + factor(gear), data = mtcars)
#' mfx <- predictions(mod)
#' tidy(mfx)
tidy.predictions <- function(x,
                             by = NULL,
                             conf_level = NULL,
                             transform_avg = NULL,
                             ...) {

    # use original conf_level by default
    # before recall
    if (is.null(conf_level)) {
        conf_level <- attr(x, "conf_level")
    }

    # `by` requires us to re-eval a modified call
    if (!is.null(by)) {
        out <- recall(x, by = by, conf_level = conf_level)
        if (!is.null(out)) {
            # back transformation
            if (!is.null(transform_avg) && !is.null(attr(x, "transform"))) {
                msg <- "Estimates were transformed twice: once during the initial computation, and once more when summarizing the results in `tidy()` or `summary()`."
                insight::format_warning(msg)
            }
            out <- backtransform(out, transform_avg)
            return(out)
        }
    }

    transform_avg <- sanitize_transform(transform_avg)

    # I left the `by` code below in case I eventually want to revert. Much
    # of it needs to stay anyway because we need the `delta` in `tidy` for
    # average predicted values, but Isome stuff could eventually be cleaned up.
    if ("by" %in% names(list(...))) {
        msg <- 
        "The `by` argument is deprecated in this function. You can use `by` in the `comparisons()`, 
        `slopes()`, and `predictions()` functions instead."
        stop(msg, call. = FALSE)
    }

    x_dt <- copy(data.table(x))

    marginaleffects_wts_internal <- attr(x, "weights")

    if ("group" %in% colnames(x_dt)) {
        idx <- "group"
    } else {
        idx <- NULL
    }

    fun <- function(...) {
        dots <- list(...)
        dots[["eps"]] <- NULL
        dots[["vcov"]] <- FALSE
        out <- data.table(do.call("predictions", dots))
        if (!is.null(marginaleffects_wts_internal)) {
            out[, "marginaleffects_wts_internal" := marginaleffects_wts_internal]
            out <- out[,
                .(predicted = stats::weighted.mean(predicted, marginaleffects_wts_internal, na.rm = TRUE)),
                by = idx]
        } else {
            out <- out[, .(predicted = mean(predicted)), by = idx]
        }
        return(out$predicted)
    }

    # only aggregate if predictions were not already aggregated before
    if (is.null(attr(x, "by"))) {

        # bayesian
        draws <- attr(x, "posterior_draws")
        if (!is.null(draws)) {
            bycols <- NULL
            x_dt <- average_draws(
                data = x_dt,
                index = bycols,
                draws = draws,
                column = "predicted")

        # frequentist
        } else {
            if (!is.null(marginaleffects_wts_internal)) {
                x_dt[, "marginaleffects_wts_internal" := marginaleffects_wts_internal]
                x_dt <- x_dt[,
                .(predicted = stats::weighted.mean(
                    predicted,
                    marginaleffects_wts_internal,
                    na.rm = TRUE)),
                by = idx]
            } else {
                x_dt <- x_dt[, .(predicted = mean(predicted)), by = idx]
            }
        }
    }

    if (!"std.error" %in% colnames(x_dt)) {
        se <- get_se_delta(
            model = attr(x, "model"),
            newdata = attr(x, "newdata"),
            vcov = attr(x, "vcov"),
            type = attr(x, "type"),
            FUN = fun,
            ...)
        if (!is.null(se)) {
            x_dt[, "std.error" := se]
        }
    }

    setnames(x_dt, old = "predicted", new = "estimate")

    # confidence intervals
    out <- get_ci(
        x_dt,
        estimate = "estimate",
        conf_level = conf_level,
        draws = attr(x_dt, "posterior_draws"),
        model = model,
        ...)

    # back transformation
    if (!is.null(transform_avg)) {
        if (!is.null(attr(x, "transform"))) {
            msg <- "Estimates were transformed twice: once during the initial computation, and once more when summarizing the results in `tidy()` or `summary()`."
            warning(insight::format_message(msg), call. = FALSE)
        }
        out <- backtransform(out, transform_avg)
    }

    attr(out, "nchains") <- attr(x, "nchains")
    attr(out, "transform_label") <- attr(x, "transform_label")
    attr(out, "transform_average_label") <- names(transform_avg)[1]

    return(out)
}