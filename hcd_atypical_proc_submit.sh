#!/bin/sh -l

# @weiz, Last updated: May 2025


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

# Generate sub list w/ atypical scan order
sub_dirs=()
keys=(REST1a REST2a) # Only incl. the first atypical scan from each session

cd ${dt_dir}
tmp=(HCD*)
subs=()
for i in ${tmp[@]}
do
    if [ -d ${dt_dir}/$i ] ; then
        cd ${dt_dir}/$i
        count=0
        rfMRI_dirs=( rfMRI_REST* )
        for d in ${rfMRI_dirs[@]}
        do
            # check if directory name contains atypical key
            if [[ "$d" == *"${keys[0]}"* || "$d" == *"${keys[1]}"* ]]; then
                count=$((count+1))  
            fi
        done

        # As long as one atypical scan exists
        if [[ $count -gt 0 ]] ; then
            subs+=("$i")
        fi   
    fi
done



###################################
####### SORT SUBJECT ORDERS #######
###################################

## Prioritize scans from the 2.0 release
mapfile -t priority_subs < ${sub_list}

# reorder sub list
ordered_subs=()
remaining=()

for s in ${subs[@]}; do
    if [[ "${priority_subs[@]}" =~ "$s" ]] ; then
        ordered_subs+=("$s")
    else
        remaining+=("$s")
    fi
done


# Combine lists
sorted_subs=("${ordered_subs[@]}" "${remaining[@]}")




###########################
####### SUBMIT JOBS #######
###########################

count=0
# start job submission from the 31st sub
for i in ${sorted_subs[@]} ; do
    # echo $i              
 
    count=$((count+1))
    sbatch --job-name=proc_${i} --output=${log_dir}/%x_%j.out \
        --error=${log_dir}/%x_%j.err \
        ${code_dir}/hcd_atypical_proc_run.sh "${wd}" "${i}" "${code_dir}"

done

echo "total n = $count "


