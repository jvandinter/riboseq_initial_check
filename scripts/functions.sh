#!/bin/bash

function get_samples() {

    # Retrieves sample data from a project data folder, validates file format,
    # and extracts sample IDs from fastq files.

  project_data_folder=$1
  data_folder=$2
  paired_end=${3:-false}
  
  # Check whether the files are in correct format
  if [[ $(ls ${project_data_folder}/*.fastq.gz | wc -l) -eq 0 ]]; then
    fatal "No .fastq.gz files found in ${project_data_folder}"
  else
    # Find unique R1 filenames and get corresponding R1/R2 fastq files
    r1_files=()
    readarray -t r1_filenames < <(find "${project_data_folder}" -maxdepth 1 -name "*fastq.gz" -printf '%f\n' | sort -u)
      for r1_filename in "${r1_filenames[@]}"; do
        if [[ -L "${project_data_folder}/${r1_filename}" ]]; then
            r1_file="$(readlink -f "${project_data_folder}/${r1_filename}")"
        else
            r1_file="${project_data_folder}/${r1_filename}"
        fi
        r1_files+=("${r1_file}")
    done
  fi

  # Initiate arrays
  sample_ids=()
  samples=()

  # Get sample IDs from fastq files
  for r1_file in "${r1_files[@]}"; do
    sample=$(basename "${r1_file}")
    sample_id=$(basename ${r1_file} | rev | cut -d '_' -f 3- | rev | sort | uniq)
    samples+=("${sample}")
    sample_ids+=("${sample_id}")
  done

  # Make sure there are samples
  if [[ ${#samples[@]} -eq 0 ]]; then
    fatal "No samples found in ${project_data_folder}/"
  fi

  info "Samples:"
  for i in ${!samples[@]}; do
    info "$((i+1))    ${samples[i]}"
  done

}
