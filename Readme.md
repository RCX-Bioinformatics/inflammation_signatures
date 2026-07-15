# 🧬 Inflammation Signatures Pipeline

This pipeline estimates multiple DNA methylation-based **inflammation signatures**:

- **Ligthart's inflammation signature:** Ligthart S, et al. DNA methylation signatures of chronic low-grade inflammation are associated with complex diseases. Genome Biol. 2016.
- **Wielscher's inflammation signature:** Wielscher M, et al. DNA methylation signature of chronic low-grade inflammation and its role in cardio-respiratory diseases. Nat Commun. 2022.

All scripts are executed inside prebuilt **Singularity containers**, ensuring a reproducible environment without manual package installation.

The pipeline consists of two main steps:

1. **DNA methylation data preprocessing** — DNA methylation data preprocessing is performed using the ChAMP R-package. Cell-type proportions are estimated using the EpiDISH R-package and reference methylation profiles.
2. **Inflammation signatures estimation** — inflammation signature scores are computed as weighted sums of methylation levels across matched CpG sites using the published effect sizes.

---

## 📁 Directory Structure

```
inflammation_signatures/
├── config/
│   ├── inflamm_config.yaml
│   └── combat_config_template.yaml
├── scripts/
├── custom_functions/
├── data/
│   ├── Ligthart_markers.csv
│   └── Wielscher_markers.csv
├── singularity/
└── run_inflamm.sh
```

---

## 💬 Quick Start

Edit the configuration file (`config/inflamm_config.yaml`) and run:

```bash
bash run_inflamm.sh config/inflamm_config.yaml
```

---

## ⚙️ Prerequisites

- **Linux environment** with:
  - `bash`, `yq`, `make`, and `singularity` installed
- **Required Singularity images** (can be built using `make`):
  - `ubuntu22.04_R4.4.1.sif` → base environment
  - `champ.sif` → ChAMP-based preprocessing; inflammation signatures

---

## 🔧 Build Singularity Images

A single Makefile is provided in the `singularity/` folder to build all containers in the correct order.

1. Navigate to the `singularity/` folder:

```bash
cd singularity/
```
2. Build all containers:
```bash
make all
```
Tip: If you encounter permission denied errors, rerun with sudo
```bash
sudo make all
```
3. To build individual containers, you can run:
```bash
make ubuntu22.04_R4.4.1    # Build only the base container (must be created first)
make champ                 # Build only the champ container
```
4.To clean all built `.sif` images:
```bash
make clean
```

---

## Configuration

The pipeline is configured through a YAML configuration file that is passed as an argument to `run_inflamm.sh`.

Edit `config/inflamm_config.yaml` to define (details provided in the config file):

```yaml
datasets:
  name: "REF1"
  idat_dir: "/path/to/idats/"

combat:
  run_combat: true

paths:
  workdir: "/$HOME/inflammation_signatures"
```

Filtering thresholds used during preprocessing are selected to match the requirements of the downstream inflammation signature analyses. Details are documented in the accompanying scripts.
Batch-effect correction is optional and controlled by the `run_combat` parameter. If `run_combat: true`, a `combat_config.yaml` file is automatically generated from `combat_config_template.yaml`. After preprocessing, users can inspect the SVD plots and specify the batch variable(s) to be corrected before rerunning the batch-correction step.

## Run

Run the pipeline by specifying the configuration file:

```bash
bash run_inflamm.sh config/inflamm_config.yaml
```

This script will:

1. **Preprocess** the input dataset using ChAMP (`champ_preprocessing.R`) and estimate cell-type proportions with EpiDISH. This step creates the following files inside the `preprocessing` folder:
  - Beta-values
    - `beta_values_*_BMIQ.rds`
  - M-values
    - `M_values_*_BMIQ.rds`
  - Metadata
    - `champ_metadata_*.rds`
  - Cell type estimates
    - `cell_proportions_hepidish_*_BMIQ.rds`
  - Quality control
    - Raw vs. normalised QC plots
    - BMIQ diagnostic plots
    - SVD plots for batch-effect assessment

2. **Optional batch-effect correction** (`batch_effect_correction.R`). This step creates the following files inside the `batch_effect_correction` folder:
  - Batch-corrected beta values
    - `beta_values_*_ComBat_*.rds`
  - Updated metadata
    - `champ_metadata_*_ComBat_*.rds`
  - Quality control
    - SVD plots after batch-effect correction

3. **The Ligthart and Wielscher inflammation signatures** are computed as weighted sums of methylation levels across matched CpG sites using the published effect sizes (`inflammation_score.R`). This step creates the following files inside the `INFLAMM_SIG_results/$name` folder:
    - `Ligthart_inflammation_signature_scores_*.csv` 
    - `Ligthart_inflammation_signature_scores_*.log`
    - `Wielscher_inflammation_signature_scores_*.csv` 
    - `Wielscher_inflammation_signature_scores_*.log`

4. Save results to:

```
$WORKDIR/
└── INFLAMM_SIG_results/
    └── $name/
          ├── preprocessing            # ChAMP preprocessing outputs
          ├── batch_effect_correction  # batch effect correction results
          ├── Ligthart_inflammation_signature_scores_*.csv # Ligthart's inflammation signature estimate
          └── Wielscher_inflammation_signature_scores_*.csv # Wielscher's inflammation signature estimate
```
---


## 🧹 Tips

- If a dataset has already been processed, delete its `.done` file to re-run that step.
- When using batch-effect correction, inspect the SVD plots before specifying the batch variable(s) in `combat_config.yaml`.
- The pipeline reads all settings from the YAML configuration file supplied on the command line.
- Make sure that `workdir` in the YAML configuration file matches the repository location.

---

## 📚 Citation

If you use this pipeline, please cite the relevant methods and tools:

- Mareckova K, et al. (update once preprint available)
- **ChAMP:** Tian Y, et al. ChAMP: updated methylation analysis pipeline for Illumina BeadChips. Bioinformatics. 2017.  
- **BMIQ normalization:** Teschendorff AE, et al. A beta-mixture quantile normalization method for correcting probe design bias in Illumina Infinium 450k DNA methylation data. Bioinformatics. 2013.  
- **Cell-type proportion estimation (EpiDISH):** Zheng SC, et al. Identification of differentially methylated cell-types in Epigenome-Wide Association Studies. Nature Methods. 2018.
- **Ligthart's inflammation signature:** Ligthart S, et al. DNA methylation signatures of chronic low-grade inflammation are associated with complex diseases. Genome Biol. 2016.
- **Wielscher's inflammation signature:** Wielscher M, et al. DNA methylation signature of chronic low-grade inflammation and its role in cardio-respiratory diseases. Nat Commun. 2022.