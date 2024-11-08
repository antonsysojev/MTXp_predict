### LAST UPDATED AUGUST 26 2024 (v1.0).
### THIS SCRIPT EXTRACTS CLINICAL TRAINING DATA FOR THE GIVEN COHORT.

#.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(haven)
library(lubridate)
library(readxl)
library(readr)
library(stringr)

register.sas.files <- str_c(c("srq_terapi", "pdr", "srq_besoksdata"), "_sub.sas7bdat")
register.ls <- list.files(paste0(FOLDERPATH, "data/raw/registers/"))
if(!all(register.sas.files %in% register.ls)) stop("ERROR: Failed to find all the registers...")

df <- read_tsv(paste0(FOLDERPATH, "data/COHORT.tsv"), show_col_types = F)

### 1. SRQ TERAPI

terapi.srq  <- read_sas(paste0(FOLDERPATH, "data/raw/registers/srq_terapi_sub.sas7bdat")) %>%
  right_join(df, by = "pid") %>%
  mutate(order_days_SRQ = interval(index_date, order_date) / days(1)) %>%
  filter(between(order_days_SRQ, -10, 30)) %>%     #LOOK ONLY INTO PRESCRIPTIONS MADE WITHIN [-10, 30] DAYS OF INDEX DATE
  mutate(STEROID_SRQ = ifelse(prep_typ == "cortisone", 1, 0), NSAID = ifelse(prep_typ == "nsaid", 1, 0)) %>%
  group_by(pid) %>% summarise(ANY_STEROID_SRQ = ifelse(sum(STEROID_SRQ) > 0, 1, 0), ANY_NSAID = ifelse(sum(NSAID) > 0, 1, 0)) %>% ungroup() %>% distinct()

terapi.pdr <- read_sas(paste0(FOLDERPATH, "data/raw/registers/pdr_sub.sas7bdat")) %>%
  right_join(df, by = "pid") %>%
  mutate(order_days_PDR = interval(index_date, EDATUM) / days(1)) %>%
  filter(between(order_days_PDR, -10, 30)) %>%
  mutate(STEROID_PDR = ifelse(ATC %in% c("H02AB06", "H02AB07"), 1, 0)) %>%
  group_by(pid) %>% summarise(ANY_STEROID_PDR = ifelse(sum(STEROID_PDR) > 0, 1, 0)) %>% ungroup() %>% distinct()

terapi.df <- df %>% left_join(terapi.srq, by = "pid") %>% left_join(terapi.pdr, by = "pid") %>%
  mutate(ANY_STEROID_PDR = ifelse(is.na(ANY_STEROID_PDR), 0, ANY_STEROID_PDR)) %>%    #TO FIX THE MISSINGS OCCURRING DUE TO NON BEING IN PDR PER FILTERING STEPS
  mutate(ANY_STEROID = ifelse(ANY_STEROID_SRQ == 1 | ANY_STEROID_PDR == 1, 1, 0)) %>% 
  select(-ANY_STEROID_SRQ, -ANY_STEROID_PDR, -index_date) %>% distinct()

### 2. SRQ BESOK

besok.df <- read_sas(paste0(FOLDERPATH, "data/raw/registers/srq_besoksdata_sub.sas7bdat")) %>%
  right_join(df, by = "pid") %>%
  mutate(visit_days = interval(index_date, visit_date) / days(1)) %>%
  filter(between(visit_days, -10, 30)) %>%     #AGAIN, LOOK ONLY INTO VISITS MADE WITHIN [-10, 30] DAYS OF INDEX DATE
  mutate(visit_exist = 1) %>%     #BOOLEAN TO USE WITH THE THERAPY DATA ABOVE
  distinct(pid, svullna_leder, omma_leder, sr, crp, patientens_globala, haq, smarta, visit_exist, visit_days) %>%     #THERE ARE STILL NON-UNIQUE VISITS WITHIN THE INTERVAL
  group_by(pid) %>% filter(abs(visit_days) == min(abs(visit_days))) %>% ungroup() %>%     #1. GRAB THE VISIT CLOSEST TO THE INDEX_DATE
  group_by(pid) %>% filter(visit_days == max(visit_days)) %>% ungroup() %>%     #2. IF YOU ARE STILL DUPLICATED, THERE ARE EQUIDISTANT VISITS, THEN WE PRIORITIZE THE ONE OCCURING AFTER INDEX DATE
  rowwise() %>% mutate(N_NA = sum(is.na(c_across(pid:visit_days)))) %>% ungroup() %>%
  group_by(pid) %>% filter(N_NA == min(N_NA)) %>% ungroup() %>%     #3. REMOVE THE ONE WITH THE MOST MISSING... SEE TODO 1.1. FOR A BETTER SOLUTION
  group_by(pid) %>% filter(n() == 1) %>% ungroup() %>% select(-visit_days, -N_NA)    #4. IF YOU ARE STILL DUPLICATED THEN WE CAN NOT CHOOSE BETWEEN TWO EQUALLY MISSING LINES AND WE JUST BLANK THEM

### 3. SRQ SMOKING

smoke.df <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/01. SRQ/srq_smoking.sas7bdat") %>%
  right_join(df, by = "pid") %>%
  filter(!is.na(smoking_date)) %>%
  mutate(smoke_days = interval(index_date, smoking_date) / days(1)) %>%
  filter(between(smoke_days, -10, 30)) %>%
  group_by(pid) %>% filter(abs(smoke_days) == min(abs(smoke_days))) %>% ungroup() %>% select(-smoking_date, -smoke_days) %>%    #REMOVE NON-FIRST RECORDS
  distinct() %>% group_by(pid) %>% mutate(N = n()) %>% ungroup() %>% mutate(rokvana = ifelse(N > 1, NA, rokvana)) %>% select(-N) %>% distinct() %>%     #FOR INDIVIDUALS WITH EQUIDISTANT DISCORDANT INFORMATION, BLANK THEM
  mutate(SMOKE = case_when(str_detect(rokvana, "Aldrig") ~ 0, str_detect(rokvana, "Slutat") ~ 1, str_detect(rokvana, "Aldrig|Slutat", negate = T) ~ 2)) %>% select(-rokvana) %>%
  distinct(pid, SMOKE)    #MODIFIED FROM THE SAS SCRIPT SENT BY DANIELA

### 4. ANTIBODIES
### ### 4.1. EIRA - RHEUMATOID FACTOR

eira.rf.raw <- read_xlsx(paste0(FOLDERPATH, "data/raw/antibodies/221215 serologi by Johan Ronnelid.xlsx")) %>% select(COHORT_ID = `Sample clean ID`, RF = `IgM RF, IU/mL`)

rf.cutoff <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/02. EIRA/eira.sas7bdat") %>% distinct(pid, COHORT_ID = eira, typ) %>%
  filter(!is.na(COHORT_ID)) %>%
  left_join(eira.rf.raw, by = "COHORT_ID") %>%
  group_by(typ) %>% summarise(RF_q098 = quantile(RF, 0.98, na.rm = T)) %>%
  filter(typ == 2)    #COMPUTE THE CUT OFF BASED ON CONTROLS...

eira.rf <- eira.rf.raw %>% mutate(RF = ifelse(RF < rf.cutoff$RF_q098, 0, 1)) %>% distinct(cid = COHORT_ID, RF)

### ### 4.2. EIRA - ANTI-CCP

eira.ccp <- read_xlsx(paste0(FOLDERPATH, "data/raw/antibodies/221206 EIRA CCP till Helga.xlsx"), col_names = paste0("V", 1:13), skip = 1) %>% mutate(ACPA_RAW = ifelse(V2 == ">3200", 3201, V2) %>% as.numeric()) %>% mutate(ACPA = ifelse(ACPA_RAW < 25, 0, 1)) %>% select(COHORT_ID = V1, ACPA) %>% filter(!is.na(COHORT_ID)) %>%
  bind_rows(read_xlsx(paste0(FOLDERPATH, "data/raw/antibodies/221206 EIRA CCP till Helga.xlsx"), col_names = paste0("V", 1:13), skip = 1) %>% mutate(ACPA_RAW = ifelse(V6 == "<25", 24, V6) %>% as.numeric()) %>% mutate(ACPA = ifelse(ACPA_RAW < 25, 0, 1)) %>% select(COHORT_ID = V5, ACPA) %>% filter(!is.na(COHORT_ID))) %>%
  distinct(cid = COHORT_ID, ACPA)    #sEE NOTE 2.1

### ### 4.3. SRQB - RHEUMATOID FACTOR - ANTI-CCP

srqb.rf.ccp <- read_sas(paste0(FOLDERPATH, "data/raw/antibodies/anton_ccp_rf.sas7bdat")) %>% 
  select(cid = biobank_id, RF = RF_IgM, ACPA = antiCCP) %>% mutate(cid = as.character(cid)) %>%
  distinct()

### ### 4.4. AGGREGATE, AND OBTAIN SEROSTATUS

serostatus.ab <- eira.rf %>% full_join(eira.ccp, by = "cid") %>% bind_rows(srqb.rf.ccp) %>%
  mutate(SEROPOS.AB = case_when(RF == 1 | ACPA == 1 ~ 1, RF == 0 & ACPA == 0 ~ 0, .default = NA)) %>%
  group_by(cid) %>% filter(!(n() > 1 & is.na(SEROPOS.AB))) %>% ungroup() %>%
  distinct(cid, SEROPOS.AB) %>% 
  left_join(read_tsv(paste0(FOLDERPATH, "data/KEY.tsv"), show_col_types = F), by = "cid") %>%
  right_join(df, by = "pid") %>%
  distinct(pid, SEROPOS.AB) %>%
  group_by(pid) %>% filter(!(n() > 1 & is.na(SEROPOS.AB))) %>% ungroup() %>%    #REMOVES DUPLICATES WHERE ONE IS MISSING AND ONE NON-MISSING
  group_by(pid) %>% filter(n() == 1) %>% ungroup() %>% arrange(pid)    #REMOVES ALL (BLANKS) THOSE WITH DISCORDANT DATA

### ### 4.5. SUPPLEMENT WITH DATA FROM ICD-10

seropos <- str_c(c("M05.3", "M05.8", "M05.9", "M06.8L", "M06.0L"), collapse = "|")
seroneg <- str_c(c("M06.8M", "M06.0M"), collapse = "|")

serostatus.icd <- df %>% left_join(serostatus.ab, by = "pid") %>% filter(is.na(SEROPOS.AB)) %>%
  left_join(read_sas(paste0(FOLDERPATH, "data/raw/registers/srq_basdata_sub.sas7bdat")) %>% distinct(pid, diagnoskod_1, diagnoskod_2), by = "pid") %>%
  mutate(SPOS_1 = ifelse(str_detect(diagnoskod_1, seropos), 1, NA), SPOS_2 = ifelse(str_detect(diagnoskod_2, seropos), 1, NA)) %>%
  mutate(SNEG_1 = ifelse(str_detect(diagnoskod_1, seroneg), 1, NA), SNEG_2 = ifelse(str_detect(diagnoskod_2, seroneg), 1, NA)) %>%
  mutate(SEROPOS_1 = case_when(SPOS_1 == 1 & is.na(SNEG_1) ~ 1, SNEG_1 == 1 & is.na(SPOS_1) ~ 0, is.na(SPOS_1) & is.na(SNEG_1) ~ -9)) %>%
  mutate(SEROPOS_2 = case_when(SPOS_2 == 1 & is.na(SNEG_2) ~ 1, SNEG_2 == 1 & is.na(SPOS_2) ~ 0, is.na(SPOS_2) & is.na(SNEG_2) ~ -9)) %>%
  mutate(SEROPOS.ICD = case_when(SEROPOS_1 == SEROPOS_2 ~ SEROPOS_1, SEROPOS_1 != SEROPOS_2 & (SEROPOS_1 + SEROPOS_2) == 1 ~ NA, SEROPOS_1 != SEROPOS_2 & SEROPOS_1 != -9 ~ SEROPOS_1, SEROPOS_1 != SEROPOS_2 & SEROPOS_2 != -9 ~ SEROPOS_2)) %>%
  mutate(SEROPOS.ICD = ifelse(SEROPOS.ICD == -9, NA, SEROPOS.ICD)) %>%
  distinct(pid, SEROPOS.ICD)

serostatus.df <- df %>% left_join(serostatus.ab, by = "pid") %>% left_join(serostatus.icd, by = "pid") %>% 
  mutate(SEROPOSITIVITY_COMBINED = ifelse(is.na(SEROPOS.AB), SEROPOS.ICD, SEROPOS.AB)) %>% 
  distinct(pid, SEROPOSITIVITY_COMBINED)

### 5. COMBINE AND OUTPUT!

df %>% left_join(terapi.df, by = "pid") %>%
  left_join(besok.df, by = "pid") %>%
  left_join(smoke.df, by = "pid") %>%
  left_join(serostatus.df, by = "pid") %>%
  mutate(STEROID = ifelse(is.na(visit_exist), NA, ANY_STEROID), NSAID = ifelse(is.na(visit_exist), NA, ANY_NSAID)) %>%    #PER COMMENT FROM JA OR TF, IF NO VISIT EXISTS AROUND THE STEROID/NSAID THEN THESE SHOULD NOT BE TRUSTED? BLANK THEM
  select(-visit_exist, -ANY_STEROID, -ANY_NSAID) %>%
  write.table(paste0(FOLDERPATH, "data/CLINICAL.tsv"), col.names = T, row.names = F, quote = F, sep = "\t")

rm(list = setdiff(ls(), "FOLDERPATH"))

### TODO:
# 1.1. If there are duplicated visits on the same date, with different numbers and/or missing, then some can be collapsed to fill out missing values. This may resolve some individuals.
#       Doing it in code was non-trivial though, and the low number of individuals that would be resolved made it more reasonable to skip and continue. Maybe later.
### NOTES:
# 2.1. I had previously not considered the fifth column here. I believe it may be valid to ignore it, as my interpretation of the column name
#       seems to indicate that this contains EIRA-controls, which a histogram of the measurements (converted to numeric after removing all `<25` values)
#       seems to agree with. Nevertheless, I considered including them here, though I never counted whether they actually lead to improvements
#       in less missing data, as it didn't seem important. I have also added some additional steps which with the current data makes no difference on the output
#       data.frame, but provides a more robust extraction that will now error out in case something strange is occurring. In particular, I deal with the non-numerical
#       values, force it to be numerical afterwards and also filter out missing IDs. Worth mentioning is that the ACPA-cutoff of 25 is based on what is written within
#       the .xlsx-file, which is also the same value given for ACPA-cutoff in EIRA in my published GWAS study, OVERLAP study and the current analysis plan. 