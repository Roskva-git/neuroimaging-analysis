# Neuroimaging Analysis

MATLAB scripts for preprocessing and analysis of neuroimaging and electrophysiological data.

This repository contains analysis workflows developed during coursework and research in cognitive neuroscience.

## Contents

### fMRI (SPM12)

- **fMRI SPM pipeline**  
  Script for preprocessing and statistical analysis of fMRI data using SPM12.  
  Includes slice timing correction, coregistration, segmentation, normalization, smoothing, first-level contrasts, and second-level group analysis.

### EEG / ERP (EEGLAB)

- **SST EEG preprocessing**  
  Batch preprocessing pipeline for stop-signal task EEG data using EEGLAB.  
  Includes filtering, resampling, channel cleanup, rereferencing, event recoding, and ICA decomposition.

- **SST ERP extraction**  
  Script for extracting ERPs from epoched EEG datasets, computing mean ERPs at FCz, and saving results in a structured format for further analysis.

## Requirements

- MATLAB  
- SPM12 (for fMRI scripts)  
- EEGLAB (for EEG/ERP scripts)

## Notes

File paths in the scripts must be adapted to match the local data directory.
