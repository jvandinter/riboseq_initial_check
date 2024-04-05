#!/bin/bash

######################################################################
#
# Authors: J.T.vandinter-3@prinsesmaximacentrum.nl
# Authors: D.A.Hofman-3@prinsesmaximacentrum.nl
# Date:    24-06-2022
#
######################################################################

# Load parameters from main script
threads=$((SLURM_CPUS_PER_TASK * 2))

echo "`date` running MultiQC for all samples"

mkdir -p "${outdir}/multiqc"

# Run MultiQC
apptainer exec -B "/hpc:/hpc" --env "LC_ALL=C.UTF-8" \
 ${container_dir}/multiqc-1.11.sif multiqc \
 "${outdir}" \
 --outdir "${outdir}/multiqc" \
 --filename "${run_name}_multiqc.html"

echo "`date` finished MultiQC"
