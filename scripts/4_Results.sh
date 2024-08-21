#!/usr/bin/env bash
### LAST VERSION UPDATED 6 MAY 2024 (v2.0).
### THIS SCRIPT EXTRACTS FIGURES, TABLES AND OTHER RELEVANT RESULTS FROM THE PREVIOUS DATA

WD=/home2/genetics/antobe/projects/MTX_PREDICT
SOFTWARE=/home2/genetics/antobe/software
TMP=${WD}/TMP/tmp-4

### 4.1. MODEL PERFORMANCE

#! Note that these scripts rely on filepaths that may have changed if the folder structure was modified in `3*.sh`...

ls ${WD}/data/output/res/ | grep -v Table > ${TMP}/OUTCOME.list
while read LINE; do
    echo "EXTRACTING RESULTS FROM ${LINE}..."
    Rscript scripts/misc/4_ExtractProb.R ${LINE} PRIMARY

    Rscript scripts/misc/4_ExtractAuc.R ${LINE} PRIMARY
    Rscript scripts/misc/4_ExtractReclass.R ${LINE} PRIMARY 0.5

    if [[ ${LINE} == "persistence_d365" || ${LINE} == "persistence_d1096" ]]; then
	echo "EXTRACTING RESULTS FROM ${LINE} IN SUBGROUPS BASED ON SEROSTATUS..."
	Rscript scripts/misc/4_ExtractProb.R ${LINE} SEROPOSITIVE
	Rscript scripts/misc/4_ExtractProb.R ${LINE} SERONEGATIVE

	Rscript scripts/misc/4_ExtractAuc.R ${LINE} SEROPOSITIVE
	Rscript scripts/misc/4_ExtractAuc.R ${LINE} SERONEGATIVE
	Rscript scripts/misc/4_ExtractReclass.R ${LINE} SEROPOSITIVE 0.5
	Rscript scripts/misc/4_ExtractReclass.R ${LINE} SERONEGATIVE 0.5
    fi
done < ${TMP}/OUTCOME.list
rm ${TMP}/OUTCOME.list

### 4.2. FOLLOW UP ON THE BEST MODEL
#### 4.2.1. BEST MODEL FOR PERSISTENCE AT ONE YEAR

TRAIN365=data/output/TRAIN2_NONGENETIC-PRS.tsv
MODEL365=glmnet

Rscript scripts/misc/4_TrainFinal.R ${TRAIN365} ${MODEL365} persistence_d365
Rscript scripts/misc/4_SHAP.R ${TRAIN365} ${MODEL365} persistence_d365
Rscript scripts/misc/4_Recalibrate.R ${TRAIN365} ${MODEL365} persistence_d365

#### 4.2.2. BEST MODEL FOR PERSISTENCE AT THREE YEARS

TRAIN1096=${WD}/data/output/TRAIN2_NONGENETIC-PRS.tsv
MODEL1096=glmnet

Rscript scripts/misc/4_TrainFinal.R ${TRAIN1096} ${MODEL1096} persistence_d1096
Rscript scripts/misc/4_SHAP.R ${TRAIN1096} ${MODEL1096} persistence_d1096
Rscript scripts/misc/4_Recalibrate.R ${TRAIN1096} ${MODEL1096} persistence_d1096