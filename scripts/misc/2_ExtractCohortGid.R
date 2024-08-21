### LAST VERSION UPDATED 29 APRIL 2024 (v1.0).
### THIS SCRIPT EXTRACTS THE gid FOR EACH INDIVIDUAL IN THE COHORT.tsv FILE, FOR EXTRACTING MY COHORT FROM THE GENOTYPE DATA...

.libPaths("/home2/genetics/antobe/software/RLibrary")
library(dplyr)

cohort.df <- read.table("data/COHORT.tsv", header = T)
key.df <- read.table("data/KEY.tsv", header = T)

cohort.key.df <- cohort.df %>% inner_join(key.df, by = "pid") %>% mutate(FID = "FAM001") %>% select(FID, IID = gid)
write.table(cohort.key.df, "TMP/tmp-2/COHORT.KEY.tsv", col.names = F, row.names = F, quote = F, sep = "\t")
