#!/bin/bash

# @weiz, Last updated: April 2025

#####################################################################
## Processing HCD dataset in following steps:
# 1. Run fMRIPrep
    # 1.1. Copy converted nifti data from HCD database
    # 1.2. BIDSification
    # 1.3. Modify relevant JSON files
    # 1.4. Copy dummy files
    # 1.5. Execute fMRIPrep container

# 2. Run XCP-D
# 3. Data Transfer 
    # 3.1. Remove redudant raw data (produced from step 1.1)
    # 3.2. Move all outputs to the /ceph shared folder

## LOG Files
    # a. Group level log dir ${log_dir} is created under ${wd} to store 
    #   the stdout of individual jobs, as well as a record of sub IDs 
    #   with irregular scan orders for later use.
    # b. An individual log ${sub_log} is created under sub dir to 
    #   provide a quick overview of the executed steps, in case processing
    #   failed midway.

#####################################################################




# set dirs
ceph_dir=/ceph/intradb/archive/CinaB/CCF_HCD_STG/
# if transfer data
shared_dir=/ceph/chpc/shared/deanna_barch_group/weiz/HCD_Preproc 
wk_dir=$1 # where data & outputs locate
sub=$2 # in format of HCDXXXXXX_VX_MR
log_dir=${wk_dir}/logs
sub_log=${wk_dir}/${sub}/proc_job_log
code_dir=$3 # where containers locate
subdirs=( A B ) # two separate acquisition directions



# set rs-fMRI dir keys
dir_keys=( rfMRI_REST1_AP rfMRI_REST1_PA rfMRI_REST2_AP rfMRI_REST2_PA T1w_MPR_vNav_4e_e1e2_mean T2w_SPC_vNav )
# get containers
fprep_container=${code_dir}/fmriprep-23.1.4.sif
xcpd_container=${code_dir}/xcp_d-0.10.6.sif



############################################
################ START PROC ################
############################################ 

echo "Processing $sub "
if [ ! -d ${wk_dir}/${sub} ]; then
    mkdir -p ${wk_dir}/${sub}
fi
time=$(date "+%Y-%m-%d %H:%M:%S")
echo "## Proc Job Starts for $sub @ ${time}" >> ${sub_log}

# sub_num=`echo "$i" | sed 's/[^0-9]//g'`
unproc_dir=${ceph_dir}/${sub}/unprocessed
# BIDS structure
sub_id=$(echo "${sub}" | awk -F"_" '{print $1}')
sub_dir=${wk_dir}/${sub}/BIDS/sub-${sub_id}/ses-01/


################################################
################### FMRIPREP ###################
################################################ 

## BIDS
count=0
if [[ ! -d ${sub_dir} ]] ; then
    echo ".. BIDSification " >> ${sub_log}
    mkdir -p ${sub_dir}/anat
    mkdir -p ${sub_dir}/func
    mkdir -p ${sub_dir}/fmap  

    # link & rename files while iterating over two runs 
    cd ${unproc_dir}    
    for d in ${dir_keys[@]} ; do        
        # skip irregular folders
        if [[ -d $d ]] ; then
            if echo "$d" | grep -q "REST"; then
                k="${d: -2}" # phase direction AP/PA
                r=`echo $d | awk -F"REST"  '{print $2}' | cut -c1` # run number
                
                ## BIDS format namestrings:
                # rfMRI
                bs_rest=sub-${sub_id}_ses-01_task-rest_dir-${k}_run-0${r}_bold
                bs_sbr=sub-${sub_id}_ses-01_task-rest_dir-${k}_run-0${r}_sbref
                bs_fmap=sub-${sub_id}_ses-01_dir-${k}_run-0${r}_epi
                        
            # cp files
                # rfmri
                cp ${unproc_dir}/${d}/HCD*REST*${k}.json \
                    ${sub_dir}/func/${bs_rest}.json
                cp ${unproc_dir}/${d}/HCD*REST*${k}.nii.gz \
                    ${sub_dir}/func/${bs_rest}.nii.gz
                # rfmri_sbr
                cp ${unproc_dir}/${d}/HCD*REST*${k}_SBRef.json \
                    ${sub_dir}/func/${bs_sbr}.json
                cp ${unproc_dir}/${d}/HCD*REST*${k}_SBRef.nii.gz \
                    ${sub_dir}/func/${bs_sbr}.nii.gz
                # fieldmap
                cp ${unproc_dir}/${d}/HCD*Spin*${k}.json \
                    ${sub_dir}/fmap/${bs_fmap}.json
                cp ${unproc_dir}/${d}/HCD*Spin*${k}.nii.gz \
                    ${sub_dir}/fmap/${bs_fmap}.nii.gz
            elif echo "$d" | grep -q "T1"; then
                cp ${unproc_dir}/${d}/HCD*json \
                    ${sub_dir}/anat/sub-${sub_id}_ses-01_T1w.json
                cp ${unproc_dir}/${d}/HCD*gz \
                    ${sub_dir}/anat/sub-${sub_id}_ses-01_T1w.nii.gz
            elif echo "$d" | grep -q "T2"; then
                cp ${unproc_dir}/${d}/HCD*json \
                    ${sub_dir}/anat/sub-${sub_id}_ses-01_T2w.json
                cp ${unproc_dir}/${d}/HCD*gz \
                    ${sub_dir}/anat/sub-${sub_id}_ses-01_T2w.nii.gz

            fi                               

        else
            echo "$d non exists for ${sub_id}"
            count=$((count+1))          
        fi               
    done 
else
    echo ".. BIDS dir exists!"
    echo ".. BIDSified already! " >> ${sub_log}
fi

# record sub w/ irregularities
if [ $count -eq 4 ] ; then
    echo ${sub_id} >> ${log_dir}/irregular_data_struc_subs
    bids_check=0 # check failed
else
    bids_check=1
fi


## ADJUST .JSONS 
json_job=${wk_dir}/${sub}/json_mod_done
if [ ! -f ${json_job} ] ; then
    echo ".. JSON modification" >> ${wk_dir}/${sub}/proc_job_log
    for json in ${sub_dir}/fmap/*.json ; do
        # echo $json
        if [[ "$json" == *"AP_run-01"* ]]; then
            # echo $json
            jq --arg sub "sub-${sub_id}" '. + { "IntendedFor": [
                "ses-01/func/\($sub)_ses-01_task-rest_dir-AP_run-01_bold.nii.gz"
            ] }' "$json" > ${sub_dir}/fmap/tmp.json && mv ${sub_dir}/fmap/tmp.json $json
        elif [[ "$json" == *"PA_run-01"* ]]; then
            jq --arg sub "sub-${sub_id}" '. + { "IntendedFor": [
                "ses-01/func/\($sub)_ses-01_task-rest_dir-PA_run-01_bold.nii.gz"
            ] }' "$json" > ${sub_dir}/fmap/tmp.json && mv ${sub_dir}/fmap/tmp.json $json
        elif [[ "$json" == *"AP_run-02"* ]]; then
            jq --arg sub "sub-${sub_id}" '. + { "IntendedFor": [
                "ses-01/func/\($sub)_ses-01_task-rest_dir-AP_run-02_bold.nii.gz"
            ] }' "$json" > ${sub_dir}/fmap/tmp.json && mv ${sub_dir}/fmap/tmp.json $json
        elif [[ "$json" == *"PA_run-02"* ]]; then
            jq --arg sub "sub-${sub_id}" '. + { "IntendedFor": [
                "ses-01/func/\($sub)_ses-01_task-rest_dir-PA_run-02_bold.nii.gz"
            ] }' "$json" > ${sub_dir}/fmap/tmp.json && mv ${sub_dir}/fmap/tmp.json $json
        fi      
    done
    # save log
    echo "" > ${json_job}
else
    echo ".. JSON modified already!" >> ${sub_log}
fi


## CP two dummy files
dm_f1=${wk_dir}/${sub}/BIDS/dataset_description.json
if [ ! -f ${dm_f1} ]; then
    cp ${code_dir}/dataset_description.json ${dm_f1}
fi
dm_f2=${wk_dir}/${sub}/BIDS/README
if [ ! -f ${dm_f2} ]; then
    cp ${code_dir}/README ${dm_f2}
fi

# cp freesurfer license file
lsc_f=${wk_dir}/${sub}/license.txt
if [ ! -f ${lsc_f} ] ; then
    cp ${code_dir}/license.txt ${lsc_f}
fi

## Run fmriprep
# create a dummy file to idnicate completion of job
fprep_job=${wk_dir}/${sub}/fprep_finished
# only run job if bids check succeeded
# if [ ! -f ${fprep_job} ] && [ ${bids_check} -gt 0 ]; then
if [ ! -f ${fprep_job} ]; then

    echo " .. start fMRIPrep .."   
    
    # max 2 attemps to avoid errors
    for n in 1 2 ; do
        echo "* Attempt $n :"
        echo ".. fMRIPrep attempt $n *" >> ${sub_log}

        ## Note, explicit mapping of /home and /opt was added
        # to avoid errors on running container on /scratch

        singularity run --cleanenv \
        -B "${wk_dir}/${sub}":/tmp \
        -B "${wk_dir}/${sub}/license.txt":/opt/freesurfer/.license \
        -B "${wk_dir}/${sub}":/home/weiz \
        ${fprep_container} --fs-license-file /opt/freesurfer/.license \
        -w /tmp /tmp/BIDS /tmp/derivatives \
        participant --participant_label "${sub_id}" \
        --output-spaces fsaverage5 MNI152NLin6Asym:res-2 MNI152NLin2009cAsym \
        --cifti-output \
        --nthreads 16 \
        --omp-nthreads 8 \
        --mem-mb 30000

        #search derivative html file for the code block that indicates no errors were found
        if grep -Pzoq '<div id="errors">[\s\S]*?<p>No errors to report!<\/p>[\s\S]*?<\/div>' \
                "${wk_dir}/${sub}/derivatives/sub-${sub_id}.html" ; then
            # No errors found, quit command loop
            echo "fMRIPrep: NO error found!"
            echo ".. .. completed!" >> ${sub_log}
            xcpd_flag=1		
            echo "" > ${fprep_job}
            # break
        else
            echo "fMRIPrep: error found!"
            echo ".. .. failed!" >> ${sub_log}            
            if [ $n -eq 2 ] ; then
                 echo ${sub_id} >> ${log_dir}/fmriprep_failed_subs
                exit
            fi
        fi  
    done

else
    echo "skip fmriprep!"
fi





#############################################
################### XCP-D ###################
#############################################

# create a dummy file to idnicate completion of job
xcpd_job=${wk_dir}/${sub}/xcpd_finished


## Only execute if fMRIPrep succeeded!!
if [ -f ${fprep_job} ]; then

    echo ".. XCPD Proc" >> ${sub_log}

    # set dirs
    sub_dir=$wk_dir/${sub}
    opt_dir=${sub_dir}/xcpd

    if [ ! -d ${opt_dir} ]; then
        mkdir ${opt_dir}
    fi


    apptainer run --cleanenv \
        -B ${sub_dir} \
        ${xcpd_container} --fs-license-file ${sub_dir}/license.txt \
        ${sub_dir}/derivatives \
        ${opt_dir} \
        participant \
        --work-dir ${opt_dir} \
        --smoothing 2 \
        --dummy-scans 6 \
        --random-seed 0 \
        --bpf-order 2 \
        --despike \
        --lower-bpf 0.01 \
        --upper-bpf 0.08 \
        --min-time 240 \
        -p 36P \
        --motion-filter-type notch \
        --band-stop-min 15 \
        --band-stop-max 25 \
        --motion-filter-order 4 \
        --head-radius auto \
        --file-format cifti \
        --warp-surfaces-native2std \
        --mode abcd \
        --abcc-qc y \
        --create-matrices all \
        --skip-parcellation \
        --fd-thresh 0.3 \
        --nthreads 16 \
        --omp-nthreads 8 \
        --mem-gb 30  

    #search output html file for the code block that indicates no errors were found
    if grep -Pzoq '<div[^>]*id="errors"[^>]*>[\s\S]*?<p[^>]*>No errors to report!<\/p>[\s\S]*?<\/div>' \
            "${sub_dir}/xcpd/sub-${sub_id}.html" ; then
        # No errors found, quit command loop
		echo "XCPD: NO error found!"
        echo ".. .. completed!" >> ${sub_log}
        echo "" > ${xcpd_job}	
		# break
	else
        echo "XCPD: error found!"
        echo ".. .. failed!" >> ${sub_log}
        echo ${sub_id} >> ${log_dir}/xcpd_failed_subs

    fi  

else
    echo ".. XCPD Proc condition not satisfied" >> ${sub_log}
fi



#############################################
############### DATA TRANSFER ###############
#############################################

if [ -f ${xcpd_job} ]; then
    # set dir
    sc_dir=${wk_dir}/${sub}
    dst_dir=${shared_dir}

    # remove BIDS dir
    # rm -rf ${sc_dir}/BIDS
    echo ".. Start Data Transfer" >> ${sub_log}
    rsync -a --partial ${sc_dir} ${dst_dir}/ >> ${sub_log} 2>&1
    status=$?

    # check transfer & delete source copy
    if [ $status -eq 0 ]; then
        echo ".. Completed Data Transfer" >> ${sub_log}
        rm -rf ${sc_dir}
        # echo ".. Deleted Source Copy" >> ${dst_dir}/${sub}/proc_job_log
    else
        echo ".. Transfer failed; rsync exited with code $status" >> ${sub_log}
    fi

fi


