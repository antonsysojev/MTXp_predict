#!/usr/bin/env Rscript
### LAST VERSION UPDATED 18 JUNE 2024 (v1.1).
### THIS SCRIPT EXTRACTS TABLE S3, THE TABLE DESCRIBING THE COUNTS FOR THE ICD-10 AND ATC-CODES.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(openxlsx)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

df.raw <- read_tsv("data/output/TRAIN1_NONGENETIC.tsv")
medical.df <- read_tsv("data/MEDICAL.tsv")
drug.df <- read_tsv("data/DRUG.tsv")
labels.df <- read_tsv("data/LABELS.tsv") %>% select(pid, persistence_d365, persistence_d1096)
icd.key <- read_tsv("data/raw/ICD10_subchapters_modifiedFromHW_translated.txt")

medical.labels <- intersect(colnames(df.raw), colnames(medical.df))
drug.labels <- intersect(colnames(df.raw), colnames(drug.df))
labels.character <- c(medical.labels, drug.labels) %>% unique()

df <- df.raw %>% select(all_of(labels.character)) %>% inner_join(labels.df, by = "pid")
outcome.id <- c("persistence_d365", "persistence_d1096")

### 1. COUNTS AND PERCENTAGES

counts.list <- list()
counts.id <- setdiff(labels.character, c("pid", "index_date"))
counts.list[[1]] <- map(counts.id, function(x) df %>% select(VAR = all_of(x)) %>% group_by(VAR) %>% summarise(N = n()) %>% mutate(N.TOT = sum(N), N.PERC = N / N.TOT) %>% mutate(OUT = 1, OUT.ID = "TOTAL", VAR.ID = x))

outcome.counts.df <-  expand.grid(OUTCOME = outcome.id, VAR = counts.id) %>% arrange(OUTCOME, VAR)
counts.list[[2]] <- map2(outcome.counts.df[, "OUTCOME"], outcome.counts.df[, "VAR"], function(x, y) df %>% select(OUT = all_of(x), VAR = all_of(y)) %>% group_by(OUT, VAR) %>% summarise(N = n(), .groups = "drop") %>% group_by(OUT) %>% mutate(N.TOT = sum(N)) %>% mutate(N.PERC = N / N.TOT, OUT.ID = x, VAR.ID = y))

### 2. CLEAN DATA

#! Some subchapters lack English translations because the input file is incomplete...
#! Row headers are missing currently not included.
#! ATC-codes do not have names currently...

counts.long.df <- counts.list %>% bind_rows() %>% mutate(ESTIMATE = str_c(N, " (", 100 * round(N.PERC, 2), "%)")) %>% select(VAR.ID, ESTIMATE, VAR, OUT, OUT.ID)
counts.wide.df <- counts.long.df %>% filter(!is.na(OUT), !is.na(VAR)) %>% filter(VAR == 1) %>% pivot_wider(names_from = c(OUT.ID, OUT), values_from = ESTIMATE) %>% select(-VAR)
counts.df <- counts.wide.df %>% mutate(VAR.ID = str_replace(VAR.ID, "\\_", "\\-")) %>% left_join(icd.key, by = c("VAR.ID" = "ICD")) %>% select(VAR.ID, TOTAL_1, persistence_d365_1, persistence_d365_0, persistence_d1096_1, persistence_d1096_0, ICD.swe, ICD.eng)
medical.counts <- counts.df %>% filter(!is.na(ICD.swe)) %>% mutate(ICD = str_c(str_replace_na(ICD.eng, ""), "(", VAR.ID, ")")) %>% select(ICD, everything()) %>% select(-VAR.ID, -ICD.swe, -ICD.eng)
drug.counts <- counts.df %>% filter(is.na(ICD.swe)) %>% select(-ICD.swe, -ICD.eng)

write.xlsx(medical.counts, str_c(FOLDERPATH, "data/output/res/TableMedicalHistory.xlsx"))
write.xlsx(drug.counts, str_c(FOLDERPATH, "data/output/res/TableDrugHistory.xlsx"))