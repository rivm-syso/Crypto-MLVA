# Cryptosporidium MLVA Nanopore Pipeline

This repository contains an automated pipeline for Multi-Locus Variable-number tandem repeat Analysis (MLVA) of *Cryptosporidium* using Oxford Nanopore sequencing of PCR-amplified MLVA loci. The pipeline is designed to run within **iRODS** as an automated workflow, but can also be executed manually from the command line.

Each barcode directory corresponds to one sample, and the pipeline produces MLVA codes, per-locus repeat statistics, histograms, and a combined CSV summary.

---

## Overview

- **Goal**: MLVA typing of *Cryptosporidium* based on repeat counts in defined loci.
- **Input**: Nanopore FASTQ files (gzip-compressed) per barcode (one sample per barcode).
- **Core tools**: `seqkit`, `pandas`, `matplotlib`, standard Unix tools (`awk`, `sort`, etc.).
- **Environment**: Conda/mamba environment defined in `envs/mlva_env.conda.yml`.
- **Automation**: Suitable for iRODS integration, and can be triggered manually via a wrapper script.

---

## Repository Structure

The main components of the repository are:

- `run_mlva_pipeline.sh`  
  Top-level wrapper script:
  - Sets working directory.
  - Ensures environment is created/updated.
  - Activates `mlva_env`.
  - Calls the main MLVA script.

- `envs/mlva_env.conda.yml`  
  Conda/mamba environment specification:
  - `seqkit`
  - `pandas`
  - `matplotlib`

- `src/get_mlva_profile_for_iRODS.sh`  
  Main per-barcode MLVA pipeline:
  - Converts FASTQ to FASTA.
  - Extracts fragment lengths for predefined MLVA loci.
  - Computes repeat counts, modes, frequencies, and percentages.
  - Writes per-sample MLVA code files.
  - Generates combined CSV of all samples.

- `src/plot_repeat_histograms.py`  
  Python script to generate histograms of repeat counts per locus and save them as a multi-page PDF.

---

## Manual usage

Run the top-level script:

bash run_mlva_pipeline.sh /path/to/INPUTDIR /path/to/OUTPUTDIR

Arguments:

- `INPUTDIR`  
  Directory containing one subdirectory per barcode, each with Nanopore FASTQ files (`*.fastq.gz`) for that sample.

- `OUTPUTDIR`  
  Directory where MLVA codes, locus-specific repeat files, histograms, and the combined CSV will be written. Must exist beforehand.

If either directory is missing or invalid, the script exits with an error.

---

## Pipeline Description

### Top-level driver: `run_mlva_pipeline.sh`

Main steps:

1. Set working directory to the location of the script.
2. Check that `INPUTDIR` and `OUTPUTDIR` are provided and exist.
3. Update/create the `mlva_env` environment using `envs/mlva_env.conda.yml`.
4. Activate the `mlva_env` environment.
5. Execute the MLVA pipeline:
```bash
   bash src/get_mlva_profile_for_iRODS.sh "${INPUTDIR}" "${OUTPUTDIR}"
```
---

### Per-barcode MLVA pipeline: `src/get_mlva_profile_for_iRODS.sh`

Inputs:

- `input_dir` – barcode directories with `*.fastq.gz`.
- `output_dir` – location for MLVA outputs.

The script defines a list of MLVA loci as “sets”:

- Each set includes:
  - Two start–end sequence pairs (primer-like flanking sequences).
  - The total length of start+stop sequences (`start_stop_len`).
  - The repeat unit length (`repeat_len`).
  - A gene/locus identifier (e.g. `cgd1_470_1429`, `cgd4_2350_796`, etc.).

For each `barcode` directory:

1. **Convert FASTQ to FASTA**  
   All `*.fastq.gz` files in the barcode directory are concatenated and converted to FASTA:
```bash
   seqkit fq2fa <(cat "$barcode"/*.fastq.gz) > "$output_prefix"_raw.fasta
```
   where `output_prefix="$output_dir/$(basename "$barcode")"`.

2. **Initialize MLVA code aggregation**  
   Strings for:
   - `MLVA_code` (per-locus mode repeat counts),
   - `frequencies` (mode frequencies per locus),
   - `percentages` (mode percentages per locus).

3. **Per-locus fragment length and repeat count calculation**  
   For each locus set:

   - Extract sequences from the FASTA that match either of the start–end pairs using `awk` and `match()`.
   - Write their fragment lengths to `<prefix>_<gene>_fragment_lengths.txt`.
   - Convert fragment lengths to repeat counts:

     `repeats = (fragment_length – start_stop_len) / repeat_len`

     and write to `<prefix>_<gene>_repeats.txt`.

   - Compute:
     - `modus` (mode of repeat counts): most frequent repeat number, rounded to integer.
     - `frequency` (how many reads support this mode).
     - `percentage` (percentage of reads belonging to the mode among all reads for that locus).

   - Append the mode (`modus`), frequency, and percentage to the MLVA code summarizing strings.
   - Remove the intermediate fragment lengths file.

4. **Write per-sample MLVA code file**  
   After all loci:

   - `MLVA_code` is a dash-separated string of per-locus modes (e.g. `5-8-3-4-...`).
   - Frequencies and percentages are dash-separated per locus.

   Output file: `<prefix>_MLVA_code.txt`, containing:

   - Line 1: MLVA code (e.g. `5-8-3-4-...`)
   - Line 2: `Frequencies: freq1 - freq2 - ...`
   - Line 3: `Percentages: perc1 - perc2 - ...`

5. **Generate repeat histograms**  
   Call the histogram script:
```bash
   python src/plot_repeat_histograms.py --output_prefix $output_prefix
```
   This creates `<output_prefix>_MLVA_histograms.pdf` containing histograms of repeat counts per locus.

6. **Create combined CSV summary**  
   After processing all barcodes, the script:

   - Writes a header to `${output_dir}/MLVA_codes_combined.csv`:
     - `filename`, `MLVAcode`, `MLVA1`–`MLVA7`, `Freq1`–`Freq7`, `Perc1`–`Perc7`.

   - For each `<prefix>_MLVA_code.txt`:
     - Extracts the sample name.
     - Parses the MLVA code (dash-separated) into per-locus columns.
     - Parses frequencies and percentages into CSV columns.
     - Appends one line per sample to the combined CSV.

   - Removes certain intermediate files:
     - `${output_dir}/barcode*_repeats.txt`
     - `${output_dir}/barcode*_raw.fasta`

The main stable outputs in `OUTPUTDIR` are:

- `barcodeX_MLVA_code.txt` – per-sample MLVA mode, frequency, and percentage.
- `barcodeX_MLVA_histograms.pdf` – per-sample MLVA repeat histograms.
- `MLVA_codes_combined.csv` – combined summary across samples.

---

## Histogram Script

File: `src/plot_repeat_histograms.py`

This script creates histograms of repeat counts for each MLVA locus of a sample and stores them in a multi-page PDF.

Usage:
```bash
python src/plot_repeat_histograms.py --output_prefix <output_prefix>
```
It expects `*_repeats.txt` files for the 7 loci (e.g. `<output_prefix>_cgd1_470_1429_repeats.txt`, etc.). For each file:

- Reads repeat counts into a `pandas` Series.
- Skips empty files.
- Filters out repeat values that occur only once (keeps values with `count > 1`).
- If any values remain, plots a histogram:
  - X-axis: number of repeats.
  - Y-axis: frequency.
- Saves all histograms into `<output_prefix>_MLVA_histograms.pdf`.

---
