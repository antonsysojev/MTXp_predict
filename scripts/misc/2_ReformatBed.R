#!/usr/bin/env Rscript
### LAST VERSION UPDATED 2 MAY 2024 (v2.0).
### THIS SCRIPT EXTRACTS THE NEAR-INDEPENDENT VARIANTS FROM THE .bed FILE AND OUTPUTS THE REMAINING SNPS IN TABULAR FORMAT.

.libPaths("/home2/genetics/antobe/software/RLibrary")
suppressMessages(suppressWarnings(library(argparser)))
suppressMessages(suppressWarnings(library(bigsnpr)))
suppressMessages(suppressWarnings(library(dplyr)))

args <- arg_parser('') %>% add_argument('BED', help = 'PATH TO .bed FILE', type = 'character') %>% parse_args()

snp_readBed(args$BED, "TMP/tmp-2/EIRA-SRQB.QC.ldprune.ldprune")
BFILE <- snp_attach("TMP/tmp-2/EIRA-SRQB.QC.ldprune.ldprune.rds")

BFILE.df <- BFILE$genotypes[1:nrow(BFILE$fam), 1:nrow(BFILE$map)] %>% as.data.frame() %>% mutate(IID = BFILE$fam$sample.ID, .before = everything())
colnames(BFILE.df) <- c("IID", BFILE$map$marker.ID)
saveRDS(BFILE.df, "data/output/EIRA-SRQB.QC.variants.rds")
