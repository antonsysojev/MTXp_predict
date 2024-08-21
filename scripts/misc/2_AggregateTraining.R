#!/usr/bin/env Rscript
### LAST VERSION UPDATED 2 MAY 2024 (v2.0).
### THIS SCRIPT COMBINES RAW DATA INTO FOUR DISTINCT SETS TO BE USED FOR TRAINING.

.libPaths("/home2/genetics/antobe/software/RLibrary")
suppressWarnings(suppressMessages(library(bigsnpr)))
suppressWarnings(suppressMessages(library(DescTools)))
suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(purrr)))
suppressWarnings(suppressMessages(library(stringr)))
suppressWarnings(suppressMessages(library(tidyr)))

KEY.df <- read_tsv("data/KEY.tsv", show_col_types = F)

### 1. EXTRACT NON-GENETIC DATA

TRAIN.1.df <- read_tsv("TMP/tmp-2/NONGENETIC.tsv", show_col_types = F)

### 2. EXTRACT NON-GENETIC AND PRS DATA

WD.ls <- list.files("data/GWAS/") %>% str_remove("\\..+") %>% sort() %>% unique()
PRS.list <- map(WD.ls, function(x) read_tsv(str_c("data/GWAS/", x, ".PRSPCA"), show_col_types = F) %>% select(FID, IID, PRSPCA = 3) %>% mutate(PRS = x))
PRS.df <- PRS.list %>% bind_rows() %>% pivot_wider(names_from = PRS, values_from = PRSPCA) %>% inner_join(KEY.df %>% distinct(pid, gid), by = c("IID" = "gid"))

TRAIN.2.df <- TRAIN.1.df %>% inner_join(PRS.df, by = "pid") %>% select(-FID, -IID) %>% distinct()

### 3. EXTRACT NON-GENETIC, PRS AND PCA DATA

PCA.raw <- read.table("data/output/EIRA-SRQB.QC.pca"); colnames(PCA.raw) <- c("FID", "IID", str_c("PC.", 1:(ncol(PCA.raw)-2)))
PCA.df <- PCA.raw %>% left_join(KEY.df %>% distinct(pid, gid), by = c("IID" = "gid"))

TRAIN.3.df <- TRAIN.2.df %>% inner_join(PCA.df, by = "pid") %>% select(-FID, -IID) %>% distinct()

### 4. EXTRACT NON-GENETIC AND SNP DATA

SNP.raw <- readRDS("data/output/EIRA-SRQB.QC.variants.rds")
SNP.df <- SNP.raw %>% inner_join(KEY.df %>% distinct(pid, gid), by = c("IID" = "gid"))
SNP.df.cp <- SNP.df

for(i in 1:ncol(SNP.df)){	#Mode imputation for missing variants
    if(any(is.na(SNP.df[, i]))){
        col.mode <- Mode(SNP.df[, i], na.rm = T)[1]    #Uses `DescTools::Mode` for mode computation - note that it takes 'the first' if there are multiple modes...
	SNP.df[is.na(SNP.df[, i]), i] <- col.mode
    }
    if(i %% 10000 == 00) print(str_c("Iteration ", i, " completed..."))
}

TRAIN.4.df <- TRAIN.2.df %>% inner_join(SNP.df, by = "pid") %>% select(-IID) %>% distinct()

### 5. OUTPUT DATA

COHORT.withGenetic.vec <- intersect(intersect(TRAIN.1.df$pid, TRAIN.2.df$pid), intersect(TRAIN.3.df$pid, TRAIN.4.df$pid))
TRAIN.1.df <- TRAIN.1.df %>% filter(pid %in% COHORT.withGenetic.vec)

write.table(TRAIN.1.df, "data/output/TRAIN1_NONGENETIC.tsv", row.names = F, col.names = T, quote = F, sep = "\t")
write.table(TRAIN.2.df, "data/output/TRAIN2_NONGENETIC-PRS.tsv", row.names = F, col.names = T, quote = F, sep = "\t")
write.table(TRAIN.3.df, "data/output/TRAIN3_NONGENETIC-PRS-PCA.tsv", row.names = F, col.names = T, quote = F, sep = "\t")
saveRDS(TRAIN.4.df, "data/output/TRAIN4_NONGENETIC-PRS-SNP.rds")    #Save as .rds as it is faster...
