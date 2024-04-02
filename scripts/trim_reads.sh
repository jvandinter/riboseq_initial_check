#!/bin/bash

######################################################################
#
# Authors: J.T.vandinter-3@prinsesmaximacentrum.nl
# Authors: D.A.Hofman-3@prinsesmaximacentrum.nl
# Date: 03-06-2021
#
######################################################################

# Load files
mapfile -t r1_files < ${project_folder}/documentation/r1_files.txt
mapfile -t sample_ids < ${project_folder}/documentation/sample_ids.txt

# Set names
sample_id="${sample_ids[$((SLURM_ARRAY_TASK_ID-1))]}"
r1_file="${r1_files[$((SLURM_ARRAY_TASK_ID-1))]}"
r1_filename=$(basename ${r1_file})

# Create output dirs
cd "${outdir}"
mkdir -p "trimming/${sample_id}/"

# Check whether script needs to run
if [[ -f "${outdir}/trimming/${sample_id}/${r1_filename}" ]]; then
  echo "`date` ${sample_id} file already present"
  exit 0
fi

echo "`date` running trimgalore for ${sample_id}"
apptainer exec -B "/hpc:/hpc" --env "LC_ALL=C.UTF-8" ${container_dir}/fastp_0.23.4--hadf994f_2.sif fastp --version
apptainer exec -B "/hpc:/hpc" --env "LC_ALL=C.UTF-8" ${container_dir}/trimgalore-0.6.6.sif fastqc --version

cd "${outdir}/trimming/${sample_id}/"

# Trim reads with fastp
apptainer exec -B "/hpc:/hpc" --env LC_ALL=C.UTF-8 ${container_dir}/fastp_0.23.4--hadf994f_2.sif fastp \
  -i "${r1_file}" \
  -o "${outdir}/trimming/${sample_id}/${bf1}" \
  -l 25 \
  --verbose \
  --thread ${cpu}

apptainer exec -B "/hpc:/hpc,${TMPDIR}:${TMPDIR}" --env "LC_ALL=C.UTF-8" ${container_dir}/trimgalore-0.6.6.sif fastqc \
  --outdir "${outdir}/trimming/${sample_id}/" \
  --dir ${TMPDIR} \
  --threads ${cpu}

# Calculate trimcounts per paired fastq
tot_reads=$(zcat "${r1_file}" | echo $((`wc -l`/4)))
trimmed_reads=$(zcat "${outdir}/trimming/${sample_id}/${bf1}" | echo $((`wc -l`/4)))
trimmed_percentage=`awk -vn=248 "BEGIN{print(${trimmed_reads}/${tot_reads}*100)}"`

# Add read trimming info to run QC file
printf '%s\t%s\t%s\t%s\n' "${sample_id}_1" "Trimmed" $trimmed_reads $trimmed_percentage >> "${outdir}/trim_stats.txt"

echo "`date` finished ${sample_id}"
