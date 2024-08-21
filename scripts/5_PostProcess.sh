#!/usr/bin/env bash
### LAST VERSION UPDATED 7 MAY 2024 (v1.0).
### THIS SCRIPT EXTRACTS TABLES FOR THE PAPER.

WD=/home2/genetics/antobe/projects/MTX_PREDICT
SOFTWARE=/home2/genetics/antobe/software
TMP=${WD}/TMP/tmp-5

### 1. COHORT DEMOGRAPHICS AND FEATURE DISTRIBUTIONS

Rscript scripts/misc/5_DemographicsClinVar.R		#Gets Table S1-S2
Rscript scripts/misc/5_MedicalDrugHistory.R		#Gets Table S3-S4

### 2. RESULT TABLES

Rscript scripts/misc/5_ModelQuality.R			#Gets Table 1 and Table S10-S11
Rscript scripts/misc/5_DemographicsCorrect.R 1 10 BETA	#Gets Table 2 - first and second input are decile groupings for negative/positive, third input is recalibration to use
Rscript scripts/misc/5_ExtractQC.R			#Gets Table S5.
Rscript scripts/misc/5_DemographicsCorrect.R 3 7 BETA	#Gets Table S9
Rscript scripts/misc/5_ExtractReclassTable.R		#Gets Table S7

### 3. REFITTED TABLES AND FIGURES

Rscript scripts/misc/5_RefitCalibration.R 		#Gets Table S8.
Rscript scripts/misc/5_CalibrationFig.R			#Gets Figure S2-S3.

### Rscript scripts/misc/5_TableS7-S8.R	#What does this do?

#! Structure here is bad... we can't get Calibration figures AFTER we've done `5_DemographicsCorrect.R`. Also, why is there some refitted tables (Table 2 and Table S9) in #2?
#! Also, what's going on with these names?