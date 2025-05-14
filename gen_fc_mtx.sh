#!/bin/sh

## Generate parcellation-based FC matrix 
# 1. generate ptseriese.nii.gz
    # using the censored timeseries; eg, 'good' time points
    # indicated in outlier.tsv
# 2. generate pconn.nii.gz
# 3. extract matrix to .tsv





########### DEFINE FUNCTION ########### 
gen_fc_matrix() {
    ## Arguments
    # $1 = atlas_name (e.g., schaefer400, gordon333, cabp)
    # $2 = func_dir (e.g., /../HCPD/HCD0015417_V1_MR/xcpd/sub-HCD0015417/ses-01/func)
    # $3 = sub_id (e.g., HCD0015417)
    # $4 = opt_dir (e.g., /../HCPD/HCD0015417_V1_MR/post_xcpd)

    atlas_name=$1
    func_dir=$2
    sub_id=$3
    opt_dir=$4

     echo " ${sub_id}: ${atlas_name} "

    module load workbench
    fn_cmd=/export/workbench/workbench-1.5.0_take2/bin_rh_linux64/wb_command

    # === Get Files === #
    atlas_dir=/ceph/chpc/shared/deanna_barch_group/hcd_code/atlas    
    dtseries_file=${func_dir}/sub-${sub_id}_ses-01_task-rest_space-fsLR_den-91k_desc-denoised_bold.dtseries.nii
    outlier_file=${func_dir}/sub-${sub_id}_ses-01_task-rest_outliers.tsv
    
    # === Sanity Check === #
    if [ ! -f ${dtseries_file} ]; then
        echo "ERROR: dtseries file not found: ${dtseries_file}"
        return 1
    fi
    if [ ! -f ${outlier_file} ]; then
        echo "ERROR: outlier file not found: ${outlier_file}"
        return 1
    fi

    # === Select Atlas === #
    if [[ "$atlas_name" == *"fer"* ]]; then
        par_file=${atlas_dir}/Schaefer456Parcels_space-fsLR_den-91k_dseg.dlabel.nii
    elif [[ "$atlas_name" == *"don"* ]]; then
        par_file=${atlas_dir}/Gordon333_space-fsLR_den-91k_dseg.dlabel.nii
    else
        par_file=${atlas_dir}/CortexSubcortex_ColeAnticevic_NetPartition_wSubcorGSR_parcels_LR.dlabel.nii
    fi


    # === Parcellation === #
    ptseries_file=${opt_dir}/sub-${sub_id}_ses-01_task-rest_space-fsLR_seg-${atlas_name}_stat-mean_timeseries.ptseries.nii
    if [ ! -f ${ptseries_file} ] ; then
        echo "... Generate ptseries "
        ${fn_cmd} -cifti-parcellate ${dtseries_file} ${par_file} COLUMN ${ptseries_file}
    else
        echo "... skip! ptseries exists"
    fi


    # === Conn Matrix === #
    pconn_file=${opt_dir}/sub-${sub_id}_ses-01_task-rest_space-fsLR_seg-${atlas_name}_stat-pearsoncorrelation_boldmap.pconn.nii
    tsv_file=${opt_dir}/sub-${sub_id}_ses-01_task-rest_space-fsLR_seg-${atlas_name}_stat-pearsoncorrelation_mat.tsv
    
    if [ ! -f ${tsv_file} ] ; then
        
        # Use outlier.tsv for temporal masking
        mask_file=${opt_dir}/tmask.tsv
        if [ ! -f ${mask_file} ] ; then
            cp ${outlier_file} ${opt_dir}/outlier.tsv
            # Remove the header line from file
            sed -i '1d' ${opt_dir}/outlier.tsv
            # Recode 1-->0 & 0-->1
            tr '01' '10' < ${opt_dir}/outlier.tsv > ${mask_file}
        fi

        echo "... Calc pconn "    
        ${fn_cmd} -cifti-correlation ${ptseries_file} ${pconn_file} -weights ${opt_dir}/tmask.tsv -fisher-z
        echo "... Export tsv "    
        ${fn_cmd} -cifti-convert -to-text ${pconn_file} ${tsv_file}

        # Clean
        if [ -f ${opt_dir}/outlier.tsv ] ; then
            rm ${opt_dir}/outlier.tsv
        fi
    else
        echo "... skip! outputs exist"
    fi

}  
