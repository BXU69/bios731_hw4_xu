#!/bin/bash
#SBATCH --job-name=bios731_sim
#SBATCH --array=1-6
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=UNLIMITED
#SBATCH --partition=wrobel
#SBATCH --output=logs/sim_%A_%a.out
#SBATCH --error=logs/sim_%A_%a.err

# Load R
module load R/4.4.0

# Run from project root
cd ~/bios731_hw4

Rscript R/run_sim.R
