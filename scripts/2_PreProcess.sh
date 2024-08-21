#!/usr/bin/env bash
### LAST VERSION UPDATE 29 APRIL 2024 (v2.0).
### THIS SCRIPT PERFORMS THE PRE-PROCESSING OF THE TRAINING DATA USED FOR THE MACHINE LEARNING PROJECT.

WD=/home2/genetics/antobe/projects/MTX_PREDICT
SOFTWARE=/home2/genetics/antobe/software
TMP=TMP/tmp-2

### 1. CLEANING OF NON-GENETIC TRAINING DATA

Rscript scripts/misc/2_FilterVariance.R			#FILTER ALL ICD AND ATC CODES ON LOW VARIANCE
Rscript scripts/misc/2_FilterCorrelation.R		#FILTER ALL ICD AND ATC CODES ON HIGH CORRELATION (CONCORDANCE)
Rscript scripts/misc/2_ManageMissing.R			#IMPUTE MISSING OBSERVATIONS

rm ${TMP}/MEDICAL-DRUG.VARFILT.tsv; rm ${TMP}/MEDICAL-DRUG.VARFILT.CORRFILT.tsv

### 2. QUALITY CONTROL OF GENETIC TRAINING DATA

Rscript scripts/misc/2_ExtractCohortGid.R	#QUICK FIX FOR JOINING COHORT.tsv AND KEY.tsv - #! SHOULD BE DO-ABLE IN BASH WITH A ONE-LINER OF PIPES BUT I CAN NOT FIGURE OUT AN EASY WAY TO DO IT...
${SOFTWARE}/plink2 --pfile /home2/genetics/antobe/data/EIRA-SRQB/EIRA-SRQB --keep ${TMP}/COHORT.KEY.tsv --make-pfile --out ${TMP}/EIRA-SRQB.raw
bash scripts/misc/2_QualityControl.sh ${WD} ${SOFTWARE} ${TMP}

rm ${TMP}/COHORT.KEY.tsv; rm ${TMP}/EIRA-SRQB.raw.*

### 3. POLYGENIC RISK SCORES FOR THE FIRST GENETIC TRAINING SET

bash scripts/misc/2_DownloadGwasData.sh ${WD} ${SOFTWARE} ${TMP}	#! Bottleneck in speed in these scripts; improvements may be considered - in particular parallelization...
bash scripts/misc/2_ClumpGwasData.sh ${WD} ${SOFTWARE} ${TMP}
ls ${WD}/data/GWAS | cut -f 1 -d '.' | uniq | sort > ${TMP}/WD.ls
while read LINE; do echo "CREATING ${LINE} PRS..."; Rscript scripts/misc/2_ConstructPrs.R ${WD}/data/GWAS/${LINE}.clumped ${WD}/data/output/EIRA-SRQB.QC.bed; rm ${TMP}/bed.*; done < ${TMP}/WD.ls

echo "Of the $(ls ${WD}/data/GWAS/*.tsv | wc -w) GWASs downloaded, clumped data was made on $(ls ${WD}/data/GWAS/*.clumped | wc -w) of them"
echo "Of the $(ls ${WD}/data/GWAS/*.clumped | wc -w) sets of clumped data, PRS were made on $(ls ${WD}/data/GWAS/*.PRSPCA | wc -w) of them"

rm ${TMP}/REFPAN.*; rm ${WD}.ls

### 4. PRINCIPAL COMPONENTS FOR THE SECOND GENETIC TRAINING SET

bash scripts/misc/2_ConstructPca.sh ${WD} ${SOFTWARE} ${TMP}

### 5. RAW VARIANTS FOR THE THIRD GENETIC TRAINING SET

bash scripts/misc/2_ExtractIndepVariants.sh ${WD} ${SOFTWARE} ${TMP}

### 6. AGGREGATE DATA INTO DISTINCT TRAINING SETS

Rscript scripts/misc/2_AggregateTraining.R ${WD} ${SOFTWARE} ${TMP}

### TO DO:
# 1.1. There are currently two QC scripts being used, but they're pretty much identical. Why is there still no standard GWAS QC script available? This would make things much more clear.
# 1.2. Reference panel extraction is currently done outside of the main script (section 3). This makes things unnecessarily difficult to follow in a strange nested structure...
#	It also presupposes that a non-standard copy of the 1000 Genomes data is available. A better solutions is as follows:
#	(i): If the 1000 Genomes data is not available, download and process it. Stick it in... TMP? Cache? Elsewhere?
#	(ii): Use the standard (see 1.1.) GWAS QC script on the downloaded reference panel. 
#	(iii): Add this into the script in a section 3.1. Move the rest of the section 3 to a section 3.2. Cut reference panel creation from the ClumpGwasData file.