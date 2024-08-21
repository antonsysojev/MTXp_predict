#!/usr/bin/env Rscript
### LAST VERSION UPDATED 10 JUNE 2024 (v1.0).
### THIS SCRIPT EXTRACTS TESTING PROBABILITIES

.libPaths("H:/Programs/RLibrary/")
library(argparser)
library(caret)
library(dplyr)
library(pROC)
library(readr)
library(stringr)
#library(tidyr)

args <- arg_parser('') %>% add_argument('OUTCOME', help = 'OUTCOME ID', type = 'character') %>% add_argument('TYPE', help = 'TYPE OF RA', type = 'character') %>% parse_args()
labels.df <- read_tsv("data/LABELS.FOLDS.tsv", show_col_types = F) %>% select(FOLD.ID = str_c(args$TYPE, ".FOLD"), everything())
#! Needs a safety belt above to stop at inappropriate inputs (unavailable OUTCOME IDs / UNAVAILABLE TYPES)

prob.list <- list()
training.id <- str_c("data/output/", c("TRAIN1_NONGENETIC.tsv", "TRAIN2_NONGENETIC-PRS.tsv", "TRAIN3_NONGENETIC-PRS-PCA.tsv", "TRAIN4_NONGENETIC-PRS-SNP.rds"))
for(i in 1:4){    #LOOP OVER SETS OF TRAINING DATA
  
  print(str_c("OBTAINING PROBABILITIES FOR ", str_extract(training.id[i], "TRAIN\\d"), " PLEASE HOLD..."))
  
  if(str_detect(training.id[i], "\\.tsv")) test.raw <- read_tsv(training.id[i], show_col_types = F)
  if(str_detect(training.id[i], "\\.rds")) test.raw <- readRDS(training.id[i])
  test.df <- labels.df %>% select(pid, FOLD.ID, OUTCOME = all_of(args$OUTCOME)) %>% inner_join(test.raw, by = "pid") %>% filter(!is.na(OUTCOME)) %>% filter(!is.na(FOLD.ID)) %>%
    mutate(OUTCOME = ifelse(OUTCOME == 1, "YES", "NO") %>% as.factor(), .before = everything())
  
  if(!(ncol(test.df) > nrow(test.df))){ M1.list <- readRDS(str_c("data/output/res/", args$OUTCOME, "/", str_extract(training.id[i], "TRAIN\\d"), ".logreg.rds"))}
  M2.list <- readRDS(str_c("data/output/res/", args$OUTCOME, "/", str_extract(training.id[i], "TRAIN\\d"), ".glmnet.rds"))
  M3.list <- readRDS(str_c("data/output/res/", args$OUTCOME, "/", str_extract(training.id[i], "TRAIN\\d"), ".rndfor.rds"))
  M4.list <- readRDS(str_c("data/output/res/", args$OUTCOME, "/", str_extract(training.id[i], "TRAIN\\d"), ".xgbost.rds"))
  
  fold.prob.list <- list()
  
  for(j in 1:5){    #LOOP OVER FOLDS
    
    test.fold.df <- test.df %>% filter(FOLD.ID == j) %>% select(-FOLD.ID)
    PRED.res <- data.frame(pid = test.fold.df$pid, OUTCOME = test.fold.df$OUTCOME, FOLD.ID = j)
    
    if(!(ncol(test.df) > nrow(test.df))){
      M1.pred <- predict(M1.list[[j]], test.fold.df, type = "prob")
      PRED.res$LOGREG <- M1.pred$YES
    }
    
    M2.pred <- predict(M2.list[[j]], test.fold.df, type = "prob")
    PRED.res$GLMNET <- M2.pred$YES
    
    M3.pred <- predict(M3.list[[j]], test.fold.df, type = "prob")
    PRED.res$RNDFOR <- M3.pred$YES
    
    M4.pred <- predict(M4.list[[j]], test.fold.df, type = "prob")
    PRED.res$XGBOST <- M4.pred$YES
    #! This has gotten loud after some type of update... terribly annoying and it clutters out my own messages...
    
    fold.prob.list[[j]] <- PRED.res
    
  }
  
  prob.list[[i]] <- fold.prob.list %>% bind_rows() %>% as_tibble() %>% mutate(TRAIN = str_extract(training.id[i], "TRAIN\\d"))

}

prob.df <- prob.list %>% bind_rows() %>% arrange(pid)
write.table(prob.df, str_c("data/output/res/", args$OUTCOME, "/PredRes.", args$TYPE, ".tsv"), col.names = T, row.names = F, sep = "\t", quote = F)