#!/usr/bin/env Rscript
### LAST VERSION UPDATED 7 MAY 2024 (v1.0).
### THIS SCRIPT EXTRACTS TABLE S1 AND S2 FOR THE MANUSCRIPT, CONTAINING COUNTS FOR THE SOCIODEMOGRAPHICS VARIABLES.

.libPaths("/home2/genetics/antobe/software/RLibrary")
library(dplyr)
library(openxlsx)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

sero.id <- c("seropos", "seroneg")
outcome.id <- c("persistence_d365", "persistence_d1096")
id.df <- expand.grid(sero.id = sero.id, outcome.id = outcome.id)

train.list <- list()
for(i in 1:nrow(id.df)){

    # AUC-ESTIMATES

    TRAIN.1 <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN1.", id.df[i, "sero.id"], ".tsv"), show_col_types = F) %>% mutate(TRAIN = 1)
    TRAIN.2 <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN2.", id.df[i, "sero.id"], ".tsv"), show_col_types = F) %>% mutate(TRAIN = 2)
    TRAIN.3 <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN3.", id.df[i, "sero.id"], ".tsv"), show_col_types = F) %>% mutate(TRAIN = 3)
    TRAIN.4 <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN4.", id.df[i, "sero.id"], ".tsv"), show_col_types = F) %>% mutate(TRAIN = 4)

    TRAIN.auc <- TRAIN.1 %>% bind_rows(TRAIN.2) %>% bind_rows(TRAIN.3) %>% bind_rows(TRAIN.4) %>% group_by(MODEL, TRAIN) %>% summarise(MU = mean(MU), ST.ERR = mean(ST.ERR), .groups = "drop") %>% mutate(MODEL.TRAIN = str_c(MODEL, ".", TRAIN))

    # CONFIDENCE INTERVALS

    TRAIN.1.ci <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN1.", id.df[i, "sero.id"], ".ConfidenceInterval.tsv"), show_col_types = F) %>% mutate(TRAIN = 1)
    TRAIN.2.ci <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN2.", id.df[i, "sero.id"], ".ConfidenceInterval.tsv"), show_col_types = F) %>% mutate(TRAIN = 2)
    TRAIN.3.ci <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN3.", id.df[i, "sero.id"], ".ConfidenceInterval.tsv"), show_col_types = F) %>% mutate(TRAIN = 3)
    TRAIN.4.ci <- read_tsv(str_c("data/output/res/", id.df[i, "outcome.id"], "/TRAIN4.", id.df[i, "sero.id"], ".ConfidenceInterval.tsv"), show_col_types = F) %>% mutate(TRAIN = 4)

    TRAIN.ci <- TRAIN.1.ci %>% bind_rows(TRAIN.2.ci) %>% bind_rows(TRAIN.3.ci) %>% bind_rows(TRAIN.4.ci) %>% pivot_longer(cols = c(V1:V5)) %>% group_by(MODEL, TYPE, TRAIN) %>% summarise(MU = mean(value, na.rm = T), .groups = "drop") %>% mutate(MODEL.TRAIN = str_c(MODEL, ".", TRAIN))

    train.list[[i]] <- TRAIN.auc %>% select(MODEL.TRAIN, AUROC = MU, ST.ERR) %>% left_join(TRAIN.ci %>% select(MODEL.TRAIN, MU, TYPE, MODEL, TRAIN), by = "MODEL.TRAIN") %>%
		 		     pivot_wider(names_from = TYPE, values_from = MU) %>%
				     mutate(ESTIMATE = str_c(round(AUROC, 4), " (", round(ST.ERR, 4), "; ", round(LOWER, 4), " - ", round(UPPER, 4), ")")) %>%
				     select(MODEL, TRAIN, ESTIMATE) %>%
				     pivot_wider(names_from = TRAIN, values_from = ESTIMATE) %>% 
				     select(MODEL, TRAIN.1 = `1`, TRAIN.2 = `2`, TRAIN.3 = `3`, TRAIN.4 = `4`) %>% slice(2, 1, 3, 4) %>% mutate(TYPE = str_c(id.df[i, "outcome.id"], ".", id.df[i, "sero.id"]))

}

train.list %>% bind_rows() %>% write.xlsx("data/output/res/TableS7.auc.xlsx")
