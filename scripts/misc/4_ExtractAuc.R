#!/usr/bin/env Rscript
### LAST VERSION UPDATED 10 JUNE 2024 (v1.0).
### THIS SCRIPT EXTRACTS AUC AND BOOTSTRAP CONFIDENCE INTERVALS

.libPaths("H:/Programs/RLibrary/")
library(argparser)
library(dplyr)
library(pROC)
library(readr)
library(stringr)
#library(tidyr)

args <- arg_parser('') %>% add_argument('OUTCOME', help = 'OUTCOME ID', type = 'character') %>% add_argument('TYPE', help = 'TYPE OF RA', type = 'character') %>% parse_args()
prob.df <- read_tsv(str_c("data/output/res/", args$OUTCOME, "/PredRes.", args$TYPE, ".tsv"))

auc.list.outer <- list()
for(i in 1:4){    #LOOP OVER EACH TRAINING SET
  
  prob.df.train <- prob.df %>% filter(TRAIN == str_c("TRAIN", i))
  auc.df <- data.frame(ESTIMATE = c("CI.L", "AUC", "CI.U")); auc.list.inner <- list()
  
  for(j in 1:5){    #LOOP OVER EACH FOLD - NOTE THAT THIS CAN BE DONE WITHOUT TAKING FOLD INTO ACCOUNT BUT THIS SEEMS MORE CORRECT
    
    prob.df.train.fold <- prob.df.sub %>% filter(FOLD.ID == j)
    auc.df$LOGREG <- pROC::ci.auc(prob.df.train.fold$OUTCOME, prob.df.train.fold$LOGREG, quiet = T) %>% as.numeric()
    auc.df$GLMNET <- pROC::ci.auc(prob.df.train.fold$OUTCOME, prob.df.train.fold$GLMNET, quiet = T) %>% as.numeric()
    auc.df$RNDFOR <- pROC::ci.auc(prob.df.train.fold$OUTCOME, prob.df.train.fold$RNDFOR, quiet = T) %>% as.numeric()
    auc.df$XGBOST <- pROC::ci.auc(prob.df.train.fold$OUTCOME, prob.df.train.fold$XGBOST, quiet = T) %>% as.numeric()
    auc.list.inner[[j]] <- auc.df %>% mutate(FOLD.ID = j)
    
  }
  
  auc.list.outer[[i]] <- auc.list.inner %>% bind_rows() %>% mutate(TRAIN = str_c("TRAIN", i))
  
}

auc.raw <- auc.list.outer %>% bind_rows() %>% as_tibble() %>% arrange(TRAIN, FOLD.ID)
write.table(auc.raw, str_c("data/output/res/", args$OUTCOME, "/AUCRaw.", args$TYPE, ".tsv"), col.names = T, row.names = F, sep = "\t", quote = F)