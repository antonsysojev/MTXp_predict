### LAST VERSION UPDATE 25 JUNE 2024 (v1.0).
### THIS SCRIPT LOADS RECLASSIFICATION STATISTICS AND EXTRACTS A NICE CLEAN TABLE...

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(ggplot2)
library(gridExtra)
library(readr)
library(stringr)
library(tidyr)
library(openxlsx)

outcome.id.raw <- list.files("data/output/res"); outcome.id <- outcome.id.raw[!str_detect(outcome.id.raw, "\\.")]
type.id <- c("PRIMARY", "SEROPOSITIVE", "SERONEGATIVE")
id.df <- expand.grid(OUTCOME = outcome.id, TYPE = type.id) %>% as_tibble() %>% filter(!(!str_detect(OUTCOME, "persistence") & TYPE != "PRIMARY"))

reclass.list <- list()
for(i in 1:nrow(id.df)){
  
  OUTCOME <- id.df$OUTCOME[i]
  TYPE <- id.df$TYPE[i]
  reclass.df <- read_tsv(str_c("data/output/res/", OUTCOME, "/Reclass.", TYPE, ".tsv"), show_col_types = F)
  
  reclass.list[[i]] <- reclass.df %>% 
    group_by(PAIRING, MODEL.ID) %>% summarise(TOTAL = mean(TOTAL), NET = mean(NET), .groups = "drop") %>%
    mutate(PAIRING = str_c("PAIR.", PAIRING)) %>%
    mutate(ESTIMATE = str_c(format(round(TOTAL, 2), nsmall = 2) , " (", format(round(NET, 2), nsmall = 2), ")")) %>% select(-TOTAL, -NET) %>%
    pivot_wider(names_from = PAIRING, values_from = ESTIMATE) %>%
    mutate(PAIR.14 = ifelse(PAIR.14 == "0.00 ( 0.00)", NA, PAIR.14)) %>%
    mutate(ID = str_c(OUTCOME, " - ", TYPE), .before = everything())
  
}

reclass.complete.df <- reclass.list %>% bind_rows()

### TABLE S7.

order.model.idx <- data.frame(MODEL.ID = c("LOGREG", "GLMNET", "RNDFOR", "XGBOST"), IDX.MODEL = 1:4)
order.outcome.idx <- data.frame(ID = c("persistence_d365 - PRIMARY", "persistence_d1096 - PRIMARY"), IDX.OUTCOME = 1:2)
reclass.complete.df %>% filter(str_detect(ID, "persistence")) %>% filter(str_detect(ID, "PRIMARY")) %>%
  left_join(order.model.idx, by = "MODEL.ID") %>% left_join(order.outcome.idx, by = "ID") %>% arrange(IDX.OUTCOME, IDX.MODEL) %>%
  select(ID, MODEL.ID, PAIR.12, PAIR.13, PAIR.14) %>%
  write.xlsx("data/output/res/TableS9.xlsx")