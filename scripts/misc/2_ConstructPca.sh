#!/usr/bin/env bash
### LAST VERSION UPDATE 2 MAY 2024 (v2.0).
### THIS SCRIPT EXTRACTS PRINCIPAL COMPONENTS ON THE POST-QC GENOTYPE DATA.

WD=${1}
SOFTWARE=${2}
TMP=${3}

### 1. EXTRACT A SET OF NEAR-INDEPENDENT VARIANTS FOR PRINCIPAL COMPONENT ANALYSIS

${SOFTWARE}/plink2 --bfile ${WD}/data/output/EIRA-SRQB.QC --indep-pairwise 100 5 0.10 --out ${TMP}/EIRA-SRQB.QC.ldprune
${SOFTWARE}/plink2 --bfile ${WD}/data/output/EIRA-SRQB.QC --extract ${TMP}/EIRA-SRQB.QC.ldprune.prune.in --out ${TMP}/EIRA-SRQB.QC.ldprune --make-pfile
${SOFTWARE}/plink2 --pfile ${TMP}/EIRA-SRQB.QC.ldprune --pca 10 --out ${TMP}/EIRA-SRQB.QC.ldprune.pca

### 2. EXTRACT AN APPROPRIATE AMOUNT OF PRINCIPAL COMPONENTS

Rscript scripts/misc/2_PCScree.R ${TMP}/EIRA-SRQB.QC.ldprune.pca.eigenval
read ncomp
covFields=$((ncomp + 2))
tail -n +2 ${TMP}/EIRA-SRQB.QC.ldprune.pca.eigenvec | cut -f 1-${covFields} > ${WD}/data/output/EIRA-SRQB.QC.pca 

rm ${TMP}/EIRA-SRQB.QC.ldprune*
