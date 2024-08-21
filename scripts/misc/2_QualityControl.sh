#!/usr/bin/env bash
### LAST VERSION UPDATE 29 APRIL 2024 (v2.0).
### THIS SCRIPT PERFORMS THE QUALITY CONTROL OF THE GENETIC DATA.

WD=${1}
SOFTWARE=${2}
TMP=${3}

touch ${TMP}/QC.log

#1. FILTER OUT VARIANTS WITH LOW IMPUTATION QUALITY
#! NOTE THAT BELOW IS HARD-CODED TO FILTER ON THRESHOLD OF RSQ 070, MORE FLEXIBLE IF DONE WITH PARAMETER...

tail -n +2 /home2/genetics/antobe/data/EIRA-SRQB/INFO.tsv | cut -f 1,7 | awk '{if ($2 < 0.70) { print } }' > ${TMP}/QC.info    #NOTE THAT 'EXTRACTING' RSQ >= 0.70 ACCIDENTALY CUTS X-CHR DATA SINCE THIS WAS NOT IMPUTED IN ALPHA
${SOFTWARE}/plink2 --pfile ${TMP}/EIRA-SRQB.raw --exclude ${TMP}/QC.info --make-bed --out ${TMP}/QC.rsq --threads 8 &>> ${TMP}/QC.log

#2. FILTER ON DISCORDANT SEX, AND DISCORAD NON-AUTOSOMAL VARIANTS

${SOFTWARE}/plink --bfile ${TMP}/QC.rsq --check-sex 0.2 0.8 --out ${TMP}/QC.CHKSEX &>> ${TMP}/QC.log
grep PROBLEM ${TMP}/QC.CHKSEX.sexcheck | awk '{if ($3 != 0) print}' > ${TMP}/QC.CHKSEX.PROBLEM
${SOFTWARE}/plink2 --bfile ${TMP}/QC.rsq --remove ${TMP}/QC.CHKSEX.PROBLEM --chr 1-22 --make-pfile --out ${TMP}/QC.rsq.sexcheck &>> ${TMP}/QC.log

#3. FILTER ON MISSINGNESS, ALLELE FREQUENCY AND DEVIATION FROM HARDY-WEINBERG EQUILIBRIUM

${SOFTWARE}/plink2 --pfile ${TMP}/QC.rsq.sexcheck --geno 0.05 --mind 0.05 --maf 0.01 --make-pfile --out ${TMP}/QC.rsq.sexcheck.mind.geno.maf &>> ${TMP}/QC.log
${SOFTWARE}/plink2 --pfile ${TMP}/QC.rsq.sexcheck.mind.geno.maf --hwe 1e-6 --make-pfile --out ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe &>> ${TMP}/QC.log

#4. PERFORM LD PRUNING TO EXCLUDE VARIANTS IN HIGH LINKAGE DISEQUILIBRIUM

${SOFTWARE}/plink2 --pfile ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe --indep-pairwise 100 5 0.2 --out ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.LDPRUNE --threads 8 &>> ${TMP}/QC.log
${SOFTWARE}/plink2 --pfile ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe --extract ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.LDPRUNE.prune.in --make-bfile --out ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.pruned &>> ${TMP}/QC.log

#5. FILTER ON CLOSELY RELATED INDIVIDUALS

${SOFTWARE}/plink --bfile ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.pruned --genome --min 0.125 --out ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.pruned.RELATED &>> ${TMP}/QC.log
${SOFTWARE}/plink2 --bfile ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.pruned --remove ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.pruned.RELATED.genome --make-pfile --out ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.pruned.rel &>> ${TMP}/QC.log

#6. FILTER ON ANCESTRY

PCA=${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe.pruned.rel
for ITER in $(seq 1 5); do
    ${SOFTWARE}/plink2 --pfile ${PCA} --pca 10 --out ${TMP}/QC.pca --threads 8 &>> ${TMP}/QC.log
    Rscript scripts/misc/2_FilterPca.R ${TMP}/QC.pca
    ${SOFTWARE}/plink2 --pfile ${PCA} --remove ${TMP}/QC.pca.outliers --out ${PCA}.PCA.${ITER} --make-pfile &>> ${TMP}/QC.log
    PCA=${PCA}.PCA.${ITER}
done

#7. RETURN THE VARIANTS WITHHELD IN STEP 4, AND OUTPUT DATA

${SOFTWARE}/plink2 --pfile ${TMP}/QC.rsq.sexcheck.mind.geno.maf.hwe --keep ${PCA}.psam --make-bed --out ${WD}/data/output/EIRA-SRQB.QC &>> ${TMP}/QC.log; rm ${WD}/data/output/EIRA-SRQB.QC.log
mv ${TMP}/QC.log ${WD}/data/log/EIRA-SRQB.QC.log
rm ${TMP}/QC.*

### TO DO:
### NOTES:
