#!/bin/sh -l

# @weiz, Last updated: April 2025

#SBATCH --time=12:00:00
#SBATCH --mem=30G
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

bash ~/Scripts/projects/hcpd_coupling/hcd_proc_job.sh "${wd}" "${sub}" "${cdir}"




