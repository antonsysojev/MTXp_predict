#!/usr/bin/env Rscript
### LAST UPDATED 13 SEPT 2023 (v1.2) - NOW ONLY FILTERS WITHIN THE NPR AND PDR DATA
### THIS SCRIPT FILTERS THE VARIABLES IN THE LARGE NPR AND PDR TRAINING DATA ON VARIATION

.libPaths("/home2/genetics/antobe/software/RLibrary")
suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(stringr)))

MEDICAL <- read_tsv("data/MEDICAL.tsv", show_col_types = F)
DRUG <- read_tsv("data/DRUG.tsv", show_col_types = F)

VARIANCE_CUTOFF <- 0.01

### ### ### 2.1.1.1. FILTERING ON VARIANCE

MEDICAL_VARIANCE <- MEDICAL %>% select(-pid, -index_date) %>% summarise_all(var, na.rm = T) %>% t()
DRUG_VARIANCE <- DRUG %>% select(-pid, -index_date) %>% summarise_all(var, na.rm = T) %>% t()

MEDICAL_VALID <- MEDICAL_VARIANCE[MEDICAL_VARIANCE >= VARIANCE_CUTOFF, ]
DRUG_VALID <- DRUG_VARIANCE[DRUG_VARIANCE >= VARIANCE_CUTOFF, ]

MEDICAL_FILTERED <- MEDICAL %>% select(pid, index_date, MEDICAL_VALID %>% names())
DRUG_FILTERED <- DRUG %>% select(pid, index_date, DRUG_VALID %>% names())

### ### ### 2.1.1.2. AGGREGATING AND WRITING DATA

df <- MEDICAL_FILTERED %>% left_join(DRUG_FILTERED %>% select(-index_date), by = "pid")
write.table(df, "TMP/tmp-2/MEDICAL-DRUG.VARFILT.tsv", col.names = T, row.names = F, quote = F, sep = "\t")

### TO DO:
### NOTES:
