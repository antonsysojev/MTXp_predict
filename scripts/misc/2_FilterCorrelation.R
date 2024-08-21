#!/usr/bin/env Rscript
### LAST UPDATED 19 FEB 2024 (v1.2) - UPDATED TO NOW CONSIDER MULTIPLES WITH IDENTICAL VARIANCE
### THIS SCRIPT FILTERS THE VARIABLES IN THE NPR AND PDR DATA ON CORRELATION

.libPaths("/home2/genetics/antobe/software/RLibrary")
suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(purrr)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(stringr)))

df <- read_tsv("TMP/tmp-2/MEDICAL-DRUG.VARFILT.tsv", show_col_types = F)
CORR_CUTOFF <- 0.95

df_FEATURES <- df %>% select(-pid, -index_date)
converged <- FALSE
list_LOG <- list()
iter <- 1

while(!converged){

    COMBINATIONS <- combn(df_FEATURES, m = 2, simplify = F)    #ACQUIRES ALL PAIRINGS
    names(COMBINATIONS) <- (combn(names(df_FEATURES), m = 2, simplify = T) %>% t() %>% as.data.frame() %>% mutate(ID = str_c(V1, "-", V2)))$ID
    CORR_RES <- map_dfc(COMBINATIONS, function(x) sum(x[1] == x[2]) / nrow(x))    #COMPUTES THE PROPORTION IDENTICAL

    if(any(CORR_RES > CORR_CUTOFF)){

      MAX_PAIR <- CORR_RES[, which(CORR_RES == max(CORR_RES))]    #IDENTIFY HIGHEST CORR - NOTE THAT THERE CAN BE MULTIPLE (SEE TODO 1.1.).
      VAR_PAIR <- df_FEATURES %>% select(str_split(names(MAX_PAIR), "-", simplify = T) %>% as.vector()) %>% summarise_all(var)
      MIN_VAR_PAIR <- VAR_PAIR[which(VAR_PAIR == min(VAR_PAIR))] %>% names()    #EXTRACTS THE ONE WITH MINIMUM VARIANCE
      MIN_VAR_PAIR <- MIN_VAR_PAIR[1]		#RESOLVES ISSUES OF IDENTICAL VARIANCES... SEE TODO 1.2.

      df_FEATURES <- df_FEATURES %>% select(-all_of(MIN_VAR_PAIR))
      list_LOG[[iter]] <- data.frame(VAR_PAIRS = str_c(names(MAX_PAIR), collapse = ", "), CORR = MAX_PAIR %>% unlist() %>% unique(), VAR_REMOVED = str_c(MIN_VAR_PAIR, collapse = ", ")) 

     }else{converged <- TRUE}
    
    iter <- iter + 1
    #if(iter_count %% 10 == 0) print(str_c("PASSED THROUGH ", iter_count, " ITERATIONS..."))	#COUNTER, HIDDEN FOR NOW

}

df_CLEAN <- df %>% select(pid, index_date, names(df_FEATURES))
df_LOG <- list_LOG %>% bind_rows() %>% as_tibble()

write.table(df_CLEAN, "TMP/tmp-2/MEDICAL-DRUG.VARFILT.CORRFILT.tsv", row.names = F, col.names = T, quote = F, sep = "\t")
write.table(df_LOG, "data/log/MEDICAL-DRUG.VARFILT.CORRFILT.log", row.names = F, col.names = T, quote = F, sep = "\t")        #INCLUDE A LOG-FILE SO THAT WE CAN CHECK THAT NOTHING WENT AWKWARD - MOSTLY USED FOR DEVELOPMENT

### TO DO:
# 1.1. Current filtering procedures means we may identify more than one pair of features in concordance, as several pairs may have
#	identical concordance rates (e.g. a pair A-B of 0.97, and a pair A-C of 0.97, or even A-B of 0.97 and C-D of 0.97). Going by
#	minimal variance is OK as long as we do not have identical variances, when there may be an issue in the case of tha first
#	example. Here, cutting B means we will also cut A or C down the line, leading to two variables disappearing, whereas cutting A
#	means we retain both B and C, given that they are not in high concordance with each other or anything else. This is messy to
#	implement and not something I'm considering at the moment.
# 1.2. Current resolution of multiple identical variances prioritizes the 'first' by position. This is an arbitrary approach which,
#	while not introducing any bias, may remove specific features of interest and will be difficult to replicate in independent data,
#	if we do not believe strongly in the data (which I am not confident enough in at ~3000 samples). Add a secondary criterion which should
# increase reproducibility...
### NOTES:
# 2.1. Have hid the iteration count for now; we can easily make it print when running the script, it might be nice to have?
#	But for now, I wasn't sure I'd keep it and just left it here.