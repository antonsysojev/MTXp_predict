#!/usr/bin/env Rscript
### LAST UPDATED 4 MAR 2024 (v2.2.1.) - NOW USES SEROSTATUS INSTEAD OF RF/ACPA
### THIS SCRIPT AGGREGATES THE SOCIODEMOGRAPHIC, CLINICAL, MEDICAL AND DRUG DATA, IMPUTES THE MISSING DATA AND OUTPUTS AN AGGREGATED FILE

.libPaths("/home2/genetics/antobe/software/RLibrary")
suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(missForest)))
suppressWarnings(suppressMessages(library(purrr)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(tidyr)))

SOCIODEMOGRAPHIC <- read_tsv("data/SOCIODEMOGRAPHICS.tsv", show_col_types = F)
CLINICAL <- read_tsv("data/CLINICAL.tsv", show_col_types = F)
MEDICAL_DRUG <- read_tsv("TMP/tmp-2/MEDICAL-DRUG.VARFILT.CORRFILT.tsv", show_col_types = F)

### 1. SETUP.

df <- SOCIODEMOGRAPHIC %>% left_join(CLINICAL %>% select(-index_date), by = "pid") %>% 
  left_join(MEDICAL_DRUG %>% select(-index_date), by = "pid") %>%
  mutate(EDUCATION = as.factor(EDUCATION), 
         SMOKE = as.factor(SMOKE), 
         SEROPOSITIVITY_COMBINED = as.factor(SEROPOSITIVITY_COMBINED), 
         STEROID = as.factor(STEROID), 
         NSAID = as.factor(NSAID)) %>%      #DISCRETE FEATURES MUST BE FACTORS
  as.data.frame()	    #`missForest` CAN NOT HANDLE `tibble` AND REQUIRES A `data.frame`

### 2. IMPUTATION WITH `missForest`

set.seed(314159)
rownames(df) <- df$pid		#IDENTIFIER FOR SUBSEQUENT LINKAGE - REDUNDANT BUT A GOOD SAFETY
df_IMPUTED <- missForest(df %>% select(-pid, -index_date), verbose = T, maxiter = 25)		#SEE NOTE 2.1 FOR DETAILS

### 3. CLEAN UP AND OUTPUT

df_IMPUTED_RAW <- df_IMPUTED$ximp %>% mutate(pid = rownames(df_IMPUTED$ximp) %>% as.numeric()) %>% 
    right_join(df %>% select(pid, index_date), by = "pid") %>% select(pid, index_date, everything()) %>% 
    mutate(svullna_leder = round(svullna_leder, 0), omma_leder = round(omma_leder, 0)) %>%	#ROUND VALUES THAT SHOULD BE INTEGERS
    mutate(das28 = 0.28 * sqrt(svullna_leder) + 0.56 * sqrt(omma_leder) + 0.70 * log(sr) + 0.014 * patientens_globala) %>%	#SEE NOTE 2.3. ON COMPUTING THIS
    mutate(das28CRP = 0.28 + sqrt(svullna_leder) + 0.56 * sqrt(omma_leder) + 0.36 * log(crp + 1) + 0.014 * patientens_globala + 0.96) %>% 
    mutate(EDUCATION_01 = ifelse(EDUCATION == 1, 1, 0), EDUCATION_02 = ifelse(EDUCATION == 2, 1, 0),      #MANUAL ONE-HOT ENCODING OF NON-BINARY CATEGORICAL VARIABLES
           SMOKE_01 = ifelse(SMOKE == 1, 1, 0), SMOKE_02 = ifelse(SMOKE == 2, 1, 0)) %>% select(-EDUCATION, -SMOKE) %>% as_tibble()

non_categorical_feat.char <- c("AGE", "TIME_INHOSP", "COST_DRUG", "DisabilityPension_Days", "SickLeave_Days", "duration", "svullna_leder", "omma_leder", "sr", "crp", "patientens_globala", "haq", "smarta", "das28", "das28CRP")
df_IMPUTED_STD <- df_IMPUTED_RAW %>% mutate(across(all_of(non_categorical_feat.char), ~ (.x - mean(.x, na.rm = T)) / sd(.x, na.rm = T)))    #STANDARDIZE AFTER IMPUTATION (SEE NOTE 2.2.)

write.table(df_IMPUTED_STD, "TMP/tmp-2/NONGENETIC.tsv", row.names = F, col.names = T, quote = F, sep = "\t")

### TO DO:
# 1.1. We can add parallelization to reduce the time needed to perform the computations - not crucial at this point.
# 1.2. We should add a check on the output data after the imputation... we can make a function that takes as input the imputation input and the imputation output, and checks
#	that range is preserved, that categorical variables have nothing outside of integers and so forth...
# 1.3. Is there a need for standardization? We kept this in as the original plan was to add unsupervised clustering on top of the project, but it was left out at a later stage.
### NOTES:
# 2.1. I did a few simple tests on the imputation algorithm but I did not find that changes to a parameter like `mtry` changed our results at all.
#	The only thing I did find that it modified was the computational time (which seemed to consistently increase for both lower and higher values than default).
# 2.2. Standardization is done AFTER imputation, this is to make sure that continuous variables remain standardized, even after imputed data has been included, something that was not
#	necessarily the case when doing it the other-way-around. Furthermore, it has the added benefit of allowing the user to check whether imputed data are realistic or not, e.g. if
#	the swollen joint count is between 0 and 28 and such. This also allows me to infer DAS28 from the imputed values over the components, something that would be impossible due to the
#	distorted scale from standardization.
# 2.3. Formula for the DAS28-ESR and DAS28-CRP is available on 4s-dawn.com/DAS28, but can also be extracted from the original publication: Prevoo et al., 1995, for DAS28-ESR. Not sure
#	where to find the paper for the DAS28-ESR though... I believe it is by Fransen et al., but I can only find a Word-file containing its description.
