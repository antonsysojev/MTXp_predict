#!/usr/bin/env bash
### LAST VERSION UPDATE 30 APRIL 2024 (v2.0).
### THIS SCRIPT DOWNLOADS AND READIES THE GWAS DATA FOR THE POLYGENIC RISK SCORES.

WD=${1}
SOFTWARE=${2}
TMP=${3}

GWAS=${WD}/data/GWAS

### 1. DOWNLOAD GWAS DATA FROM THE UK BIOBANK

#IRNT IS LIKELY INVERSE NORMAL RANK TRANSFORMATION
if ! [[ -f ${GWAS}/ASTHMA.tsv ]]; then wget -q -O ${GWAS}/ASTHMA.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/J45.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/ASTHMA.tsv.gz; fi
if ! [[ -f ${GWAS}/BIPO.tsv ]]; then wget -q -O ${GWAS}/BIPO.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/F31.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/BIPO.tsv.gz; fi
if ! [[ -f ${GWAS}/BMI.tsv ]]; then wget -q -O ${GWAS}/BMI.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/21001_irnt.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/BMI.tsv.gz; fi
if ! [[ -f ${GWAS}/COPD.tsv ]]; then wget -q -O ${GWAS}/COPD.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/J44.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/COPD.tsv.gz; fi
if ! [[ -f ${GWAS}/CROHNS.tsv ]]; then wget -q -O ${GWAS}/CROHNS.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/K50.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/CROHNS.tsv.gz; fi
if ! [[ -f ${GWAS}/CRP.tsv ]]; then wget -q -O ${GWAS}/CRP.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/30710_irnt.gwas.imputed_v3.both_sexes.varorder.tsv.bgz; gunzip ${GWAS}/CRP.tsv.gz; fi  
if ! [[ -f ${GWAS}/DEP.tsv ]]; then wget -q -O ${GWAS}/DEP.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/F33.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/DEP.tsv.gz; fi
if ! [[ -f ${GWAS}/HYPERTEN.tsv ]]; then wget -q -O ${GWAS}/HYPERTEN.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/I10.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/HYPERTEN.tsv.gz; fi
if ! [[ -f ${GWAS}/HYPERTHYR.tsv ]]; then wget -q -O ${GWAS}/HYPERTHYR.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/E05.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/HYPERTHYR.tsv.gz; fi
if ! [[ -f ${GWAS}/RA.tsv ]]; then wget -q -O ${GWAS}/RA.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/M13_RHEUMA.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/RA.tsv.gz; fi
if ! [[ -f ${GWAS}/SCZ.tsv ]]; then wget -q -O ${GWAS}/SCZ.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/F20.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/SCZ.tsv.gz; fi
if ! [[ -f ${GWAS}/SMK.tsv ]]; then wget -q -O ${GWAS}/SMK.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/22506_111.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/SMK.tsv.gz; fi
if ! [[ -f ${GWAS}/T1D.tsv ]]; then wget -q -O ${GWAS}/T1D.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/E4_DM1.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/T1D.tsv.gz; fi
if ! [[ -f ${GWAS}/T2D.tsv ]]; then wget -q -O ${GWAS}/T2D.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/E4_DM2.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/T2D.tsv.gz; fi
if ! [[ -f ${GWAS}/UC.tsv ]]; then wget -q -O ${GWAS}/UC.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/K51.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/UC.tsv.gz; fi
if ! [[ -f ${GWAS}/ULCERDUO.tsv ]]; then wget -q -O ${GWAS}/ULCERDUO.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/K26.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/ULCERDUO.tsv.gz; fi
if ! [[ -f ${GWAS}/ULCERGAS.tsv ]]; then wget -q -O ${GWAS}/ULCERGAS.tsv.gz https://broad-ukb-sumstats-us-east-1.s3.amazonaws.com/round2/additive-tsvs/K25.gwas.imputed_v3.both_sexes.tsv.bgz; gunzip ${GWAS}/ULCERGAS.tsv.gz; fi

### TODO:
# 1.1. Why are we using BMI (continuous) when we could use obesity? That seems like a more robust phenotype. Should be OK, but consider it...
### NOTES:
# 2.1.  We download files as .bgz but rename them as .gz, as `gunzip` will effectively refuse a .bgz file, but this effectively cheats the program that seems to otherwise be confused.
