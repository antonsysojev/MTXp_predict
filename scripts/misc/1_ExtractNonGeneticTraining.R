### LAST VERSION UPDATED 26 APRIL 2024 (v2.0) - UPDATED FROM `1_ExtractRaw.R` TO NEW PIPELINE STRUCTURE.
### THIS SCRIPT EXTRACTS ALL THE NON-GENETIC TRAINING DATA FROM THE VARIOUS REGISTERS.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(haven)
library(stringr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)

df <- read_tsv("H:/Projects/MTX_PREDICT/data/COHORT.tsv")

### 1. TOTAL POPULATION REGISTER

tpr_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/tpr_sub.sas7bdat")

tpr_clean <- df %>% left_join(tpr_raw, by = "pid") %>%
  mutate(AGE = floor(interval(birthdate, index_date) / years(1))) %>%
  mutate(BORN_IN_SWEDEN = ifelse(fodelselandgrupp == "Sverige", 1, 0)) %>%
  mutate(SEX = as.numeric(kon) - 1) %>%
  distinct(pid, SEX, AGE, BORN_IN_SWEDEN)

rm(tpr_raw)

### 2. LISA REGISTER

lisa_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/lisa_sub.sas7bdat")

lisa_clean <- df %>% left_join(lisa_raw, by = "pid") %>%
  pivot_longer(cols = starts_with("Sun"), names_to = "SUN", values_to = "SUN_VAL") %>%
  mutate(SUN_YEAR = str_extract(SUN, "\\d+$")) %>%
  mutate(EDU = case_when(between(year(index_date), 2000, 2019) & year(index_date) == SUN_YEAR ~ SUN_VAL,
                         year(index_date) < 2000 & SUN == "Sun2000niva_old_2000" ~ SUN_VAL,
                         year(index_date) > 2019 & SUN == "Sun2000niva_old_2019" ~ SUN_VAL)) %>%
  filter(!is.na(EDU)) %>%     #A FEW PEOPLE DISAPPEAR HERE - THEY HAVE ONLY NA, MEANING THEY FIT NEITHER OF THE ABOVE CATEGORIES
  mutate(EDUCATION = case_when(EDU %in% c(1, 2) ~ 0,
                               EDU %in% c(3, 4) ~ 1,
                               EDU > 4 ~ 2)) %>%    #A FEW PEOPLE HAVE MISSING EDUCATION DUE TO HAVING `SUN_VAL` SET TO EITHER "" OR "*".
  filter(!is.na(EDUCATION)) %>%
  distinct(pid, EDUCATION)

rm(lisa_raw)

### 3. MULTI-GENERATION REGISTER

mgr_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/mgr_sub.sas7bdat")
npr_rel_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/npr_rel_sub.sas7bdat")

mgr_clean <- df %>% left_join(mgr_raw, by = "pid") %>%
  filter(!is.na(pid_rel)) %>%     #REMOVE THOSE WITHOUT ANY RELATIVES IN MGR - NEEDED SINCE WE DO LEFT_JOIN BUT MORE CLEAR THIS WAY
  filter(reltyp %in% c("Mother", "Father", "Helsyskon", "Barn")) %>%     #IDENTIFY ALL FIRST-DEGREE RELATIVES
  left_join(npr_rel_raw, by = c("pid_rel" = "pid"), relationship = "many-to-many") %>%
  mutate(RA = ifelse(str_detect(HDIA, "M05|M06|M053|M060|M0[5-6][8-9]|M0[5-6][08-9][A-DF-HL-NX]"), 1, 0)) %>%
  mutate(preindex = ifelse(INDATUM < index_date, 1, 0)) %>%
  mutate(RA_preindex = ifelse(RA == 1 & preindex == 1, 1, 0)) %>%
  group_by(pid) %>% summarise(FDR_wRA = ifelse(sum(RA_preindex, na.rm = T) > 0, 1, 0))    #NEED `na.rm = T` SINCE WE LEFT JOIN AND SOME MAY NOT BE IN NPR AND THUS MISSING

rm(mgr_raw); rm(npr_rel_raw)

### 4. FORSAKRINGSKASSAN

fsk_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/fsk_sub.sas7bdat")

fsk_clean <- fsk_raw %>% select(pid, DisabilityPension_Days = DP_days_1, SickLeave_Days = SL_days_1)

rm(fsk_raw)

### 5. SWEDISH RHEUMATOLOGY QUALITY REGISTER AND EIRA
### ### 5.1. SRQ BASDATA

basdata_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/srq_basdata_sub.sas7bdat")

basdata_clean <- basdata_raw %>% select(pid, duration) %>% distinct()

rm(basdata_raw)

### ### 5.2. SRQ TERAPI

terapi_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/srq_terapi_sub.sas7bdat")
pdr_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/pdr_sub.sas7bdat")

terapi_srq_clean <- df %>% left_join(terapi_raw, by = "pid") %>%
  mutate(order_days_SRQ = interval(index_date, order_date) / days(1)) %>%
  filter(between(order_days_SRQ, -10, 30)) %>%     #LOOK ONLY INTO PRESCRIPTIONS MADE WITHIN [-10, 30] DAYS OF INDEX DATE
  mutate(STEROID_SRQ = ifelse(prep_typ == "cortisone", 1, 0), NSAID = ifelse(prep_typ == "nsaid", 1, 0)) %>%
  group_by(pid) %>% summarise(ANY_STEROID_SRQ = ifelse(sum(STEROID_SRQ) > 0, 1, 0), ANY_NSAID = ifelse(sum(NSAID) > 0, 1, 0)) %>% ungroup() %>% distinct()

terapi_pdr_clean <- df %>% left_join(pdr_raw, by = "pid") %>%
  mutate(order_days_PDR = interval(index_date, EDATUM) / days(1)) %>%
  filter(between(order_days_PDR, -10, 30)) %>%
  mutate(STEROID_PDR = ifelse(ATC %in% c("H02AB06", "H02AB07"), 1, 0)) %>%
  group_by(pid) %>% summarise(ANY_STEROID_PDR = ifelse(sum(STEROID_PDR) > 0, 1, 0)) %>% ungroup() %>% distinct()

terapi_clean <- df %>% left_join(terapi_srq_clean, by = "pid", ) %>% left_join(terapi_pdr_clean, by = "pid") %>%
  mutate(ANY_STEROID_PDR = ifelse(is.na(ANY_STEROID_PDR), 0, ANY_STEROID_PDR)) %>%    #TO FIX THE MISSINGS OCCURRING DUE TO NON BEING IN PDR PER FILTERING STEPS
  mutate(ANY_STEROID = ifelse(ANY_STEROID_SRQ == 1 | ANY_STEROID_PDR == 1, 1, 0)) %>% 
  select(-ANY_STEROID_SRQ, -ANY_STEROID_PDR, -index_date) %>% distinct()

rm(terapi_raw); rm(pdr_raw); rm(terapi_srq_clean); rm(terapi_pdr_clean)

### ### 5.3. SRQ BESOKSDATA

besok_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/srq_besoksdata_sub.sas7bdat")

besok_clean <- df %>% left_join(besok_raw, by = "pid") %>%
  mutate(visit_days = interval(index_date, visit_date) / days(1)) %>%
  filter(between(visit_days, -10, 30)) %>%     #AGAIN, LOOK ONLY INTO VISITS MADE WITHIN [-10, 30] DAYS OF INDEX DATE
  mutate(visit_exist = 1) %>%     #BOOLEAN TO USE WITH THE THERAPY DATA ABOVE
  select(pid, svullna_leder, omma_leder, sr, crp, patientens_globala, haq, smarta, visit_exist, visit_days) %>%     #THERE ARE STILL NON-UNIQUE VISITS WITHIN THE INTERVAL
  distinct() %>%     #1. GET RID OF IDENTICAL COPIES
  group_by(pid) %>% filter(abs(visit_days) == min(abs(visit_days))) %>% ungroup() %>%     #2. GRAB THE VISIT CLOSEST TO THE INDEX_DATE
  group_by(pid) %>% filter(visit_days == max(visit_days)) %>% ungroup() %>%     #3. IF YOU ARE STILL DUPLICATED, THERE ARE EQUIDISTANT VISITS, THEN WE PRIORITIZE THE ONE OCCURING AFTER INDEX DATE
  rowwise() %>% mutate(N_NA = sum(is.na(c_across(pid:visit_days)))) %>% ungroup() %>%
  group_by(pid) %>% filter(N_NA == min(N_NA)) %>% ungroup() %>%     #4. REMOVE THE ONE WITH THE MOST MISSING... SEE NOTE 2.7 FOR A BETTER SOLUTION
  group_by(pid) %>% filter(n() == 1) %>% ungroup() %>% select(-visit_days, -N_NA)    #5. IF YOU ARE STILL DUPLICATED THEN WE CAN NOT CHOOSE BETWEEN TWO EQUALLY MISSING LINES AND WE JUST BLANK THEM

rm(besok_raw)

### ### 5.4. SRQ SMOKING DATA

smoke_raw <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/01. SRQ/srq_smoking.sas7bdat")

smoke_clean <- df %>% left_join(smoke_raw, by = "pid") %>% select(-fran_per, -datum) %>%    #WE CAN TOSS `datum` AS IT IS HERE IDENTICAL TO `smoking_date`
  filter(!is.na(smoking_date)) %>%
  mutate(smoke_days = interval(index_date, smoking_date) / days(1)) %>%
  filter(between(smoke_days, -10, 30)) %>%
  group_by(pid) %>% filter(abs(smoke_days) == min(abs(smoke_days))) %>% ungroup() %>% select(-smoking_date, -smoke_days) %>%    #REMOVE NON-FIRST RECORDS
  distinct() %>% group_by(pid) %>% mutate(N = n()) %>% ungroup() %>% mutate(rokvana = ifelse(N > 1, NA, rokvana)) %>% select(-N) %>% distinct() %>%     #FOR INDIVIDUALS WITH EQUIDISTANT DISCORDANT INFORMATION, BLANK THEM
  mutate(SMOKE = case_when(str_detect(rokvana, "Aldrig") ~ 0, str_detect(rokvana, "Slutat") ~ 1, str_detect(rokvana, "Aldrig|Slutat", negate = T) ~ 2)) %>% select(-rokvana) %>%
  distinct(pid, SMOKE)    #MODIFIED FROM THE SAS SCRIPT SENT BY DANIELA

rm(smoke_raw)

### 6. NATIONAL PATIENT REGISTER
### ### 6.1. NPR HOSPITALIZATIONS

npr_in_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/npr_inpat_sub.sas7bdat")

npr_in_clean <- df %>% left_join(npr_in_raw, by = "pid") %>%
  filter(between(INDATUM, index_date - years(1), index_date)) %>%
  mutate(DAYS_IN_TIME = interval(INDATUM, UTDATUM) / days(1) + 1) %>%    #SEE NOTE 2.9 ABOUT THE PLUS 1
  select(-HDIA) %>%
  group_by(pid) %>% summarise(TOTAL_DAYS_IN_TIME = sum(DAYS_IN_TIME)) %>% ungroup()

### ### 6.2. NPR FOR ICD-10 CODES

npr_out_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/npr_outpat_sub.sas7bdat")
ICD10_subchapters <- read_tsv("H:/Projects/MTX_PREDICT/data/raw/ICD10_subchapters_modifiedFromHW.txt", show_col_types = F) %>% mutate(ID = str_c(start, "_", end))    #SEE NOTE

npr_clean <- df %>% left_join(npr_in_raw %>% select(-UTDATUM) %>% bind_rows(npr_out_raw), by = "pid") %>%
  filter(between(INDATUM, index_date - years(5), index_date)) %>%
  filter(HDIA != "") %>%    #THIS GETS RID OF ALL `HDIA` THAT ARE SET TO ""
  mutate(HDIA_3 = str_extract(HDIA, "^...")) %>%
  left_join(ICD10_subchapters, join_by(between(HDIA_3, start, end))) %>% filter(!is.na(ID)) %>%    #FILTER OUT THOSE WITH MISSING IDS I.E. THOSE WITHOUT A SUBCHAPTER
  mutate(HDIA_VAL = 1) %>% group_by(pid, ID) %>% summarise(HDIA_COUNT = mean(HDIA_VAL), .groups = "drop") %>% ungroup() %>%    #COUNT ALL OCCURENCES OF EACH HDIA FOR EACH INDIVIDUAL - USE MEAN WHICH AUTOMATICALLY GETS US TO 0/1 FORMAT
  pivot_wider(names_from = ID, values_from = HDIA_COUNT, values_fill = 0, names_sort = T)     #USE `values_fill = 0` TO SET EMPTY CELLS TO 0 INSTEAD OF NA - USE `names_sort = T` TO SORT COLUMNS ALPHABETICALLY

rm(npr_in_raw); rm(npr_out_raw)

### 7. PRESCRIBED DRUG REGISTER
### ### 7.1. PDR PRESCRIPTION COSTS

pdr_raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/pdr_sub.sas7bdat")

pdr_clean_1 <- df %>% left_join(pdr_raw, by = "pid") %>%
  filter(between(EDATUM, index_date - years(1), index_date)) %>%
  select(-ATC) %>%
  group_by(pid) %>% summarise(TOTAL_TKOST = sum(TKOST)) %>% ungroup()

### ### 7.2. PDR ATC CODES

pdr_clean_2 <- df %>% left_join(pdr_raw, by = "pid") %>%
  filter(between(EDATUM, index_date - years(1), index_date)) %>%
  filter(ATC != "") %>%
  mutate(ATC_LEVEL3 = str_extract(ATC, "^...")) %>%
  mutate(ATC_VAL = 1) %>% group_by(pid, ATC_LEVEL3) %>% summarise(ATC_COUNT = mean(ATC_VAL), .groups = "drop") %>% ungroup() %>%
  pivot_wider(names_from = ATC_LEVEL3, values_from = ATC_COUNT, values_fill = 0, names_sort = T)

rm(pdr_raw)

### 8. ANTIBODIES
### ### 8.1. USING TYPED DATA

srqb_rf_ccp <- read_sas("H:/Projects/MTX_PREDICT/data/raw/anton_ccp_rf.sas7bdat") %>% select(COHORT_ID = biobank_id, RF = RF_IgM, ACPA = antiCCP)
eira_rf <- read_xlsx("H:/Projects/MTX_PREDICT/data/raw/221215 serologi by Johan Ronnelid.xlsx") %>% select(COHORT_ID = `Sample clean ID`, RF = `IgM RF, IU/mL`)
eira_ccp_1 <- read_xlsx("H:/Projects/MTX_PREDICT/data/raw/221206 EIRA CCP till Helga.xlsx", col_names = paste0("V", 1:13), skip = 1) %>% mutate(ACPA_RAW = ifelse(V2 == ">3200", 3201, V2) %>% as.numeric()) %>% mutate(ACPA = ifelse(ACPA_RAW < 25, 0, 1)) %>% select(COHORT_ID = V1, ACPA) %>% filter(!is.na(COHORT_ID))    #SEE NOTE 2.6
eira_ccp_2 <- read_xlsx("H:/Projects/MTX_PREDICT/data/raw/221206 EIRA CCP till Helga.xlsx", col_names = paste0("V", 1:13), skip = 1) %>% mutate(ACPA_RAW = ifelse(V6 == "<25", 24, V6) %>% as.numeric()) %>% mutate(ACPA = ifelse(ACPA_RAW < 25, 0, 1)) %>% select(COHORT_ID = V5, ACPA) %>% filter(!is.na(COHORT_ID))
eira_ccp <- eira_ccp_1 %>% bind_rows(eira_ccp_2) %>% distinct()
eira_rf_ccp <- eira_rf %>% full_join(eira_ccp, by = "COHORT_ID") %>% arrange(COHORT_ID)    #NOTE THE FULL-JOIN, SINCE ONE MAY BE TYPED FOR ACPA BUT RF AND VICE-VERSA, WITHOUT FULL IT IS ON CONDITIONAL ON THE IDS IN THE FIRST SET!

rf_ccp_1 <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/01. SRQ/srq_basdata.sas7bdat") %>% distinct(pid, biobank_ID) %>%    #USE FULL DATA INSTEAD OF SUB (SAME RESULT BUT SHOULD BE SAFER)
  filter(!is.na(biobank_ID)) %>%    #GET RID OF NA IDS TO AVOID MATCHING ON IT
  left_join(srqb_rf_ccp, by = c("biobank_ID" = "COHORT_ID")) %>%
  mutate(SRQB_RF = RF, SRQB_ACPA = ACPA) %>% distinct(pid, SRQB_RF, SRQB_ACPA)    #THERE MAY BE DUPLICATES HERE WITH MORE THAN ONE RF/ACPA MEASURE...

rf_cutoff <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/02. EIRA/eira.sas7bdat") %>% distinct(pid, COHORT_ID = eira, typ) %>%
  filter(!is.na(COHORT_ID)) %>%
  left_join(eira_rf_ccp, by = "COHORT_ID") %>%
  group_by(typ) %>% summarise(RF_q098 = quantile(RF, 0.98, na.rm = T)) %>%
  filter(typ == 2)

rf_ccp_2 <- read_sas("K:/Reuma/RASPA 2021/01. Data Warehouse/01. Processed Data/02. EIRA/eira.sas7bdat") %>% distinct(pid, COHORT_ID = eira) %>%
  filter(!is.na(COHORT_ID)) %>%
  left_join(eira_rf_ccp, by = "COHORT_ID") %>%
  #mutate(RF = ifelse(RF <= ?, 0, 1)) %>%     #OLD CODE FOR IDENTIFICATION OF RF... CHANGE THE LINE WE USE FOR DEFINITION AND WE'RE COOL
  mutate(RF = ifelse(RF <= rf_cutoff$RF_q098, 0, 1)) %>%
  mutate(EIRA_RF = RF, EIRA_ACPA = ACPA) %>% distinct(pid, EIRA_RF, EIRA_ACPA) %>% arrange(pid, EIRA_RF, EIRA_ACPA)    #THERE MAY BE DUPLICATES HERE WITH MORE THAN ONE RF/ACPA MEASURE

rf_ccp <- df %>% left_join(rf_ccp_1, by = "pid") %>% left_join(rf_ccp_2, by = "pid", relationship = "many-to-many")    #SEE NOTE 2.4 ABOUT THE MANY-TO-MANY FLAG

rf_ccp_clean <- rf_ccp %>% distinct() %>%    #1. REMOVES ALL WITH CONCORDANT ESTIMATES
  rowwise() %>% mutate(N_NA = sum(is.na(c_across(SRQB_RF:EIRA_ACPA)))) %>% ungroup() %>%
  group_by(pid) %>% filter(!(n() > 1 & N_NA == 4)) %>% ungroup() %>% select(-N_NA) %>%    #2. REMOVE DUPLICATES WHERE ONE IS ALL NA - NOTE THAT THIS CUTS AN INDIVIDUAL IF THEY ARE DUPLICATED WITH BOTH ALL NA, BUT THIS IS CORRECT SINCE SUCH AN INDIVIDUAL WILL BE MISSING BOTH IN THE END ANYWAYS
  group_by(pid) %>% mutate(SRQB_RF_COLLAPSE = str_c(str_replace_na(SRQB_RF), collapse = "_"), SRQB_ACPA_COLLAPSE = str_c(str_replace_na(SRQB_RF), collapse = "_"), EIRA_RF_COLLAPSE = str_c(str_replace_na(EIRA_RF), collapse = "_"), EIRA_ACPA_COLLAPSE = str_c(str_replace_na(EIRA_ACPA), collapse = "_")) %>% ungroup(pid) %>%
  mutate(SRQB_RF = ifelse(str_detect(SRQB_RF_COLLAPSE, "NA_|_NA"), str_remove(SRQB_RF_COLLAPSE, "NA_|_NA"), SRQB_RF), SRQB_ACPA = ifelse(str_detect(SRQB_ACPA_COLLAPSE, "NA_|_NA"), str_remove(SRQB_ACPA_COLLAPSE, "NA_|_NA"), SRQB_ACPA), EIRA_RF = ifelse(str_detect(EIRA_RF_COLLAPSE, "NA_|_NA"), str_remove(EIRA_RF_COLLAPSE, "NA_|_NA"), EIRA_RF), EIRA_ACPA = ifelse(str_detect(EIRA_ACPA_COLLAPSE, "NA_|_NA"), str_remove(EIRA_ACPA_COLLAPSE, "NA_|_NA"), EIRA_ACPA)) %>%
  distinct(pid, SRQB_RF, SRQB_ACPA, EIRA_RF, EIRA_ACPA) %>%    #3. FILL IN INFORMATION ACROSS DUPLICATES - SEE NOTE 2.5.
  group_by(pid) %>% filter(n() == 1) %>% ungroup()     #4. IF THERE ARE STILL CLASHES (I.E. IF SOMEONE HAS TWO DISCORDANT MEASURES THEN WE REMOVE THEM BOTH)

rf_ccp_cleanER <- rf_ccp_clean %>% mutate(SRQB_RF = str_replace_na(SRQB_RF), SRQB_ACPA = str_replace_na(SRQB_ACPA), EIRA_RF = str_replace_na(EIRA_RF), EIRA_ACPA = str_replace_na(EIRA_ACPA)) %>%
  mutate(RF_1 = ifelse(SRQB_RF == EIRA_RF, SRQB_RF, NA)) %>%    #1. IF BOTH ALREADY MATCHING, THEN KEEP THIS DATA
  mutate(RF_2 = case_when(SRQB_RF == "NA" & EIRA_RF != "NA" ~ EIRA_RF, SRQB_RF != "NA" & EIRA_RF == "NA" ~ SRQB_RF, .default = RF_1)) %>%    #2. IF ONE IS MISSING, USE THE DATA FROM THE OTHER, FOR ALL OTHERS USE PREVIOUS DATA
  mutate(RF_3 = case_when(SRQB_RF != "NA" & EIRA_RF != "NA" & SRQB_RF != EIRA_RF ~ EIRA_RF, .default = RF_2)) %>%    #3. IF NEITHER IS MISSING, BUT THEY ARE NOT CONCORDANT, USE THE EIRA DATA (PER DISCUSSION WITH HELGA)
  mutate(ACPA_1 = ifelse(SRQB_ACPA == EIRA_ACPA, SRQB_ACPA, NA)) %>%
  mutate(ACPA_2 = case_when(SRQB_ACPA == "NA" & EIRA_ACPA != "NA" ~ EIRA_ACPA, SRQB_ACPA != "NA" & EIRA_ACPA == "NA" ~ SRQB_ACPA, .default = ACPA_1)) %>%
  mutate(ACPA_3 = case_when(SRQB_ACPA != "NA" & EIRA_ACPA != "NA" & SRQB_ACPA != EIRA_ACPA ~ EIRA_ACPA, .default = ACPA_2)) %>%
  mutate(RF = as.numeric(RF_3), ACPA = as.numeric(ACPA_3)) %>% distinct(pid, RF, ACPA)    #NOTE THAT THIS THROWS A WARNING OF CONVERSION ISSUES - IT CAN NOT CONVERT "NA" TO NUMERIC AND THUS CONVERTS IT TO NA... WHICH IS WHAT I WANTED ALL ALONG...

df.serostatus <- rf_ccp_cleanER %>% mutate(SEROPOSITIVITY = case_when(RF == 1 | ACPA == 1 ~ 1, RF == 0 & ACPA == 0 ~ 0, .default = NA)) %>% distinct(pid, SEROPOSITIVITY)

rm(srqb_rf_ccp); rm(eira_rf); rm(eira_ccp); rm(eira_rf_ccp); rm(rf_ccp_1); rm(rf_ccp_2); rm(rf_cutoff)

### ### 8.2. USING ICD-10 DATA FROM SRQ

seropos <- str_c(c("M05.3", "M05.8", "M05.9", "M06.8L", "M06.0L"), collapse = "|")
seroneg <- str_c(c("M06.8M", "M06.0M"), collapse = "|")

df.basdata.ABICD10 <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/srq_basdata_sub.sas7bdat") %>% select(pid, diagnoskod_1, diagnoskod_2) %>% distinct() %>%
  mutate(SPOS_1 = ifelse(str_detect(diagnoskod_1, seropos), 1, NA), SPOS_2 = ifelse(str_detect(diagnoskod_2, seropos), 1, NA)) %>%
  mutate(SNEG_1 = ifelse(str_detect(diagnoskod_1, seroneg), 1, NA), SNEG_2 = ifelse(str_detect(diagnoskod_2, seroneg), 1, NA)) %>%
  mutate(SEROPOS_1 = case_when(SPOS_1 == 1 & is.na(SNEG_1) ~ 1, SNEG_1 == 1 & is.na(SPOS_1) ~ 0, is.na(SPOS_1) & is.na(SNEG_1) ~ -9)) %>%
  mutate(SEROPOS_2 = case_when(SPOS_2 == 1 & is.na(SNEG_2) ~ 1, SNEG_2 == 1 & is.na(SPOS_2) ~ 0, is.na(SPOS_2) & is.na(SNEG_2) ~ -9))  %>%
  mutate(SEROPOSITIVITY_ICD = case_when(SEROPOS_1 == SEROPOS_2 ~ SEROPOS_1, SEROPOS_1 != SEROPOS_2 & (SEROPOS_1 + SEROPOS_2) == 1 ~ NA, SEROPOS_1 != SEROPOS_2 & SEROPOS_1 != -9 ~ SEROPOS_1, SEROPOS_1 != SEROPOS_2 & SEROPOS_2 != -9 ~ SEROPOS_2)) %>%
  distinct(pid, SEROPOSITIVITY_ICD)

df.serostatus.CLEAN <- df.serostatus %>% left_join(df.basdata.ABICD10, by = "pid") %>%
  mutate(SEROPOSITIVITY_COMBINED = ifelse(is.na(SEROPOSITIVITY), SEROPOSITIVITY_ICD, SEROPOSITIVITY)) %>%
  mutate(SEROPOSITIVITY_COMBINED = ifelse(SEROPOSITIVITY_COMBINED == -9, NA, SEROPOSITIVITY_COMBINED)) %>%
  distinct(pid, SEROPOSITIVITY_COMBINED)

### 9. COMBINING AND WRITING
### ### 9.1. SOCIODEMOGRAPHIC DATA

SOCIODEMOGRAPHIC <- df %>% left_join(tpr_clean, by = "pid") %>%
  left_join(lisa_clean, by = "pid") %>%
  left_join(mgr_clean, by = "pid") %>%
  left_join(basdata_clean, by = "pid") %>%
  left_join(smoke_clean, by = "pid") %>%
  left_join(fsk_clean, by = "pid") %>%
  left_join(npr_in_clean, by = "pid") %>%
  left_join(pdr_clean_1, by = "pid") %>%
  mutate(TIME_INHOSP = ifelse(is.na(TOTAL_DAYS_IN_TIME), 0, TOTAL_DAYS_IN_TIME), COST_DRUG = ifelse(is.na(TOTAL_TKOST), 0, TOTAL_TKOST), FDR_wRA = ifelse(is.na(FDR_wRA), 0, FDR_wRA)) %>%
  select(pid, index_date, SEX, AGE, BORN_IN_SWEDEN, EDUCATION, TIME_INHOSP, COST_DRUG, DisabilityPension_Days, SickLeave_Days, FDR_wRA, SMOKE)

rm(tpr_clean); rm(lisa_clean); rm(mgr_clean); rm(npr_in_clean); rm(pdr_clean_1)

### ### 9.2. CLINICAL VARIABLES

CLINICAL <- df %>% left_join(basdata_clean, by = "pid") %>%
  left_join(besok_clean, by = "pid") %>%
  left_join(terapi_clean, by = "pid") %>%
  left_join(df.serostatus.CLEAN, by = "pid") %>%
  mutate(STEROID = ifelse(is.na(visit_exist), NA, ANY_STEROID), NSAID = ifelse(is.na(visit_exist), NA, ANY_NSAID)) %>%
  select(-visit_exist, -ANY_STEROID, -ANY_NSAID)

rm(basdata_clean); rm(besok_clean); rm(terapi_clean)

### ### 9.3. MEDICAL HISTORY

MEDICAL <- df %>% left_join(npr_clean, by = "pid")
MEDICAL[is.na(MEDICAL)] <- 0

rm(npr_clean)

### ### 9.4. DRUG HISTORY

DRUG <- df %>% left_join(pdr_clean_2, by = "pid")
DRUG[is.na(DRUG)] <- 0

rm(pdr_clean_2)

### ### 9.5. WRITING DATA

write.table(SOCIODEMOGRAPHIC, "H:/Projects/MTX_PREDICT/data/SOCIODEMOGRAPHICS.tsv", row.names = F, col.names = T, quote = F, sep = "\t")
write.table(CLINICAL, "H:/Projects/MTX_PREDICT/data/CLINICAL.tsv", row.names = F, col.names = T, quote = F, sep = "\t")
write.table(MEDICAL, "H:/Projects/MTX_PREDICT/data/MEDICAL.tsv", row.names = F, col.names = T, quote = F, sep = "\t")
write.table(DRUG, "H:/Projects/MTX_PREDICT/data/DRUG.tsv", row.names = F, col.names = T, quote = F, sep = "\t")

rm(list = ls())
gc()

### TO DO:
# 1.1. There are multiple index date variables in clinical. Probably not an issue but awkward and should not be occurring if can be fixed easily.
# 1.3. A better filtering of duplicates in clinical data, would be to collapse observations (like we do with RF and ACPA) and replace missing
#       values with observed values when an observed value is available. We should implement such a solution...
### NOTES:
# 2.1. Note that we do the unintuitive filtering on degree of missingness among duplicates in visit data. We do it
#       this way instead of removing duplicates with `N_NA == max(N_NA)` since that approach will only remove ONE copy
#       from each group with a non-unique member. This is fine for all duplications, but there is a triplicate here,
#       which is now also dealt with in this line.
#       EDIT: What does this refer to? Can't find it anymore...
# 2.2. There is a problem with the DAS28-components reported for some of the individuals in the data. Going by
#       visit dates within the target interval, certain individuals have multiple. For now, I target the visit
#       closest (in days) to the index date, and then if two visits are equidistant I take the one following
#       the index date. If there are still duplicates, I select the observation with the least amount of missing.
#       However, at this point there are still people with duplicates, i.e. people with complete data from a visit
#       occurring at the same date, where the data is reported differently. I've currently chosen to cut all copies
#       of such individuals, as no choice can be made between them. Note that this is identical to BLANKING THEM, i.e.
#       setting their DAS28-component data to NA. This is relevant as we do not remove them from data, but keep them
#       and allow for the potential of imputing.
# 2.3. Note that we blank STEROIDS and NSAIDS if there is no visit detected. Thomas informed me that
#       the visit data and treatment data are linked, meaning that no visit should be a blank on the other too.
# 2.4. When joining the EIRA-antibodies onto the primary data.frame, I use a `many-to-many` call which is generally
#       not recommended. However, here we need it as there are duplicates within both the SRQb and EIRA data, which
#       means that not every line is distinct. This is OK here, because we immediately deal with duplicates afterwards,
#       so that the resulting final data.frame has only RF and ACPA for each individual once. 
# 2.5. For a few of the duplicated individuals in data on antibodies, a clear pattern emerges. Some people are
#       reported twice where they, for instance, miss RF in one observation but have it in the other. What I do
#       here is I essentially wish to 'collapse' these duplicates into one, something that was apparently much
#       more difficult to do in practice than in theory. What I ended up doing was treat the variables as strings,
#       collapse them, and then sort them out afterwards. This leaves each distinct observation untouched, but
#       duplicates are collapsed together with NA-variables overwritten only if there is distinct available
#       information. As such, we get one line for each variable.
# 2.6. I had previously not considered the fifth column here. I believe it may be valid to ignore it, as my interpretation of the column name
#       seems to indicate that this contains EIRA-controls, which a histogram of the measurements (converted to numeric after removing all `<25` values)
#       seems to agree with. Nevertheless, I considered including them here, though I never counted whether they actually lead to improvements
#       in less missing data, as it didn't seem important. I have also added some additional steps which with the current data makes no difference on the output
#       data.frame, but provides a more robust extraction that will now error out in case something strange is occurring. In particular, I deal with the non-numerical
#       values, force it to be numerical afterwards and also filter out missing IDs. Worth mentioning is that the ACPA-cutoff of 25 is based on what is written within
#       the .xlsx-file, which is also the same value given for ACPA-cutoff in EIRA in my published GWAS study, OVERLAP study and the current analysis plan. 
# 2.7. Removing the observation with the most missing works, and is a valid criterion for filtering. However, we could also consider collapsing duplicates into one,
#       similar to how we do for RF and ACPA. This makes more sense, but would be a nuisance to code. I've thus left it as a TO-DO for now (1.3).
# 2.8. Helga has a package for ICD-10 categorization. I worked on the remote when adding this into the script, and struggled
#       with getting all the tools from the package in here. Instead, I simply use a text-file version of the contents of
#       the `ICD10SE_sub_chapters` workspace within the data folder of the package. See mail conversation with HW on the 12th October for the full package.
# 2.9. I noticed earlier that some people had INDATUM and UTDATUM on the same date, meaning they came to the hospital, was
#       admitted, and left the same day. These would previously have gotten zero days in-time, which is not wrong per se
#       but makes them non-differentiated from the patients who had no visits to the hospital during the period (which will
#       also have zero days in-time). Instead, the variable now counts each unique date spent at the hospital, e.g.
#       if you were admitted but left the same day, you spent one day at the hospital and if you were admitted and left the
#       day after, you've spent two days at the hospital. It essentially now corresponds to 'nights spent in-hospital'.