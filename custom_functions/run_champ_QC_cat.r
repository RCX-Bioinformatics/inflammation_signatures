# Function to run champ.QC for each categorical variable
run_champ_QC_cat <- function(beta, pheno, folder) {
  num_samples <- nrow(pheno)  # Total number of samples
  categorical_vars <- names(pheno)[sapply(pheno, function(vec) {
    len <- length(unique(vec)) 
    len > 1 & len < num_samples
  })]
  if (length(categorical_vars) == 0) {
    stop("No categorical variables found in pheno data.")
  }
  for (var in categorical_vars) {
    message(paste("Running champ.QC_recursive for:", var))
    champ.QC_recursive(
      beta = beta,
      pheno = pheno[[var]],
      resultsDir = paste0("./CHAMP_QC_", var, folder)  # Naming results directory by variable
    )
  }
}