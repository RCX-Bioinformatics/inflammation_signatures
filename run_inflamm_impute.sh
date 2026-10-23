#!/usr/bin/env bash

set -e
set -o pipefail

# -----------------------------
# CONFIG
# -----------------------------
CONFIG="$1"

if [[ -z "$CONFIG" ]]; then
    echo "Usage:"
    echo "  $0 inflamm_impute_config.yaml"
    exit 1
fi

WORKDIR=$(yq e '.paths.workdir' "$CONFIG")
SING_IMAGE="$WORKDIR/singularity/champ/champ.sif"
RESULTS_DIR="$WORKDIR/INFLAMM_SIG_IMPUTED_results"

name=$(yq e '.dataset.name' "$CONFIG")
idat_dir=$(yq e '.dataset.idat_dir' "$CONFIG")
rds_file=$(yq e '.gold_standard_dataset.rds_file' "$CONFIG")

DATASET_DIR="$RESULTS_DIR/$name"
mkdir -p "$DATASET_DIR"


# --------------------------------------
# Step 1: Preprocessing methylation data
# --------------------------------------
echo "====================================================================="
echo " Preprocessing methylation data for inflammation signatures analysis"
echo "====================================================================="

PREPROCESS_DIR="$DATASET_DIR/preprocessing"
mkdir -p "$PREPROCESS_DIR"
DONE_PRE="$PREPROCESS_DIR/.done_preprocessing"

if [[ -f "$DONE_PRE" ]]; then
    echo "Dataset '$name' already preprocessed. Skipping."
else
    singularity exec "$SING_IMAGE" Rscript "$WORKDIR/scripts/champ_preprocessing.R" \
        dataset_name="$name" \
        idat_dir="$idat_dir" \
        filter_nonCG=FALSE \
        filter_XY=FALSE \
        filter_multihit=TRUE \
        filter_snps=TRUE \
        output_dir="$PREPROCESS_DIR"

    touch "$DONE_PRE"
    echo "Dataset '$name' successfully preprocessed."
fi
CELLPROP_RDS=$(find "$PREPROCESS_DIR" -type f -name "cell_proportions_*.rds" | head -n 1)

# ---------------------------------------------------------
# Step 3: Imputation of missing values 
# ---------------------------------------------------------
echo "========================================================="
echo " Imputation of missing values using gold standard dataset"
echo "========================================================="   

IMPUTE_DIR="$DATASET_DIR/imputation"
mkdir -p "$IMPUTE_DIR"
DONE_IMPUTE="$IMPUTE_DIR/.done_imputation"

if [[ -f "$DONE_IMPUTE" ]]; then
    echo "Imputation for '$name' already done. Skipping."
else
    BETA_RDS=$(find "$PREPROCESS_DIR" -type f -name "beta_values_*.rds" | head -n 1)
    singularity exec "$SING_IMAGE" Rscript "$WORKDIR/scripts/impute_missing_values.R" \
        beta_vals="$BETA_RDS" \
        gold_standard_rds="$rds_file" \
        probes_to_impute="$WORKDIR/data/Wielscher_Ligthart_markers.rds" \
        output_dir="$IMPUTE_DIR"
    touch "$DONE_IMPUTE"
    echo "Imputation for '$name' successfully completed."
fi
BETA_IMPUTED_RDS=$(echo "$IMPUTE_DIR"/beta_values_*_imputed.rds)

# ---------------------------------------------------------
# Step 4: Ligthart inflammation signature score calculation
# ---------------------------------------------------------
echo "=================================================="
echo " Ligthart inflammation signature score calculation"
echo "=================================================="

DONE_LIGTHART="$DATASET_DIR/.done_ligthart"
OUT_CSV="$DATASET_DIR/Ligthart_inflammation_signature_scores_${name}.csv"
LOG_FILE="$DATASET_DIR/Ligthart_inflammation_signature_scores_${name}.log"

if [[ -f "$DONE_LIGTHART" ]]; then
    echo "Ligthart inflammation signature scores for '$name' already calculated. Skipping."
else
    singularity exec "$SING_IMAGE" Rscript "$WORKDIR/scripts/inflammation_score.R" \
        beta_rds="$BETA_IMPUTED_RDS" \
        markers_csv="$WORKDIR/data/Ligthart_markers.csv" \
        cellprop_rds="$CELLPROP_RDS" \
        out_csv="$OUT_CSV" \
        log_file="$LOG_FILE"

    touch "$DONE_LIGTHART"
    echo "Ligthart inflammation signature scores for '$name' successfully calculated."
fi


# ----------------------------------------------------------
# Step 5: Wielscher inflammation signature score calculation
# ----------------------------------------------------------
echo "=================================================="
echo " Wielscher inflammation signature score calculation"
echo "=================================================="

OUT_CSV="$DATASET_DIR/Wielscher_inflammation_signature_scores_${name}.csv"
LOG_FILE="$DATASET_DIR/Wielscher_inflammation_signature_scores_${name}.log"

singularity exec "$SING_IMAGE" Rscript "$WORKDIR/scripts/inflammation_score.R" \
    beta_rds="$BETA_IMPUTED_RDS" \
    markers_csv="$WORKDIR/data/Wielscher_markers.csv" \
    cellprop_rds="$CELLPROP_RDS" \
    out_csv="$OUT_CSV" \
    log_file="$LOG_FILE"

echo "Wielscher inflammation signature scores for '$name' successfully calculated."