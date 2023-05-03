"""
FER Pipeline (Nipype 0.7)
- Level 1 in subject's own functional space
- Coregister output to freesurfer anatomy
- SPM normalization or ANTS

Created:		09-17-2013	# based on Domain pipeline script (J.Richey)
Code Revised:	8-31-2022	# update to run ARSA subjects (C. Carlton)
"""

import os                                    # system functions
import nipype.algorithms.modelgen as model   # model generation
import nipype.algorithms.rapidart as ra      # artifact detection
import nipype.interfaces.freesurfer as fs    # freesurfer
import nipype.interfaces.fsl as fsl          # fsl
import nipype.interfaces.io as nio           # i/o routines
import nipype.interfaces.matlab as mlab      # how to run matlab
import nipype.interfaces.spm as spm          # spm
import nipype.interfaces.utility as util     # utility
import nipype.pipeline.engine as pe          # pypeline engine
from nipype.utils.filemanip import *	 # some useful stuff for debugging
from nipype.interfaces.ants import WarpImageMultiTransform
import scipy.io as sio
import numpy as np
from nipype.interfaces.base import Bunch
from copy import deepcopy
import sys
import nipype.interfaces

#uncomment to turn on verbose logging for debugging
from nipype import config, logging
config.enable_debug_mode()
logging.update_logging(config)

###### CONFIGURABLE INPUTS ######

#note that this pipeline assumes that the output of recon_all is in ./Analysis/nipype/
experiment 	='ARSA.01'
runs 		=['run1']
numberofruns	= 1
study_TR 	= 2.000
test_type 	= 'T'  		# "T" / "F"
normalize	='ANTS'		# dartel / SPM_normalize / ANTS
datasink	='off' 		#on / off 
T1_identifier 	='anat.nii.gz'
ANTS_template  = '/Users/scanlab_user/Desktop/ARSA.01/Analysis/ANTS/MNI_152_1mm_brain.nii.gz'
#note that for local (not global) paths, these will have to be explicitly pointing to the file and cannot use string objects as I did above. 
#changed path to local lab computer 8.31.22

subjects_list = [
  					'ARSA1001',
 				]


def get_events(subject_id):
	
	
	event_1		= '/Users/scanlab_user/Desktop/ARSA.01/Data/behav/antic.run001.txt' 
	event_2		= '/Users/scanlab_user/Desktop/ARSA.01/Data/behav/outcome_general.run001.txt' 
# 	event_3		= path2events+'/%(MYSUBJECT)s/run2emrec2sec_2SEC_duration/disgust_cor.run001.txt'%{"MYSUBJECT":(subject_id)}
# 	event_4		= path2events+'/%(MYSUBJECT)s/run2emrec2sec_2SEC_duration/disgust_inc.run001.txt'%{"MYSUBJECT":(subject_id)}
# 	event_5		= path2events+'/%(MYSUBJECT)s/run2emrec2sec_2SEC_duration/anger_cor.run001.txt'%{"MYSUBJECT":(subject_id)}
# 	event_6		= path2events+'/%(MYSUBJECT)s/run2emrec2sec_2SEC_duration/anger_inc.run001.txt'%{"MYSUBJECT":(subject_id)}
# 	event_7		= path2events+'/%(MYSUBJECT)s/run2emrec2sec_2SEC_duration/fear_cor.run001.txt'%{"MYSUBJECT":(subject_id)}
# 	event_8		= path2events+'/%(MYSUBJECT)s/run2emrec2sec_2SEC_duration/fear_inc.run001.txt'%{"MYSUBJECT":(subject_id)}

			
	events		= 	[
			
			[
			
			event_1,
			event_2,
#			event_3,
#  			event_4,
#  			event_5,
#  			event_6,
#  			event_7,
#  			event_8,
#  			
			]
		
			

			]
	print (events)	
	return events

#################################


#from nipype.utils.config import config
#config.enable_debug_mode()

# Tell freesurfer what subjects directory to use
experiment_dir='/Users/scanlab_user/Desktop/ARSA.01'
subjects_dir = experiment_dir + '/Analysis/nipype/reconall/'
fs.FSCommand.set_default_subjects_dir(subjects_dir)
# Set the way matlab should be called
mlab.MatlabCommand.set_default_matlab_cmd("/Applications/MATLAB_R2016b.app/bin/matlab -nodesktop -nosplash")
#If SPM is not in your MATLAB path you should add it here
#commented out becuase spm is in my matlab
mlab.MatlabCommand.set_default_paths('/Users/scanlab_user/Desktop/ARSA.01/spm12/')
# Set up how FSL should write nifti files:
fsl.FSLCommand.set_default_output_type('NIFTI')


#initialize the pipeline
l1pipeline = pe.Workflow(name="l1pipeline")
l1pipeline.config['execution'] = {'job_finished_timeout':30}
l1pipeline.base_dir = os.path.abspath('/Users/scanlab_user/Desktop/ARSA.01/Analysis/nipype/')

# Map field names to individual subject runs.
infosource = pe.Node(

		interface=util.IdentityInterface(
		
			fields				= ['subject_id'],
			),
			iterables 			= [('subject_id', subjects_list)],
			name				= "infosource")



# DataGrabber node to get the input files for each subject
datasource = pe.Node(

		interface=nio.DataGrabber(
		
			infields			= ['subject_id'],
			outfields			= ['func', 'anat']),
			
				base_directory		= subjects_dir,
				name 			= 'datasource')

datasource.inputs.template_args				= dict(	func	= [[ 'subject_id', 'run' ]],
													anat	= [[ 'subject_id' ]],
												)
								
datasource.inputs.template				= '*'
#removes %s/%s from datasource on func
#adjusted hyperscanepi in path to be short subject num
datasource.inputs.field_template 		= dict(
													func 	= experiment_dir + '/Data/func/%s/%s/f.nii.gz',
													anat 	= experiment_dir + '/Data/anat/%s/anat_watershed.nii.gz',
								 				)
								 
#datasource.inputs.sorted 				= True
datasource.inputs.sort_filelist 		= True
datasource.inputs.run					= runs

#**************
l1pipeline.connect(infosource, 'subject_id',datasource,'subject_id' )
#**************

#Slice-Time Correction Node
slice_timing = pe.MapNode(

		interface=fsl.SliceTimer(
		
			interleaved				= True,
			time_repetition 		= study_TR,
			output_type 			= 'NIFTI',
			
			),
				iterfield		= ['in_file'],
				name			= "slice_timing")

#**************
l1pipeline.connect(datasource,'func',slice_timing,'in_file')
#**************


# Motion Correction Node
realign = pe.Node(
		
		interface=spm.Realign(
		
			register_to_mean 		= True),
		 
		 		name				="realign")

#**************
l1pipeline.connect(slice_timing,'slice_time_corrected_file',realign,'in_files')
#**************


#Artifact Detection Node
art = pe.Node(interface=ra.ArtifactDetect(

			use_differences     		= [True,False],
			use_norm           			= True,
			norm_threshold    			= 1.0,
			zintensity_threshold		= 3.0,
			mask_type           		= 'file',
			parameter_source    		= 'SPM',
		),
		 
		 				name			="art")

#**************
l1pipeline.connect(realign,'realignment_parameters',art,'realignment_parameters')
l1pipeline.connect(realign,'realigned_files',art,'realigned_files')
#**************


#Stimulus correlation quality control node:
stimcor = pe.Node(interface=ra.StimulusCorrelation(), name="stimcor")
stimcor.inputs.concatenated_design = False
#**************
l1pipeline.connect(art,'intensity_files',stimcor,'intensity_values')
l1pipeline.connect(realign,'realignment_parameters',stimcor,'realignment_parameters')
#**************


# run SPM's smoothing
volsmooth = pe.Node(interface=spm.Smooth(), name="volsmooth")
volsmooth.inputs.fwhm = [6,6,6]
#**************
l1pipeline.connect(realign,'realigned_files',volsmooth,'in_files')
#**************


# Coregister node for functional images to FreeSurfer surfaces
calcSurfReg = pe.Node(interface=fs.BBRegister(),name='calcSurfReg')
calcSurfReg.inputs.init = 'fsl'
calcSurfReg.inputs.contrast_type = 't2'
calcSurfReg.inputs.registered_file = True
#**************
l1pipeline.connect(infosource,'subject_id',calcSurfReg,'subject_id')
l1pipeline.connect(realign,'mean_image',calcSurfReg,'source_file')
#**************


# Apply surface coregistration to output t-maps
applySurfRegT = pe.MapNode(interface=fs.ApplyVolTransform(),name='applySurfRegT', iterfield = ['source_file'])
#**************
l1pipeline.connect(calcSurfReg,'out_reg_file',applySurfRegT,'reg_file')
l1pipeline.connect(calcSurfReg,'registered_file',applySurfRegT,'target_file')
#**************


# Apply surface coregistration to output contrast images
applySurfRegCon = pe.MapNode(interface=fs.ApplyVolTransform(),name='applySurfRegCon', iterfield = ['source_file'])
l1pipeline.connect(calcSurfReg,'out_reg_file',applySurfRegCon,'reg_file')
l1pipeline.connect(calcSurfReg,'registered_file',applySurfRegCon,'target_file')		


# Node to find Freesurfer data
FreeSurferSource = pe.Node(interface=nio.FreeSurferSource(), name='fssource')
FreeSurferSource.inputs.subjects_dir = os.path.abspath('/Users/scanlab_user/Desktop/ARSA.01/Analysis/nipype/reconall')

def get_aparc_aseg(files):
        for name in files:
            if 'aparc+aseg' in name:
                return name
        raise ValueError('aparc+aseg.mgz not found')

#**************
l1pipeline.connect(infosource,'subject_id',FreeSurferSource,'subject_id')
#**************


# Volume Transform (for making brain mask)
ApplyVolTransform = pe.Node(
			
			interface			=fs.ApplyVolTransform(),
			
				 name			='applyreg')
				 
ApplyVolTransform.inputs.inverse = True
#**************
l1pipeline.connect(realign,'mean_image',ApplyVolTransform,'source_file')
l1pipeline.connect(calcSurfReg,'out_reg_file',ApplyVolTransform,'reg_file')
l1pipeline.connect(FreeSurferSource, ('aparc_aseg', get_aparc_aseg),  ApplyVolTransform,'target_file')
#**************


# Threshold (for making brain mask)
Threshold = pe.Node(interface=fs.Binarize(dilate=1),name='threshold')
Threshold.inputs.min = 0.5
Threshold.inputs.out_type = 'nii'
#**************
l1pipeline.connect(Threshold,'binary_file',art, 'mask_file')
l1pipeline.connect(ApplyVolTransform,'transformed_file',Threshold,'in_file')
#**************



# Model Specification (NiPype) Node
modelspec = pe.Node(interface=model.SpecifyModel(), name="modelspec", overwrite=True)
modelspec.inputs.input_units = 'secs'
modelspec.inputs.time_repetition = study_TR
modelspec.inputs.high_pass_filter_cutoff = 160 #160 OR np.inf #inf because of linear / quad regressors - otherwise ~160
#**************
l1pipeline.connect(infosource, ('subject_id', get_events),modelspec,'event_files')
l1pipeline.connect(realign,'realignment_parameters',modelspec,'realignment_parameters')
l1pipeline.connect(volsmooth,'smoothed_files',modelspec,'functional_runs')
l1pipeline.connect(art,'outlier_files',modelspec,'outlier_files')
#**************


# Level 1 Design (SPM) Node
level1design = pe.Node(interface=spm.Level1Design(), name= "level1design")
level1design.inputs.timing_units = 'secs'
level1design.inputs.interscan_interval = modelspec.inputs.time_repetition
level1design.inputs.bases = {'hrf':{'derivs':[1,1]}}
#level1design.inputs.bases = {'gamma':{'length':[1],'order':[1]}}

level1design.inputs.model_serial_correlations = 'AR(1)' #'none'
#**************
l1pipeline.connect(modelspec,'session_info',level1design,'session_info')
l1pipeline.connect(Threshold,'binary_file',level1design,'mask_image')
l1pipeline.connect(level1design,'spm_mat_file',stimcor,'spm_mat_file')
#**************

#apply brain mask to functional run - useful for SVC prediction on run 2 later, but do not use this to create L1 contrasts
maskfunc = pe.Node(interface=fsl.ImageMaths(), name = 'maskfunc')
l1pipeline.connect(realign,'realigned_files', maskfunc,'in_file')
l1pipeline.connect(Threshold,'binary_file',maskfunc,'mask_file')

# Level 1 Estimation node
level1estimate = pe.Node(interface=spm.EstimateModel(), name="level1estimate")
level1estimate.inputs.estimation_method = {'Classical' : 1}
#**************
l1pipeline.connect(level1design,'spm_mat_file',level1estimate,'spm_mat_file')
#**************


# Constrast Estimation node
contrastestimate = pe.Node(

		interface		 	= spm.EstimateContrast(),
			
				name		="contrastestimate")

contrast1 = ('contrast1',	'T', 			['antic'],								[1]	)
contrast2 = ('contrast2',	'T', 			['outcome_general'],					[1]	)
contrast3 = ('contrast3',	'T', 			['antic','outcome_general'], 			[1,-1] 	)	
contrast4 = ('contrast4',	'T', 			['antic','outcome_general'],  			[-1,1] 	)	
contrast5 = ('contrast5',   'T', 			['antic','outcome_general'], 			[0.5,0.5])

# if test_type == "T":
# 	
# 	
contrasts =   [	
	
 			contrast1,
 			contrast2,
 			contrast3,
 			contrast4
 			
 			]	
# # 			contrast5,
# #  			contrast6,
# #            contrast7,
# #            contrast8,
# #            contrast9,
# #            contrast10
# 			]

# if test_type == "F":
# 	contrasts = [contrast41,contrast42,contrast43,contrast44,contrast45,contrast46,maineffect_emotion, maineffect_validity,int1,int2]

contrastestimate.inputs.contrasts 		=  contrasts

#**************
l1pipeline.connect(level1estimate,'spm_mat_file',contrastestimate,'spm_mat_file')
l1pipeline.connect(level1estimate,'beta_images',contrastestimate,'beta_images')
l1pipeline.connect(level1estimate,'residual_image',contrastestimate,'residual_image')
#**************


# Have a node that converts spm TSTAT IMG files to NIFTI files so FreeSurfer doesn't have a stupid header error.
makeImgNiiT = pe.MapNode(interface=fs.MRIConvert(),name='makeImgNiiT', iterfield=['in_file'])
makeImgNiiT.inputs.in_type = 'analyze'
makeImgNiiT.inputs.out_type = 'nii'

# Have a node that converts spm CON (i.e. cope) IMG files to NIFTI files so FreeSurfer doesn't have a stupid header error.
makeImgNiiCon = pe.MapNode(interface=fs.MRIConvert(),name='makeImgNiiCon', iterfield=['in_file'])
makeImgNiiCon.inputs.in_type = 'analyze'
makeImgNiiCon.inputs.out_type = 'nii'	

if normalize == 'SPM_normalize':

	template='/Users/scanlab_user/Desktop/Other/packages/fsl/data/standard/T1.nii'
	
	normalize_T = pe.MapNode(
		
			interface			=spm.Normalize(
			
				template		=template,
					),
					
					iterfield	= ['source'],
					name		='normalize_T')
					
	
	normalize_cons = pe.MapNode(
		
			interface			=spm.Normalize(
			
				template		=template,
					),
					
					iterfield	= ['source'],
					name		='normalize_con')
						


	#**************
	l1pipeline.connect(contrastestimate,'spmT_images',normalize_T,'source')
	l1pipeline.connect(contrastestimate,'con_images',normalize_cons,'source')
	l1pipeline.connect(normalize_T,'normalized_source',makeImgNiiT,'in_file')
	l1pipeline.connect(normalize_cons,'normalized_source',makeImgNiiCon,'in_file')
	l1pipeline.connect(makeImgNiiCon,'out_file',applySurfRegCon,'source_file')
	l1pipeline.connect(makeImgNiiT,'out_file',applySurfRegT,'source_file')
	#**************

if normalize == 'ANTS':
	
	def get_transformation_series(subject_id):
	
		image					= '/Users/scanlab_user/Desktop/ARSA.01/Analysis/ANTS/ARSA1001_ANAT_WATERSHEDWarp.nii.gz' 
		affline 				= '/Users/scanlab_user/Desktop/ARSA.01/Analysis/ANTS/ARSA1001_ANAT_WATERSHEDAffine.txt' 
		warpfiles 				= [image,affline]
		print ("WARPING",warpfiles)
		return warpfiles
	
	#warp to ANTS Template
	warp_T = pe.MapNode(
		interface 				= WarpImageMultiTransform(
		
			reference_image 		= '/Users/scanlab_user/Desktop/ARSA.01/Analysis/ANTS/MNI152_T1_1mm_brain.nii.gz',
				),
				
				iterfield 		= ['input_image'],
				name			= "warp_T")

	warp_con = pe.MapNode(
		interface 				= WarpImageMultiTransform(
		
			reference_image 		= '/Users/scanlab_user/Desktop/ARSA.01/Analysis/ANTS/MNI152_T1_1mm_brain.nii.gz',
				),
				
				iterfield 		= ['input_image'],
				name			= "warp_con")
	#**************
	#get transformation series
	l1pipeline.connect([
		
		(infosource, warp_T,[(('subject_id', get_transformation_series),'transformation_series')]),
		(infosource, warp_con,[(('subject_id', get_transformation_series),'transformation_series')]),
			])
	
	l1pipeline.connect(contrastestimate,'spmT_images',makeImgNiiT,'in_file')
	l1pipeline.connect(contrastestimate,'con_images',makeImgNiiCon,'in_file')
	l1pipeline.connect(makeImgNiiT,'out_file',applySurfRegT,'source_file')		
	l1pipeline.connect(makeImgNiiCon,'out_file',applySurfRegCon,'source_file')
	l1pipeline.connect(applySurfRegT,'transformed_file',warp_T,'input_image')
	l1pipeline.connect(applySurfRegCon,'transformed_file',warp_con,'input_image')
	#**************

	#if test_type == "T":
	#	l1pipeline.connect(contrastestimate,'spmT_images',warp_T,'moving_image')
	#if test_type is "F":
		#l1pipeline.connect(contrastestimate,'spmF_images',warp_T,'moving_image') # if using F images
	#l1pipeline.connect(contrastestimate,'con_images',warp_con,'moving_image')
	#l1pipeline.connect(warp_T,'output_image',makeImgNiiT,'in_file')
	#l1pipeline.connect(warp_con,'output_image',makeImgNiiCon,'in_file')
	#l1pipeline.connect(makeImgNiiCon,'out_file',applySurfRegCon,'source_file')
	#l1pipeline.connect(makeImgNiiT,'out_file',applySurfRegT,'source_file')			
	##**************


# HANDY, IN CASE YOU NEED .IMG FILES. Have a node that converts .nii BACK TO spm TSTAT IMG files so that spm_crossvalidation will run later.
# makeNiiImgT = pe.MapNode(interface=fs.MRIConvert(),name='makeNiiImgT', iterfield=['in_file'])
# makeNiiImgT.inputs.in_type = 'nifti1'
# makeNiiImgT.inputs.out_type = 'nii'
# 
# # HANDY, IN CASE YOU NEED .IMG FILES. Have a node that converts .nii BACK TO spm con IMG files so that spm_crossvalidation will run later.
# makeNiiImgCon = pe.MapNode(interface=fs.MRIConvert(),name='makeNiiImgCon', iterfield=['in_file'])
# makeNiiImgCon.inputs.in_type = 'nifti1'
# makeNiiImgCon.inputs.out_type = 'nii'

#**************
#l1pipeline.connect(warp_T,'output_image',makeNiiImgT,'in_file' )
#l1pipeline.connect(warp_con,'output_image',makeNiiImgCon, 'in_file' )
#**************


# Datasink node for saving output of the pipeline
datasink = pe.Node(

		interface			=nio.DataSink(
		
			base_directory 		= os.path.abspath('/Users/scanlab_user/Desktop/Analysis/nipype/l1output_2022/'),),
		
				name		="datasink")
				
				

def getsubs(subject_id,contrast_list):
	subs = [('_subject_id_%s/'%subject_id,'')]
	for i in range(len(contrast_list),0,-1):
		subs.append(('_applySurfRegCon%d/'%(i-1),''))
		subs.append(('_applySurfRegT%d/'%(i-1),''))
		subs.append(('_applySurfRegVar%d/'%(i-1),''))
		subs.append(('con_%04d_out_maths_warped'%(i),'var_%04d_out_warped'%(i)))
	return subs


#connections for the datasink
if datasink == 'on': 
	l1pipeline.connect([
	(infosource,datasink,[('subject_id','container'),
						
						(
						
						('subject_id',getsubs,contrastestimate.inputs.contrasts),'substitutions')]),
						(FreeSurferSource,datasink,[('brain','subj_anat.@brain')]),
						(realign,datasink,[('mean_image','subj_anat.@mean')]),
						(calcSurfReg,datasink,[('out_reg_file','surfreg'),
												('min_cost_file','qc_bbreg'),
												('registered_file','subj_anat.@reg_mean')]),
						(warp_T,datasink,[('output_image','reg_cons')]),
						(warp_con,datasink,[('output_image','reg_cons')]),
						(level1estimate,datasink,[
													('spm_mat_file','model.@spm'),
													('mask_image','model.@mask'),
													('residual_image','model.@res'),
													('RPVimage','model.@rpv')]),
						(art,datasink,[('outlier_files','qc_art.@outliers'),
										('plot_files','qc_art.@motionplots'),
										('statistic_files','qc_art.@statfiles'),
										]),
						(stimcor,datasink,[('stimcorr_files','qc_stimcor')]),
						])


#l1pipeline.write_graph()
l1pipeline.run()#plugin='MultiProc', plugin_args={'n_procs' : 2})#plugin='PBS',plugin_args={'qsub_args':qsubargs})