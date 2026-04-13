#!/bin/bash
# Progress monitor for SLURM array job 38373724

JOB_ID=38380055
WORKDIR=~/bios731_hw4

SCENARIOS=(
  [1]="n=100   gibbs"
  [2]="n=100   cavi "
  [3]="n=1000  gibbs"
  [4]="n=1000  cavi "
  [5]="n=10000 gibbs"
  [6]="n=10000 cavi "
)

echo "============================================"
echo " Simulation Progress  (Job ${JOB_ID})"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"

# SLURM queue status
echo ""
echo "[SLURM Queue]"
squeue -j ${JOB_ID} --format="  TaskID=%-6K Status=%-10T Runtime=%-12M Node=%N" 2>/dev/null \
  || echo "  (job not in queue — finished or not started)"

# Per-task progress from log files
echo ""
echo "[Simulation Progress]  (500 sims per job)"
echo "  JOBID  Scenario          Progress   Last log"
echo "  -----  ----------------  ---------  ---------"

for i in 1 2 3 4 5 6; do
  log="${WORKDIR}/logs/sim_${JOB_ID}_${i}.out"
  rds=$(ls ${WORKDIR}/results/job${i}_*.rds 2>/dev/null)

  if [ -n "$rds" ]; then
    status="DONE (100%)"
    last=""
  elif [ -f "$log" ]; then
    last_sim=$(grep -oP 'sim \K[0-9]+' "$log" 2>/dev/null | tail -1)
    if [ -n "$last_sim" ]; then
      pct=$(( last_sim * 100 / 500 ))
      bar=$(printf '%-20s' $(printf '#%.0s' $(seq 1 $((pct / 5)))))
      status="[${bar}] ${pct}%"
      last="(sim ${last_sim}/500)"
    else
      status="[running — no output yet]"
      last=""
    fi
  else
    status="[pending]"
    last=""
  fi

  printf "  %-5s  %-16s  %-25s %s\n" "$i" "${SCENARIOS[$i]}" "$status" "$last"
done

# Results summary
n_done=$(ls ${WORKDIR}/results/job*.rds 2>/dev/null | wc -l)
echo ""
echo "[Results] ${n_done}/6 jobs completed"
echo "============================================"
