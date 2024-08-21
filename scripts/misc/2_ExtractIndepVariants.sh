#!/usr/bin/env bash
### LAST VERSION UPDATE 9 MAY 2024 (v2.1) - NOW TARGETING GENOTYPED VARAINTS ONLY, WITH A HARDER PRUNING.
### THIS SCRIPT EXTRACTS A SUBSET OF NEAR-INDEPENDENT VARIANTS.

WD=${1}
SOFTWARE=${2}
TMP=${3}

### 1. EXTRACTING VARIANTS IN NEAR-LINKAGE-EQUIBLIRIUM

${SOFTWARE}/plink2 --bfile ${WD}/data/output/EIRA-SRQB.QC --set-all-var-ids @:# --extract ${WD}/data/raw/Genotyped.tsv --make-bed --out ${TMP}/EIRA-SRQB.QC.genotyped	#Genotyped variants from ExtractGenotyped.R at H:/

${SOFTWARE}/plink2 --bfile ${TMP}/EIRA-SRQB.QC.genotyped --indep-pairwise 100 5 0.01 --out ${TMP}/EIRA-SRQB.QC.genotyped.ldprune
${SOFTWARE}/plink2 --bfile ${TMP}/EIRA-SRQB.QC.genotyped --extract ${TMP}/EIRA-SRQB.QC.genotyped.ldprune.prune.in --out ${TMP}/EIRA-SRQB.QC.genotyped.ldprune --make-bed
${SOFTWARE}/plink2 --bfile ${TMP}/EIRA-SRQB.QC.genotyped.ldprune --indep-pairwise 1000 5 0.05 --out ${TMP}/EIRA-SRQB.QC.genotyped.ldprune.ldprune --threads 8
${SOFTWARE}/plink2 --bfile ${TMP}/EIRA-SRQB.QC.genotyped.ldprune --extract ${TMP}/EIRA-SRQB.QC.genotyped.ldprune.ldprune.prune.in --out ${TMP}/EIRA-SRQB.QC.genotyped.ldprune.ldprune --make-bed

### 2. REFORMATING TO A TABULAR FORMAT

Rscript ${WD}/scripts/misc/2_ReformatBed.R ${TMP}/EIRA-SRQB.QC.genotyped.ldprune.ldprune.bed

rm ${TMP}/EIRA-SRQB.QC.ldprune*
