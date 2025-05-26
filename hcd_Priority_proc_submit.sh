#!/bin/sh -l

# @weiz, Last updated: April 2025

# set dirs
wd=/scratch/weiz/projects/HCPD
log_dir=${wd}/logs
code_dir=/scratch/weiz/projects/HCPD/hcd_code
sub_list=${code_dir}/RL2.0_subs_formatted.txt

# create log dir to store job stdout files
if [[ ! -d ${log_dir} ]] ; then
    mkdir ${log_dir}
fi

dt_dir=/ceph/intradb/archive/CinaB/CCF_HCD_STG/

# Prioritize scans from the 2.0 release
mapfile -t subs < ${sub_list}

# echo "total N = ${#subs[@]}"


###########################
####### SUBMIT JOBS #######
###########################

count=0
# start job submission from the 31st sub
for i in ${subs[@]} ; do
    echo $i                
    count=$((count+1))
    sbatch --job-name=proc_${i} --output=${log_dir}/%x_%j.out \
        --error=${log_dir}/%x_%j.err \
        ${code_dir}/hcd_proc_run.sh "${wd}" "${i}" "${code_dir}"
    
done

echo "total n = $count "
