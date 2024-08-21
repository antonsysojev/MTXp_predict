### LAST VERSION UPDATED 23 MAY 2024 (v1.0).
### THIS SCRIPT TAKES A FINAL MODEL AS INPUT, AND COMPUTES KERNEL-BASED GLOBAL SHAP VALUES.

.libPaths("H:/Programs/RLibrary/")
library(argparser)
library(doParallel)
library(dplyr)
library(foreach)
library(kernelshap)
library(readr)
library(stringr)

### 1. SETUP

args <- arg_parser('') %>% add_argument('TRAIN', help = '', type = 'character') %>% add_argument('MODEL', help = '', type = 'character') %>% add_argument('OUTCOME', help = '', type = 'character') %>% parse_args()

labels.df <- read_tsv("data/LABELS.FOLDS.tsv", show_col_types = F)
train.raw <- read_tsv(args$TRAIN, show_col_types = F)
pred.model <- readRDS(str_c("data/output/res/", str_extract(args$TRAIN, "TRAIN\\d"), ".", args$MODEL, ".", args$OUTCOME, ".rds"))

train.df <- labels.df %>% select(pid, OUTCOME = all_of(args$OUTCOME)) %>% 
  inner_join(train.raw, by = "pid") %>%
  filter(!is.na(OUTCOME)) %>% 
  mutate(OUTCOME = ifelse(OUTCOME == 1, "YES", "NO") %>% as.factor(), .before = everything()) %>% 
  select(-pid, -index_date, -TOTAL_TKOST)

### 2. KERNEL SHAP INPUTS

set.seed(31415)
n.inds <- nrow(train.df); n.bg <- 500
X <- train.df %>% slice(sample(1:nrow(train.df), n.inds)) %>% select(-OUTCOME) %>% as.data.frame()
X.bg <- train.df %>% slice(sample(1:nrow(train.df), n.bg)) %>% as.data.frame()     #SEE NOTE 2.1.

### 3. PERFORMING KERNEL SHAP

#! Setup cluster. See NOTES 2.2.

shap.kernel <- kernelshap(pred.model, X, bg_X = X.bg)
saveRDS(shap.kernel, str_replace(args$MODEL, "\\.rds", "\\.kernelshap.rds"))

#! Close cluster.

### NOTES:
# 2.1. Tried several different sizes of the background data, but performance seemed robust. Originally wanted to do X.bg = X but it takes
#       a lot of time and even at nrow(X.bg) > 1000 we see no real difference in results. This is fast enough and efficient, and can probably
#       be reduced further (250? Possibly).
# 2.2. I tried adding parallelization through the built-in `kernelshap()` functionality, though testing gave me awkward performance.
#       First of all, it removes the progress bar (can't have progress bar on parallel workers), so gauging time was difficult. Second,
#       testing indicated that performance was slower (how?) and standard performance was not too bad. If parallel implementations were to be
#       implemented, for global feature importance, then either (i) split up data, make a loop that goes in parallel over each split or (ii),
#       make a bootleg version of `kernelshap()` through the available github source code, and make the internal function run in parallel.