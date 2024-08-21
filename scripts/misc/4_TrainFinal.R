### LAST VERSION UPDATED 10 JUNE 2024 (v1.1).
### THIS SCRIPT FITS THE FINAL MODEL, I.E. A MODEL TRAINED ON ALL DATA, WITHOUT CROSS-VALIDATION.

.libPaths("H:/Programs/RLibrary/")
library(argparser)
library(caret)
library(doParallel)
library(dplyr)
library(foreach)
library(readr)
library(stringr)

### 1. SETUP

args <- arg_parser('') %>% add_argument('TRAIN', help = '', type = 'character') %>% add_argument('MODEL', help = '', type = 'character') %>% add_argument('OUTCOME', help = '', type = 'character') %>% parse_args()
#! Safety belt on inputs here. Existence of file / correct model name / correct outcome name.

labels.df <- read_tsv("data/LABELS.FOLDS.tsv", show_col_types = F) %>% select(pid, FOLD.ID = PRIMARY.FOLD, everything())
if(str_detect(args$TRAIN, "\\.tsv")) train.raw <- read_tsv(args$TRAIN, show_col_types = F)
if(str_detect(args$TRAIN, "\\.rds")) train.raw <- readRDS(args$TRAIN)

train.df <- labels.df %>% select(pid, FOLD.ID, OUTCOME = all_of(args$OUTCOME)) %>%
    inner_join(train.raw, by = "pid") %>%
    filter(!is.na(OUTCOME)) %>% filter(!is.na(FOLD.ID)) %>% 
    mutate(OUTCOME = ifelse(OUTCOME == 1, "YES", "NO") %>% as.factor(), .before = everything())

### 2. SUPERVISED LEARNING

cl <- makePSOCKcluster(8)       #Might error on Windows! Try makeForkCluster instead; wait it is the opposite right? Just use `makeCluster()` to be safe...
registerDoParallel()

set.seed(314159)
train.sub.df <- train.df %>% select(-pid, -FOLD.ID, -index_date, -TOTAL_TKOST)
trainControl.object <- trainControl(method = "cv", number = 10, summaryFunction = twoClassSummary, classProbs = T, returnData = F, allowParallel = T)

if(args$MODEL == "logreg") pred.model <- train(OUTCOME ~ ., data = train.sub.df, method = "glm", family = binomial(link  = "logit"))		#LOGREG

if(args$MODEL == "glmnet"){	#GLMNET
    ALPHA.grid <- c(0, 0 + 1e-3, seq(0.05, 0.95, length.out = 16), 1 - 1e-3, 1); LAMBDA.grid <- exp(seq(log(1e+4), log(1e-4), length.out = 100))
    GLMNET.grid <- expand.grid(alpha = ALPHA.grid, lambda = LAMBDA.grid)
    pred.model <- train(OUTCOME ~ ., data = train.sub.df, method = "glmnet", family = "binomial", tuneGrid = GLMNET.grid, trControl = trainControl.object, metric = "ROC")
}

if(args$MODEL == "rndfor"){	#RNDFOR
    MTRY.grid <-  c(seq(1, sqrt(ncol(train.sub.df) - 1), length.out = 10), seq(sqrt(ncol(train.sub.df) - 1), ncol(train.sub.df) - 1, length.out = 10)) %>% floor() %>% unique()
    RNDFOR.grid <- expand.grid(mtry = MTRY.grid, min.node.size = 1, splitrule = "gini")
    pred.model <- train(OUTCOME ~ ., data = train.sub.df, method = "ranger", tuneGrid = RNDFOR.grid, trControl = trainControl.object, metric = "ROC", num.trees = 1500)
}

if(args$MODEL == "xgbost"){	#XGBOST
    NROUNDS.grid <- c(50, 100, 500, 1000, 5000, 10000); ETA.grid <- ETA_GRID <- c(exp(seq(log(0 + 1e-3), log(0.3), length.out = 10)), exp(seq(log(0.4), log(1 - 1e-3), length.out = 10)))
    MAXDEPTH.grid <- c(1, 3, 6, 10, 20, 50, 1e+6)
    SUBSAMPLE.grid <- c(0.35, 0.5, 0.65, 0.80, 0.95, 1.00); COLSAMPLE.grid <- c(0.25, 0.50, 0.75, 1.00)
    XGBOST.grid <- expand.grid(nrounds = NROUNDS.grid, eta = ETA.grid, max_depth = MAXDEPTH.grid, gamma = 0, min_child_weight = 1, subsample = SUBSAMPLE.grid, colsample_bytree = COLSAMPLE.grid)
    trainControl_object <- trainControl(method = "cv", number = 10, summaryFunction = twoClassSummary, classProbs = T, returnData = F, allowParallel = F)    #See NOTES 2.3.
    pred.model <- train(OUTCOME ~ ., data = train.sub.df, method = "xgbTree", trControl = trainControl.object, metric = "ROC", verbosity = 0)
}

stopCluster(cl)

pred.df <- data.frame(pid = train.df$pid, OUTCOME = train.df$OUTCOME)
pred.res <- predict(pred.model, train.df, type = "prob")
pred.df$PROB <- pred.res$YES

saveRDS(pred.model, str_c("data/output/res/", str_extract(args$TRAIN, "TRAIN\\d"), ".", args$MODEL, ".", args$OUTCOME, ".rds"))
write.table(pred.df, str_c("data/output/res/", str_extract(args$TRAIN, "TRAIN\\d"), ".", args$MODEL, ".", args$OUTCOME, ".tsv"), col.names = T, row.names = F, sep = "\t", quote = F)