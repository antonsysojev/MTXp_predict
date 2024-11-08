### LAST VERSION UPDATED 26 AUGUST 2024 (v1.1).
### THIS SCRIPT EXTRACTS THE INDIVIDUALS IN THE STUDY COHORT.

#.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(haven)
library(lubridate)

eira.raw <- read_sas(paste0(FOLDERPATH, "data/raw/eira_mtx_all_PREDICT.sas7bdat"))
srqb.raw <- read_sas(paste0(FOLDERPATH, "data/raw/srqb_mtx_all_PREDICT.sas7bdat"))

eira.df <- eira.raw %>% filter(year(index_date) >= 2006) %>% distinct(pid, index_date)
srqb.df <- srqb.raw %>% filter(year(index_date) >= 2006) %>% distinct(pid, index_date)

cohort.df <- eira.df %>% bind_rows(srqb.df) %>% distinct(pid, index_date)
write.table(cohort.df, paste0(FOLDERPATH, "data/COHORT.tsv"), row.names = F, col.names = T, quote = F, sep = "\t")
rm(list = setdiff(ls(), "FOLDERPATH"))