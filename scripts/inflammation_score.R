#!/usr/bin/env Rscript

# ============================================================
# Argument parsing
# ============================================================

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(name) {
  arg <- args[grepl(paste0("^", name, "="), args)]
  if (length(arg) == 0) {
    stop(paste("Missing argument:", name))
  }
  sub(paste0("^", name, "="), "", arg)
}

beta_rds     <- get_arg("beta_rds")
markers_csv  <- get_arg("markers_csv")
cellprop_rds <- get_arg("cellprop_rds")
out_csv      <- get_arg("out_csv")
log_file     <- get_arg("log_file")

sink(log_file, split = TRUE)

cat("====================================================\n")
cat("PERS calculation started\n")
cat("Time:", as.character(Sys.time()), "\n\n")

cat("Arguments:\n")
cat("beta_rds    =", beta_rds, "\n")
cat("markers_csv =", markers_csv, "\n")
cat("cellprop_rds=", cellprop_rds, "\n")
cat("out_csv     =", out_csv, "\n")
cat("log_file    =", log_file, "\n\n")

# ============================================================
# Load data
# ============================================================

cat("Loading beta values...\n")
HBA <- readRDS(beta_rds)
cat("Dimensions (before transpose):\n")
print(dim(HBA))

HBA <- as.data.frame(t(HBA))
cat("Dimensions (after transpose):\n")
print(dim(HBA))
cat("\n")

cat("Loading CpG markers...\n")
markers <- read.csv(
  markers_csv,
  header = TRUE,
  skip = 1,
  dec = ",",
  stringsAsFactors = FALSE
)
cat("Total markers:", nrow(markers), "\n\n")

# ============================================================
# Match CpGs
# ============================================================

common_cpgs <- intersect(colnames(HBA), markers$MarkerName)
missing_cpgs <- setdiff(markers$MarkerName, common_cpgs)

cat("CpGs matched:", length(common_cpgs), "\n")
cat("CpGs missing:", length(missing_cpgs), "\n\n")

if (length(common_cpgs) == 0) {
  stop("No overlapping CpGs found. Stopping.")
}

# ============================================================
# PERS calculation
# ============================================================

methylation_sub <- HBA[, common_cpgs, drop = FALSE]

effect_sizes <- markers[
  match(common_cpgs, markers$MarkerName),
  "Effect"
]

# Verify dimensions match (prevent duplicate CpGs in markers)
if (ncol(methylation_sub) != length(effect_sizes)) {
  stop("Dimension mismatch: ", ncol(methylation_sub), " methylation columns vs ", length(effect_sizes), " effect sizes")
}

pers_scores <- as.numeric(crossprod(t(methylation_sub), effect_sizes))

cat("PERS summary:\n")
print(summary(pers_scores))
cat("\n")

# ============================================================
# Cell proportion merge
# ============================================================

cat("Loading cell proportions...\n")
cell_prop <- readRDS(cellprop_rds)
cat("Cell proportion dimensions:\n")
print(dim(cell_prop))
cat("\n")

inflammation_tab <- data.frame(
  PERS_raw = pers_scores,
  PERS_z   = as.numeric(scale(pers_scores)),
  row.names = rownames(methylation_sub)
)

merged_tab <- merge(
  inflammation_tab,
  cell_prop,
  by = "row.names",
  all = TRUE
)

rownames(merged_tab) <- merged_tab$row.names
merged_tab$row.names <- NULL

merged_tab <- merged_tab[rownames(cell_prop), , drop = FALSE]

cat("Final table dimensions:\n")
print(dim(merged_tab))
cat("\n")

# ============================================================
# Write output
# ============================================================

write.csv(merged_tab, out_csv, row.names = TRUE)

cat("Output written to:", out_csv, "\n\n")

# ============================================================
# Session info
# ============================================================

cat("Session info:\n")
print(sessionInfo())

cat("\nCompleted at:", as.character(Sys.time()), "\n")
cat("====================================================\n")

sink()
