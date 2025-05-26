#!/bin/sh -l

## Extract framewise displacement from 'outlier.tsv'
# produced by XCP-D
# @weiz, Last updated: May 2025


extract_fd_column () {
    sub=$1
    mtion_file=$2
    out_dir=$3
    
    column_name="framewise_displacement"
      
    if [ ! -f "${mtion_file}" ]; then
        echo " !! Missing motion file for $sub"
        return 
    fi

    # Extract column
    col_num=$(head -1 "${mtion_file}" | tr '\t' '\n' | grep -n -m1 "^${column_name}$" | cut -d: -f1)
    if [ -z "$col_num" ]; then
        echo "!! FD Column not found for $sub"
    else
        tail -n +2 "${mtion_file}" | cut -f"$col_num" > ${out_dir}/FD.tsv
        echo " ✓✓ FD extracted!"
    fi
}

