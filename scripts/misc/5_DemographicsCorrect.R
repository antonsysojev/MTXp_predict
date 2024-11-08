### LAST VERSION UPDATE 24 JUNE 2024 (v1.1).
### THIS SCRIPT EXTRACTS CHARACTERISTICS FOR THOSE CLASSIFIED AS NON-PERSISTENT.

.libPaths("H:/Programs/RLibrary/")
library(argparser)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(openxlsx)

args <- arg_parser('') %>% add_argument('NEG.CUT', type = "numerical") %>% add_argument('POS.CUT', type = "numerical") %>% add_argument('CALIBRATION', type = "character") %>% parse_args()
ntile.neg <- args$NEG.CUT
ntile.pos <- args$POS.CUT

prob.files <- list.files("data/output/res")[str_which(list.files("data/output/res"), "Prob")]
prob.p1yr.file <- prob.files[str_which(prob.files, "persistence_d365")]
prob.p3yr.file <- prob.files[str_which(prob.files, "persistence_d1096")]
prob.p1yr.df <- read_tsv(str_c(FOLDERPATH, "data/output/res/", prob.p1yr.file)) %>% mutate(TYPE = "persistence_d365")
prob.p3yr.df <- read_tsv(str_c(FOLDERPATH, "data/output/res/", prob.p3yr.file)) %>% mutate(TYPE = "persistence_d1096")
prob.df <- prob.p1yr.df %>% bind_rows(prob.p3yr.df) %>% arrange(pid)
# Previous code just loaded a TMP-file, this ought to work better!

sociodemographics.df <- read_tsv("H:/Projects/MTX_PREDICT/data/SOCIODEMOGRAPHICS.tsv", show_col_types = F)
clinical.df <- read_tsv("H:/Projects/MTX_PREDICT/data/CLINICAL.tsv", show_col_types = F) %>% select(-index_date)

recalibrate.id <- str_c("PROB.", args$CALIBRATION)
cut.val <- c(0.65, 0.45, 0.65, 0.45)    #! This should be automated...
type.id <- c("persistence_d365", "persistence_d1096", "persistence_d365", "persistence_d1096")
column.id <- c("negative", "negative", "positive", "positive")
df.list <- list()

for(j in 1:length(cut.val)){
  
  if(column.id[j] == "negative"){
    complete.df <- prob.df %>% left_join(sociodemographics.df, by = "pid") %>% left_join(clinical.df, by = "pid") %>%
      mutate(my.PROB = get(recalibrate.id)) %>%
      filter(TYPE == type.id[j]) %>%
      mutate(decile.outer = ntile(my.PROB, 10)) %>% filter(decile.outer <= ntile.neg) %>% 
      mutate(PRED.OUT = ifelse(my.PROB < cut.val[j], 0, 1)) %>% filter(OUTCOME == PRED.OUT, OUTCOME == 0)
  }
  
  if(column.id[j] == "positive"){
    complete.df <- prob.df %>% left_join(sociodemographics.df, by = "pid") %>% left_join(clinical.df, by = "pid") %>%
      mutate(my.PROB = get(recalibrate.id)) %>% 
      filter(TYPE == type.id[j]) %>%
      mutate(decile.outer = ntile(my.PROB, 10)) %>% filter(decile.outer >= ntile.pos) %>%
      mutate(PRED.OUT = ifelse(my.PROB < cut.val[j], 0, 1)) %>% filter(OUTCOME == PRED.OUT, OUTCOME == 1) 
  }
  
  complete.df <- complete.df %>% mutate(EDUCATION_01 = case_when(EDUCATION == 1 ~ 1, .default = 0), 
                                        EDUCATION_02 = case_when(EDUCATION == 2 ~ 1, .default = 0),
                                        SMOKE_01 = case_when(SMOKE == 1 ~ 1, .default = 0),
                                        SMOKE_02 = case_when(SMOKE == 2 ~ 1, .default = 0))
  
  ### 1. COUNTS AND PERCENTAGES
  
  counts.list <- list()
  counts.id <- c("SEX", "BORN_IN_SWEDEN", "FDR_wRA", "EDUCATION_01", "EDUCATION_02", "SMOKE_01", "SMOKE_02", "SEROPOSITIVITY_COMBINED", "STEROID", "NSAID")
  for(i in 1:length(counts.id)){
    counts.list[[i]] <- complete.df %>% select(PRED.OUT, VAR = all_of(counts.id[i])) %>%
      filter(!is.na(VAR)) %>%
      group_by(PRED.OUT, VAR) %>% summarise(N = n(), .groups = "drop") %>%
      group_by(PRED.OUT) %>% mutate(N.TOT = sum(N), N.PERC = N / N.TOT) %>% ungroup() %>%
      mutate(VAR.ID = counts.id[i])
  }
  counts.long.df <- counts.list %>% bind_rows() %>% mutate(ESTIMATE = str_c(N, " (", round(N.PERC, 2), ")")) %>% select(VAR.ID, ESTIMATE, VAR, PRED.OUT)
  counts.df <- counts.long.df %>% filter(!is.na(PRED.OUT), !is.na(VAR)) %>% filter(VAR == 1) %>% pivot_wider(names_from = PRED.OUT, values_from = ESTIMATE) %>% select(-VAR)
  colnames(counts.df) <- c("VAR.ID", "VALUE")
  
  ### 2. MEDIAN AND IQR
  
  medians.list <- list()
  medians.id <- c("AGE", "TIME_INHOSP", "DisabilityPension_Days", "SickLeave_Days", "COST_DRUG", "duration", "svullna_leder", "omma_leder", "sr", "crp", "patientens_globala", "haq", "smarta")
  for(i in 1:length(medians.id)){
    medians.list[[i]] <- complete.df %>% select(PRED.OUT, VAR = all_of(medians.id[i])) %>%
      filter(!is.na(VAR)) %>%
      group_by(PRED.OUT) %>% summarise(MEDIAN = median(VAR, na.rm = T), MIN = min(VAR, na.rm = T), MAX = max(VAR, na.rm = T), IQR = IQR(VAR, na.rm = T), .groups = "drop") %>%
      mutate(VAR.ID = medians.id[i])
  }
  
  medians.long.df <- medians.list %>% bind_rows() %>% mutate(ESTIMATE = str_c(MEDIAN, " (", IQR, "; ", MIN, "-", MAX, ")")) %>% select(VAR.ID, ESTIMATE, PRED.OUT)
  medians.df <- medians.long.df %>% filter(!is.na(PRED.OUT)) %>% pivot_wider(names_from = PRED.OUT, values_from = ESTIMATE)
  colnames(medians.df) <- c("VAR.ID", "VALUE")
  
  df.list[[j]] <- bind_rows(counts.df, medians.df) %>% mutate(OUT.TYPE = type.id[j], LABEL.TYPE = column.id[j])
  print(str_c("Number of individuals in ", type.id[j], " class ", column.id[j], " N = ", nrow(complete.df)))
  
}

table.df <- df.list %>% bind_rows() %>% pivot_wider(names_from = c(LABEL.TYPE, OUT.TYPE), values_from = VALUE)

### 3. P-VALUES FOR CATEGORICAL
### 3.1. PERSISTENCE AT ONE YEAR

counts.df.365 <- table.df %>% filter(VAR.ID %in% counts.id) %>% 
  select(VAR.ID, negative_persistence_d365, positive_persistence_d365) %>%
  mutate(N.neg = str_extract(negative_persistence_d365, "\\d+") %>% as.numeric(), N.pos = str_extract(positive_persistence_d365, "\\d+") %>% as.numeric())

p.cat.df <- data.frame(VAR = counts.id); p.vec <- numeric(length(counts.id))
for(i in 1:length(counts.id)){p.vec[i] <- prop.test(x = c(counts.df.365[i, "N.neg"] %>% as.numeric(), counts.df.365[i, "N.pos"] %>% as.numeric()), n = c(143, 197))$p.value}
p.cat.df$P.365 <- p.vec

### 3.2. PERSISTENCE AT THREE YEARS

counts.df.1096 <- table.df %>% filter(VAR.ID %in% counts.id) %>% 
  select(VAR.ID, negative_persistence_d1096, positive_persistence_d1096) %>%
  mutate(N.neg = str_extract(negative_persistence_d1096, "\\d+") %>% as.numeric(), N.pos = str_extract(positive_persistence_d1096, "\\d+") %>% as.numeric())

for(i in 1:length(counts.id)){p.vec[i] <- prop.test(x = c(counts.df.1096[i, "N.neg"] %>% as.numeric(), counts.df.1096[i, "N.pos"] %>% as.numeric()), n = c(175, 148))$p.value}
p.cat.df$P.1096 <- p.vec

### 4. P-VALUES FOR NUMERICAL
### 4.1. PERSISTENCE AT ONE YEAR

prob.yes.df <- prob.df %>% left_join(sociodemographics.df, by = "pid") %>% left_join(clinical.df, by = "pid") %>%
  mutate(my.PROB = get(recalibrate.id)) %>%
  filter(TYPE == "persistence_d365") %>%
  mutate(decile.outer = ntile(my.PROB, 10)) %>% filter(decile.outer <= ntile.neg) %>% 
  mutate(PRED.OUT = ifelse(my.PROB < 0.65, 0, 1)) %>% filter(OUTCOME == PRED.OUT, OUTCOME == 0)

prob.no.df <- prob.df %>% left_join(sociodemographics.df, by = "pid") %>% left_join(clinical.df, by = "pid") %>%
  mutate(my.PROB = get(recalibrate.id)) %>% 
  filter(TYPE == "persistence_d365") %>%
  mutate(decile.outer = ntile(my.PROB, 10)) %>% filter(decile.outer >= ntile.pos) %>%
  mutate(PRED.OUT = ifelse(my.PROB < 0.65, 0, 1)) %>% filter(OUTCOME == PRED.OUT, OUTCOME == 1)

p.numeric.df <- data.frame(VAR = medians.id)
for(i in 1:length(medians.id)){p.numeric.df[i, "P.365"] <- (t.test(prob.yes.df[, medians.id[i]], prob.no.df[, medians.id[i]]))$p.value}

prob.yes.df <- prob.df %>% left_join(sociodemographics.df, by = "pid") %>% left_join(clinical.df, by = "pid") %>%
  mutate(my.PROB = get(recalibrate.id)) %>%
  filter(TYPE == "persistence_d1096") %>%
  mutate(decile.outer = ntile(my.PROB, 10)) %>% filter(decile.outer <= ntile.neg) %>% 
  mutate(PRED.OUT = ifelse(my.PROB < 0.45, 0, 1)) %>% filter(OUTCOME == PRED.OUT, OUTCOME == 0)

prob.no.df <- prob.df %>% left_join(sociodemographics.df, by = "pid") %>% left_join(clinical.df, by = "pid") %>%
  mutate(my.PROB = get(recalibrate.id)) %>% 
  filter(TYPE == "persistence_d1096") %>%
  mutate(decile.outer = ntile(my.PROB, 10)) %>% filter(decile.outer >= ntile.pos) %>%
  mutate(PRED.OUT = ifelse(my.PROB < 0.45, 0, 1)) %>% filter(OUTCOME == PRED.OUT, OUTCOME == 1)

for(i in 1:length(medians.id)){p.numeric.df[i, "P.1096"] <- (t.test(prob.yes.df[, medians.id[i]], prob.no.df[, medians.id[i]]))$p.value}

### 5. AGGREGATE AND OUTPUT

order.var.idx <- data.frame(VAR = c("SEX", "AGE", "BORN_IN_SWEDEN", "FDR_wRA", "EDUCATION_01", "EDUCATION_02", "SMOKE_01", "SMOKE_02", "TIME_INHOSP", "DisabilityPension_Days",
                                    "SickLeave_Days", "COST_DRUG", "duration", "SEROPOSITIVITY_COMBINED", "svullna_leder", "omma_leder", "sr", "crp", "patientens_globala",
                                    "STEROID", "NSAID", "haq", "smarta"), IDX = 1:23)

df.clean <- p.cat.df %>% bind_rows(p.numeric.df) %>% 
  right_join(table.df, by = c("VAR" = "VAR.ID")) %>% as_tibble() %>%
  left_join(order.var.idx, by = "VAR") %>% arrange(IDX) %>%
  select(VAR, negative_persistence_d365, positive_persistence_d365, P.365, negative_persistence_d1096, positive_persistence_d1096, P.1096)

write.xlsx(df.clean, str_c("data/output/res/TableDemographicsCorrectNtileNeg", ntile.neg, "NtilePos", ntile.pos, ".xlsx"))