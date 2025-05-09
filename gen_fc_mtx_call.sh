#!/bin/sh

## Generate parcellation-based FC matrix 
# by 'calling gen_fc_matrix' function, 
# which takes 4 args:
    # var1 = atlas_name (e.g., schaefer400, gordon333, cabp)
    # var2 = func_dir (e.g., /../HCPD/HCD0015417_V1_MR/xcpd/sub-HCD0015417/ses-01/func)
    # var3 = sub_id (e.g., HCD0015417)
    # var4 = opt_dir (e.g., /../HCPD/HCD0015417_V1_MR/post-proc)

code_dir=/ceph/chpc/shared/deanna_barch_group/hcd_code
source ${code_dir}/gen_fc_mtx.sh

## Define vars
# Select parcellation from schaefer456,gordon333,& cabp
single_parcel=false # true=only use cabp; false=use all three
if ${single_parcel} ; then
    parcels=( cabp )
else
    parcels=( schaefer456 gordon333 cabp )
fi


# == iteration over all subs can be added here == #
# 1. first get the subject list into an array
# 2. using a for loop to iterate over the array
# !! make sure to differentiate vars of sub and sub_id 

# Specify sub name and id
sub=HCD0015417_V1_MR
sub_id=HCD0015417


# Set xcpd-func data direcotry
### !!! CHANGE DIRECTORY
func_dir=/scratch/weiz/projects/HCPD/${sub}/xcpd/sub-${sub_id}/ses-01/func


# Specify output direcotry
### !!! CHANGE DIRECTORY
out_dir=/scratch/weiz/projects/HCPD/${sub}/post_xcpd
if [ ! -d ${out_dir} ]; then
    mkdir ${out_dir}
fi

# Call function to generate FC matrix
for p in ${parcels[@]}
do
    gen_fc_matrix ${p} ${func_dir} ${sub_id} ${out_dir}
done



# == iteration over all subs should end here == #
