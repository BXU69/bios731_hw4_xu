# =============================================================================
# combine_results.R
# Load all job outputs, compute bias/coverage summaries with MC SE,
# and produce plots for the hw4 report.
# Run from ~/bios731_hw4/ after all jobs finish.
# =============================================================================

library(ggplot2)
library(dplyr)

# ---------------------------------------------------------------------------
# Load all result files
# ---------------------------------------------------------------------------
rds_files <- list.files("results", pattern = "^job.*\\.rds$", full.names = TRUE)

if (length(rds_files) == 0) stop("No result files found in results/")

cat("Loading", length(rds_files), "result files...\n")

all_rows <- lapply(rds_files, function(f) {
  dat      <- readRDS(f)
  nsim     <- length(dat$results)
  K        <- length(dat$mu_true)

  # Flatten bias and coverage across simulations and mu components
  do.call(rbind, lapply(seq_len(nsim), function(s) {
    r <- dat$results[[s]]
    data.frame(
      n       = dat$n,
      method  = dat$method,
      sim     = s,
      mu_idx  = 1:K,
      mu_true = dat$mu_true,
      bias    = r$bias,
      covered = r$covered,
      elapsed = r$elapsed
    )
  }))
})

df <- bind_rows(all_rows)

# ---------------------------------------------------------------------------
# Summary: bias and coverage per (n, method, mu_true)
# MC SE for bias  = sd(bias) / sqrt(nsim)
# MC SE for coverage = sqrt(p*(1-p)/nsim)
# ---------------------------------------------------------------------------
nsim <- 500

summary_df <- df %>%
  group_by(n, method, mu_true) %>%
  summarise(
    mean_bias   = mean(bias),
    se_bias     = sd(bias) / sqrt(n()),
    coverage    = mean(covered),
    se_coverage = sqrt(mean(covered) * (1 - mean(covered)) / n()),
    mean_time   = mean(elapsed),
    .groups     = "drop"
  ) %>%
  mutate(
    n_label  = factor(paste0("n=", n), levels = c("n=100", "n=1000", "n=10000")),
    mu_label = factor(paste0("mu=", mu_true))
  )

# ---------------------------------------------------------------------------
# Plot 1: Bias
# ---------------------------------------------------------------------------
p_bias <- ggplot(summary_df,
                 aes(x = n_label, y = mean_bias,
                     color = method, group = method)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbar(
    aes(ymin = mean_bias - 1.96 * se_bias,
        ymax = mean_bias + 1.96 * se_bias),
    width = 0.2, position = position_dodge(0.4)
  ) +
  geom_point(size = 2.5, position = position_dodge(0.4)) +
  facet_wrap(~ mu_label, nrow = 1) +
  scale_color_manual(values = c(gibbs = "#2166AC", cavi = "#D6604D"),
                     labels = c(gibbs = "Gibbs", cavi = "CAVI")) +
  labs(
    title  = expression("Bias of " * hat(mu) * " (±1.96 MC SE)"),
    x      = "Sample size",
    y      = "Bias",
    color  = "Method"
  ) +
  theme_bw(base_size = 12) +
  theme(legend.position = "bottom")

# ---------------------------------------------------------------------------
# Plot 2: Coverage
# ---------------------------------------------------------------------------
p_cov <- ggplot(summary_df,
                aes(x = n_label, y = coverage,
                    color = method, group = method)) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "grey50") +
  geom_errorbar(
    aes(ymin = coverage - 1.96 * se_coverage,
        ymax = coverage + 1.96 * se_coverage),
    width = 0.2, position = position_dodge(0.4)
  ) +
  geom_point(size = 2.5, position = position_dodge(0.4)) +
  facet_wrap(~ mu_label, nrow = 1) +
  scale_color_manual(values = c(gibbs = "#2166AC", cavi = "#D6604D"),
                     labels = c(gibbs = "Gibbs", cavi = "CAVI")) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(
    title  = expression("Coverage of 95% CI for " * hat(mu) * " (±1.96 MC SE)"),
    x      = "Sample size",
    y      = "Coverage",
    color  = "Method"
  ) +
  theme_bw(base_size = 12) +
  theme(legend.position = "bottom")

# ---------------------------------------------------------------------------
# Save outputs
# ---------------------------------------------------------------------------
ggsave("results/bias_plot.pdf",     p_bias, width = 10, height = 4)
ggsave("results/coverage_plot.pdf", p_cov,  width = 10, height = 4)
saveRDS(summary_df, "results/summary_df.rds")

cat("Plots saved to results/\n")
print(summary_df)
