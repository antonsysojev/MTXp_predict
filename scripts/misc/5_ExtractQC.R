#!/usr/bin/env Rscript
### LAST VERSION UPDATED 7 MAY 2024 (v1.0).
### THIS SCRIPT EXTRACTS TABLE S4 FOR THE MANUSCRIPT, CONTAINING THE VARIANTS AND INDIVIDUALS FILTERED OUT DURING THE QUALITY CONTROL.

.libPaths("/home2/genetics/antobe/software/RLibrary")
library(dplyr)
library(stringr)

qc.df <- data.frame(QC = readLines("data/log/EIRA-SRQB.QC.log")) %>% as_tibble()

### 1. EXTRACTING VARIANTS AND INDIVIDUALS

qc.snp <- qc.df %>% filter(str_detect(QC, "\\d+ variants remaining after")) %>% mutate(N = str_extract(QC, "\\d+")) %>% distinct(N) %>% slice(1:(nrow(.) - 1)) %>% mutate(STEP = c("1.RSQ", "3.GENO-MIND-MAF", "4.HWE"))
qc.snp.0 <- qc.df %>% filter(str_detect(QC, "\\d+ variants loaded")) %>% mutate(N = str_extract(QC, "\\d+")) %>% slice(1) %>% select(N) %>% mutate(STEP = "0.RAW")

qc.ind <- qc.df %>% filter(str_detect(QC, "\\d+ samples .+ remaining")) %>% mutate(N = str_extract(QC, "\\d+")) %>% distinct(N) %>% slice(-1)  %>% mutate(STEP = c("2.SEX", "5.REL", "6.PCA"))
qc.ind.0 <- qc.df %>% filter(str_detect(QC, "\\d+ samples .+ loaded")) %>% mutate(N = str_extract(QC, "\\d+")) %>% slice(1) %>% select(N) %>% mutate(STEP = "0.RAW")

### 2. CLEANING UP DATA

qc.snp %>% bind_rows(qc.snp.0) %>% bind_rows(qc.ind) %>% bind_rows(qc.ind.0) %>% arrange(STEP) %>% write.table("data/output/res/TableS5.qc", col.names = T, row.names = F, sep = "\t", quote = F)
