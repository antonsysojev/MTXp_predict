### LAST VERSION UPDATED JUNE 24 2024 (v1.0).
### THIS SCRIPTS EXTRACTS THE AUC MODEL QUALITY FOR ALL OUTCOMES, TRAINING DATA AND ML MODELS.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(openxlsx)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

outcome.id.raw <- list.files("data/output/res"); outcome.id <- outcome.id.raw[!str_detect(outcome.id.raw, "\\.")]
type.id <- c("PRIMARY", "SEROPOSITIVE", "SERONEGATIVE")
id.df <- expand.grid(OUTCOME = outcome.id, TYPE = type.id) %>% as_tibble() %>% filter(!(!str_detect(OUTCOME, "persistence") & TYPE != "PRIMARY"))

auc.list <- list()
for(i in 1:nrow(id.df)){
  
  OUTCOME <- id.df$OUTCOME[i]
  TYPE <- id.df$TYPE[i]
  auc.df <- read_tsv(str_c("data/output/res/", OUTCOME, "/AUCRaw.", TYPE, ".tsv"))
  
  auc.list[[i]] <- auc.df %>% pivot_longer(c(LOGREG, GLMNET, RNDFOR, XGBOST), names_to = "MODEL", values_to = "VALUE") %>%
    pivot_wider(names_from = ESTIMATE, values_from = VALUE) %>%
    group_by(TRAIN, MODEL) %>% summarise(CI.L = mean(CI.L), AUC = mean(AUC), CI.U = mean(CI.U), .groups = "drop") %>%
    mutate(ESTIMATE = str_c(round(AUC, 3), " (", round(CI.L, 3), " - ", round(CI.U, 3), ")")) %>% 
    mutate(ID = str_c(OUTCOME, " - ", TYPE)) %>% select(ID, TRAIN, MODEL, ESTIMATE) %>%
    pivot_wider(names_from = TRAIN, values_from = ESTIMATE)
  
}

auc.complete.df <- auc.list %>% bind_rows()

### TABLE 1.

order.model.idx <- data.frame(MODEL = c("LOGREG", "GLMNET", "RNDFOR", "XGBOST"), IDX.MODEL = 1:4)
order.outcome.idx <- data.frame(ID = c("persistence_d365 - PRIMARY", "persistence_d1096 - PRIMARY"), IDX.OUTCOME = 1:2)
auc.complete.df %>% filter(str_detect(ID, "persistence")) %>% filter(str_detect(ID, "PRIMARY")) %>%
  left_join(order.model.idx, by = "MODEL") %>% left_join(order.outcome.idx, by = "ID") %>% arrange(IDX.OUTCOME, IDX.MODEL) %>%
  select(-IDX.MODEL, -IDX.OUTCOME) %>% write.xlsx("data/output/res/Table1.tsv")

### TABLE S10.

order.model.idx <- data.frame(MODEL = c("LOGREG", "GLMNET", "RNDFOR", "XGBOST"), IDX.MODEL = 1:4)
order.outcome.idx <- data.frame(OUTCOME = c("persistence_d365", "persistence_d1096"), IDX.OUTCOME = 1:2)
order.type.idx <- data.frame(TYPE = c("SEROPOSITIVE", "SERONEGATIVE"), IDX.TYPE = 1:2)

auc.complete.df %>% filter(!str_detect(ID, "PRIMARY")) %>% 
  mutate(OUTCOME = str_extract(ID, "^persistence_d\\d+"), TYPE = str_extract(ID, "SERO.+$")) %>%
  left_join(order.model.idx, by = "MODEL") %>% left_join(order.outcome.idx, by = "OUTCOME") %>% left_join(order.type.idx, by = "TYPE") %>%
  arrange(IDX.TYPE, IDX.OUTCOME, IDX.MODEL) %>% 
  select(-IDX.TYPE, -IDX.OUTCOME, -IDX.MODEL, -OUTCOME, -TYPE) %>%
  write.xlsx("data/output/res/TableS10.tsv")
  
### TABLE S11.

order.model.idx <-data.frame(MODEL = c("LOGREG", "GLMNET", "RNDFOR", "XGBOST"), IDX.MODEL = 1:4)
order.outcome.idx <- data.frame(OUTCOME = c("remission_retention_d365", "remission_retention_d1096", "discontinuation_d365", "discontinuation_d1096", "das28_remission_m12", "eular_response_m6"), IDX.OUTCOME = 1:6)

auc.complete.df %>% filter(!str_detect(ID, "persistence")) %>%
  mutate(OUTCOME = str_extract(ID, "^[^ ]+")) %>% 
  left_join(order.model.idx, by = "MODEL") %>% left_join(order.outcome.idx, by = "OUTCOME") %>% arrange(IDX.OUTCOME, IDX.MODEL) %>% 
  select(-IDX.MODEL, -IDX.OUTCOME, -OUTCOME) %>%
  write.xlsx("data/output/res/TableS11.tsv")