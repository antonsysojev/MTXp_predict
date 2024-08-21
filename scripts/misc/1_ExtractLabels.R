### LAST UPDATED APRIL 26 2024 (v1.0).
### THIS SCRIPT EXTRACTS THE LABELS FOR THE GIVEN COHORT.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)

df <- read_tsv("H:/Projects/MTX_PREDICT/data/COHORT.tsv", show_col_types = F)
eira.raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/eira_mtx_all_PREDICT.sas7bdat")
srqb.raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/srqb_mtx_all_PREDICT.sas7bdat")

### 1. PERSISTENCE OUTCOMES

persistence.df <- eira.raw %>% distinct(pid, persistence_d365, persistence_d1096) %>%
  bind_rows(srqb.raw) %>% distinct(pid, persistence_d365, persistence_d1096)

### ### 2. NON-PERSISTENCE DUE TO LACK OF ADHERENCE

discontinuation.df <- eira.raw %>% distinct(pid, index_date, retention_d365, retention_d1096) %>% 
  bind_rows(srqb.raw %>% distinct(pid, index_date, retention_d365, retention_d1096)) %>% 
  mutate(discontinuation_d365 = ifelse(retention_d365 == 0, 1, 0), discontinuation_d1096 = ifelse(retention_d1096 == 0, 1, 0)) %>%
  distinct(pid, discontinuation_d365, discontinuation_d1096)

### ### 3. EARLY REMISSION AND BEING PERSISTENT

remRetention.df <- eira.raw %>% distinct(pid, index_date, retention_d365, retention_d1096, das28_remission_m6) %>%
  bind_rows(srqb.raw %>% distinct(pid, index_date, retention_d365, retention_d1096, das28_remission_m6)) %>%
  mutate(remission_retention_d365 = case_when(is.na(das28_remission_m6) | is.na(retention_d365) ~ NA, das28_remission_m6 == 1 & retention_d365 == 1 ~ 1, das28_remission_m6 == 0 | retention_d365 == 0 ~ 0, .default = NA)) %>%
  mutate(remission_retention_d1096 = case_when(is.na(das28_remission_m6) | is.na(retention_d1096) ~ NA, das28_remission_m6 == 1 & retention_d1096 == 1 ~ 1, das28_remission_m6 == 0 | retention_d1096 == 0 ~ 0, .default = NA)) %>%
  distinct(pid, remission_retention_d365, remission_retention_d1096)

### ### 4. EULAR RESPONSE AT SIX MONTHS AND DAS28 REMISSION AT ONE YEAR

classicOutcomes.df <- eira.raw %>% distinct(pid, index_date, eular_response_m6, das28_remission_m12) %>% 
  bind_rows(srqb.raw %>% distinct(pid, eular_response_m6, das28_remission_m12)) %>%
  distinct(pid, eular_response_m6, das28_remission_m12)

### ### 5. WRITING LABELS

df %>% left_join(persistence.df, by = "pid") %>%
  left_join(discontinuation.df, by = "pid") %>%
  left_join(remRetention.df, by = "pid") %>%
  left_join(classicOutcomes.df, by = "pid") %>%
  write.table("H:/Projects/MTX_PREDICT/data/LABELS.tsv", row.names = F, col.names = T, quote = F, sep = "\t")

rm(list = ls())