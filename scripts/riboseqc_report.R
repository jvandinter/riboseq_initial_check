###########################################################################
#
# Authors: D.A.Hofman-3@prinsesmaximacentrum.nl
# Authors: J.T.vandinter-3@prinsesmaximacentrum.nl
# Date: 28-08-2023
#
# Description:
# Script to create a batch QC HTML file
#
###########################################################################

# Load libraries ----------------------------------------------------------
message("Loading required libraries ...")
suppressPackageStartupMessages({
  library(RiboseQC)
  library(rmarkdown)
})

# Get variables from input ------------------------------------------------
args = commandArgs(trailingOnly = TRUE)
output_file = args[1]
pandoc_dir = args[2]
scriptdir = args[3]

# Define variables --------------------------------------------------------
rmarkdown::find_pandoc(dir = pandoc_dir)

input_files = list.files(output_file,recursive = T, pattern = "_results_RiboseQC_all", full.names = T)
input_sample_names = gsub("_.*","",basename(input_files))

# Run script --------------------------------------------------------------


    # get input and output file paths
    input_files <- paste(normalizePath(dirname(input_files)),basename(input_files),sep="/")
    output_file <- paste(normalizePath(dirname(output_file)),basename(output_file),sep="/")

    # get path to RMarkdown file (to be rendered)
    rmd_path <- paste(scriptdir,"heesch_riboseqc_report.Rmd", sep = "/")

    # set tmp folder outside Rpackage
    tmp_dir = dirname(output_file)

    # get folder path for pdf figures
    output_fig_path <- paste(output_file,"_plots/", sep = "")

    # create folder for rds ojects and pdf figures
    dir.create(paste0(output_fig_path, "rds/"), recursive=TRUE, showWarnings=FALSE)
    dir.create(paste0(output_fig_path, "pdf/"), recursive=TRUE, showWarnings=FALSE)
    sink(file = paste(output_file,"_report_text_output.txt",sep = ""))
    # render RMarkdown file > html report
    knitclean<-knitr::knit_meta(class=NULL, clean = TRUE)
    suppressWarnings(render(rmd_path,
           params = list(input_files = input_files,
                         input_sample_names = input_sample_names,
                         output_fig_path = output_fig_path),
           output_file = output_file,
	   intermediates_dir = tmp_dir))
    gici<-gc()
    sink()
