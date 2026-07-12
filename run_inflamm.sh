#!/usr/bin/env bash

set -e
set -o pipefail

# -----------------------------
# CONFIG
# -----------------------------
CONFIG="/$HOME/inflammation_singatures/config/inflamm_config.yaml"

WORKDIR=$(yq e '.paths.workdir' "$CONFIG")
CHAMP_SING_IMAGE="$WORKDIR/singularity/champ/champ.sif"
RESULTS_DIR="$WORKDIR/INFLAMMATION_results"

name=$(yq e '.dataset.name' "$CONFIG")
idat_dir=$(yq e '.dataset.idat_dir' "$CONFIG")
pheno_csv=$(yq e '.dataset.pheno_csv' "$CONFIG")
DATASET_DIR="$RESULTS_DIR/$name"
mkdir -p "$DATASET_DIR"
PREPROCESS_DIR="$DATASET_DIR/preprocessing"
mkdir -p "$PREPROCESS_DIR"

# -------------------------------------
# Step 1: Preprocessing methylation data
# -------------------------------------
echo "====================================================================="
echo " Preprocessing methylation data for inflammation signatures analysis"
echo "====================================================================="

DONE_PRE="$PREPROCESS_DIR/.done_preprocessing"

if [[ -f "$DONE_PRE" ]]; then
    echo "Dataset '$name' already preprocessed. Skipping."
else
    singularity exec "$CHAMP_SING_IMAGE" Rscript "$WORKDIR/scripts/champ_preprocessing.R" \
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
# Step 2: Remove batch effect if necessary
# --------------------------------------------
echo "=============================================="
echo " Removing batch effect from methylation data"
echo "=============================================="

gs_BMIQ=$(yq e '.gold_standard_BMIQ' "$CONFIG")
gs=$(yq e '.gold_standard_raw' "$CONFIG")
COMPLETE_BETAS_DIR=$DATASET_DIR/complete_betas
mkdir -p "$COMPLETE_BETAS_DIR"

# BMIQ normalised beta values
DONE_BMIQ="$COMPLETE_BETAS_DIR/.done_BMIQ_completion"
if [[ -f "$DONE_BMIQ" ]]; then
    echo "BMIQ completion for '$name' already done. Skipping."
else
    echo "Running ref_vals_completion.R for BMIQ-normalized beta values..."

    BMIQ_FILE=$(find "$DATASET_DIR" -type f -name "beta_values_*_BMIQ*.rds")
    singularity exec "$CHAMP_SING_IMAGE" Rscript "$WORKDIR/scripts/epiclocks/ref_vals_completion.R" \
        beta_vals="$BMIQ_FILE" \
        ref_vals="$gs_BMIQ" \
        output_dir="$COMPLETE_BETAS_DIR"

    touch "$DONE_BMIQ"
    echo "BMIQ-normalised beta values for dataset '$name' successfully completed using reference values from the gold standard dataset."
fi

# ----------------------------------------------------
# Step 3: Estimate individual epigenetic ageing clocks
# ----------------------------------------------------
BETA_VALS_BMIQ=$(find "$COMPLETE_BETAS_DIR" -type f -name "beta_values_*_BMIQ*.rds")
BETA_VALS_BMIQ_CSV=$(find "$COMPLETE_BETAS_DIR" -type f -name "beta_values_*_BMIQ*.csv")
BETA_VALS_RAW=$(find "$COMPLETE_BETAS_DIR" -type f -name "beta_values_*.rds" ! -name "*_BMIQ*.rds")

echo "========================================="
echo " Prepare inputs for CheekAge shiny server"
echo "========================================="

CHEEKAGE_DIR=$DATASET_DIR/cheekage
mkdir -p "$CHEEKAGE_DIR"

DONE_CHEEKAGE="$CHEEKAGE_DIR/.done_CheekAge"
if [[ -f "$DONE_CHEEKAGE" ]]; then
    echo "CheekAge inputs for dataset '$name' already prepared. Skipping."
else
    echo "Running cheekage_input_prep.R for dataset '$name'..."

    singularity exec "$CHAMP_SING_IMAGE" Rscript "$WORKDIR/scripts/epiclocks/cheekage_input_prep.R" \
        dataset_name="$name" \
        beta_vals="$BETA_VALS_BMIQ" \
        samples_in_chunk=13 \
        output_dir="$CHEEKAGE_DIR"

    touch "$DONE_CHEEKAGE"
    echo "CheekAge inputs for dataset '$name' successfully prepared. Please upload these inputs to shiny servet at https://cheekage.tallyhealth.com/."
fi


echo "========================================"
echo " Compute AltumAge estimate using pyaging"
echo "========================================"

ALTUMAGE_DIR=$DATASET_DIR/altumage
mkdir -p "$ALTUMAGE_DIR"

DONE_ALTUMAGE="$ALTUMAGE_DIR/.done_AltumAge"
if [[ -f "$DONE_ALTUMAGE" ]]; then
    echo "AltumAge estimate for dataset '$name' already computed. Skipping."
else
    echo "Running pyaging_clocks.py for dataset '$name'..."

    singularity exec "$PYAGING_SING_IMAGE" python "$WORKDIR/scripts/epiclocks/pyaging_clocks.py" \
        $BETA_VALS_BMIQ_CSV \
        --output pyaging_estimate_"$name".csv \
        --epicv2 false \
        --clocks AltumAge \
        --output_dir "$ALTUMAGE_DIR"

    touch "$DONE_ALTUMAGE"
    echo "AltumAge estimate for dataset '$name' successfully computed."
    rm -r $WORKDIR/pyaging_data
fi


echo "==================================="
echo " Compute Horvath's DNAmAge estimate"
echo "==================================="

DNAMAGE_DIR=$DATASET_DIR/dnamage
mkdir -p "$DNAMAGE_DIR"

DONE_DNAMAGE="$DNAMAGE_DIR/.done_DNAmAge"
if [[ -f "$DONE_DNAMAGE" ]]; then
    echo "DNAmAge estimate for dataset '$name' already computed. Skipping."
else
    echo "Running horvath_dnamage.R for dataset '$name'..."

    singularity exec "$HORVATH_SING_IMAGE" Rscript "$WORKDIR/scripts/epiclocks/horvath_dnamage.R" \
        beta_vals="$BETA_VALS_RAW" \
        output_dir="$DNAMAGE_DIR"

    touch "$DONE_DNAMAGE"
    echo "DNAmAge estimate for dataset '$name' successfully computed."
fi


echo "==================================="
echo " Compute GrimAge estimate"
echo "==================================="

GRIMAGE_DIR=$DATASET_DIR/grimage
mkdir -p "$GRIMAGE_DIR"

DONE_GRIMAGE="$GRIMAGE_DIR/.done_GrimAge"
if [[ -f "$DONE_GRIMAGE" ]]; then
    echo "GrimAge estimate for dataset '$name' already computed. Skipping."
else
    echo "Running grimage.R for dataset '$name'..."

    singularity exec "$GRIMAGE_SING_IMAGE" Rscript "$WORKDIR/scripts/epiclocks/grimage.R" \
    beta_vals="$BETA_VALS_BMIQ" \
    pheno_data="$pheno_csv" \
    dataset_name="$name" \
    output_dir="$GRIMAGE_DIR"

    touch "$DONE_GRIMAGE"
    echo "GrimAge estimate for dataset '$name' successfully computed."
fi


echo "==================================="
echo " Compute DunedinPACE estimate"
echo "==================================="

DUNEDINPACE_DIR=$DATASET_DIR/dunedinpace
mkdir -p "$DUNEDINPACE_DIR"

DONE_DUNEDINPACE="$DUNEDINPACE_DIR/.done_DunedinPACE"
if [[ -f "$DONE_DUNEDINPACE" ]]; then
    echo "DunedinPACE estimate for dataset '$name' already computed. Skipping."
else
    echo "Running dunedinpace.R for dataset '$name'..."

    singularity exec "$DUNEDINPACE_SING_IMAGE" Rscript "$WORKDIR/scripts/epiclocks/dunedinpace.R" \
    beta_vals="$BETA_VALS_BMIQ" \
    dataset_name="$name" \
    output_dir="$DUNEDINPACE_DIR"

    touch "$DONE_DUNEDINPACE"
    echo "DunedinPACE estimate for dataset '$name' successfully computed."
fi