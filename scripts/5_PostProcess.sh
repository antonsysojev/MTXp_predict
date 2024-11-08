#!/usr/bin/env bash
### LAST VERSION UPDATED 12 SEPTEMBER 2024 (v1.1).
### THIS SCRIPT EXTRACTS TABLES FOR THE PAPER.

WD=/home2/genetics/antobe/projects/MTX_PREDICT
SOFTWARE=/home2/genetics/antobe/software
TMP=${WD}/TMP/tmp-5

### 1. COHORT DEMOGRAPHICS AND FEATURE DISTRIBUTIONS

Rscript scripts/misc/5_DemographicsClinVar.R		#Gets Table S2-S3
Rscript scripts/misc/5_MedicalDrugHistory.R		#Gets Table S4-S5

### 2. RESULT TABLES

Rscript scripts/misc/5_ModelQuality.R    #Gets Table 1 and Table S11-S12
Rscript scripts/misc/5_ExtractQC.R    #Gets Table S6
Rscript scripts/misc/5_ExtractReclassTable.R    #Gets Table S8

### 3. REFITTED TABLES AND FIGURES

Rscript scripts/misc/5_RefitCalibration.R    #Gets information for Table S9
Rscript scripts/misc/5_CalibrationFig.R			#Gets Figure S2-S3.

CALIBRATION=BETA
Rscript scripts/misc/5_DemographicsCorrect.R 1 10 $CALIBRATION    #Gets Table 2
Rscript scripts/misc/5_DemographicsCorrect.R 3 7 $CALIBRATION	    #Gets Table S10