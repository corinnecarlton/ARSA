#!/bin/bash

#must make sure that the MNI file is in each folder

#navigate to the appropriate directory and change sub num
cd /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1005/anat

#perform skull stripping note - ensure anat file named approapriately and that subj name has been adjusted
mri_watershed ARSA1005_ANAT.nii.gz ARSA1005_ANAT_WATERSHED.nii.gz

#run ants but ensure MNI template in each anat folder and that subject name has been adjusted
antsIntroduction.sh -d 3 -i ARSA1005_ANAT_WATERSHED.nii.gz -r MNI152_T1_1mm_brain.nii.gz

# to build the path in bash profile to ants
#export ANTSPATH=/Users/Corinne/Desktop/antsBuild/install/bin/

#previous code to run ants but actually using the one above:
#WarpImageMultiTransform 3 ARSA1002_ANAT.nii.gz ARSA1002_WARP.nii.gz -R MNI152_T1_1mm_brain.nii.gz ARSA1002_Affine.txt

