#!/bin/bash
set -euo pipefail

function allFilesExist(){
    # Checks that all files in given array exist
    path_array=("$@")
    for file_path in "${path_array[@]}";
    do
        if [ ! -f $file_path ]
        then
            return 1
        fi
    done
    return 0
}

function fslAnat(){
   # change into input directory ${temp_dir}/input
   cd ${temp_dir}/input

   # if all output files exist, skip rest of function
   anat_dir=${temp_dir}/input/t1-mni.anat/
   output_files=(
    "${anat_dir}"/T1_biascorr_brain.nii.gz
    "${anat_dir}"/T1_biascorr.nii.gz
    "${anat_dir}"/T1_fast_pve_0.nii.gz
    "${anat_dir}"/MNI_to_T1_nonlin_field.nii.gz
    "${anat_dir}"/T1.nii.gz
    "${anat_dir}"/T1_fullfov.nii.gz
    "${anat_dir}"/T1_to_MNI_lin.mat
    "${anat_dir}"/T1_to_MNI_nonlin_coeff.nii.gz
    "${anat_dir}"/T1_roi2nonroi.mat
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping fsl_anat as output already exists"
        return
   fi

   # run FSL's fsl_anat tool on the input T1 image, with outputs
   # saved to a new subdirectory ${temp_dir}/input/t1-mni.anat
   echo running fsl_anat on t1 in ${anat_dir}
   # flags this will stop fsl_anat going through unnecessary steps and generating outputs we don’t use.
   fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz --nosubcortseg --clobber

   echo "fsl_anat done"
   echo
}

function flairPrep(){
   # create new subdirectory to pre-process input FLAIR image, change
   # into it ${temp_dir}/input/flair-bet
   flair_dir=${temp_dir}/input/flair-bet
   mkdir -p ${flair_dir}
   cd ${flair_dir}

   # if all output files exist, skip rest of function
   output_files=(
    "${flair_dir}"/flairvol_brain.nii.gz
    "${flair_dir}"/flairbrain2t1brain_inv.mat
    "${flair_dir}"/flairvol2t1brain.nii.gz
    "${flair_dir}"/flairvol.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping flair prep as output already exists"
        return
   fi

   # run FSL's tools on input FLAIR image to ensure mni orientation followed by brain extraction
   echo preparing flair in ${flair_dir}
   fslreorient2std -m flair_orig2std.mat ../flairvol_orig.nii.gz flairvol
   bet flairvol.nii.gz flairvol_brain -m -R -S -B -Z -v

   # run FSL's flirt tool to register/align FLAIR brain with T1 brain
   flirt -in flairvol_brain.nii.gz -omat flairbrain2t1brain.mat \
     -out flairbrain2t1brain \
     -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
     -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz

   # run FSL's flirt tool to transform/align input FLAIR image (whole head) with T1 brain
   flirt -in flairvol.nii.gz -applyxfm -init flairbrain2t1brain.mat \
     -out flairvol2t1brain \
     -paddingsize 0.0 -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz

   # run FSL's convert_xfm to invert FLAIR to T1 transformation matrix
   convert_xfm -omat flairbrain2t1brain_inv.mat -inverse flairbrain2t1brain.mat
   echo "flair prep done"
   echo
}

function ventDistMapping(){
   # create new subdirectory to create distance map from ventricles in order to determine periventricular vs deep white matter,
   # change into it ${temp_dir}/input/vent_dist_mapping
   vent_dir=${temp_dir}/input/vent_dist_mapping
   mkdir -p ${vent_dir}
   cd ${vent_dir}

   # if all output files exist, skip rest of function
   output_files=(
    "${vent_dir}"/perivent_t1brain.nii.gz
    "${vent_dir}"/dwm_t1brain.nii.gz
    "${vent_dir}"/perivent_flairbrain.nii.gz
    "${vent_dir}"/dwm_flairbrain.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping ventricle distance mapping as output already exists"
        return
   fi

   # copy required images and transformation/warp coefficients from ${temp_dir}/input/t1-mni.anat here
   cp ../t1-mni.anat/T1_biascorr.nii.gz .
   cp ../t1-mni.anat/T1_biascorr_brain.nii.gz .
   cp ../t1-mni.anat/T1_fast_pve_0.nii.gz .
   cp ../t1-mni.anat/MNI_to_T1_nonlin_field.nii.gz .
   cp ../flair-bet/flairvol_brain.nii.gz .
   cp ../flair-bet/flairbrain2t1brain_inv.mat .

   # run FSL's make_bianca_mask tool to create binary masks of the ventricles (ventmask) and white matter (bianca_mask)
   make_bianca_mask T1_biascorr.nii.gz T1_fast_pve_0.nii.gz MNI_to_T1_nonlin_field.nii.gz

   # run FSL's flirt tool to transform/align ventmask and bianca_mask with FLAIR brain
   flirt -in T1_biascorr_bianca_mask.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat -out biancamask_trans2_flairbrain -paddingsize 0.0 -interp nearestneighbour -ref flairvol_brain.nii.gz
   flirt -in T1_biascorr_ventmask.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat -out ventmask_trans2_flairbrain -paddingsize 0.0 -interp nearestneighbour -ref flairvol_brain.nii.gz

   # run FSL's distancemap tool to create maps of the distance of every white matter voxel from the edge of the ventricles,
   # in the T1 and FLAIR brains respectively
   distancemap --in=T1_biascorr_ventmask.nii.gz --out=dist_from_vent_t1brain -v
   distancemap --in=ventmask_trans2_flairbrain.nii.gz --out=dist_from_vent_flairbrain -v

   # run FSL's fslmaths tool to threshold the distance-from-ventricles maps to give perivantricular vs deep white matter masks
   fslmaths dist_from_vent_t1brain -uthr 10 -mas T1_biascorr_bianca_mask -bin perivent_t1brain
   fslmaths dist_from_vent_t1brain -thr 10 -mas T1_biascorr_bianca_mask -bin dwm_t1brain
   fslmaths dist_from_vent_flairbrain -uthr 10 -mas biancamask_trans2_flairbrain -bin perivent_flairbrain
   fslmaths dist_from_vent_flairbrain -thr 10 -mas biancamask_trans2_flairbrain -bin dwm_flairbrain

   echo "ventricle distance mapping done"
   echo
}

function prepImagesForUnet(){
   # change one directory up to ${temp_dir}/input
   cd ${temp_dir}/input

   # if all output files exist, skip rest of function
   output_files=(
    "${temp_dir}"/input/T1.nii.gz
    "${temp_dir}"/input/FLAIR.nii.gz
    "${temp_dir}"/input/T1_croppedmore2roi.mat
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping UNets-pgs prep as output already exists"
        return
   fi

   # run FSL's fslroi tool to crop correctly-oriented T1 and co-registered FLAIR, ready for UNets-pgs
   # Only crop if dim1 or dim2 are >= 500
   t1size=( $(fslsize ./t1-mni.anat/T1.nii.gz) )
   if [ ${t1size[1]} -ge 500 ] || [ ${t1size[3]} -ge 500 ]
   then
       fslroi ./t1-mni.anat/T1.nii.gz                     T1    20 472 8 496 0 -1
       fslroi ./flair-bet/flairvol2t1brain.nii.gz         FLAIR 20 472 8 496 0 -1
   else
       cp ./t1-mni.anat/T1.nii.gz                     T1.nii.gz
       cp ./flair-bet/flairvol2t1brain.nii.gz         FLAIR.nii.gz
   fi

   # run FSL's flirt tool to register/align cropped T1 with full-fov T1
   flirt -in T1.nii.gz -omat T1_croppedmore2roi.mat \
     -out T1_croppedmore2roi \
     -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
     -interp trilinear -ref ./t1-mni.anat/T1.nii.gz

  echo "Images prepared for UNets-pgs"
  echo
}

function unetsPgs(){
   # change one directory up to ${temp_dir}
   cd ${temp_dir}

   # if all output files exist, skip rest of function
   output_files=(
    "${temp_dir}"/output/results.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping UNets-pgs as output already exists"
        return
   fi

   # run UNets-pgs in Singularity
   echo running UNets-pgs Singularity in ${temp_dir}

   /WMHs_segmentation_PGS.sh T1.nii.gz FLAIR.nii.gz results.nii.gz ./input ./output

   echo UNets-pgs done!
   echo
}

function processOutputs(){
   # change into output directory ${temp_dir}/output
   cd ${temp_dir}/output

   # if all output files exist, skip rest of function
   output_files=(
    "${data_outpath}"/output/results2mni_lin_deep.nii.gz
    "${data_outpath}"/output/results2mni_lin.nii.gz
    "${data_outpath}"/output/results2mni_lin_perivent.nii.gz
    "${data_outpath}"/output/results2mni_nonlin.nii.gz
    "${data_outpath}"/output/results2mni_nonlin_deep.nii.gz
    "${data_outpath}"/output/results2mni_nonlin_perivent.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping processing outputs as output already exists"
        return
   fi

   echo processing outputs in ${temp_dir}/output/

   echo "copy required images"
   # copy required images and transformation/warp coefficients from ${temp_dir}/input here, renaming T1 and FLAIR
   cp ${temp_dir}/input/T1_croppedmore2roi.mat .
   cp ${temp_dir}/input/t1-mni.anat/T1.nii.gz T1_roi.nii.gz
   cp ${temp_dir}/input/t1-mni.anat/T1_fullfov.nii.gz .
   cp ${temp_dir}/input/t1-mni.anat/T1_to_MNI_lin.mat .
   cp ${temp_dir}/input/t1-mni.anat/T1_to_MNI_nonlin_coeff.nii.gz .
   cp ${temp_dir}/input/t1-mni.anat/T1_roi2nonroi.mat .
   cp ${temp_dir}/input/flair-bet/flairbrain2t1brain_inv.mat .
   cp ${temp_dir}/input/flair-bet/flairvol.nii.gz FLAIR_orig.nii.gz
   cp ${temp_dir}/input/vent_dist_mapping/perivent_t1brain.nii.gz .
   cp ${temp_dir}/input/vent_dist_mapping/dwm_t1brain.nii.gz .
   cp ${temp_dir}/input/vent_dist_mapping/perivent_flairbrain.nii.gz .
   cp ${temp_dir}/input/vent_dist_mapping/dwm_flairbrain.nii.gz .


   tree ${temp_dir}/input/

   # copy MNI T1 template images here
   cp ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz .
   cp ${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz .

   echo "STEP 01"
   # run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with roi-cropped T1
   flirt -in results.nii.gz -applyxfm -init T1_croppedmore2roi.mat \
     -out results2t1roi \
     -paddingsize 0.0 -interp nearestneighbour -ref T1_roi.nii.gz

   echo "STEP 02"
   # run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with full-fov T1
   flirt -in results2t1roi.nii.gz -applyxfm -init T1_roi2nonroi.mat \
     -out results2t1fullfov \
     -paddingsize 0.0 -interp nearestneighbour -ref T1_fullfov.nii.gz

   echo "STEP 03"
   # run FSL's flirt tool to transform/align WML segmentations with full-fov FLAIR
   flirt -in results2t1roi.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat \
     -out results2flairfullfov \
     -paddingsize 0.0 -interp nearestneighbour -ref FLAIR_orig.nii.gz

   # run FSL's fslmaths tool to divide WML segmentations from UNets-pgs into periventricular and deep white matter
   fslmaths results2t1roi.nii.gz -mul perivent_t1brain.nii.gz results2t1roi_perivent
   fslmaths results2t1roi.nii.gz -mul dwm_t1brain.nii.gz results2t1roi_deep
   fslmaths results2flairfullfov.nii.gz -mul perivent_flairbrain.nii.gz results2flairfullfov_perivent
   fslmaths results2flairfullfov.nii.gz -mul dwm_flairbrain.nii.gz results2flairfullfov_deep


   echo "STEP 04"
   # run FSL's flirt tool to linearly transform/align WML segmentations with MNI T1
   flirt -in results2t1roi.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz

   flirt -in results2t1roi_perivent.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin_perivent \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz

   flirt -in results2t1roi_deep.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin_deep \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz


   echo "STEP 05"
   # run FSL's applywarp tool to nonlinearly warp WML segmentations with MNI T1
   applywarp --in=results2t1roi.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin \
          --interp=nn --ref=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz

   applywarp --in=results2t1roi_perivent.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin_perivent \
          --interp=nn --ref=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz

   applywarp --in=results2t1roi_deep.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin_deep \
          --interp=nn --ref=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz


   # copy all contents of temporary data directory to output data directory, and delete temporary data directory
   echo copying all contents
   echo  from ${temp_dir}
   echo  to ${data_outpath}
   cp -r ${temp_dir}/* ${data_outpath}
   # echo deleting ${temp_dir}
   # rm -r ${temp_dir}

   echo all done!
   echo
}

function runAnalysis (){
   # set options are lost when running this function in parallel
   # so set them again here
   set -euo pipefail

   subjid=$1
   echo subjid : ${subjid}
   echo

   # search full paths and filenames for input T1 and FLAIR images in compressed NIfTI format
   t1_fn=$(find ${data_path}/${subjid}/niftis/*[Tt]1*.nii.gz)
   flair_fn=$(find ${data_path}/${subjid}/niftis/*[Ff][Ll][Aa][Ii][Rr]*.nii.gz)
   echo t1_fn    : ${t1_fn}
   echo flair_fn : ${flair_fn}
   echo

   # assign path for output data directory and create it (if it doesn't exist)
   export data_outpath=${data_path}/UNet-pgs/${subjid}
   mkdir -p ${data_outpath}
   echo data_outpath : ${data_outpath}

   # REL # Why under code dir?
   # assign path for a temporary data directory under the code directory and create it
   export temp_dir=${code_dir}/Controls+PD/${subjid}
   mkdir -p ${temp_dir}
   echo temp_dir     : ${temp_dir}
   echo

   # change into temporary data directory and create input and output subdirectories
   # directories are required by flair
   cd ${temp_dir}
   mkdir -p ${temp_dir}/input
   mkdir -p ${temp_dir}/output

   # change into input directory ${temp_dir}/input
   # flirt expects to be ran in the same dir (maybe able to do this
   # outside of dir, but paths would be long)
   cd ${temp_dir}/input

   # copy input T1 and FLAIR images here, renaming them
   # files need to be renamed otherwise overwritten when fslroi is called.
   # also need to keep original file for flirt command
   cp ${t1_fn}    t1vol_orig.nii.gz
   cp ${flair_fn} flairvol_orig.nii.gz

   fslAnat
   flairPrep
   ventDistMapping
   prepImagesForUnet
   unetsPgs
   processOutputs

   # change to ${data_outpath}
   cd ${data_outpath}

   zip -q ${subjid}_results.zip ./output/results2mni_lin*.nii.gz ./output/results2mni_nonlin*.nii.gz

   echo =====================================================
   echo please send this zip file to the ENIGMA-PD-Vasc team!
   echo  ${data_outpath}/${subjid}_results.zip
   echo =====================================================
   echo
   echo Thank you!
   echo
}

function setupRunAnalysis(){
  echo code_dir  : ${code_dir}
  echo data_path : ${data_path}
  echo

  # FSL Setup
  FSLDIR=/usr/local/fsl
  PATH=${FSLDIR}/share/fsl/bin:${PATH}
  export FSLDIR PATH
  . ${FSLDIR}/etc/fslconf/fsl.sh

  # Create dir to hold subject logs
  subject_logs_dir=${code_dir}/subject_logs
  mkdir -p $subject_logs_dir

  # assign path and filename of the list of subject IDs saved as a text file
  subjids_list=${data_path}/subjects.txt
  echo subjids_list : ${subjids_list}

  n=1
  export overwrite=false
  while getopts "n:o" opt; do
    case ${opt} in
      n)
        # Read -n argument, to give number of jobs to use for parallel processing
        # If n=1 (or isn't specified), run sequentially
        n=${OPTARG}
        ;;
      o)
        # Read overwrite option. If true, all pipeline steps will be run (even if their output already exists)
        echo "overwrite option enabled"
        overwrite=true
        ;;
      ?)
        echo "Invalid option: -${OPTARG}."
        exit 1
        ;;
    esac
  done

  if [[ $n -eq 1 ]]
  then
    echo "Running sequentially on 1 core"
    for subjid in $(cat ${subjids_list});
    do
      echo "Processing subject with id ${subjid}"
      runAnalysis $subjid > $subject_logs_dir/${subjid}-log.txt 2>&1
    done
  else
    echo "Running in parallel with ${n} jobs"
    export -f runAnalysis fslAnat flairPrep ventDistMapping prepImagesForUnet unetsPgs processOutputs allFilesExist
    cat ${subjids_list} | parallel --jobs ${n} runAnalysis {} ">" ${subject_logs_dir}/{}-log.txt "2>&1"
  fi
}

# assign paths for code and input data directories, as well as overall log file
export code_dir=/code
export data_path=/data
overall_log=${code_dir}/overall_log.txt

echo "Running analysis script"
echo "See overall log at /code/overall_log.txt and subject logs at /code/subject_logs/"
setupRunAnalysis "$@" >> $overall_log 2>&1
