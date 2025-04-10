### LAST VERSION UPDATED 25 JUNE 2024 (v1.0).
### THIS SCRIPT EXTRACTS AUC AND CALIBRATION VALUES FOR THE REFITTED DATA.

.libPaths("H:/Programs/RLibrary")
library(dplyr)
library(readr)
library(stringr)
library(pROC)
library(openxlsx)
library(tidyr)

outcomes.id <- c("persistence_d365", "persistence_d1096")

refit.list <- list()
for(i in 1:length(outcomes.id)){
  
  refit.inner.list <- list()
  refit.file <- list.files(str_c(FOLDERPATH, "data/output/res/"), "Prob")[str_which(list.files(str_c(FOLDERPATH, "data/output/res/"), "Prob"), outcomes.id[i])]
  refit.df <- read_tsv(str_c(FOLDERPATH, "data/output/res/", refit.file)) %>% select(pid, OUTCOME, PROB)
  
  # AUC AND OTHERS
  refit.inner.list[[1]] <- ci.auc(refit.df$OUTCOME, refit.df$PROB, quiet = T) %>% as.numeric()
  
  #! Need Youden J, sensitivity, specificity, ppv and npv too...
  #! Do we?
  
  # CALIBRATION
  
  refit.inner.list[[2]] <- mean(refit.df$OUTCOME) - mean(refit.df$PROB)    #MEAN CALIBRATION
  
  cal.int.raw <- (glm(OUTCOME ~ I(PROB), data = refit.df, family = binomial(link = "logit")) %>% coef())[1]
  cal.int <- exp(cal.int.raw) %>% as.numeric()    #CALIBRATION INTERCEPT
  refit.inner.list[[3]] <- cal.int
  
  cal.slope.raw <- (glm(OUTCOME ~ PROB, data = refit.df, family = binomial(link = "logit")) %>% coef())[2]
  cal.slope <- exp(cal.slope.raw) / (1 + exp(cal.slope.raw)) %>% as.numeric()     #CALIBRATION SLOPE
  refit.inner.list[[4]] <- cal.slope
  
  refit.list[[i]] <- data.frame(VALUE = refit.inner.list %>% unlist(), ID = c("CI.L", "AUC", "CI.U", "MEAN", "INTERCEPT", "SLOPE")) %>% mutate(OUTCOME = outcomes.id[i])
  
}

refit.list %>% bind_rows() %>% as_tibble() %>%
  pivot_wider(names_from = ID, values_from = VALUE) %>%
  mutate(AUC = str_c(round(AUC, 3), " (", round(CI.L, 3), " - ", round(CI.U, 3), ")")) %>% 
  mutate(MEAN = as.character(MEAN), INTERCEPT = as.character(INTERCEPT), SLOPE = as.character(SLOPE)) %>%
  select(OUTCOME, AUC, MEAN, INTERCEPT, SLOPE) %>%
  pivot_longer(cols = c(AUC, MEAN, INTERCEPT, SLOPE)) %>%
  pivot_wider(names_from = OUTCOME, values_from = value) %>%
  write.xlsx("data/output/res/TableRefitCalibration.xlsx")