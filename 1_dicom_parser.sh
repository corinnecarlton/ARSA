#!/bin/bash

STUDY_DIR=/Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1001/

# NOTES #########################
# This is a 1 step script.  follow the steps below and run in terminal
# n.b. must have run wget.sh, and make_subject_numbers.sh
#################################


#Step 1 uncomment the subject you want to run

#dont forget to get rid of the forward slashes in the long subject number. Replace each with a colon

#SUBJECT=14.04.19-12:45:46-DST-1.3.12.2.1107.5.2.32.35439 #PILOT
#SUBJECT=14.07.31-12:13:34-DST-1.3.12.2.1107.5.2.32.35439 #TOM001
#SUBJECT=14.08.06-09:53:17-DST-1.3.12.2.1107.5.2.32.35439 #TOM002
#SUBJECT=14.08.06-15:07:12-DST-1.3.12.2.1107.5.2.32.35439 #TOM003 - make sure to get entire subject
#SUBJECT=14.08.19-11:16:47-DST-1.3.12.2.1107.5.2.32.35439 #TOM004
#SUBJECT=14.09.04-17:58:42-DST-1.3.12.2.1107.5.2.32.35439 #TOM005 
#SUBJECT=14.09.16-10:41:54-DST-1.3.12.2.1107.5.2.32.35439 #TOM006 
#SUBJECT=14.10.01-18:40:00-DST-1.3.12.2.1107.5.2.32.35439 # TOM007
#SUBJECT=14.10.07-15:28:08-DST-1.3.12.2.1107.5.2.32.35439 #TOM008
#SUBJECT=14.10.07-17:49:24-DST-1.3.12.2.1107.5.2.32.35439 #TOM009
#SUBJECT=14.10.18-10:59:57-DST-1.3.12.2.1107.5.2.32.35439 #TOM0010
#SUBJECT=14.10.18-15:10:57-DST-1.3.12.2.1107.5.2.32.35439 #TOM0011
#SUBJECT=14.10.19-14:57:39-DST-1.3.12.2.1107.5.2.32.35439 #TOM0012
#SUBJECT='14.10.23-10:59:24-DST-1.3.12.2.1107.5.2.32.35439' #TOM0013
#SUBJECT=14.11.01-12:01:47-DST-1.3.12.2.1107.5.2.32.35439 #TOM0014
SUBJECT=ARSA1001_22_06_02-10_59_23-DST-1_3_12_2_1107_5_2_32_35439 #ARSA1001
#SUBJECT=14.11.09-12:19:46-STD-1.3.12.2.1107.5.2.32.35439 #TOM016
#SUBJECT=14.11.11-15:45:17-STD-1.3.12.2.1107.5.2.32.35439 #TOM017
#SUBJECT=14.11.16-11:13:57-STD-1.3.12.2.1107.5.2.32.35439 #TOM018
#SUBJECT=15.01.28-17:51:51-STD-1.3.12.2.1107.5.2.32.35439 #TOM019
#SUBJECT=15.02.25-10:25:02-STD-1.3.12.2.1107.5.2.32.35439 #TOM021
#SUBJECT=15.02.27-12:48:04-STD-1.3.12.2.1107.5.2.32.35439 #TOM022

cd /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1001/$SUBJECT/ARSA/
NAME=`ls ARSA*`

## code below should not need to be changed. 
echo $PWD '======='$NAME'============'


#parse the dicoms; #make a note of what dcm names the file and replace the 20
for i in T1_MPR_CC_0002; do
cd ${i}
rm *.nii.gz
dcm2niiX -z y *.IMA
cp *.nii.gz anat.nii.gz
cd ../
done

#for i in 003-hyperscanEpi2d 004-hyperscanEpi2d 005-hyperscanEpi2d 006-hyperscanEpi2d; make sure the hyperscan name matches; do adjusted to new dci2nii
for i in HYPERSCANEPI2D_0003; do

cd ${i}
rm *.nii.gz
dcm2niix -z y *.IMA
cp *.nii.gz f.nii.gz
cd ..
done

#move the nifti file to the data directories
anat
mkdir -p $STUDY_DIR/anat/$NAME/
cp /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1001/$SUBJECT/ARSA/T1_MPR_CC_0002/anat.nii.gz $STUDY_DIR/anat/$NAME/
done 

func
for i in HYPERSCANEPI2D_0003; do
mkdir -p $STUDY_DIR/func/$NAME/$i/
cp /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Data/Scan/ARSA1001/$SUBJECT/ARSA/$i/f.nii.gz $STUDY_DIR/func/$NAME/$i/
done

#run qa for functional data
#for i in HYPERSCANEPI2D_0003; do
#for i in hyperscanEpi2d-0003; do

#cd $STUDY_DIR/func/$NAME/$i/
#fslwrapbxh f.nii.gz
#fmriqa_generate.pl --overwrite --verbose f.bxh $STUDY_DIR/func/$NAME/$i/
#mkdir -p /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Analysis/qa/raw/$NAME/run${i}/
#mv $STUDY_DIR/func/$NAME/run${i}/QA/* /Users/Corinne/Desktop/Research/Active_Projects/Dissertation/Analysis/qa/raw/$NAME/run${i}/
#rmdir $STUDY_DIR/func/$NAME/run${i}/QA/
#done








