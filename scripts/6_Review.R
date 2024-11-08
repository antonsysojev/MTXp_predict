### LAST VERSION UPDATED 29 OCTOBER 2024 (v1.3).
### THIS SCRIPT PERFORMS VARIOUS ANALYSES RELATED TO THE REVIEW PROCESS.

FOLDERPATH <- "K:/HW/people/Anton Öberg Sysojev/MTXp_predict/"

### 1. ANALYSIS USING SEX, AGE AND GENETIC DATA

source(paste0(FOLDERPATH, "scripts/misc/6_ExtractSexAgeGenetic.R"))    #Extracts target features

TRAIN365 <- paste0(FOLDERPATH, "data/output/TRAIN_SEXAGE-SNP.rds")
MODEL365 <- "glmnet"
OUTCOME <- "persistence_d365"; TRAIN <- TRAIN365; MODEL <- MODEL365
source(paste0(FOLDERPATH, "scripts/misc/4_TrainFinal.R"))    #Trains model with these features

TRAIN1096 <- paste0(FOLDERPATH, "data/output/TRAIN_SEXAGE-SNP.rds")
MODEL1096 <- "glmnet"
OUTCOME <- "persistence_d1096"; TRAIN <- TRAIN1096; MODEL <- MODEL1096
source(paste0(FOLDERPATH, "scripts/misc/4_TrainFinal.R"))    #Trains model with these features

p365.df <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d365.tsv"))
p365.auc <- pROC::ci.auc(p365.df$OUTCOME, p365.df$PROB, quiet = T) %>% as.numeric()
p1096.df <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d1096.tsv"))
p1096.auc <- pROC::ci.auc(p1096.df$OUTCOME, p1096.df$PROB, quiet = T) %>% as.numeric()

matrix(c(p365.auc, p1096.auc), ncol = 3, byrow = T) %>% as.data.frame() %>% 
  select(AUC = V2, CI.L = V1, CI.U = V3) %>% mutate(TYPE = c("P1YR", "P3YR")) %>%
  mutate(CI = str_c(round(CI.L, 3), "-", round(CI.U, 3))) %>%
  mutate(ESTIMATE = str_c(round(AUC, 3), " (", CI, ")")) %>% 
  select(TYPE, ESTIMATE)    #AUC USING ONLY SEX, AGE AND PRS

### 2. ANALYSIS USING SOLELY SEX AND AGE

sexage.raw.df <- read.table("K:/HW/people/Anton ?berg Sysojev/MTXp_predict/data/output/TRAIN1_NONGENETIC.tsv", header = T)
sexage.df <- sexage.raw.df[, c("pid", "index_date", "SEX", "AGE")]
write.table(sexage.df, paste0(FOLDERPATH, "data/output/TRAIN_SEXAGE.tsv"), col.names = T, row.names = F, quote = F, sep = "\t")
rm(sexage.raw.df); rm(sexage.df)

TRAIN365 <- paste0(FOLDERPATH, "data/output/TRAIN_SEXAGE.tsv")
MODEL365 <- "glmnet"
OUTCOME <- "persistence_d365"; TRAIN <- TRAIN365; MODEL <- MODEL365
source(paste0(FOLDERPATH, "scripts/misc/4_TrainFinal.R"))    #Trains model with these features

TRAIN1096 <- paste0(FOLDERPATH, "data/output/TRAIN_SEXAGE.tsv")
MODEL1096 <- "glmnet"
OUTCOME <- "persistence_d1096"; TRAIN <- TRAIN1096; MODEL <- MODEL1096
source(paste0(FOLDERPATH, "scripts/misc/4_TrainFinal.R"))    #Trains model with these features

p365.df <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d365.tsv"))
p365.auc <- pROC::ci.auc(p365.df$OUTCOME, p365.df$PROB, quiet = T) %>% as.numeric()
p1096.df <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d1096.tsv"))
p1096.auc <- pROC::ci.auc(p1096.df$OUTCOME, p1096.df$PROB, quiet = T) %>% as.numeric()

matrix(c(p365.auc, p1096.auc), ncol = 3, byrow = T) %>% as.data.frame() %>% 
  select(AUC = V2, CI.L = V1, CI.U = V3) %>% mutate(TYPE = c("P1YR", "P3YR")) %>%
  mutate(CI = str_c(round(CI.L, 3), "-", round(CI.U, 3))) %>%
  mutate(ESTIMATE = str_c(round(AUC, 3), " (", CI, ")")) %>% 
  select(TYPE, ESTIMATE)    #AUC USING ONLY SEX, AGE AND PRS

### 3. FIGURES AND BASIC CHECKS REQUESTED BY HW AND JA ON OCTOBER 29TH
### 3.1. CROSS TABULATION PER HW

pop.prev.p1yr <- mean((read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d365.tsv")))$OUTCOME %>% as.factor() %>% as.numeric() - 1)
sexage.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d365.tsv")) %>% mutate(PRED.OUTCOME = ifelse(PROB > pop.prev.p1yr, "YES", "NO"))
sexage.snp.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d365.tsv")) %>% mutate(PRED.OUTCOME = ifelse(PROB > pop.prev.p1yr, "YES", "NO"))    #CUT BASED ON YOUDEN'S J
table(sexage.p1yr$OUTCOME, sexage.p1yr$PRED.OUTCOME); table(sexage.snp.p1yr$OUTCOME, sexage.snp.p1yr$PRED.OUTCOME)  
round(table(sexage.p1yr$OUTCOME, sexage.p1yr$PRED.OUTCOME) / 2382, 2); round(table(sexage.snp.p1yr$OUTCOME, sexage.snp.p1yr$PRED.OUTCOME) / 2382, 2)
rm(list = setdiff(ls(), "FOLDERPATH"))

pop.prev.p3yr <- mean((read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d1096.tsv")))$OUTCOME %>% as.factor() %>% as.numeric() - 1)
sexage.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d1096.tsv")) %>% mutate(PRED.OUTCOME = ifelse(PROB > pop.prev.p3yr, "YES", "NO"))
sexage.snp.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d1096.tsv")) %>% mutate(PRED.OUTCOME = ifelse(PROB > pop.prev.p3yr, "YES", "NO"))    #CUT BASED ON YOUDEN'S J
table(sexage.p3yr$OUTCOME, sexage.p3yr$PRED.OUTCOME); table(sexage.snp.p3yr$OUTCOME, sexage.snp.p3yr$PRED.OUTCOME)
round(table(sexage.p3yr$OUTCOME, sexage.p3yr$PRED.OUTCOME) / 2302, 2); round(table(sexage.snp.p3yr$OUTCOME, sexage.snp.p3yr$PRED.OUTCOME) / 2302, 2)
rm(list = setdiff(ls(), "FOLDERPATH"))

#! Using this cut-off, we see similar performance between sex/age and sex/age/snp for both phenotypes.
#! 

### 3.2. ROC CURVES FOR SEX/AGE, SEX/AGE/SNP, NON-GENETIC, NON-GENETIC/PRS/SNP PER JA

sexage.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d365.tsv"))
sexage.snp.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d365.tsv"))
nongenetic.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d365/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN1") %>% select(pid, OUTCOME, PROB = GLMNET)
nongenetic.prs.snp.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d365/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN4") %>% select(pid, OUTCOME, PROB = GLMNET)
p1yr.df <- sexage.p1yr %>% select(pid, OUTCOME, SEXAGE.PROB = PROB) %>% left_join(sexage.snp.p1yr %>% select(pid, SEXAGE.SNP.PROB = PROB), by = "pid") %>% left_join(nongenetic.p1yr %>% select(pid, NONGENETIC.PROB = PROB), by = "pid") %>% left_join(nongenetic.prs.snp.p1yr %>% select(pid, NONGENETIC.PRS.SNP.PROB = PROB), by = "pid")

plot(roc(p1yr.df$OUTCOME, p1yr.df$SEXAGE.PROB), main = "PERSISTENCE AT ONE YEAR", col = "blue")
plot(roc(p1yr.df$OUTCOME, p1yr.df$SEXAGE.SNP.PROB), col = "green", add = T)
plot(roc(p1yr.df$OUTCOME, p1yr.df$NONGENETIC.PROB), col = "red", add = T)
plot(roc(p1yr.df$OUTCOME, p1yr.df$NONGENETIC.PRS.SNP.PROB), col = "yellow", add = T)
legend("bottomright", legend = c("SEX/AGE", "SEX/AGE/SNP", "NONGENETIC", "NONGENETIC/PRS/SNP"), col = c("blue", "green", "red", "yellow"), lwd = 2)
rm(list = setdiff(ls(), "FOLDERPATH"))

sexage.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d1096.tsv"))
sexage.snp.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d1096.tsv"))
nongenetic.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d1096/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN1") %>% select(pid, OUTCOME, PROB = GLMNET)
nongenetic.prs.snp.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d1096/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN4") %>% select(pid, OUTCOME, PROB = GLMNET)
p3yr.df <- sexage.p3yr %>% select(pid, OUTCOME, SEXAGE.PROB = PROB) %>% left_join(sexage.snp.p3yr %>% select(pid, SEXAGE.SNP.PROB = PROB), by = "pid") %>% left_join(nongenetic.p3yr %>% select(pid, NONGENETIC.PROB = PROB), by = "pid") %>% left_join(nongenetic.prs.snp.p3yr %>% select(pid, NONGENETIC.PRS.SNP.PROB = PROB), by = "pid")

plot(roc(p3yr.df$OUTCOME, p3yr.df$SEXAGE.PROB), main = "PERSISTENCE AT THREE YEARS", col = "blue")
plot(roc(p3yr.df$OUTCOME, p3yr.df$SEXAGE.SNP.PROB), col = "green", add = T)
plot(roc(p3yr.df$OUTCOME, p3yr.df$NONGENETIC.PROB), col = "red", add = T)
plot(roc(p3yr.df$OUTCOME, p3yr.df$NONGENETIC.PRS.SNP.PROB), col = "yellow", add = T)
legend("bottomright", legend = c("SEX/AGE", "SEX/AGE/SNP", "NONGENETIC", "NONGENETIC/PRS/SNP"), col = c("blue", "green", "red", "yellow"), lwd = 2)
rm(list = setdiff(ls(), "FOLDERPATH"))

#! I didn't bother with the calibration curves as we know these will not be perfect and most likely resemble those in the Supplementary Material.
#! ROC curves for P3YR indicates that performance is similar across all sets of training features, with any 'best' model difficult to discern from graphical inspection.
#! For P1YR it seems that the NONGENETIC model is best of the four, but only minimally, and the 'full models' seem to generally beat out the sex/age and sex/age/snp models.

### 3.3. PREDICTED PROBABILITIES ACROSS MODELS FOR SEX/AGE, SEX/AGE/SNP, NON-GENETIC, NON-GENETIC/PRS/SNP PER JA.

sexage.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d365.tsv"))
sexage.snp.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d365.tsv"))
nongenetic.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d365/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN1") %>% select(pid, OUTCOME, PROB = GLMNET)
nongenetic.prs.snp.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d365/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN4") %>% select(pid, OUTCOME, PROB = GLMNET)
p1yr.df <- sexage.p1yr %>% select(pid, OUTCOME, SEXAGE.PROB = PROB) %>% left_join(sexage.snp.p1yr %>% select(pid, SEXAGE.SNP.PROB = PROB), by = "pid") %>% left_join(nongenetic.p1yr %>% select(pid, NONGENETIC.PROB = PROB), by = "pid") %>% left_join(nongenetic.prs.snp.p1yr %>% select(pid, NONGENETIC.PRS.SNP.PROB = PROB), by = "pid")
p1yr.cormat <- p1yr.df %>% select(-pid, -OUTCOME) %>% cor()
p1yr.pos.cormat <- p1yr.df %>% filter(OUTCOME == "YES") %>% select(-pid, -OUTCOME) %>% cor()
p1yr.neg.cormat <- p1yr.df %>% filter(OUTCOME == "NO") %>% select(-pid, -OUTCOME) %>% cor()
rm(list = setdiff(ls(), "FOLDERPATH"))

sexage.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d1096.tsv"))
sexage.snp.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE-SNP.glmnet.persistence_d1096.tsv"))
nongenetic.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d1096/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN1") %>% select(pid, OUTCOME, PROB = GLMNET)
nongenetic.prs.snp.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d1096/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN4") %>% select(pid, OUTCOME, PROB = GLMNET)
p3yr.df <- sexage.p3yr %>% select(pid, OUTCOME, SEXAGE.PROB = PROB) %>% left_join(sexage.snp.p3yr %>% select(pid, SEXAGE.SNP.PROB = PROB), by = "pid") %>% left_join(nongenetic.p3yr %>% select(pid, NONGENETIC.PROB = PROB), by = "pid") %>% left_join(nongenetic.prs.snp.p3yr %>% select(pid, NONGENETIC.PRS.SNP.PROB = PROB), by = "pid")
p3yr.cormat <- p3yr.df %>% select(-pid, -OUTCOME) %>% cor()
p3yr.pos.cormat <- p3yr.df %>% filter(OUTCOME == "YES") %>% select(-pid, -OUTCOME) %>% cor()
p3yr.neg.cormat <- p3yr.df %>% filter(OUTCOME == "NO") %>% select(-pid, -OUTCOME) %>% cor()
rm(list = setdiff(ls(), "FOLDERPATH"))

#! Estimated probabilities are highly correlated (>95%) between models trained on sex/age and sex/age/prob.
#! However, compared to models trained on non-genetic data, correlation is weaker with a more pronounced difference in P1YR (>75% for P3YR, >50% for P1YR).
#! These correlations are somewhat stable when stratifying on observed label (i.e., in positive and negative patients, respectively).

### 3.3.1. IS IT POSSIBLE THAT WE CAPTURE DIFFERENT INDIVIDUALS WITH THE DIFFERENT MODELS PER JA

pop.prev.p1yr <- mean((read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d365.tsv")))$OUTCOME %>% as.factor() %>% as.numeric() - 1)
sexage.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d365.tsv"))
nongenetic.prs.snp.p1yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d365/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN4") %>% select(pid, OUTCOME, PROB = GLMNET)
sexage.p1yr.correct <- sexage.p1yr %>% mutate(PRED.LABEL = ifelse(PROB <= pop.prev.p1yr, "NO", "YES")) %>% filter(OUTCOME == PRED.LABEL)
nongenetic.prs.snp.p1yr.correct <- nongenetic.prs.snp.p1yr %>% mutate(PRED.LABEL = ifelse(PROB <= pop.prev.p1yr, "NO", "YES")) %>% filter(OUTCOME == PRED.LABEL)
nrow(sexage.p1yr.correct); nrow(nongenetic.prs.snp.p1yr.correct); length(intersect(sexage.p1yr.correct$pid, nongenetic.prs.snp.p1yr.correct$pid))
rm(list = setdiff(ls(), "FOLDERPATH"))

pop.prev.p3yr <- mean((read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d1096.tsv")))$OUTCOME %>% as.factor() %>% as.numeric() - 1)
sexage.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/TRAIN_SEXAGE.glmnet.persistence_d1096.tsv"))
nongenetic.prs.snp.p3yr <- read_tsv(paste0(FOLDERPATH, "data/output/res/persistence_d1096/PredRes.PRIMARY.tsv")) %>% filter(TRAIN == "TRAIN4") %>% select(pid, OUTCOME, PROB = GLMNET)
sexage.p3yr.correct <- sexage.p3yr %>% mutate(PRED.LABEL = ifelse(PROB <= pop.prev.p3yr, "NO", "YES")) %>% filter(OUTCOME == PRED.LABEL)
nongenetic.prs.snp.p3yr.correct <- nongenetic.prs.snp.p3yr %>% mutate(PRED.LABEL = ifelse(PROB <= pop.prev.p3yr, "NO", "YES")) %>% filter(OUTCOME == PRED.LABEL)
nrow(sexage.p3yr.correct); nrow(nongenetic.prs.snp.p3yr.correct); length(intersect(sexage.p3yr.correct$pid, nongenetic.prs.snp.p3yr.correct$pid))
