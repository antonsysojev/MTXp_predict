### LAST VERSION UPDATED 10 JUNE 2024 (v1.1).
### THIS SCRIPTS EXTRACTS RECALIBRATED PROBABILITIES (PLATT, ISOTONIC AND BETA)

.libPaths("H:/Programs/RLibrary/")
library(betacal)
library(dplyr)
library(readr)
library(stringr)

### 1. SETUP

args <- arg_parser('') %>% add_argument('TRAIN', help = '', type = 'character') %>% add_argument('MODEL', help = '', type = 'character') %>% add_argument('OUTCOME', help = '', type = 'character') %>% parse_args()

model.raw <- readRDS(str_c("data/output/res/", str_extract(args$TRAIN, "TRAIN\\d"), ".", args$MODEL, ".", args$OUTCOME, ".rds"))
train.raw <- read_tsv(str_c("data/output/res/", str_extract(args$TRAIN, "TRAIN\\d"), ".", args$MODEL, ".", args$OUTCOME, ".tsv"))

train.df <- train.raw %>% mutate(OUTCOME = case_when(OUTCOME == "YES" ~ 1, OUTCOME == "NO" ~ 0, .default = NA))

### 2. RESCALING - PLATT, ISOTONIC AND BETA  

platt.prob <- glm(OUTCOME ~ PROB, data = train.df, family = binomial(link = "logit"))$fitted    #PLATT

source("scripts/utils/Isoreg.R")    #ISOTONIC
train.df.uniq <- train.df %>% group_by(PROB) %>% filter(n() == 1) %>% ungroup()    #REMOVE DUPLICATES OR FUNCTION WILL BREAK
iso.reg <- isoreg(train.df.uniq$PROB, train.df.uniq$OUTCOME)
iso.prob <- fit.isoreg(iso.reg, train.df.uniq$PROB)
iso.df <- data.frame(PROB = train.df.uniq$PROB, PROB.ISO = iso.prob)

bc <- beta_calibration(train.df$PROB, train.df$OUTCOME, parameters = "abm")    #BETA
beta.prob <- beta_predict(train.df$PROB, bc)

train.df$PROB.PLATT <- platt.prob
train.df$PROB.BETA <- beta.prob
train.df.complete <- train.df %>% left_join(iso.df, by = "PROB")

### 3. OUTPUT

write.table(train.df, str_c("data/output/res/", str_extract(args$TRAIN, "TRAIN\\d"), ".", args$MODEL, ".", args$OUTCOME, "RecalibratedProb.tsv"), col.names = T, row.names = F, quote = F, sep = "\t")