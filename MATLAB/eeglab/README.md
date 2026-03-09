# EEGLAB – Stop-Signal Task (SST) EEG Analysis

MATLAB scripts for preprocessing and ERP extraction from EEG data recorded during a stop-signal task (SST), using **EEGLAB**.

## Scripts

### 1. `sst_eeg_preprocessing.m`
Batch preprocessing pipeline for SST EEG data.

Steps include:
- Import BrainVision EEG files
- Bandpass filtering (0.1–40 Hz)
- Resampling to 500 Hz
- Removal of EMG channels
- Channel location lookup (10–05 system)
- Re-referencing to average earlobes (A1/A2)
- Event recoding for SST trials
- Independent Component Analysis (ICA)
- Saving ICA-ready datasets

Output: preprocessed EEG datasets with ICA decomposition.

---

### 2. `sst_erp_extraction.m`
Batch script for extracting ERPs from preprocessed and epoched SST datasets.

Steps include:
- Load epoched `.set` datasets
- Identify the **FCz** electrode
- Compute mean ERP across trials
- Extract participant ID and condition from filenames
- Store ERPs in a structured array

Output:  
`ERP_FCz_struct.mat` containing participant IDs, conditions, ERP waveforms, and time vectors.

---

## Requirements

- MATLAB  
- EEGLAB

## Notes

File paths in the scripts must be adapted to the local data directory before running.
