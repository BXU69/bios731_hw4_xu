# =============================================================================
# sim_functions.R
# Core functions for Problem 4 simulation study
# =============================================================================

# -----------------------------------------------------------------------------
# Data generation
# -----------------------------------------------------------------------------

#' Generate data from K-component Gaussian mixture (unit variance, equal weights)
generate_data <- function(n, mu_true) {
  K <- length(mu_true)
  ci <- sample(1:K, n, replace = TRUE)
  y  <- rnorm(n, mean = mu_true[ci], sd = 1)
  list(y = y, ci = ci)
}

# -----------------------------------------------------------------------------
# Vectorized Gibbs sampler
# Uses Gumbel-max trick for fast vectorized categorical sampling
# -----------------------------------------------------------------------------

#' @param y       numeric vector of observations
#' @param K       number of clusters
#' @param sigma_sq prior variance for mu
#' @param n_iter  total number of Gibbs iterations
#' @param burn_in number of iterations to discard as burn-in
gibbs_sampler <- function(y, K, sigma_sq, n_iter, burn_in) {
  n <- length(y)

  # Initialize
  mu <- sort(rnorm(K, mean(y), sd(y)))
  ci <- sample(1:K, n, replace = TRUE)

  n_post <- n_iter - burn_in
  mu_samples <- matrix(0, nrow = n_post, ncol = K)
  post_idx <- 0L

  for (t in 1:n_iter) {

    # -- Update cluster assignments (vectorized) --
    # log_prob_mat[i, k] = -0.5 * (y_i - mu_k)^2
    log_prob_mat <- -0.5 * outer(y, mu, function(a, b) (a - b)^2)
    # Numerically stabilize row-wise
    log_prob_mat <- log_prob_mat - apply(log_prob_mat, 1, max)
    prob_mat <- exp(log_prob_mat)
    prob_mat <- prob_mat / rowSums(prob_mat)
    # Gumbel-max trick: fully vectorized categorical sampling
    gumbel  <- -log(-log(matrix(runif(n * K), n, K) + 1e-300))
    ci      <- max.col(log(prob_mat + 1e-300) + gumbel)

    # -- Update cluster means --
    for (k in 1:K) {
      y_k      <- y[ci == k]
      n_k      <- length(y_k)
      post_var  <- 1 / (1 / sigma_sq + n_k)
      post_mean <- post_var * sum(y_k)
      mu[k]    <- rnorm(1, post_mean, sqrt(post_var))
    }

    # Store post-burn-in samples
    if (t > burn_in) {
      post_idx <- post_idx + 1L
      mu_samples[post_idx, ] <- mu
    }
  }

  mu_samples
}

# -----------------------------------------------------------------------------
# CAVI
# -----------------------------------------------------------------------------

#' @param y        numeric vector of observations
#' @param K        number of clusters
#' @param sigma_sq prior variance for mu
#' @param tol      ELBO convergence tolerance
#' @param max_iter maximum CAVI iterations
cavi_mixture <- function(y, K, sigma_sq, tol = 1e-6, max_iter = 1000) {
  n <- length(y)

  # Initialize variational parameters
  m    <- sort(rnorm(K, mean(y), sd(y)))
  s_sq <- rep(0.1, K)
  phi  <- matrix(1 / K, nrow = n, ncol = K)

  elbo_prev <- -Inf

  for (iter in 1:max_iter) {

    # -- Update phi --
    for (k in 1:K) {
      phi[, k] <- exp(y * m[k] - 0.5 * (m[k]^2 + s_sq[k]))
    }
    phi <- phi / rowSums(phi)

    # -- Update m and s_sq --
    for (k in 1:K) {
      sum_phi  <- sum(phi[, k])
      s_sq[k]  <- 1 / (1 / sigma_sq + sum_phi)
      m[k]     <- s_sq[k] * sum(phi[, k] * y)
    }

    # -- ELBO --
    elbo <- compute_elbo(y, K, sigma_sq, m, s_sq, phi)
    if (abs(elbo - elbo_prev) < tol) break
    elbo_prev <- elbo
  }

  list(m = m, s_sq = s_sq)
}

compute_elbo <- function(y, K, sigma_sq, m, s_sq, phi) {
  n <- length(y)
  e_log_p_mu <- sum(-0.5 * log(2 * pi * sigma_sq) - (m^2 + s_sq) / (2 * sigma_sq))
  e_log_p_c  <- n * (-log(K))
  e_log_p_y  <- 0
  for (k in 1:K) {
    e_log_p_y <- e_log_p_y +
      sum(phi[, k] * (-0.5 * log(2 * pi) -
            0.5 * (y^2 - 2 * y * m[k] + m[k]^2 + s_sq[k])))
  }
  ent_mu <- sum(0.5 * log(2 * pi * exp(1) * s_sq))
  ent_c  <- -sum(phi * log(phi + 1e-300))
  e_log_p_mu + e_log_p_c + e_log_p_y + ent_mu + ent_c
}

# -----------------------------------------------------------------------------
# Single simulation replicate
# Returns bias, coverage indicator, and elapsed time for each mu_k
# Label switching handled by sorting estimated means
# -----------------------------------------------------------------------------

#' @param n         sample size
#' @param mu_true   true means (will be sorted internally)
#' @param sigma_sq  prior variance
#' @param method    "gibbs" or "cavi"
run_one_sim <- function(n, mu_true, sigma_sq, method,
                        gibbs_iter = 10000, burn_in = 2000) {
  K            <- length(mu_true)
  mu_true_sort <- sort(mu_true)

  dat <- generate_data(n, mu_true_sort)
  y   <- dat$y

  t0 <- proc.time()[["elapsed"]]

  if (method == "gibbs") {
    mu_samp      <- gibbs_sampler(y, K, sigma_sq, gibbs_iter, burn_in)
    # Sort each posterior draw to fix label switching
    sorted_samp  <- t(apply(mu_samp, 1, sort))
    mu_est       <- colMeans(sorted_samp)
    ci_low       <- apply(sorted_samp, 2, quantile, 0.025)
    ci_high      <- apply(sorted_samp, 2, quantile, 0.975)

  } else {
    res     <- cavi_mixture(y, K, sigma_sq)
    ord     <- order(res$m)
    mu_est  <- res$m[ord]
    s_sq    <- res$s_sq[ord]
    ci_low  <- mu_est - 1.96 * sqrt(s_sq)
    ci_high <- mu_est + 1.96 * sqrt(s_sq)
  }

  elapsed <- proc.time()[["elapsed"]] - t0

  list(
    bias    = mu_est - mu_true_sort,
    covered = as.integer((mu_true_sort >= ci_low) & (mu_true_sort <= ci_high)),
    elapsed = elapsed
  )
}
