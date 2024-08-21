#!/usr/bin/env bash
### LAST VERSION UPDATE 30 APRIL 2024 (v2.0).
### THIS SCRIPT PERFORMS THE QUALITY CONTROL FOR THE REFERENCE PANEL DATA.

WD=${1}
SOFTWARE=${2}
TMP=${3}

touch ${TMP}/QC.log

#1. MODIFY THE FORMAT OF THE DATA

${SOFTWARE}/plink2 --pfile /home2/genetics/antobe/data/1KGEN/EUR --set-all-var-ids @:#\$r:\$a --new-id-max-allele-len 1000 --rm-dup --make-bed --out ${TMP}/QC.raw &>> ${TMP}/QC.log

#2. FILTER ON DISCORDANT SEX, AND DISCARD NON-AUTOSOMAL VARIANTS

${SOFTWARE}/plink --bfile ${TMP}/QC.raw --check-sex 0.2 0.8 --out ${TMP}/QC.raw.CHKSEX --allow-extra-chr &>> ${TMP}/QC.log
grep PROBLEM ${TMP}/QC.raw.CHKSEX.sexcheck | awk '{if ($3 != 0) print}' > ${TMP}/QC.raw.CHKSEX.PROBLEM
${SOFTWARE}/plink2 --bfile ${TMP}/QC.raw --remove ${TMP}/QC.raw.CHKSEX.PROBLEM --chr 1-22 --make-pfile --out ${TMP}/QC.raw.sexcheck &>> ${TMP}/QC.log

#3. FILTER ON MISSINGNESS, ALLELE FREQUENCY AND DEVIATION FROM HARDY-WEINBERG EQUILIBRIUM

${SOFTWARE}/plink2 --pfile ${TMP}/QC.raw.sexcheck --geno 0.05 --mind 0.05 --maf 0.01 --make-pfile --out ${TMP}/QC.raw.sexcheck.mind.geno.maf &>> ${TMP}/QC.log
${SOFTWARE}/plink2 --pfile ${TMP}/QC.raw.sexcheck.mind.geno.maf --hwe 1e-6 --make-pfile --out ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe &>> ${TMP}/QC.log

#4. PERFORM LD PRUNING TO EXCLUDE VARIANTS IN HIGH LINKAGE DISEQUILIBRIUM

${SOFTWARE}/plink2 --pfile ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe --indep-pairwise 100 5 0.2 --out ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.LDPRUNE --threads 8 &>> ${TMP}/QC.log
${SOFTWARE}/plink2 --pfile ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe --extract ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.LDPRUNE.prune.in --make-bfile --out ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.pruned &>> ${TMP}/QC.log

#5. FILTER ON CLOSELY RELATED INDIVIDUALS

${SOFTWARE}/plink --bfile ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.pruned --genome --min 0.125 --out ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.pruned.RELATED &>> ${TMP}/QC.log
${SOFTWARE}/plink2 --bfile ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.pruned --remove ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.pruned.RELATED.genome --make-pfile --out ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.pruned.rel &>> ${TMP}/QC.log

#6. FILTER ON ANCESTRY

PCA=${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe.pruned.rel
for ITER in $(seq 1 5); do
    ${SOFTWARE}/plink2 --pfile ${PCA} --pca 10 --out ${TMP}/QC.pca --threads 8 &>> ${TMP}/QC.log
    Rscript scripts/misc/2_FilterPca.R ${TMP}/QC.pca
    ${SOFTWARE}/plink2 --pfile ${PCA} --remove ${TMP}/QC.pca.outliers --out ${PCA}.PCA.${ITER} --make-pfile &>> ${TMP}/QC.log
    PCA=${PCA}.PCA.${ITER}
done

#7. RETURN THE VARIANTS WITHHELD IN STEP 4, AND OUTPUT DATA

${SOFTWARE}/plink2 --pfile ${TMP}/QC.raw.sexcheck.mind.geno.maf.hwe --keep ${PCA}.psam --make-pfile --out ${TMP}/REFPAN.QC &>> ${TMP}/QC.log
rm ${TMP}/QC.*
