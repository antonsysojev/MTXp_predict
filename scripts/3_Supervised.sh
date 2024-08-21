#!/usr/bin/env bash
### LAST VERSION UPDATED 4 JUNE 2024 (v2.1).
### THIS SCRIPT CREATES THE CROSS-VALIDATION SETS AND RUNS THE SUPERVISED LEARNING PIPELINE FOR RAW OUTPUT.

WD=/home2/genetics/antobe/projects/MTX_PREDICT
SOFTWARE=/home2/genetics/antobe/software
TMP=${WD}/TMP/tmp-3

### 1. IDENTIFYING DIFFERENT FOLDS FOR ANALYSIS

Rscript scripts/misc/3_ExtractFolds.R

### 2. SUPERVISED PIPELINE FOR EACH OF THE OUTCOMES OF INTEREST

ls ${WD}/data/output/res/ | grep -v \\. > ${TMP}/OUTCOME.list     #ROBUST HERE, IN IDENTIFYING OUTCOME NAMES, BUT MAY TRANSLATE POORLY...
while read LINE; do
    echo "TRAINING FOR ${LINE}..."
    Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN1_NONGENETIC.tsv ${LINE} PRIMARY
    Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN2_NONGENETIC-PRS.tsv ${LINE} PRIMARY
    Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN3_NONGENETIC-PRS-PCA.tsv ${LINE} PRIMARY
    Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN4_NONGENETIC-PRS-SNP.rds ${LINE} PRIMARY
done < ${TMP}/OUTCOME.list

### 3. PRIMARY OUTCOMES IN SEROPOSITIVE AND SERONEGATIVE SUBTYPES

for SERO in SEROPOS SERONEG; do
    for OUTCOME in persistence_d365 persistence_d1096; do
        echo "TRAINING FOR ${OUTCOME} AMONG ${SERO}..."
        Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN1_NONGENETIC.tsv ${OUTCOME} ${SERO}
        Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN2_NONGENETIC-PRS.tsv ${OUTCOME} ${SERO}
        Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN3_NONGENETIC-PRS-PCA.tsv ${OUTCOME} ${SERO}
        Rscript scripts/misc/3_SupervisedPipeline.R ${WD}/data/output/TRAIN4_NONGENETIC-PRS-SNP.rds ${OUTCOME} ${SERO}
    done
done

### TO DO:
### 1.1. I intensely dislike the current folder structure that this supposes and builds upon, as it leads to several folders with
#         an extensive number of files that are difficult to keep track of. Still, I can't think of a better option than this.