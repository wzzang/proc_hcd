#!/bin/sh -l

# @weiz, Last updated: May 2025

#SBATCH --time=13:00:00
#SBATCH --mem=40G
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task 16
#SBATCH --partition=tier3_cpu
#SBATCH --account=deanna_barch



module load singularity
module load apptainer

wd="${1}"
sub="${2}"
cdir="${3}"

bash ${cdir}/hcd_proc_job.sh "${wd}" "${sub}" "${cdir}"




