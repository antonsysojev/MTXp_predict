#!/usr/bin/env Rscript
### LAST VERSION UPDATED 5 JUNE 2024 (v3.0) - NOW TAKES ALL SUBTYPES AS INPUT, ONE SCRIPT TO RULE THEM ALL
### THIS SCRIPT PERFORMS THE SUPERVISED LEARNING.

.libPaths("/home2/genetics/antobe/software/RLibrary")
library(argparser)
library(caret)
library(dplyr)
library(readr)
library(stringr)

args <- arg_parser('') %>% add_argument('TRAIN', help = 'FILEPATH TO TRAINING .tsv', type = 'character') %>% 
                           add_argument('OUTCOME', help = 'OUTCOME VARIABLE NAME', type = 'character') %>% 
                           add_argument('TYPE', help = 'TYPE OF RA', type = 'character') %>% parse_args()
if(!file.exists(args$TRAIN)) stop("FAILED TO FIND INPUT TRAINING DATA - BAD FILE PATH...")	#Safety belts for input!
if(any(sapply(c(".logreg", ".glmnet", ".rndfor", ".xgbost"), function(x) file.exists(str_c("data/output/res/", args$OUTCOME, "/", str_extract(args$TRAIN, "TRAIN\\d"), x, ".rds"))))) stop("RESULTS ALREADY EXIST - PLEASE CLEAR OUT FIRST")

labels.df <- read_tsv("data/LABELS.FOLDS.tsv", show_col_types = F) %>% select(FOLD.ID = str_c(args$TYPE, ".FOLD"), everything())
if(str_detect(args$TRAIN, "\\.tsv")) train.raw <- read_tsv(args$TRAIN, show_col_types = F)
if(str_detect(args$TRAIN, "\\.rds")) train.raw <- readRDS(args$TRAIN)

### 1. SETUP AND PROCESS DATA

train.df <- labels.df %>% select(pid, FOLD.ID, OUTCOME = all_of(args$OUTCOME)) %>%
    inner_join(train.raw, by = "pid") %>% select(-pid) %>%
    filter(!is.na(OUTCOME)) %>% filter(!is.na(FOLD.ID)) %>%
    mutate(OUTCOME = ifelse(OUTCOME == 1, "YES", "NO") %>% as.factor(), .before = everything())

### 2. PIPELINE FOR SUPERVISED ANALYSIS

cl <- makePSOCKcluster(8)	    #Might error on Windows! Try makeCluster instead...
registerDoParallel()

M1.list <- M2.list <- M3.list <- M4.list <- list()
set.seed(314159)

for(i in 1:max(labels.df$FOLD.ID)){
  
  print(paste0("INITIATING WORK ON FOLD, ", i, "... PLEASE HOLD..."))
  train.fold.df <- train.df %>% filter(FOLD.ID != i) %>% select(-FOLD.ID, -index_date)
  trainControl_object <- trainControl(method = "cv", number = 10, summaryFunction = twoClassSummary, classProbs = T, returnData = F, allowParallel = T)    #Details in NOTE 2.1.
  
  #LOGISTIC REGRESSION
  if(!str_detect(args$TRAIN, "TRAIN4")){    #AVOID LOGISTIC REGRESSION FOR TRAIN4 - IT IS TOO BIG...
    M1.list[[i]] <- train(OUTCOME ~ ., data = train.fold.df, method = "glm", trControl = trainControl(method = "none", summaryFunction = twoClassSummary, classProbs = T, returnData = F), family = binomial(link = "logit"))
    saveRDS(M1.list, paste0("data/output/res/", args$OUTCOME, "/", str_extract(args$TRAIN, "TRAIN\\d"), ".logreg.rds"))
  }

  #ELASTIC NET
  ALPHA.grid <- c(0, 0 + 1e-3, seq(0.05, 0.95, length.out = 16), 1 - 1e-3, 1)
  LAMBDA.grid <- exp(seq(log(1e+4), log(1e-4), length.out = 100))            
  GLMNET.grid <- expand.grid(alpha = ALPHA.grid, lambda = LAMBDA.grid)
  
  M2.list[[i]] <- train(OUTCOME ~ ., data = train.fold.df, method = "glmnet", family = "binomial", tuneGrid = GLMNET.grid, trControl = trainControl_object, metric = "ROC")
  saveRDS(M2.list, paste0("data/output/res/", args$OUTCOME, "/", str_extract(args$TRAIN, "TRAIN\\d"), ".glmnet.rds")) 
  print(paste0("ELASTIC NET TRAINED WITHIN FOLD ", i, "..."))
  
  #RANDOM FOREST
  MTRY.grid <-  c(seq(1, sqrt(ncol(train.fold.df) - 1), length.out = 10), seq(sqrt(ncol(train.fold.df) - 1), ncol(train.fold.df) - 1, length.out = 10)) %>% floor() %>% unique()
  RNDFOR.grid <- expand.grid(mtry = MTRY.grid, min.node.size = 1, splitrule = "gini")
  
  M3.list[[i]] <- train(OUTCOME ~ ., data = train.fold.df, method = "ranger", tuneGrid = RNDFOR.grid, trControl = trainControl_object, metric = "ROC", num.trees = 1500)
  saveRDS(M3.list, paste0("data/output/res/", args$OUTCOME, "/", str_extract(args$TRAIN, "TRAIN\\d"), ".rndfor.rds"))
  print(paste0("RANDOM FOREST TRAINED WITHIN FOLD ", i, "..."))
  
  #XGBOOST
  NROUNDS.grid <- c(50, 100, 500, 1000, 5000, 10000); ETA.grid <- ETA_GRID <- c(exp(seq(log(0 + 1e-3), log(0.3), length.out = 10)), exp(seq(log(0.4), log(1 - 1e-3), length.out = 10)))
  MAXDEPTH.grid <- c(1, 3, 6, 10, 20, 50, 1e+6)
  SUBSAMPLE.grid <- c(0.35, 0.5, 0.65, 0.80, 0.95, 1.00); COLSAMPLE.grid <- c(0.25, 0.50, 0.75, 1.00)
  XGBOST.grid <- expand.grid(nrounds = NROUNDS.grid, eta = ETA.grid, max_depth = MAXDEPTH.grid, gamma = 0, min_child_weight = 1, subsample = SUBSAMPLE.grid, colsample_bytree = COLSAMPLE.grid)
  trainControl_object <- trainControl(method = "cv", number = 10, summaryFunction = twoClassSummary, classProbs = T, returnData = F, allowParallel = F)    #See NOTES 2.3.
  
  M4.list[[i]] <- train(OUTCOME ~ ., data = train.fold.df, method = "xgbTree", tuneGrid = XGBOST.grid, trControl = trainControl_object, metric = "ROC", verbosity = 0)
  saveRDS(M4.list, paste0("data/output/res/", args$OUTCOME, "/", str_extract(args$TRAIN, "TRAIN\\d"), ".xgbost.rds"))
  print(paste0("XGBOOST TRAINED WITHIN FOLD ", i, "..."))
  
}

stopCluster(cl)

### TO DO:
### NOTES:
# 2.1. I use `twoClassSummary` to get AUROC, which also requires `classProbs = T` as additional input.
# 2.2. Grid choices are extensively detailed in `texts/misc/on hyperparameter tuning.txt`.
# 2.3. Saw strangely slow performance when allowing XGBoost to run in parallel. It is of course sequential at its
#       core, which may be causing the issues? But it should still be able to parallelize over the grid of tuning values.