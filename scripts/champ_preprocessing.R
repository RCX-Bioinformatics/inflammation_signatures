suppressPackageStartupMessages(library(ChAMP))
suppressPackageStartupMessages(library(sva))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(dendextend))
suppressPackageStartupMessages(library(EpiDISH))
suppressPackageStartupMessages(library(lumi))

# Load custom R functions
source("custom_functions/run_champ_QC_cat.r")
source("custom_functions/parse_named_args.r")
source("custom_functions/champ.QC_recursive.r")
# Read command-line arguments and parse them
args <- commandArgs(trailingOnly = TRUE)
parsed_args <- type.convert.args(args)

# Description of arguments
cat("Usage: Rscript champ_preprocessing.R filter_nonCG=TRUE filter_XY=TRUE idat_dir=/my/idat/dir/ dataset_name=my_dataset filter_multihit=TRUE filter_snps=TRUE output_dir=/my/output/dir\n\n")
cat("Arguments:\n\n")
cat("  idat_dir: Provide the full path to your IDAT directory.\n\n")
cat("  filter_nonCG: If filter_nonCG=TRUE, non-cg probes are removed.(default = TRUE).\n\n")
cat("  filter_XY: If filter_XY=TRUE, probes from X and Y chromosomes are removed.(default = TRUE).\n\n")
cat("  filter_multihit: If filter_multihit=TRUE, probes in which the probe aligns to multiple locations with bwa as defined in Nordlund et al are removed.(default = TRUE).\n\n")
cat("  filter_snps: If filterSNPs=TRUE, probes in which the probed CpG falls near a SNP as defined in Nordlund et al are removed.(default = TRUE).\n\n")
cat("  dataset_name: Name of the processed dataset, will be part of output filenames.\n\n")
cat("  output_dir: Directory where all outputs will be saved. (default = current working directory)\n\n")

filter_nonCG <- ifelse(!is.null(parsed_args$filter_nonCG), parsed_args$filter_nonCG, TRUE)
filter_XY <- ifelse(!is.null(parsed_args$filter_XY), parsed_args$filter_XY, TRUE)
filter_multihit <- ifelse(!is.null(parsed_args$filter_multihit), parsed_args$filter_multihit, TRUE)
filter_snps <- ifelse(!is.null(parsed_args$filter_snps), parsed_args$filter_snps, TRUE)
dataset_name <- parsed_args$dataset_name
output_dir <- ifelse(!is.null(parsed_args$output_dir), parsed_args$output_dir, getwd())

# Ensure top-level output_dir exists and set working directory
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
setwd(output_dir)

cat("Filter non CG probes:", filter_nonCG, "\n")
cat("Filter probes from X and Y chromosomes:", filter_XY, "\n")
cat("Filter probes that align to multiple locations:", filter_multihit, "\n")
cat("Filter probes in which the probed CpG falls near a SNP:", filter_snps, "\n")

# Define filename suffix
suffix <- paste0(dataset_name,
  ifelse(filter_nonCG, "", "_nonCpGs"),
  ifelse(filter_XY, "", "_XY"),
  ifelse(filter_multihit, "", "_MultiHit"),
  ifelse(filter_snps, "", "_SNPs"))

# Load IDATs using ChAMP package
idat_loaded <- champ.load(directory = as.character(parsed_args$idat_dir), 
                          arraytype = "EPIC", method = "minfi", 
                          filterNoCG = filter_nonCG, filterXY = filter_XY,
                          filterMultiHit = filter_multihit, 
                          filterSNPs = filter_snps)

# Run BMIQ normalisation
meth_bmiq <- champ.norm(beta=idat_loaded$beta, arraytype="EPIC",
                        cores = 1, method = "BMIQ", plotBMIQ = TRUE, resultsDir="./CHAMP_Normalization/")
meth_bmiq <- meth_bmiq[,rownames(idat_loaded$pd)]
champ.SVD(beta=data.frame(meth_bmiq), pd=idat_loaded$pd, PDFplot = TRUE, resultsDir="./CHAMP_SVDimages/")

# Generate QC plots before and after normalisation
run_champ_QC_cat(idat_loaded$beta, idat_loaded$pd, "/raw_data")
run_champ_QC_cat(meth_bmiq, idat_loaded$pd, "/normalised")

# Perform cell type prediction using EpiDISH
cell_proportions_hepidish <- hepidish(beta.m = meth_bmiq, 
                                      ref1.m = centEpiFibIC.m,
                                      ref2.m = centBloodSub.m, 
                                      h.CT.idx = 3, method = 'RPC', 
                                      maxit = 100000)

# Convert beta values to M values
Mvals_bmiq <- beta2m(meth_bmiq)

# Save results with dynamic filenames
saveRDS(Mvals_bmiq, paste0("M_values_", suffix, "_BMIQ.rds"))
saveRDS(meth_bmiq, paste0("beta_values_", suffix, "_BMIQ.rds"))
saveRDS(idat_loaded$pd, paste0("champ_metadata_", suffix, ".rds"))
saveRDS(cell_proportions_hepidish, paste0("cell_proportions_hepidish_", suffix, "_BMIQ.rds"))
cat("ChAMP data loading, normalisation and cell proportions estimate completed successfully!\n")