source("helpers.R")
if (!EXPENSIVE) exit_file("EXPENSIVE")
using("marginaleffects")

requiet("margins")
requiet("haven")
requiet("lme4")
requiet("insight")
requiet("emmeans")
requiet("broom")


# satterthwaite (no validity)
# skip_if_not_installed("insight", minimum_version = "0.17.1")
dat <- mtcars
dat$cyl <- factor(dat$cyl)
dat <- dat
mod <- lme4::lmer(mpg ~ hp + (1 | cyl), data = dat)
x <- predictions(mod, re.form = NA)
y <- predictions(mod, vcov = "satterthwaite", re.form = NA)
z <- predictions(mod, vcov = "kenward-roger", re.form = NA)
expect_true(all(x$conf.low != y$conf.low))
expect_true(all(x$conf.low != z$conf.low))
expect_true(all(y$conf.low != z$conf.low))
expect_true(all(x$p.value != y$p.value))
expect_true(all(x$p.value != z$p.value))
expect_true(all(y$p.value != z$p.value))
# kenward-roger adjusts vcov but not satterthwaite
expect_equivalent(x$std.error, y$std.error)
expect_true(all(x$std.error != z$std.error))
expect_true(all(y$std.error != z$std.error))


x <- plot_predictions(mod, condition = "hp", draw = FALSE, re.form = NA)
y <- plot_predictions(mod, condition = "hp", vcov = "satterthwaite", draw = FALSE, re.form = NA)
z <- plot_predictions(mod, condition = "hp", vcov = "kenward-roger", draw = FALSE, re.form = NA)
expect_true(all(x$conf.low != y$conf.low))
expect_true(all(x$conf.low != z$conf.low))
expect_true(all(y$conf.low != z$conf.low))
expect_equivalent(x$std.error, y$std.error)
expect_true(all(x$std.error != z$std.error))
expect_true(all(y$std.error != z$std.error))

# comparisons
x <- comparisons(mod, re.form = NA)
y <- comparisons(mod, vcov = "satterthwaite", re.form = NA)
z <- comparisons(mod, vcov = "kenward-roger", re.form = NA)
expect_true(all(x$conf.low != y$conf.low))
expect_true(all(x$conf.low != z$conf.low))
expect_true(all(y$conf.low != z$conf.low))
expect_true(all(x$std.error == y$std.error))
expect_true(all(x$std.error != z$std.error))
expect_true(all(y$std.error != z$std.error))

# at the mean (regression test)
mfx <- slopes(
    mod,
    newdata = datagrid(),
    vcov = "satterthwaite",
    re.form = NA
)
expect_inherits(mfx, "marginaleffects")


# GLM not supported
mod <- glmer(am ~ hp + (1 | cyl), family = binomial, data = dat)
expect_error(comparisons(mod, vcov = "satterthwaite", re.form = NA), pattern = "(?i)unable.*satter")
expect_error(predictions(mod, vcov = "kenward-roger", re.form = NA), pattern = "(?i)unable.*kenward")

# type = "link"
w <- predict(mod, type = "link")
x <- get_predict(mod, type = "link")
y <- get_predict(mod, type = "link", conf.level = .9)
z <- get_predicted(mod, predict = "link")
expect_equivalent(w, x$estimate)
expect_equivalent(w, y$estimate)
expect_equivalent(w, as.numeric(z))

# type = "response"
w <- predict(mod, type = "response")
x <- get_predict(mod, type = "response")
y <- get_predict(mod, type = "response", conf.level = .9)
z <- get_predicted(mod, predict = "expectation")
expect_equivalent(w, x$estimate)
expect_equivalent(w, y$estimate)
expect_equivalent(w, as.numeric(z))

# confidence intervals (weak test)
w <- get_predict(mod, conf.level = .95)
x <- get_predict(mod, conf.level = .90)
expect_true(all(w$conf.low < x$conf.low))
expect_true(all(w$conf.high > x$conf.high))

# no random effects: grand mean
w <- predict(mod, re.form = NA, type = "response")
x <- get_predict(mod, re.form = NA, type = "response")
expect_equivalent(w, x$estimate)


# glmer vs. stata vs. emtrends
tmp <- read.csv(testing_path("stata/databases/lme4_02.csv"))
mod <- glmer(y ~ x1 * x2 + (1 | clus), data = tmp, family = binomial)
stata <- readRDS(testing_path("stata/stata.rds"))$lme4_glmer
mfx <- merge(avg_slopes(mod, re.form = NA), stata)
expect_slopes(mod, re.form = NA)
expect_equivalent(mfx$estimate, mfx$dydxstata, tolerance = .01)
expect_equivalent(mfx$std.error, mfx$std.errorstata, tolerance = .01)
# emtrends
mod <- glmer(y ~ x1 + x2 + (1 | clus), data = tmp, family = binomial)
mfx <- slopes(mod, variables = "x1", newdata = datagrid(x1 = 0, x2 = 0, clus = 1), type = "link", re.form = NA)
em <- emtrends(mod, ~x1, "x1", at = list(x1 = 0, x2 = 0, clus = 1))
em <- tidy(em)
expect_equivalent(mfx$estimate, em$x1.trend)
expect_equivalent(mfx$std.error, em$std.error, tolerance = 1e-5)

# grand mean with new data
nd <- datagrid(model = mod, clus = NA, x1 = -1:1)
w <- predict(mod, newdata = nd, re.form = NA, type = "response")
x <- get_predict(mod, newdata = nd, re.form = NA)
y <- predictions(mod, newdata = nd, re.form = NA, type = "response")
expect_equivalent(w, x$estimate)
expect_equivalent(w, y$estimate)


# lme4::lmer vs. stata
tmp <- read.csv(testing_path("stata/databases/lme4_01.csv"))
mod <- lme4::lmer(y ~ x1 * x2 + (1 | clus), data = tmp)
stata <- readRDS(testing_path("stata/stata.rds"))$lme4_lmer
mfx <- merge(avg_slopes(mod, re.form = NA), stata)
expect_slopes(mod)
expect_equivalent(mfx$estimate, mfx$dydxstata, tolerance = .001)
expect_equivalent(mfx$std.error, mfx$std.errorstata, tolerance = .001)

# emtrends
mod <- lme4::lmer(y ~ x1 + x2 + (1 | clus), data = tmp)
mfx <- slopes(mod, variables = "x1", newdata = datagrid(x1 = 0, x2 = 0, clus = 1), re.form = NA)
em <- emtrends(mod, ~x1, "x1", at = list(x1 = 0, x2 = 0, clus = 1))
em <- tidy(em)
expect_equivalent(mfx$estimate, em$x1.trend)
expect_equivalent(mfx$std.error, em$std.error, tolerance = .001)


# vs. margins (dydx only)
tmp <- read.csv(testing_path("stata/databases/lme4_02.csv"))
mod <- lme4::glmer(y ~ x1 * x2 + (1 | clus), data = tmp, family = binomial)
res <- avg_slopes(mod, vcov = FALSE, re.form = NA)
mar <- summary(margins::margins(mod, re.form = NA))
expect_equivalent(res$estimate[1], mar$AME[1], tolerance = 1e-4)
expect_equivalent(res$estimate[2], mar$AME[2], tolerance = 1e-4)

tmp <- read.csv(testing_path("stata/databases/lme4_01.csv"))
mod <- lme4::lmer(y ~ x1 * x2 + (1 | clus), data = tmp)
res <- slopes(mod, vcov = FALSE, re.form = NA)
mar <- margins::margins(mod)
expect_true(expect_margins(res, mar))


# sanity check on dpoMatrix
tmp <- read.csv(testing_path("stata/databases/lme4_02.csv"))
mod <- lme4::glmer(y ~ x1 * x2 + (1 | clus), data = tmp, family = binomial)
k <- slopes(mod, vcov = as.matrix(stats::vcov(mod)), re.form = NA)
expect_inherits(k, "data.frame")


# bug stay dead: tidy without std.error
tmp <- read.csv(testing_path("stata/databases/lme4_02.csv"))
mod <- lme4::glmer(y ~ x1 * x2 + (1 | clus), data = tmp, family = binomial)
tid <- avg_slopes(mod, vcov = FALSE, re.form = NA)
expect_inherits(tid, "data.frame")
expect_equivalent(nrow(tid), 2)


# predictions: glmer: no validity
tmp <- read.csv(testing_path("stata/databases/lme4_02.csv"))
tmp$clus <- as.factor(tmp$clus)
tmp <- tmp
model <- lme4::glmer(y ~ x1 * x2 + (1 | clus), data = tmp, family = binomial)
pred1 <- predictions(model, newdata = datagrid(), re.form = NA)
pred2 <- predictions(model, newdata = head(tmp), re.form = NA)
expect_predictions(pred1, n_row = 1)
expect_predictions(pred2, n_row = 6)


# glmer.nb: marginaleffects vs. emtrends
set.seed(101)
dd <- expand.grid(
    f1 = factor(1:3),
    f2 = LETTERS[1:2],
    g = 1:9,
    rep = 1:15,
    KEEP.OUT.ATTRS = FALSE
)
dd$x <- rnorm(nrow(dd))
mu <- 5 * (-4 + with(dd, as.integer(f1) + 4 * as.numeric(f2)))
dd$y <- rnbinom(nrow(dd), mu = mu, size = 0.5)
dd <- dd
model <- suppressMessages(glmer.nb(y ~ f1 * f2 + (1 | g), data = dd, verbose = FALSE))
void <- capture.output(
    expect_slopes(model, n_unique = 2, re.form = NA)
)

# emtrends
mod <- suppressMessages(glmer.nb(y ~ x + (1 | g), data = dd, verbose = FALSE))
mfx <- slopes(mod, variables = "x", newdata = datagrid(g = 2), type = "link", re.form = NA)
em <- emtrends(mod, ~x, "x", at = list(g = 2))
em <- tidy(em)
expect_equivalent(mfx$estimate, em$x.trend)
expect_equivalent(mfx$std.error, em$std.error, tolerance = 1e-3)

# margins
mar <- tidy(margins(mod))
mfx <- avg_slopes(mod, re.form = NA)
expect_equivalent(mfx$estimate, mar$estimate, tolerance = .0001)
expect_equivalent(mfx$std.error, mar$std.error, tolerance = .0001)


# population-level
# Some contrasts are identical with include_random TRUE/FALSE because on Time has a random effect
mod <- suppressMessages(lmer(
    weight ~ 1 + Time + I(Time^2) + Diet + Time:Diet + I(Time^2):Diet + (1 + Time + I(Time^2) | Chick),
    data = ChickWeight
))

mfx2 <- slopes(
    mod,
    newdata = datagrid(
        Chick = NA,
        Diet = 1:4,
        Time = 0:21
    ),
    re.form = NA
)
mfx3 <- slopes(
    mod,
    newdata = datagrid(
        Chick = "1",
        Diet = 1:4,
        Time = 0:21
    ),
    re.form = NA
)
expect_inherits(mfx2, "marginaleffects")
expect_inherits(mfx3, "marginaleffects")

pred2 <- predictions(
    mod,
    newdata = datagrid(
        Chick = NA,
        Diet = 1:4,
        Time = 0:21
    ),
    re.form = NA
)
pred3 <- predictions(
    mod,
    newdata = datagrid(
        Chick = "1",
        Diet = 1:4,
        Time = 0:21
    ),
    re.form = NA
)
expect_inherits(pred2, "predictions")
expect_inherits(pred3, "predictions")

# sattertwhaite
tmp <- mtcars
tmp$cyl <- factor(tmp$cyl)
tmp$am <- as.logical(tmp$am)
tmp <- tmp
mod <- lme4::lmer(mpg ~ hp + am + (1 | cyl), data = tmp)

mfx <- slopes(mod, vcov = "kenward-roger", re.form = NA)
cmp <- comparisons(mod, vcov = "kenward-roger", re.form = NA)
cmp2 <- comparisons(mod, re.form = NA)
mfx2 <- slopes(mod, re.form = NA)
expect_equivalent(mfx$estimate, cmp$estimate)
expect_equivalent(mfx$std.error, cmp$std.error, tolerance = .0001)
expect_equivalent(attr(mfx, "vcov.type"), "Kenward-Roger")
expect_equivalent(attr(cmp, "vcov.type"), "Kenward-Roger")


# Issue #436
# e = number of events
# n = total
dat <- data.frame(
    e = c(
        1,
        1,
        134413,
        92622,
        110747,
        3625,
        35,
        64695,
        19428,
        221,
        913,
        13,
        5710,
        121,
        1339,
        1851,
        637,
        20,
        7,
        10,
        2508
    ),
    n = c(
        165,
        143,
        10458616,
        5338995,
        6018504,
        190810,
        1607,
        2504824,
        471821,
        5158,
        15027,
        205,
        86371,
        1785,
        10661,
        14406,
        4048,
        102,
        916,
        1079,
        242715
    ),
    year = round(runif(21, min = 1, max = 24)),
    sid = as.factor(1:21)
)

mod <- glmer(
    cbind(e, n - e) ~ 1 + year + (1 | sid),
    data = dat,
    family = binomial()
)

p <- predictions(
    mod,
    newdata = datagrid(
        newdata = dat,
        e = 1,
        n = 160,
        year = 1:5,
        sid = NA
    ),
    re.form = NA
)
expect_predictions(p)

cmp <- comparisons(
    mod,
    variables = "year",
    newdata = datagrid(
        newdata = dat,
        e = 1,
        n = 160,
        year = 1:5,
        sid = NA
    ),
    re.form = NA
)
expect_inherits(cmp, "comparisons")


# Issue #651: satterthwaite not supported for avg_*() because lmerTest needs a
# `data` argument and model matrix, but here we compute the average over several
# units of observations.
d <- sleepstudy
d$Cat <- sample(c("A", "B"), replace = TRUE, size = nrow(d))
fit <- lmer(Reaction ~ Days + Cat + (1 | Subject), d)
expect_error(
    avg_comparisons(fit, vcov = "satterthwaite", re.form = NA),
    pattern = "not supported.*with.*by.*hypothesis"
)
expect_error(
    comparisons(fit, vcov = "satterthwaite", hypothesis = 'b1 = 0', re.form = NA),
    pattern = "not supported.*with.*by.*hypothesis"
)
expect_error(
    avg_predictions(fit, vcov = "kenward-roger", re.form = NA),
    pattern = "not supported"
)


cmp1 <- comparisons(fit, newdata = datagrid(Cat = unique), vcov = "satterthwaite", re.form = NA)
cmp2 <- comparisons(fit, newdata = datagrid(Cat = unique), re.form = NA)
expect_true(all(cmp1$conf.low != cmp2$conf.low))
expect_true(all(cmp1$std.error == cmp2$std.error))


# Issue #1396: error on reserved names
set.seed(123)
dat <- data.frame(
    outcome = rbinom(n = 100, size = 1, prob = 0.35),
    var_binom = as.factor(rbinom(n = 100, size = 1, prob = 0.2)),
    var_cont = rnorm(n = 100, mean = 10, sd = 7),
    grp = as.factor(sample(letters[1:4], size = 100, replace = TRUE))
)
dat$group <- dat$grp
dat$var_cont <- datawizard::standardize(dat$var_cont)
m <- lme4::glmer(
    outcome ~ var_binom + var_cont + (1 | group),
    data = dat,
    family = binomial(link = "logit")
)
expect_error(avg_predictions(m, by = "var_binom", newdata = "balanced"), pattern = "forbidden")


# Issue #1490: no warning when vcov=FALSE
options(marginaleffects_safe = TRUE)
mod <- lmer(Sepal.Length ~ Sepal.Width + (1|Species), data = iris)
expect_warning(avg_comparisons(mod, vcov = TRUE))
expect_warning(avg_comparisons(mod))
expect_false(ignore(expect_warning)(avg_comparisons(mod, vcov = FALSE)))
options(marginaleffects_safe = NULL)
