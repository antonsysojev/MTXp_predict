### LAST VERSION UPDATED 22 OCTOBER 2024 (v1.1).
### THIS SCRIPT EXTRACTS SEX, AGE AND GENETIC DATA IN THE FORM OF RAW SNPS

#.libPaths("H:/Programs/RLibrary/")
library(dplyr)

nongenetic.prs.snp.df <- readRDS(paste0(FOLDERPATH, "data/output/TRAIN4_NONGENETIC-PRS-SNP.rds"))

features.df <- nongenetic.prs.snp.df %>% select(pid, index_date, SEX, AGE, matches("\\d+\\:\\d+"))

saveRDS(features.df, paste0(FOLDERPATH, "data/output/TRAIN_SEXAGE-SNP.rds"))
rm(list = setdiff(ls(), "FOLDERPATH"))