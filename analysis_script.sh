#!/bin/bash
set -euxo pipefail

# assign paths for code and input data directories, as well as overall log file
code_dir=/code
data_path=/data
overall_log=${code_dir}/overall_log.txt

echo code_dir  : ${code_dir} >> $overall_log 2>&1
echo data_path : ${data_path} >> $overall_log 2>&1
echo   >> $overall_log 2>&1

# FSL Setup
FSLDIR=/usr/local/fsl
PATH=${FSLDIR}/share/fsl/bin:${PATH}
export FSLDIR PATH
. ${FSLDIR}/etc/fslconf/fsl.sh

# Create dir to hold sample logs
sample_logs_dir=${code_dir}/sample_logs
mkdir -p $sample_logs_dir >> $overall_log 2>&1

# assign path and filename of the list of subject IDs saved as a text file
subjids_list=${data_path}/subjects.txt
echo subjids_list : ${subjids_list} >> $overall_log 2>&1

# Read -n argument, to give number of jobs to use for parallel processing
# If n=1 (or isn't specified), run sequentially
n=1
while getopts "n:" opt; do
  case ${opt} in
    n)
      n=${OPTARG}
      ;;
    ?)
      echo "Invalid option: -${OPTARG}." >> $overall_log 2>&1
      exit 1
      ;;
  esac
done

if [[ $n -eq 1 ]]
then
  echo "Running sequentially on 1 core"  >> $overall_log 2>&1
  for subjid in $(cat ${subjids_list});
  do
    echo "Processing sample with id ${subjid}" >> $overall_log 2>&1
    /analysis_run.sh $subjid $code_dir $data_path > $sample_logs_dir/$subjid-log.txt 2>&1
  done
else
  echo "Running in parallel with ${n} jobs"  >> $overall_log 2>&1
  cat ${subjids_list} | parallel --jobs ${n} /analysis_run.sh {} $code_dir $data_path ">" $sample_logs_dir/{}-log.txt "2>&1"
fi
