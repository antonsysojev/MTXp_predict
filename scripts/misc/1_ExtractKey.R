### LAST VERSION UPDATED 26 AUGUST 2024 (v2.1).
### THIS SCRIPT EXTRACTS A KEY THAT LINKS pid TO cid (COHORT ID) TO gid (GWAS ID).

#.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(haven)
library(readr)

### 1. EXTRACT KEY FROM pid TO cid

srqb.raw <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/01. SRQ/srq_basdata.sas7bdat") %>% distinct(pid, biobank_ID) %>% arrange(pid, biobank_ID)
eira.raw <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/02. EIRA/eira.sas7bdat") %>% distinct(pid, eira) %>% arrange(pid, eira)     #NOTE THAT THERE ARE DUPLICATES IN `pid`

### 2. EXTRACT KEY FROM cid TO gid

srqb.b123 <- read_sas("K:/RA_genetics/keys/key_20230126.sas7bdat")      #SEE NOTE 2.1. FOR DETAILS ON THE KEY FILE
srqb.b1 <- srqb.b123 %>% select(SRQb = SRQ_id, GWAS = barcode_deCODE_b1) %>% mutate(BATCH = "SRQb-B1") %>% filter(!is.na(GWAS)) %>% distinct()
srqb.b2 <- srqb.b123 %>% select(SRQb = SRQ_id, GWAS = Barcode_deCODE_b2) %>% mutate(BATCH = "SRQb-B2") %>% filter(!is.na(GWAS)) %>% distinct()
srqb.b3 <- srqb.b123 %>% select(SRQb = SRQ_id, GWAS = RID_decode_b3) %>% mutate(BATCH = "SRQb-B3") %>% filter(!is.na(GWAS)) %>% distinct()    #USE `RID` INSTEAD OF BARCODE SINCE THIS BATCH IS CODED DIFFERENTLY IN THE .fam

eira.b1 <- read_tsv("K:/RA_genetics/EIRA/documents/Genotyped_EIRA_from_Leonid_20190823.txt", show_col_types = F) %>% select(EIRA = `EIRA ID`, GWAS = `SMP number`) %>% mutate(BATCH = "EIRA-B1") %>% distinct()
eira.b2 <- read_tsv("K:/RA_genetics/EIRA/new EIRA data/deCODE_batch2_key.txt", show_col_types = F) %>% select(EIRA, GWAS = SMP.number) %>% mutate(BATCH = "EIRA-B2") %>% distinct()    #SEE NOTE 2.2. FOR DETAILS

### 3. LINKING THEM TOGETHER

srqb.b1.KEY <- srqb.b1 %>% inner_join(srqb.raw, by = c("SRQb" = "biobank_ID"))    #SEE NOTE 2.3. FOR DETAILS ON THE LINKAGE
srqb.b2.KEY <- srqb.b2 %>% inner_join(srqb.raw, by = c("SRQb" = "biobank_ID"))
srqb.b3.KEY <- srqb.b3 %>% inner_join(srqb.raw, by = c("SRQb" = "biobank_ID"))
srqb.KEY <- srqb.b1.KEY %>% bind_rows(srqb.b2.KEY) %>% bind_rows(srqb.b3.KEY) %>% select(pid, cid = SRQb, gid = GWAS, BATCH) %>% arrange(BATCH, pid) %>% mutate(cid = as.character(cid), gid = as.character(gid))

eira.b1.KEY <- eira.b1 %>% inner_join(eira.raw, by = c("EIRA" = "eira"))    #SEE NOTE 2.4. FOR DETAILS ON THE LINKAGE
eira.b2.KEY <- eira.b2 %>% inner_join(eira.raw, by = c("EIRA" = "eira"))
eira.KEY <- eira.b1.KEY %>% bind_rows(eira.b2.KEY) %>% select(pid, cid = EIRA, gid = GWAS, BATCH) %>% arrange(BATCH, pid)

KEY <- srqb.KEY %>% bind_rows(eira.KEY) %>% distinct()     #NOTE THAT THERE MAY BE DUPLICATES DEPENDING ON THE ID!
write.table(KEY, paste0(FOLDERPATH, "data/KEY.tsv"), row.names = F, col.names = T, quote = F, sep = "\t")
rm(list = setdiff(ls(), "FOLDERPATH"))

### NOTES:
# 2.1. This seems to be the main key for linking SRQb-participants from cid to gid.
#      - SRQb.b1 has 3159 non-missing gids, which match 3156 gids in the raw data, of which 2877 remain in imputed (ALPHA VERSION OF IMPUTED DATA).
#      - SRQb.b2 has 1338 non-missing gids, which match 1334 gids in the raw data, of which 1178 remain in imputed (ALPHA VERSION OF IMPUTED DATA).
#      - SRQb.b3 has 409 non-missing gids, which match 409 gids in the raw data, of which 0 remain in imputed (ALPHA VERSION OF IMPUTED DATA).
#          - This is indeed something that happens. See TODO 23 (FOR THE BETA VERSION OF THE GENOTYPE IMPUTATION PIPELINE) for details.
# 2.2. The file with the cid-gid keys for EIRA are less clear, but it seems that similar keys are available at K:/RA_genetics/eira,
#      one file at `deCODE genetics raw` and one at `new EIRA data`.
#      - EIRA.b1 has 7811 non-missing gids, which match 7181 gids in the raw data, of which 6557 remain in imputed (ALPHA).
#      - EIRA.b2 has 1211 non-missing gids, which match 1199 gids in the raw data, of which 977 remain in imputed (ALPHA).
#          - Looks to drop in individuals (eira.b1) but is actually a ~100% match to the individuals in the raw data (7180).
# 2.3. A handful of SRQb individuals fall out per not having a matching cid across both files.
#      - Of the 3159 non-missing gids in SRQb.b1, 3128 had a match in cid.
#      - Of the 1338 non-missing gids in SRQb.b1, 1331 had a match in cid.
#      - Of the 409 non-missing gids in SRQb.b3, 407 had a match in cid.
# 2.4. A handful of EIRA individuals fall out per not having a matching cid across both files.
#      - Of the 7811 non-missing gids in EIRA.b1, 7396 had a match in cid.
#      - Of the 1211 non-missing gids in EIRA.b2, 1180 had a match in cid.