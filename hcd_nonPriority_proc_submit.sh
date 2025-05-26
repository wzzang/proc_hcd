#!/bin/sh -l

# @weiz, Last updated: April 2025

# set dirs
wd=/scratch/weiz/projects/HCPD
log_dir=${wd}/logs
code_dir=/ceph/chpc/shared/deanna_barch_group/hcd_code
sub_list=${code_dir}/RL2.0_subs_formatted.txt

# create log dir to store job stdout files
if [[ ! -d ${log_dir} ]] ; then
    mkdir ${log_dir}
fi

dt_dir=/ceph/intradb/archive/CinaB/CCF_HCD_STG/
cd ${dt_dir}
# subs=(HCD*)
# ls -d HCD* | head -3
subs=($(ls -d HCD* | awk 'length($0) == 16'))
Nsubs=${#subs[@]}


###################################
####### SORT SUBJECT ORDERS #######
###################################

# Prioritize scans from the 2.0 release
mapfile -t priority_subs < ${sub_list}

# identify non-RL2.0 subs from the list
non_priority_subs=()
for sub in "${subs[@]}"; do
    if ! grep -qx "$sub" ${sub_list}; then
        non_priority_subs+=("$sub")
    fi
done

echo "non priority subs N = ${#non_priority_subs[@]}"

# Split above into V1 and others
v1_subs=()
other_subs=()
for sub in "${non_priority_subs[@]}"; do
    if [[ "$sub" == *_V1_* ]]; then
        v1_subs+=("$sub")
    else
        other_subs+=("$sub")
    fi
done

echo "V1 subs N = ${#v1_subs[@]}"
echo "Other subs N = ${#other_subs[@]}"

# Combine non-priority list:  V1s, then others
sorted_subs=("${v1_subs[@]}" "${other_subs[@]}")
echo "Sorted subs N = ${#sorted_subs[@]}"
# Remove duplicates while preserving order
sorted_subs=($(printf "%s\n" "${sorted_subs[@]}" | awk '!seen[$0]++'))
echo "Final subs N = ${#sorted_subs[@]}"


###########################
####### SUBMIT JOBS #######
###########################

# count=0
# # start job submission from the 31st sub
# for i in ${sorted_subs[@]} ; do
#     echo $i              

#     # prioritize "V1" scans    
#     count=$((count+1))
#     # sbatch --job-name=proc_${i} --output=${log_dir}/%x_%j.out \
#     #     --error=${log_dir}/%x_%j.err \
#     #     ${code_dir}/hcd_proc_run.sh "${wd}" "${i}" "${code_dir}"

# done

# echo "total n = $count "