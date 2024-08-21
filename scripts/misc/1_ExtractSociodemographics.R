### LAST UPDATED 26 APRIL 2024 (v1.0).
### THIS SCRIPT EXTRACTS SOCIODEMOGRAPIC TRAINING DATA FOR THE GIVEN COHORT.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(haven)
library(lubridate)
library(readr)
library(stringr)
library(tidyr)

register.sas.files <- str_c(c("tpr", "lisa", "fsk", "npr_rel", "npr_inpat", "pdr"), "_sub.sas7bdat")
register.ls <- list.files("H:/Projects/MTX_PREDICT/data/raw/registers/")
if(!all(register.sas.files %in% register.ls)) stop("ERROR: Failed to find all the registers...")      #LOOK FOR THE REGISTERS!

df <- read_tsv("H:/Projects/MTX_PREDICT/data/COHORT.tsv", show_col_types = F)

### 1. TOTAL POPULATION REGISTER

tpr.clean <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/tpr_sub.sas7bdat") %>%
  right_join(df, by = "pid") %>%
  mutate(AGE = floor(interval(birthdate, index_date) / years(1))) %>%
  mutate(BORN_IN_SWEDEN = ifelse(fodelselandgrupp == "Sverige", 1, 0)) %>%
  mutate(SEX = as.numeric(kon) - 1) %>%    #FLATTENS TO 0/1-SCALE
  distinct(pid, SEX, AGE, BORN_IN_SWEDEN)

### 2. LISA REGISTER

lisa.clean <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/lisa_sub.sas7bdat") %>%
  right_join(df, by = "pid") %>%
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

### 3. MULTI-GENERATION REGISTER

npr.rel.raw <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/npr_rel_sub.sas7bdat")
  
mgr.clean <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/mgr_sub.sas7bdat") %>%
  right_join(df, by = "pid") %>%
  filter(!is.na(pid_rel)) %>%     #REMOVE THOSE WITHOUT ANY RELATIVES IN MGR - NEEDED SINCE WE DO LEFT_JOIN BUT MORE CLEAR THIS WAY
  filter(reltyp %in% c("Mother", "Father", "Helsyskon", "Barn")) %>%     #IDENTIFY ALL FIRST-DEGREE RELATIVES
  left_join(npr.rel.raw, by = c("pid_rel" = "pid"), relationship = "many-to-many") %>%
  mutate(RA = ifelse(str_detect(HDIA, "M05|M06|M053|M060|M0[5-6][8-9]|M0[5-6][08-9][A-DF-HL-NX]"), 1, 0)) %>%
  mutate(preindex = ifelse(INDATUM < index_date, 1, 0)) %>%
  mutate(RA_preindex = ifelse(RA == 1 & preindex == 1, 1, 0)) %>%
  group_by(pid) %>% summarise(FDR_wRA = ifelse(sum(RA_preindex, na.rm = T) > 0, 1, 0))    #NEED `na.rm = T` SINCE WE LEFT JOIN AND SOME MAY NOT BE IN NPR AND THUS MISSING

rm(npr.rel.raw)

### 4. FORSAKRINGSKASSAN

fsk.clean <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/fsk_sub.sas7bdat") %>%
  right_join(df, by = "pid") %>%
  distinct(pid, DisabilityPension_Days = DP_days_1, SickLeave_Days = SL_days_1)

### 5. SRQ BASDATA

srq.clean<- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/srq_basdata_sub.sas7bdat") %>%
  right_join(df, by = "pid") %>% 
  distinct(pid, duration)

### 6. NPR HOSPITALIZATIONS

npr.clean <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/npr_inpat_sub.sas7bdat") %>%
  right_join(df, by = "pid") %>%
  filter(between(INDATUM, index_date - years(1), index_date)) %>%
  mutate(DAYS_IN_TIME = interval(INDATUM, UTDATUM) / days(1) + 1) %>%    #SEE NOTE 2.1 ABOUT THE PLUS 1
  select(-HDIA) %>%
  group_by(pid) %>% summarise(TOTAL_DAYS_IN_TIME = sum(DAYS_IN_TIME)) %>% ungroup()

### 7. PRESCRIBED DRUG REGISTER

pdr.clean <- read_sas("H:/Projects/MTX_PREDICT/data/raw/registers/pdr_sub.sas7bdat") %>%
  right_join(df, by = "pid") %>% 
  filter(between(EDATUM, index_date - years(1), index_date)) %>%
  group_by(pid) %>% summarise(TOTAL_TKOST = sum(TKOST)) %>% ungroup()

### 8. COMBINE AND OUTPUT!

df %>% left_join(tpr.clean, by = "pid") %>%
  left_join(lisa.clean, by = "pid") %>%
  left_join(mgr.clean, by = "pid") %>%
  left_join(srq.clean, by = "pid") %>%
  left_join(fsk.clean, by = "pid") %>%
  left_join(npr.clean, by = "pid") %>%
  left_join(pdr.clean, by = "pid") %>%
  mutate(TIME_INHOSP = ifelse(is.na(TOTAL_DAYS_IN_TIME), 0, TOTAL_DAYS_IN_TIME), 
         COST_DRUG = ifelse(is.na(TOTAL_TKOST), 0, TOTAL_TKOST), 
         FDR_wRA = ifelse(is.na(FDR_wRA), 0, FDR_wRA)) %>% select(-TOTAL_DAYS_IN_TIME, -TOTAL_TKOST) %>%
  write.table("H:/Projects/MTX_PREDICT/data/SOCIODEMOGRAPHICS.tsv", col.names = T, row.names = F, quote = F, sep = "\t")

rm(list = ls())

### NOTES:
# 2.1. I noticed earlier that some people had INDATUM and UTDATUM on the same date, meaning they came to the hospital, were
#       admitted, and left the same day. These would previously have gotten zero days in-time, which is not wrong per se
#       but makes them non-differentiated from the patients who had no visits to the hospital during the period (which will
#       also have zero days in-time). Instead, the variable now counts each unique date spent at the hospital, e.g.
#       if you were admitted but left the same day, you spent one day at the hospital and if you were admitted and left the
#       day after, you've spent two days at the hospital. It essentially now corresponds to 'nights spent in-hospital'.