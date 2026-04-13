# =============================================================================
# run_sim.R
# Entry point for each SLURM array job.
# Each JOBID maps to one (n, method) scenario.
#
# Scenario table (6 scenarios):
#   JOBID 1: n=100,   method=gibbs
#   JOBID 2: n=100,   method=cavi
#   JOBID 3: n=1000,  method=gibbs
#   JOBID 4: n=1000,  method=cavi
#   JOBID 5: n=10000, method=gibbs
#   JOBID 6: n=10000, method=cavi
#
# Run from ~/bios731_hw4/:
#   Rscript R/run_sim.R
# =============================================================================

source("R/sim_functions.R")

# ---------------------------------------------------------------------------
# Read job ID from SLURM environment
# ---------------------------------------------------------------------------
job_id <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
if (is.na(job_id)) stop("SLURM_ARRAY_TASK_ID not set.")

# ---------------------------------------------------------------------------
# Scenario lookup table
# ---------------------------------------------------------------------------
scenarios <- data.frame(
  n      = c(100, 100, 1000, 1000, 10000, 10000),
  method = c("gibbs", "cavi", "gibbs", "cavi", "gibbs", "cavi"),
  stringsAsFactors = FALSE
)

if (job_id < 1 || job_id > nrow(scenarios)) {
  stop("SLURM_ARRAY_TASK_ID must be between 1 and ", nrow(scenarios))
}

n      <- scenarios$n[job_id]
method <- scenarios$method[job_id]

cat(sprintf("Job %d | n = %d | method = %s\n", job_id, n, method))

# ---------------------------------------------------------------------------
# Fixed simulation parameters
# ---------------------------------------------------------------------------
K         <- 4
mu_true   <- c(0, 5, 10, 20)
sigma_sq  <- 10
nsim      <- 500
gibbs_iter <- 10000
burn_in   <- 2000

set.seed(job_id * 42)

# ---------------------------------------------------------------------------
# Run simulations
# ---------------------------------------------------------------------------
results <- vector("list", nsim)

for (sim in seq_len(nsim)) {
  if (sim %% 50 == 0) cat(sprintf("  sim %d / %d\n", sim, nsim))
  results[[sim]] <- run_one_sim(
    n        = n,
    mu_true  = mu_true,
    sigma_sq = sigma_sq,
    method   = method,
    gibbs_iter = gibbs_iter,
    burn_in  = burn_in
  )
}

# ---------------------------------------------------------------------------
# Save results
# ---------------------------------------------------------------------------
out <- list(
  job_id   = job_id,
  n        = n,
  method   = method,
  mu_true  = sort(mu_true),
  results  = results
)

out_path <- sprintf("results/job%d_n%d_%s.rds", job_id, n, method)
saveRDS(out, out_path)
cat("Saved:", out_path, "\n")
