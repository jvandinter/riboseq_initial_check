#!/bin/bash

# Parse command-line arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--config)
    CONFIG="$2"
    shift
    shift
    ;;
    -h|--help)
    usage
    exit
    ;;
    "")
    echo "Error: no option provided"
    usage
    exit 1
    ;;
    *)
    echo "Unknown option: $key"
    usage
    exit 1
    ;;
esac
done

# Check that configuration file is provided
if [[ -z ${CONFIG+x} ]]; then 
    echo "Error: no configuration file provided"
    usage
    exit 1
fi

# Load configuration variables
source $CONFIG

# Load general functions
source ${scriptdir}/functions.sh

# Create a unique prefix for the names for this run_id of the pipeline
# This makes sure that run_ids can be identified
run_id=$(uuidgen | tr '-' ' ' | awk '{print $1}')

################################################################################
#
# Find fastq samples in directory
#
################################################################################

# Find samples
echo "$(date '+%Y-%m-%d %H:%M:%S') Finding samples..."
get_samples $project_data_folder $data_folder

printf "%s\n" "${r1_files[@]}" > ${project_folder}/documentation/r1_files.txt
printf "%s\n" "${sample_ids[@]}" > ${project_folder}/documentation/sample_ids.txt

# Create output directories
mkdir -p ${project_folder}/log/${run_id}/{trim,star_align,bowtie2,riboseqc} 
echo "`date` using run ID: ${run_id}"
mkdir -p ${outdir}

# make sure there are samples
if [[ ${#samples[@]} -eq 0 ]]; then
  fatal "no samples found in ./raw/ or file containing fastq file locations not present"
fi

info "samples: n = ${#samples[@]}"
for sample in ${samples[@]}; do
  info "    $sample"
done

################################################################################
#
# Run the pipeline
#
################################################################################

echo -e "\n ====== `date` Map Riboseq Pipeline ====== \n"

echo -e "\n`date` Filtering and trimming ..."
echo -e "====================================================================================== \n"

# 1. TRIMGALORE. Parallel start of all trimgalore jobs to filter for quality
#                with CUTADAPT and output quality reports with FASTQC

trim_jobid=()

trim_jobid+=($(sbatch --parsable \
  --mem=8G \
  --cpus-per-task=4 \
  --time=24:00:00 \
  --array 1-${#samples[@]}%${simul_array_runs} \
  --job-name=${run_id}.trimgalore \
  --output=${project_folder}/log/${run_id}/trimgalore/%A_%a.out \
  --export=ALL \
  ${scriptdir}/trim_reads.sh 
))

if [[ ${#trim_jobid[@]} -eq 0 ]]; then
  fatal "Trimming job not submitted successfully, trim_jobid array is empty"
fi

info "trimming jobid: ${trim_jobid}"

echo -e "\n`date` Removing contaminants ..."
echo -e "====================================================================================== \n"

# 2. BOWTIE2. Use combination of tRNA, rRNA, snRNA, snoRNA, mtDNA fastas to
#             remove those contaminants from RIBO-seq data. Outputs QC stats
#             to a file per contaminant group.

contaminant_jobid=()

contaminant_jobid+=($(sbatch --parsable \
  --mem=8G \
  --cpus-per-task=12 \
  --time=24:00:00 \
  --array 1-${#samples[@]}%${simul_array_runs} \
  --job-name=${run_id}.contaminants \
  --output=${project_folder}/log/${run_id}/bowtie2/%A_%a.out \
  --dependency=aftercorr:${trim_jobid} \
  --export=ALL \
  ${scriptdir}/remove_contaminants.sh
  
))

info "RPF jobid: ${contaminant_jobid}"

echo -e "\n`date` Align reads to genome with STAR ..."
echo -e "====================================================================================== \n"

# 3. STAR. Align contaminant-depleted read files to supplied genome and
#          transcriptome. If no new custom transcriptome is supplied, 
#          the normal reference transcriptome is used for 
#          guided assembly.

star_jobid=()

star_jobid+=($(sbatch --parsable \
  --mem=60G \
  --cpus-per-task=8 \
  --time=24:00:00 \
  --array 1-${#samples[@]}%${simul_array_runs} \
  --job-name=${run_id}.star_align \
  --output=${project_folder}/log/${run_id}/star_align/%A_%a.out \
  --dependency=aftercorr:${contaminant_jobid} \
  --export=ALL \
  ${scriptdir}/star_align.sh
))

info "alignment jobid: ${star_jobid}"

echo -e "\n`date` Perform QC with RiboseQC ..."
echo -e "====================================================================================== \n"

# 4. RiboseQC. 

riboseqc_jobid=()

riboseqc_jobid+=($(sbatch --parsable \
  --mem=24G \
  --cpus-per-task=1 \
  --time=24:00:00 \
  --array 1-${#samples[@]}%${simul_array_runs} \
  --job-name=${run_id}.riboseqc \
  --output=${project_folder}/log/${run_id}/riboseqc/%A_%a.out \
  --dependency=aftercorr:${star_jobid} \
  --export=ALL \
  ${scriptdir}/riboseqc.sh
))

info "RiboseQC jobid: ${riboseqc_jobid}"

echo -e "\n`date` Creating RiboseQC reports ..."
echo -e "====================================================================================== \n"

# 5. RiboseQC report. 

riboreport_jobid=()

riboreport_jobid+=($(sbatch --parsable \
  --mem=48G \
  --cpus-per-task=1 \
  --time=24:00:00 \
  --job-name=${run_id}.riboreport \
  --output=${project_folder}/log/${run_id}/riboreport.out \
  --dependency=afterok:${riboseqc_jobid} \
  --export=ALL \
  ${scriptdir}/riboseqc_report.sh
))

info "RiboseQC report jobid: ${riboreport_jobid}"

echo -e "\n`date` Creating MultiQC reports ..."
echo -e "====================================================================================== \n"

# 6. MultiQC.

multiqc_jobid=()

multiqc_jobid+=($(sbatch --parsable \
  --mem=8G \
  --cpus-per-task=1 \
  --time=24:00:00 \
  --job-name=${run_id}.multiqc \
  --output=${project_folder}/log/${run_id}/%A_multiqc.out \
  --dependency=afterok:${riboseqc_jobid} \
  --export=ALL \
  ${scriptdir}/multiqc.sh
))

info "MultiQC jobid: ${multiqc_jobid[@]}"

echo -e "\n`date` Creating final HTML report ..."
echo -e "====================================================================================== \n"

figure_jobid=()

figure_jobid+=($(sbatch --parsable \
  --mem=8G \
  --cpus-per-task=1 \
  --time=24:00:00 \
  --job-name=${run_id}.multiqc \
  --output=${project_folder}/log/${run_id}/%A_QC_report.out \
  --dependency=afterok:${multiqc_jobid} \
  --export=ALL \
  ${scriptdir}/create_QC_report.sh
))

info "Final report jobid: ${figure_jobid[@]}"

echo -e "\n ====== `date` Started all jobs! ====== \n"
