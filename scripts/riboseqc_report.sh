#!/bin/bash

######################################################################
#
# Authors: J.T.vandinter-3@prinsesmaximacentrum.nl
# Authors: D.A.Hofman-3@prinsesmaximacentrum.nl
# Date: 03-06-2021
#
######################################################################

# Load parameters from main script

threads=$((SLURM_CPUS_PER_TASK * 2))

# Check whether script needs to run
if [[ -f "${outdir}/RiboseQC.html" ]]; then
  echo "`date` QC report already present"
  exit 0
fi

echo "`date` creating RIBO-seq QC report"

# Use RiboSeQC to generate HTML report of the data
apptainer exec -B "/hpc:/hpc" --env LC_CTYPE="en_US.UTF-8" ${container_dir}/orfquant-4.1.2.sif \
  Rscript "${scriptdir}/mrp_riboseqc_report.R" \
  "${outdir}/RiboseQC" \
  "${pandoc_dir}" \
  "${scriptdir}"
