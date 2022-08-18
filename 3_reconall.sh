#/bin/bash

#cd into directory where data is stored
cd /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1005/anat

#create a directory for reconall files
mkdir -p /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1005/mri/

#convert anat to image with readable name
mri_convert ARSA1005_ANAT.nii.gz /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1005/mri/001.mgz

#begin reconall
recon-all -subjid ARSA1005 -all