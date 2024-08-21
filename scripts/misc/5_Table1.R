#!/usr/bin/env bash
### LAST VERSION UPDATED 8 MAY 2024 (v1.0).
### THIS SCRIPT EXTRACTS THE TABLE 1 DATA, CONTAINING THE AVERAGE AUC.

.libPaths("/home2/genetics/antobe/software/RLibrary")
library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

outcome.ls.raw <- list.files("data/output/res")
outcome.ls <-  outcome.ls.raw[!str_detect(outcome.ls.raw, "\\.")]

outcome.list <- list()
for(i in 1:length(outcome.ls)){

    train.ls.raw <- list.files(str_c("data/output/res/", outcome.ls[i]))
    train.ls <- train.ls.raw[str_detect(train.ls.raw, "TRAIN\\d\\.tsv")]

    train.list <- list()
    for(j in 1:length(train.ls)){
	train.raw.df <- read_tsv(str_c("data/output/res/", outcome.ls[i], "/", train.ls[j]), show_col_types = F)

	train.raw.ci <- read_tsv(str_c("data/output/res/", outcome.ls[i], "/", str_replace(train.ls[j], "tsv", "ConfidenceInterval.tsv")), show_col_types = F)
	train.ci.long <- train.raw.ci %>% pivot_longer(cols = c(V1, V2, V3, V4, V5)) %>% group_by(MODEL, TYPE) %>% summarise(MU = mean(value), .groups = "drop")
	train.ci <- train.ci.long %>% pivot_wider(names_from = TYPE, values_from = MU) %>% mutate(CI = str_c("(", round(LOWER, 4), " - ", round(UPPER, 4), ")")) %>% select(MODEL, CI)

	train.list[[j]] <- train.raw.df %>% distinct(MODEL, MU, ST.ERR) %>% left_join(train.ci, by = "MODEL") %>% mutate(ESTIMATE = str_c(round(MU, 4), " (", round(ST.ERR, 4), "; ", CI, ")"), TRAIN = j) %>% select(MODEL, ESTIMATE, TRAIN)
    }
    outcome.list[[i]] <- train.list %>% bind_rows() %>% mutate(TRAIN = str_c("ESTIMATE.", TRAIN)) %>% pivot_wider(names_from = TRAIN, values_from = ESTIMATE) %>% mutate(OUTCOME = outcome.ls[i])
}

outcome.list %>% bind_rows() %>% write.table("data/output/res/Table1.auc", col.names = T, row.names = F, sep = "\t", quote = F)
