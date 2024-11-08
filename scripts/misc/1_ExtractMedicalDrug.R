### LAST UPDATED 26 AUGUST 2024 (v1.1).
### THIS SCRIPT EXTRACTS THE MEDICAL HISTORY AND DRUG HISTORY TRAINING DATA FOR THE GIVEN COHORT.

#.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(haven)
library(readr)
library(stringr)
library(tidyr)

register.sas.files <- str_c(c("npr_inpat", "npr_outpat", "pdr"), "_sub.sas7bdat")
register.ls <- list.files("H:/Projects/MTX_PREDICT/data/raw/registers/")
if(!all(register.sas.files %in% register.ls)) stop("ERROR: Failed to find all the registers...")

df <- read_tsv(paste0(FOLDERPATH, "data/COHORT.tsv"), show_col_types = F)

### 1. NATIONAL PATIENT REGISTER

ICD10.subchapters <- read_tsv(paste0(FOLDERPATH, "data/raw/ICD10_subchapters_modifiedFromHW.txt"), show_col_types = F) %>% mutate(ID = str_c(start, "_", end))    #SEE NOTE 2.1.

medical.raw <- read_sas(paste0(FOLDERPATH, "data/raw/registers/npr_outpat_sub.sas7bdat")) %>%
  bind_rows(read_sas(paste0(FOLDERPATH, "data/raw/registers/npr_inpat_sub.sas7bdat")) %>% select(-UTDATUM)) %>%
  right_join(df, by = "pid") %>%
  filter(between(INDATUM, index_date - years(5), index_date)) %>%
  filter(HDIA != "") %>%    #THIS GETS RID OF ALL `HDIA` THAT ARE SET TO ""
  mutate(HDIA_3 = str_extract(HDIA, "^...")) %>%
  left_join(ICD10.subchapters, join_by(between(HDIA_3, start, end))) %>% filter(!is.na(ID)) %>%    #FILTER OUT THOSE WITH MISSING IDS I.E. THOSE WITHOUT A SUBCHAPTER
  mutate(HDIA_VAL = 1) %>% group_by(pid, ID) %>% summarise(HDIA_COUNT = mean(HDIA_VAL), .groups = "drop") %>% ungroup() %>%    #COUNT ALL OCCURENCES OF EACH HDIA FOR EACH INDIVIDUAL - USE MEAN WHICH AUTOMATICALLY GETS US TO 0/1 RANGE
  pivot_wider(names_from = ID, values_from = HDIA_COUNT, values_fill = 0, names_sort = T)     #USE `values_fill = 0` TO SET EMPTY CELLS TO 0 INSTEAD OF NA - USE `names_sort = T` TO SORT COLUMNS ALPHABETICALLY

medical.df <- df %>% left_join(medical.raw, by = "pid")
medical.df[is.na(medical.df)] <- 0

### 2. PRESCRIBED DRUG REGISTER

drug.raw <- read_sas(paste0(FOLDERPATH, "data/raw/registers/pdr_sub.sas7bdat")) %>%
  right_join(df, by = "pid") %>%
  filter(between(EDATUM, index_date - years(1), index_date)) %>%
  filter(ATC != "") %>%
  mutate(ATC_LEVEL3 = str_extract(ATC, "^....")) %>%    #NOTE FOUR WILDCARDS - LEVEL 1 ATC IS FIRST CHARACTER; LEVEL 2 ATC IS FIRST AND SECOND CHARACTER; BUT LEVEL 3 ATC IS FIRST TO FOURTH CHARACTER, NOT FIRST TO THIRD!
  mutate(ATC_VAL = 1) %>% group_by(pid, ATC_LEVEL3) %>% summarise(ATC_COUNT = mean(ATC_VAL), .groups = "drop") %>% ungroup() %>%
  pivot_wider(names_from = ATC_LEVEL3, values_from = ATC_COUNT, values_fill = 0, names_sort = T)

drug.df <- df %>% left_join(drug.raw, by = "pid")
drug.df[is.na(drug.df)] <- 0

### 3. WRITING FILES

write.table(medical.df, paste0(FOLDERPATH, "data/MEDICAL.tsv"), row.names = F, col.names = T, quote = F, sep = "\t")
write.table(drug.df, paste0(FOLDERPATH, "data/DRUG.tsv"), row.names = F, col.names = T, quote = F, sep = "\t")

rm(list = setdiff(ls(), "FOLDERPATH"))

### NOTES:
# 2.1. Helga has a package for ICD-10 categorization. I worked on the remote when adding this into the script, and struggled
#       with getting all the tools from the package in here. Instead, I simply use a text-file version of the contents of
#       the `ICD10SE_sub_chapters` workspace within the data folder of the package. See mail conversation with HW on the 12th October for the full package.