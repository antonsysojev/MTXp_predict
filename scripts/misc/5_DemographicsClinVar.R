#!/usr/bin/env Rscript
### LAST VERSION UPDATED 18 JUNE 2024 (v1.1).
### THIS SCRIPT EXTRACTS TABLES CONTAINING DISTRIBUTIONS OF THE SOCIODEMOGRAPHICS VARIABLES.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(openxlsx)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

sociodemographics.df <- read_tsv("data/SOCIODEMOGRAPHICS.tsv")
clinical.df <- read_tsv("data/CLINICAL.tsv")
labels.df <- read_tsv("data/LABELS.FOLDS.tsv")
cohort.df <- read_tsv("data/output/TRAIN1_NONGENETIC.tsv") %>% distinct(pid)

df <- sociodemographics.df %>% inner_join(clinical.df, by = "pid") %>% inner_join(labels.df, by = "pid") %>% inner_join(cohort.df, by = "pid")
outcome.id <- c("persistence_d365", "persistence_d1096")

### 1. COUNTS AND PERCENTAGES

counts.list <- list()
counts.id <- c("SEX", "BORN_IN_SWEDEN", "FDR_wRA", "EDUCATION", "SMOKE", "SEROPOSITIVITY_COMBINED", "STEROID", "NSAID")
counts.list[[1]] <- map(counts.id, function(x) df %>% select(VAR = all_of(x)) %>% filter(!is.na(VAR)) %>% group_by(VAR) %>% summarise(N = n()) %>% ungroup() %>% mutate(N.TOT = sum(N), N.PERC = N / N.TOT) %>% mutate(OUT = 1, OUT.ID = "TOTAL", VAR.ID = x))

outcome.counts.df <- expand.grid(OUTCOME = outcome.id, VAR = counts.id) %>% arrange(OUTCOME, VAR)
counts.list[[2]] <- map2(outcome.counts.df[, "OUTCOME"], outcome.counts.df[, "VAR"], function(x, y) df %>% select(OUT = all_of(x), VAR = all_of(y)) %>% filter(!is.na(VAR)) %>% group_by(OUT, VAR) %>% summarise(N = n(), .groups = "drop") %>% group_by(OUT) %>% mutate(N.TOT = sum(N)) %>% mutate(N.PERC = N / N.TOT, OUT.ID = x, VAR.ID = y))

### 2. MEDIAN AND IQR

medians.list <- list()
medians.id <- c("AGE", "TIME_INHOSP", "DisabilityPension_Days", "SickLeave_Days", "COST_DRUG", "duration", "svullna_leder", "omma_leder", "sr", "crp", "patientens_globala", "haq", "smarta")
medians.list[[1]] <- map(medians.id, function(x) df %>% select(VAR = all_of(x)) %>% summarise(MEDIAN = median(VAR, na.rm = T), MIN = min(VAR, na.rm = T), MAX = max(VAR, na.rm = T), IQR = IQR(VAR, na.rm = T)) %>% mutate(OUTCOME = 1, OUTCOME.ID = "TOTAL", VAR.ID = x))

outcome.medians.df <- expand.grid(OUTCOME = outcome.id, VAR = medians.id) %>% arrange(OUTCOME, VAR)
medians.list[[2]] <- map2(outcome.medians.df[, "OUTCOME"], outcome.medians.df[, "VAR"], function(x, y) df %>% select(OUTCOME = all_of(x), VAR = all_of(y)) %>% group_by(OUTCOME) %>% summarise(MEDIAN = median(VAR, na.rm = T), MIN = min(VAR, na.rm = T), MAX = max(VAR, na.rm = T), IQR = IQR(VAR, na.rm = T), .groups = "drop") %>% mutate(OUTCOME.ID = x, VAR.ID = y))

### 3. CLEAN DATA

counts.long.df <- counts.list %>% bind_rows() %>% mutate(ESTIMATE = str_c(N, " (", 100 * round(N.PERC, 2), "%)")) %>% select(VAR.ID, ESTIMATE, VAR, OUT, OUT.ID)
counts.wide.df <- counts.long.df %>% filter(!is.na(OUT), !is.na(VAR)) %>% group_by(VAR.ID) %>% filter(VAR == 1 | n() > 2 * 5) %>% ungroup() %>% pivot_wider(names_from = c(OUT.ID, OUT), values_from = ESTIMATE) %>% mutate(VAR.ID = str_c(VAR.ID, "_", VAR)) %>% select(-VAR)

medians.long.df <- medians.list %>% bind_rows() %>% mutate(ESTIMATE = str_c(MEDIAN, " (", IQR, "; ", MIN, "-", MAX, ")")) %>% select(VAR.ID, ESTIMATE, OUTCOME, OUTCOME.ID)
medians.wide.df <- medians.long.df %>% filter(!is.na(OUTCOME)) %>% pivot_wider(names_from = c(OUTCOME.ID, OUTCOME), values_from = ESTIMATE)

### 4. OUTPUT DATA

#! Lacks sorting of rows to fit the desired order...
#! Lacks row header...

demographics.id <- c("SEX", "BORN_IN_SWEDEN", "FDR_wRA", "EDUCATION", "SMOKE", "AGE", "TIME_INHOSP", "DisabilityPension_Days", "SickLeave_Days", "COST_DRUG")
clinvar.id <- c("SEROPOSITIVITY", "STEROID", "NSAID", "duration", "svullna_leder", "omma_leder", "sr", "crp", "patientens_globala", "haq", "smarta")

counts.wide.df %>% bind_rows(medians.wide.df) %>% 
  filter(str_detect(VAR.ID, str_c(demographics.id, collapse = "|"))) %>% 
  select(VAR.ID, TOTAL_1, persistence_d365_1, persistence_d365_0, persistence_d1096_1, persistence_d1096_0) %>%
  write.xlsx("data/output/res/TableDemographics.xlsx")

counts.wide.df %>% bind_rows(medians.wide.df) %>% 
  filter(str_detect(VAR.ID, str_c(clinvar.id, collapse = "|"))) %>% 
  select(VAR.ID, TOTAL_1, persistence_d365_1, persistence_d365_0, persistence_d1096_1, persistence_d1096_0) %>%
  write.xlsx("data/output/res/TableClinVar.xlsx")