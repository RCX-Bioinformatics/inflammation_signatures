suppressPackageStartupMessages(library(ChAMP))
suppressPackageStartupMessages(library(sva))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(dendextend))
suppressPackageStartupMessages(library(lumi))

# Load custom R functions
source("custom_functions/run_champ_QC_cat.r")
source("custom_functions/parse_named_args.r")
source("custom_functions/champ.QC_recursive.r")
# Read command-line arguments and parse them
args <- commandArgs(trailingOnly = TRUE)
parsed_args <- type.convert.args(args)

# Description of arguments
cat("Usage: Rscript batch_effect_correction.R m_vals=my_M_vals.rds champ_metadata=my_metadata.rds batch_effect=batch1,batch2 dataset_name=my_dataset output_dir=/my/output/dir\n\n")
cat("Arguments:\n\n")
cat("  m_vals: Provide the full path to your M values rds file.\n\n")
cat("  champ_metadata: Provide the full path to your ChAMP metadata rds file.\n\n")
cat("  batch_effect: Colname(s) of metadata that will be used to remove batch effect (e.g. batch_effect=Plate,SentrixID).\n\n")
cat("  dataset_name: Name of the processed dataset, will be part of output filenames.\n\n")
cat("  output_dir: Directory where all outputs will be saved. (default = current working directory)\n\n")

output_dir <- ifelse(!is.null(parsed_args$output_dir), parsed_args$output_dir, getwd())

# Ensure top-level output_dir exists and set working directory
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
setwd(output_dir)

# Define filename suffix
suffix <- paste0(parsed_args$dataset_name, "_ComBat_", sub(",","_",parsed_args$batch_effect))

cat("Batch effect that will be removed:", parsed_args$batch_effect, "\n")
batch_effect <- unlist(strsplit(as.character(parsed_args$batch_effect), ","))
metadata <- readRDS(as.character(parsed_args$champ_metadata))
mvals_bmiq <- readRDS(as.character(parsed_args$m_vals))

# Ensure batch_effect variable is present in metadata
if (!all(batch_effect %in% colnames(metadata))) {
  stop("Error: Incorrect batch effect variable(s) - ", 
    paste(batch_effect[!(batch_effect %in% colnames(metadata))], collapse = ", "),
    ". Available columns are: ", paste(colnames(metadata), collapse = ", "))
}

# If only one batch effect, use it directly; if multiple, combine them
batch_colname <- paste(batch_effect, collapse = "_") 
if (length(batch_effect) > 1) {
  metadata[[batch_colname]] <- apply(metadata[, batch_effect, drop = FALSE], 1, paste, collapse = "_")
  saveRDS(metadata, paste0("champ_metadata_", suffix, ".rds"))
}

# Check number of batches and warn if too many (is really categorical variable)
batch_factor <- factor(metadata[[batch_colname]])
n_batches <- nlevels(batch_factor)
if (n_batches > nrow(metadata) * 0.2) {
  warning("Batch variable has ", n_batches, " levels - verify this is intended")
}


# Remove -Inf values to run ComBat without error
cat("Number of M values = -Inf (imputed with the lowest M value available):", sum(mvals_bmiq==(-Inf)), "\n")
mvals_bmiq[mvals_bmiq==(-Inf)] <- min(mvals_bmiq[mvals_bmiq!=(-Inf)])
mvals_bmiq_combat <- ComBat(dat = mvals_bmiq,
                            batch = metadata[[batch_colname]],
                            mod = NULL, par.prior = TRUE,
                            prior.plots = FALSE, mean.only = FALSE,
                            ref.batch = NULL)

beta_vals_bmiq_combat <- m2beta(mvals_bmiq_combat)
champ.SVD(beta=data.frame(beta_vals_bmiq_combat), pd=metadata, PDFplot = TRUE, resultsDir="./CHAMP_SVDimages/")
run_champ_QC_cat(beta_vals_bmiq_combat, metadata, "/combat")

saveRDS(beta_vals_bmiq_combat, paste0("beta_values_", suffix, ".rds"))
cat("Batch effect correction completed successfully!\n")