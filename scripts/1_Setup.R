### LAST VERSION UPDATED 26 AUGUST 2024 (v2.1).
### THIS SCRIPT SETS UP THE NON-GENETIC DATA FOR THE PREDICTION PROJECT.

FOLDERPATH <- "K:/HW/people/Anton Öberg Sysojev/MTXp_predict/"

### 1. EXTRACT THE 'COHORT' - READ RAW DATA, APPLY EXCLUSION CRITERIA AND OUTPUT A SET OF IDS AND INDEX DATES

source(paste0(FOLDERPATH, "scripts/misc/1_ExtractCohort.R"))

### 2. EXTRACT KEY - LINKS PID TO COHORT ID (UNIQUE FOR EIRA AND SRQB) TO GWAS ID

source(paste0(FOLDERPATH, "scripts/misc/1_ExtractKey.R"))

### 3. EXTRACT TRAINING DATA
#! Note that this needs you to run `misc/1_ExtractNonGeneticTrainingHelper.sas` and `misc/1_ExtractFskHelper.sas` a priori, to extract the data used in the three below scripts. 
#! See TODO 1.1. for potential improvements.

source(paste0(FOLDERPATH, "scripts/misc/1_ExtractSociodemographics.R"))
source(paste0(FOLDERPATH, "scripts/misc/1_ExtractClinical.R"))
source(paste0(FOLDERPATH, "scripts/misc/1_ExtractMedicalDrug.R"))

### 4. EXTRACT LABELS

source(paste0(FOLDERPATH, "scripts/misc/1_ExtractLabels.R"))

### TODO:
# 1.1. The underlying SAS-HELPER scripts should not be in SAS. They might as well be in R
#       which would make them more easily executable through this pipeline. There won't be time to
#       make that change, but it might be useful if we can find the time.
#      - If we do, then it should also be incorporated to run through the individual scripts, in case the files are missing, at the if-check.
# 1.2. I previously had some print out information in here, but cut it prior to GitLab publishing as it was mostly for development use.
#       It should be added back though, in terms of safety belts, where prints and checks would make sure that nothing is missed.