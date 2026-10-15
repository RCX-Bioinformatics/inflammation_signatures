suppressPackageStartupMessages(library(ChAMP))

# Load custom R functions
source("custom_functions/parse_named_args.r")

# Read command-line arguments and parse them
args <- commandArgs(trailingOnly = TRUE)
parsed_args <- type.convert.args(args)

# Description of arguments
cat("Usage: Rscript impute_missing_values.R beta_vals=beta_values.rds gold_standard_rds=gs_ref_vals_BMIQ.rds probes_to_impute=probes_to_impute.rds output_dir=/my/output/dir\n\n")

cat("Arguments:\n\n")
cat("  beta_vals: Path to the input beta values RDS file. The filename must end in _BMIQ.rds.\n\n")
cat("  gold_standard_rds: Path to the gold standard reference values RDS file. The filename must end in _BMIQ.rds.\n\n")
cat("  probes_to_impute: Path to the RDS file containing the CpG markers for which values should be available.\n\n")
cat("  output_dir: Directory where the imputed beta values will be saved (default = current working directory).\n\n")

# Parse arguments
beta_vals <- as.character(parsed_args$beta_vals)
gs_ref_vals <- as.character(parsed_args$gold_standard_rds)
probes_to_impute <- as.character(parsed_args$probes_to_impute)

output_dir <- ifelse(
  !is.null(parsed_args$output_dir),
  parsed_args$output_dir,
  getwd()
)

# Validate required arguments
if (is.null(parsed_args$beta_vals) ||
    is.null(parsed_args$gs_ref_vals) ||
    is.null(parsed_args$probes_to_impute)) {
  stop("Missing required arguments. Please provide beta_vals, gs_ref_vals, and probes_to_impute.")
}

# Check input file suffixes
if (!all(grepl("_BMIQ\\.rds$", basename(c(beta_vals, gs_ref_vals))))) {
  stop("Both beta_vals and gs_ref_vals filenames must end in _BMIQ.rds!")
}

# Check that input files exist
input_files <- c(beta_vals, gs_ref_vals, probes_to_impute)

if (!all(file.exists(input_files))) {
  stop(
    "The following input files do not exist: ",
    paste(input_files[!file.exists(input_files)], collapse = ", ")
  )
}

cat("Input beta values:", beta_vals, "\n")
cat("Gold standard reference values:", gs_ref_vals, "\n")
cat("Markers to impute:", probes_to_impute, "\n")
cat("Output directory:", output_dir, "\n\n")

# Load input data
gs_ref <- readRDS(gs_ref_vals)
betas <- readRDS(beta_vals)
inflamm_markers <- readRDS(probes_to_impute)

# Identify missing markers available in the gold standard reference
missing_markers <- c()

for (i in seq_along(inflamm_markers)) {
  marker <- inflamm_markers[[i]]
  score <- names(inflamm_markers)[i]

  cat("Checking inflammation score:", score, "\n")
  cat("Number of CpGs in the score:", length(marker), "\n")

  miss <- setdiff(marker, rownames(betas))

  if (length(miss) > 0) {
    cat("Number of missing markers in input beta values:", length(miss), "\n")

    miss_avail <- intersect(miss, rownames(gs_ref))

    cat(
      "Number of missing markers available in gold standard reference:",
      length(miss_avail), "\n"
    )

    missing_markers <- unique(c(missing_markers, miss_avail))
  } else {
    cat("All markers present in input beta values.\n")
  }

  cat("\n")
}

cat("Total number of unique missing markers available for imputation:",
    length(missing_markers), "\n\n")

# Extract reference values for missing markers
ref_values <- gs_ref[missing_markers, , drop = FALSE]

# Replicate reference values across the input samples
ref_matrix <- matrix(
  ref_values,
  nrow = length(missing_markers),
  ncol = ncol(betas),
  dimnames = list(missing_markers, colnames(betas))
)

# Append missing markers to the input beta values
betas <- rbind(betas, ref_matrix)

# Define output filename
output_filename <- paste0(
  sub("\\.rds$", "", basename(beta_vals)),
  "_imputed.rds"
)

output_path <- file.path(output_dir, output_filename)

# Save imputed beta values
saveRDS(betas, output_path)

cat("Imputed beta values saved to:", output_path, "\n")
cat("Final number of CpG markers:", nrow(betas), "\n")
cat("Number of samples:", ncol(betas), "\n")
cat("Gold standard reference imputation completed successfully!\n")