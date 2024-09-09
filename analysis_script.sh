#!/bin/bash
set -euo pipefail

function setupRunAnalysis(){
  echo code_dir  : ${code_dir}
  echo data_path : ${data_path}
  echo

  # FSL Setup
  FSLDIR=/usr/local/fsl
  PATH=${FSLDIR}/share/fsl/bin:${PATH}
  export FSLDIR PATH
  . ${FSLDIR}/etc/fslconf/fsl.sh

  # Create dir to hold sample logs
  sample_logs_dir=${code_dir}/sample_logs
  mkdir -p $sample_logs_dir

  # assign path and filename of the list of subject IDs saved as a text file
  subjids_list=${data_path}/subjects.txt
  echo subjids_list : ${subjids_list}

  n=1
  overwrite=false
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

  args=(-c "${code_dir}" -d "${data_path}")
  ${overwrite} && args+=( '-o' )

  if [[ $n -eq 1 ]]
  then
    echo "Running sequentially on 1 core"
    for subjid in $(cat ${subjids_list});
    do
      echo "Processing sample with id ${subjid}"
      /analysis_run.sh -s ${subjid} "${args[@]}" > $sample_logs_dir/${subjid}-log.txt 2>&1
    done
  else
    echo "Running in parallel with ${n} jobs"
    cat ${subjids_list} | parallel --jobs ${n} /analysis_run.sh -s {} "${args[@]}" ">" ${sample_logs_dir}/{}-log.txt "2>&1"
  fi
}

# assign paths for code and input data directories, as well as overall log file
code_dir=/code
data_path=/data
overall_log=${code_dir}/overall_log.txt

echo "Running analysis script"
echo "See overall log at /code/overall_log.txt and sample logs at /code/sample_logs/"
setupRunAnalysis "$@" >> $overall_log 2>&1
