#!/usr/bin/env bash

set -e
set -o pipefail

# -----------------------------
# CONFIG
# -----------------------------
CONFIG="/$HOME/inflammation_singatures/config/inflamm_config.yaml"

WORKDIR=$(yq e '.paths.workdir' "$CONFIG")
SING_IMAGE="$WORKDIR/singularity/champ/champ.sif"
RESULTS_DIR="$WORKDIR/INFLAMM_SIG_results"
COMBAT_TEMPLATE="$WORKDIR/config/combat_config_template.yaml"

name=$(yq e '.dataset.name' "$CONFIG")
idat_dir=$(yq e '.dataset.idat_dir' "$CONFIG")
RUN_COMBAT=$(yq e '.combat.run_combat // false' "$CONFIG")

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


# --------------------------------------------
# Create ComBat configuration (first run only)
# --------------------------------------------
COMBAT_CONFIG="$DATASET_DIR/combat_config.yaml"

if [[ "$RUN_COMBAT" == "true" && ! -f "$COMBAT_CONFIG" ]]; then
    cp "$COMBAT_TEMPLATE" "$COMBAT_CONFIG"
    echo ""
    echo "Created:"
    echo "  $COMBAT_CONFIG"
    echo ""
    echo "Inspect preprocessing results,"
    echo "edit batch_effect in this file, and rerun the pipeline."
    exit 0
fi


# --------------------------------------------
# Step 2: Remove batch effect if necessary
# --------------------------------------------
echo "========================"
echo " Batch effect correction"
echo "========================"

COMBAT_DIR="$DATASET_DIR/batch_effect_correction"
mkdir -p "$COMBAT_DIR"
DONE_COMBAT="$COMBAT_DIR/.done_combat"


if [[ "$RUN_COMBAT" == "false" ]]; then
    echo "ComBat disabled in configuration. Skipping."
else
    batch_effect=$(yq e '.batch_effect' "$COMBAT_CONFIG")
    if [[ "$batch_effect" == "null" || -z "$batch_effect" ]]; then
        echo ""
        echo "ComBat is enabled, but no batch variable has been specified."
        echo ""
        echo "If a batch variable is available, edit:"
        echo "  $COMBAT_CONFIG"
        echo ""
        echo "Example:"
        echo "  batch_effect: Sentrix_ID,Plate"
        echo ""
        echo "If no batch effect correction is required,"
        echo "set in the main config:"
        echo "  combat:"
        echo "    run_combat: false"
        echo ""
        echo "Then rerun the pipeline."
        exit 0
    elif [[ -f "$DONE_COMBAT" ]]; then
        echo "Batch effect correction for '$name' already done. Skipping."
    else
        echo "Running batch_effect_correction.R ..."
        M_VALUES=$(find "$PREPROCESS_DIR" -type f -name "M_values_*.rds")
        METADATA=$(find "$PREPROCESS_DIR" -type f -name "champ_metadata_*.rds")

        singularity exec "$SING_IMAGE" Rscript "$WORKDIR/scripts/batch_effect_correction.R" \
            m_vals="$M_VALUES" \
            champ_metadata="$METADATA" \
            batch_effect="$batch_effect" \
            dataset_name="$name" \
            output_dir="$COMBAT_DIR"

        touch "$DONE_COMBAT"
        echo "Batch effect correction for '$name' successfully completed."
    fi
fi

# Select beta values for downstream analyses
if [[ "$RUN_COMBAT" == "true" ]]; then
    BETA_DIR="$COMBAT_DIR"
else
    BETA_DIR="$PREPROCESS_DIR"
fi
BETA_RDS=$(find "$BETA_DIR" -type f -name "beta_values_*.rds" | head -n 1)
CELLPROP_RDS=$(find "$PREPROCESS_DIR" -type f -name "cell_proportions_*.rds" | head -n 1)

# ---------------------------------------------------------
# Step 3: Ligthart inflammation signature score calculation
# ---------------------------------------------------------
echo "=================================================="
echo " Ligthart inflammation signature score calculation"
echo "=================================================="

DONE_LIGTHART="$RESULTS_DIR/.done_ligthart"
OUT_CSV="$RESULTS_DIR/Ligthart_inflammation_signature_scores_${name}.csv"
LOG_FILE="$RESULTS_DIR/Ligthart_inflammation_signature_scores_${name}.log"

if [[ -f "$DONE_LIGTHART" ]]; then
    echo "Ligthart inflammation signature scores for '$name' already calculated. Skipping."
else
    singularity exec "$SING_IMAGE" Rscript "$WORKDIR/scripts/inflammation_score.R" \
        beta_rds="$BETA_RDS" \
        markers_csv="$WORKDIR/data/Ligthart_markers.csv" \
        cellprop_rds="$CELLPROP_RDS" \
        out_csv="$OUT_CSV" \
        log_file="$LOG_FILE"

    touch "$DONE_LIGTHART"
    echo "Ligthart inflammation signature scores for '$name' successfully calculated."
fi


# ----------------------------------------------------------
# Step 4: Wielscher inflammation signature score calculation
# ----------------------------------------------------------
echo "=================================================="
echo " Wielscher inflammation signature score calculation"
echo "=================================================="

OUT_CSV="$RESULTS_DIR/Wielscher_inflammation_signature_scores_${name}.csv"
LOG_FILE="$RESULTS_DIR/Wielscher_inflammation_signature_scores_${name}.log"

singularity exec "$SING_IMAGE" Rscript "$WORKDIR/scripts/inflammation_score.R" \
    beta_rds="$BETA_RDS" \
    markers_csv="$WORKDIR/data/Wielscher_markers.csv" \
    cellprop_rds="$CELLPROP_RDS" \
    out_csv="$OUT_CSV" \
    log_file="$LOG_FILE"

echo "Wielscher inflammation signature scores for '$name' successfully calculated."