#!/bin/sh

## 1. Generate parcellation-based FC matrix 
    # by calling /gen_fc_matrix' function, 
    # which takes 4 args:
        # var1 = atlas_name (e.g., schaefer400, gordon333, cabp)
        # var2 = func_dir (e.g., /../HCPD/HCD0015417_V1_MR/xcpd/sub-HCD0015417/ses-01/func)
        # var3 = sub_id (e.g., HCD0015417)
        # var4 = opt_dir (e.g., /../HCPD/HCD0015417_V1_MR/post-proc)
        # var5 = denoised dtseries file name
        # var6 = outliers.tsv file name

## 2. Extract Framewise_Displacement Column from motion.tsv
    # by calling 'extract_fd_column' function,
    # which takes 3 args:
        # var1 = sub (e.g., HCD0015417_V1_MR)
        # var2 = motion file name with full path
        # var3 = output directory (eg, post_xcpd)


code_dir=/scratch/weiz/projects/HCPD/hcd_code/
source ${code_dir}/gen_fc_mtx.sh
source ${code_dir}/extract_fd.sh

## Define vars
# Select parcellation from schaefer400,gordon333,& cabp
single_parcel=false # true=only use cabp; false=use all three
if ${single_parcel} ; then
    parcels=( cabp )
else
    parcels=( schaefer456 gordon333 cabp718 )
fi



# get sub list
# !! make sure to differentiate vars of sub and sub_id 
ceph_dir=/ceph/chpc/shared/deanna_barch_group/weiz/HCD_Preproc
# sub_list=${code_dir}/RL2.0_subs_formatted.txt
# sub list w/ incomplete runs
run1_subs=()
PA_subs=()

mapfile -t subs < ${sub_list}
count=0
for sub in ${subs[@]} ; do

    echo "### Processing ${sub} ###"

    sub_id=$(echo ${sub} | awk -F"_" '{print $1}')
    
    # check scan pattern
    if [[ " ${run1_subs[*]} " == *" $sub "* ]] ; then        
        dtseries_name=ses-01_task-rest_run-01_space-fsLR_den-91k_desc-denoised_bold.dtseries.nii
        outlier_file_name=ses-01_task-rest_dir-AP_run-01_outliers.tsv
        mtion_file_name=ses-01_task-rest_dir-AP_run-01_motion.tsv
    elif [[ " ${PA_subs[*]} " == *" $sub "* ]] ; then
        dtseries_name=ses-01_task-rest_dir-PA_space-fsLR_den-91k_desc-denoised_bold.dtseries.nii
        outlier_file_name=ses-01_task-rest_dir-PA_outliers.tsv
        mtion_file_name=ses-01_task-rest_dir-PA_motion.tsv
    else
        # typical subs 
        dtseries_name=ses-01_task-rest_space-fsLR_den-91k_desc-denoised_bold.dtseries.nii
        outlier_file_name=ses-01_task-rest_outliers.tsv
        mtion_file_name=ses-01_task-rest_motion.tsv
    fi

    # check if xcpd completed        
    func_dir=${ceph_dir}/${sub}/xcpd/sub-${sub_id}/ses-01/func    
    func_file=${func_dir}/sub-${sub_id}_${dtseries_name}
    outlier_file=${func_dir}/sub-${sub_id}_${outlier_file_name}
    mtion_file=${func_dir}/sub-${sub_id}_${mtion_file_name}    
    
    if [ -f ${func_file} ]; then      
        # Specify output directory
        out_dir=${ceph_dir}/${sub}/post_xcpd
        if [ ! -d ${out_dir} ]; then
            mkdir ${out_dir}
        fi

        # Call function to generate FC matrix
        for p in ${parcels[@]}
        do
            gen_fc_matrix ${p} ${func_dir} ${sub_id} ${out_dir} ${func_file} ${outlier_file}                 
        done  

        # Call function to extract FD column  
        extract_fd_column ${sub} ${mtion_file} ${out_dir}
        
        
        count=$((count+1))
        echo "!!! Processed: $count "

    else
        echo "... No func file!"
    fi    

done



