# BIOS 731 Homework 4: Bayesian Inference for Mixture Models

## Overview

This repository contains the code and report for Homework 4 of BIOS 731 (Advanced Statistical Computing) at Emory University. The assignment implements and compares two Bayesian inference algorithms — **Gibbs sampling** and **Coordinate Ascent Variational Inference (CAVI)** — for a K-component Gaussian mixture model with unit variance.

The main report covers:
- **Problem 1**: Derivation and implementation of a Gibbs sampler for the posterior $p(\mu, \mathbf{c} \mid y)$
- **Problem 2**: Derivation and implementation of a CAVI algorithm under the mean-field approximation
- **Problem 3**: Fitting both methods to the Old Faithful waiting times dataset, with MCMC diagnostics and a comparison of estimates and computation time
- **Problem 4**: A simulation study (executed on the Emory RSPH computing cluster) evaluating bias, 95% CI coverage, and computation time across sample sizes $n \in \{100, 1000, 10000\}$

---

## Repository Structure

```
bios731_hw4_xu/
│
├── hw4_report.Rmd          # Main report: all derivations, code, and results (Problems 1–4)
├── hw4_report.pdf          # Compiled PDF output
│
├── R/
│   ├── sim_functions.R     # Core functions: data generation, Gibbs sampler, CAVI, run_one_sim()
│   ├── run_sim.R           # Cluster job entry point; reads SLURM_ARRAY_TASK_ID and runs one scenario
│   └── combine_results.R   # Loads all job outputs, computes summaries, and saves plots
│
├── results/                # Simulation output (.rds files, one per SLURM job)
│   ├── job1_n100_gibbs.rds
│   ├── job2_n100_cavi.rds
│   ├── job3_n1000_gibbs.rds
│   ├── job4_n1000_cavi.rds
│   ├── job5_n10000_gibbs.rds
│   └── job6_n10000_cavi.rds
│
├── logs/                   # SLURM stdout/stderr logs (one pair per array job)
│
├── submit.sh               # SLURM array job submission script (array=1–6, partition=wrobel)
├── HW_bayes-1.pdf          # Original assignment instructions
└── README.md               # This file
```

### SLURM job–scenario mapping

| JOBID | n     | Method |
|-------|-------|--------|
| 1     | 100   | Gibbs  |
| 2     | 100   | CAVI   |
| 3     | 1000  | Gibbs  |
| 4     | 1000  | CAVI   |
| 5     | 10000 | Gibbs  |
| 6     | 10000 | CAVI   |

---

## Reproducing the Results

### Report (Problems 1–3)

Open `bios731_hw4_xu.Rproj` in RStudio and knit `hw4_report.Rmd` to PDF. The report requires the following R packages:

```r
install.packages(c("coda", "ggplot2", "patchwork", "dplyr", "scales", "knitr"))
```

Problem 3 uses the built-in `faithful` dataset — no external data download needed.

### Simulation Study (Problem 4)

The simulation was run on the Emory RSPH HPC cluster. To reproduce:

**1. Transfer scripts to the cluster**

```bash
scp -r R/ submit.sh <your_id>@clogin01.sph.emory.edu:~/bios731_hw4/
ssh <your_id>@clogin01.sph.emory.edu "mkdir -p ~/bios731_hw4/results ~/bios731_hw4/logs"
```

**2. Submit the array job**

```bash
ssh <your_id>@clogin01.sph.emory.edu
cd ~/bios731_hw4
sbatch submit.sh        # launches 6 jobs (JOBID 1–6) on the wrobel partition
```

Each job runs 500 simulation replicates for its assigned (n, method) scenario. Gibbs chains use 10,000 iterations with a 2,000-iteration burn-in.

**3. Download results and compile the report**

Once all 6 jobs finish, copy the results back locally:

```bash
scp <your_id>@clogin01.sph.emory.edu:~/bios731_hw4/results/*.rds results/
```

Then knit `hw4_report.Rmd` — Problem 4 loads the `.rds` files from `results/` and generates all plots inline.
