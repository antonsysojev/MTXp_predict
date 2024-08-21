#!/usr/bin/env bash
### LAST VERSION UPDATE 30 APRIL 2024 (v2.0).
### THIS SCRIPT PERFORMS THE CLUMPING PRIOR TO CONSTRUCTING THE POLYGENIC RISK SCORES.

WD=${1}
SOFTWARE=${2}
TMP=${3}

### 1. PREPARING THE REFERENCE PANEL DATA

bash scripts/misc/2_QualityControlReferencePanel.sh ${WD} ${SOFTWARE} ${TMP}
${SOFTWARE}/plink2 --pfile ${TMP}/REFPAN.QC --set-all-var-ids @:# --rm-dup force-first --make-bfile -out ${TMP}/REFPAN.QC.NoDup       #PROBLEM WITH DUPLICATES - THIS FORCES THEM AWAY...

### 2. CLEANING THE GWAS DATA

GWAS=${WD}/data/GWAS
ls ${GWAS} | cut -f 1 -d '.' | uniq | sort > ${TMP}/WD.ls
while read LINE; do
    echo "CLEANING $LINE GWAS..."
    tail -n +2 ${GWAS}/${LINE}.tsv | cut -f 1 | cut -f 1,2 -d ":" > ${TMP}/${LINE}.CHRPOS
    tail -n +2 ${GWAS}/${LINE}.tsv | cut -f 1 | cut -f 3 -d ":" > ${TMP}/${LINE}.EA
    tail -n +2 ${GWAS}/${LINE}.tsv | cut -f 1 | cut -f 4 -d ":" > ${TMP}/${LINE}.RA
    if [[ ${LINE} =~ "BMI" ]] || [[ ${LINE} =~ "CRP" ]]; then tail -n +2 ${GWAS}/${LINE}.tsv | cut -f 8,9,11 > ${TMP}/${LINE}.MISC      #THIS IS NOT ROBUST CODING FOR DEALING WITH QUANTITATIVE/BINARY PHENOTYPES
    else tail -n +2 ${GWAS}/${LINE}.tsv | cut -f 9,10,12 > ${TMP}/${LINE}.MISC; fi	#Columns are different across binary/quantitative traits

    echo -e "SNP\tEFFECT_ALLELE\tREFERENCE_ALLELE\tbeta\tse\tP" > ${TMP}/GWAS.${LINE}.tsv
    paste ${TMP}/${LINE}.CHRPOS ${TMP}/${LINE}.EA ${TMP}/${LINE}.RA ${TMP}/${LINE}.MISC >> ${TMP}/GWAS.${LINE}.tsv
    rm ${TMP}/${LINE}.*
done < ${TMP}/WD.ls

### 3. PERFORMING THE CLUMPING

touch ${TMP}/CLUMP.log
while read LINE; do
    echo "CLUMPING $LINE GWAS..."
    ${SOFTWARE}/plink --bfile ${TMP}/REFPAN.QC.NoDup --clump ${TMP}/GWAS.${LINE}.tsv --clump-p1 1 --clump-kb 250 --clump-r2 0.1 --out ${GWAS}/${LINE} &>> ${TMP}/CLUMP.log
    rm ${GWAS}/${LINE}.log	#Parameter choices are to mimic Coombes et al., with `clump-p1 1` to avoid thresholding; see NOTE 2.1. for details on an expected warning.
done < ${TMP}/WD.ls

mv ${TMP}/CLUMP.log ${WD}/data/log/CLUMP.log
rm ${TMP}/GWAS.*

### TO DO:
### NOTES:
# 2.1. As we do no thresholding, all SNPs will be considered 'top-SNPs', meaning we receive a warning with respect to all non-matching variants. This may seem like a large amount, but is reasonable
#	when contrasting between the total number of variants in both the reference panel set and the GWAS set.
