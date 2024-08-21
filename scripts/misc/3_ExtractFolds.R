#!/usr/bin/env Rscript
### LAST VERSION UPDATE 5 JUNE 2024 (v3.0) - NOW COMBINED STANDARD WITH SEROSTRATIFIED.
### THIS SCRIPT SPLITS DATA INTO FOLDS FOR CROSS-VALIDATION.

.libPaths("/home2/genetics/antobe/software/RLibrary")
library(caret)      #FOR `createFolds()` WHICH IS SIMPLE AND FAST
library(dplyr)
library(haven)
library(lubridate)
library(readr)

labels.df <- read_tsv("data/LABELS.tsv")

### 1. PRIMARY FOLDS

set.seed(314159)
folds.df <- labels.df %>% mutate(PRIMARY.FOLD = createFolds(labels.df$pid, k = 5, list = F)) %>% select(pid, PRIMARY.FOLD, everything()) %>% arrange(pid)

### 2. SEROSTRATIFIED FOLDS

serostatus.df <- read_tsv("data/CLINICAL.tsv", show_col_types = F) %>% select(pid, SEROPOSITIVITY_COMBINED)    #USE THE NON-IMPUTED DATA
labels.seropos.df <- serostatus.df %>% filter(SEROPOSITIVITY_COMBINED == 1) %>% select(-SEROPOSITIVITY_COMBINED)
labels.seroneg.df <- serostatus.df %>% filter(SEROPOSITIVITY_COMBINED == 0) %>% select(-SEROPOSITIVITY_COMBINED)

set.seed(314159)
folds.seropos.df <- labels.seropos.df %>% mutate(SEROPOSITIVE.FOLD = createFolds(labels.seropos.df$pid, k = 5, list = F)) %>% select(pid, SEROPOSITIVE.FOLD) %>% arrange(pid)
folds.seroneg.df <- labels.seroneg.df %>% mutate(SERONEGATIVE.FOLD = createFolds(labels.seroneg.df$pid, k = 5, list = F)) %>% select(pid, SERONEGATIVE.FOLD) %>% arrange(pid)

### 3. COMBINE AND OUTPUT

folds.df %>% left_join(folds.seropos.df, by = "pid") %>% left_join(folds.seroneg.df, by = "pid") %>% 
  select(pid, PRIMARY.FOLD, SEROPOSITIVE.FOLD, SERONEGATIVE.FOLD, everything()) %>%
  write.table("data/LABELS.FOLDS.tsv", col.names = T, row.names = F, quote = F, sep = "\t")
