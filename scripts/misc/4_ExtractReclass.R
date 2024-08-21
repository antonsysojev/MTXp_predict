#!/usr/bin/env Rscript
### LAST VERSION UPDATE 10 JUNE 2024 (v2.1).
### THIS SCRIPT OBTAINS STATISTICS RELATING TO RECLASSIFICATION.

.libPaths("H:/Programs/RLibrary/")
library(argparser)
library(dplyr)
library(readr)
library(stringr)

args <- arg_parser('') %>% add_argument('OUTCOME', help = 'OUTCOME ID', type = 'character') %>% add_argument('TYPE', help = 'TYPE OF RA', type = 'character') %>% add_argument('CUT', help = 'CLASSIFICATION THRESHOLD', type = 'numeric') %>% parse_args()
prob.df <- read_tsv(str_c("data/output/res/", args$OUTCOME, "/PredRes.", args$TYPE, ".tsv"))
prob.label.df <- prob.df %>% mutate(LOGREG = ifelse(LOGREG < args$CUT, "NO", "YES"), GLMNET = ifelse(GLMNET < args$CUT, "NO", "YES"), RNDFOR = ifelse(RNDFOR < args$CUT, "NO", "YES"), XGBOST = ifelse(XGBOST < args$CUT, "NO", "YES"))

reclass.list.outer <- list()
model.id <- c("LOGREG", "GLMNET", "RNDFOR", "XGBOST")
source("scripts/utils/Reclassification.R")
for(i in 1:5){    #LOOP OVER EACH FOLD
  
  prob.label.fold.df <- prob.label.df %>% filter(FOLD.ID == i) %>% select(-FOLD.ID)
  
  reclass.list.inner <- list()
  for(j in 1:length(model.id)){    #LOOP OVER EACH MODEL
    
    prob.label.fold.model.df <- prob.label.fold.df %>% select(pid, OUTCOME, PRED.LABEL = all_of(model.id[j]), TRAIN)
    
    total.12 <- reclassification.total.fun(prob.label.fold.model.df %>% filter(TRAIN == "TRAIN1"), prob.label.fold.model.df %>% filter(TRAIN == "TRAIN2"))
    total.13 <- reclassification.total.fun(prob.label.fold.model.df %>% filter(TRAIN == "TRAIN1"), prob.label.fold.model.df %>% filter(TRAIN == "TRAIN3"))
    total.14 <- reclassification.total.fun(prob.label.fold.model.df %>% filter(TRAIN == "TRAIN1"), prob.label.fold.model.df %>% filter(TRAIN == "TRAIN4"))
    total.num <- c(total.12, total.13, total.14)
    
    net.12 <- reclassification.net.fun(prob.label.fold.model.df %>% filter(TRAIN == "TRAIN1"), prob.label.fold.model.df %>% filter(TRAIN == "TRAIN2"))
    net.13 <- reclassification.net.fun(prob.label.fold.model.df %>% filter(TRAIN == "TRAIN1"), prob.label.fold.model.df %>% filter(TRAIN == "TRAIN3"))
    net.14 <- reclassification.net.fun(prob.label.fold.model.df %>% filter(TRAIN == "TRAIN1"), prob.label.fold.model.df %>% filter(TRAIN == "TRAIN4"))
    net.num <- c(sum(net.12), sum(net.13), sum(net.14))
    
    reclass.list.inner[[j]] <- data.frame(TOTAL = total.num, NET = net.num, PAIRING = c("12", "13", "14")) %>% mutate(MODEL.ID = model.id[j])
  }
  
  reclass.list.outer[[i]] <- reclass.list.inner %>% bind_rows() %>% mutate(FOLD.ID = i)
  
}

reclass.df <- reclass.list.outer %>% bind_rows() %>% as_tibble()
write.table(reclass.df, str_c("data/output/res/", args$OUTCOME, "/Reclass.", args$TYPE, ".tsv"), col.names = T, row.names = F, quote = F, sep = "\t")