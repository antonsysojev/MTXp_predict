#!/user/bin/env Rscript
### LAST VERSION UPDATE JAN 15 2024 (v2.2) - REMOVED UNNECESSARY PACKAGE DEPENDENCE, UPDATED TO WORK WITH GENERALIZED QC SCRIPT
### TAKES THE PLINK2 PCA OUTPUT AS INPUT, FILTERS OUT INDIVIDUALS ANALOGOUSLY TO EIGENSOFT, OUTPUTS A LIST OF IDS FOR EXCLUSION VIA PLINK

.libPaths('/home2/genetics/antobe/software/RLibrary/')
suppressMessages(library(argparser))
suppressMessages(library(dplyr))

args <- arg_parser('') %>% add_argument('DATA', help = 'FILEPATH TO THE .eigenvec FILE PRODUCED BY PLINK', type = 'character') %>% parse_args()

pca.df <- read.table(paste0(args$DATA, '.eigenvec'), header = F)
sigma <- 6    #N STANDARD DEVIATIONS USED FOR FILTRATIONS - SIX IS DEFAULT IN EIGENSOFT

mean.pci <- pca.df %>% summarise(across(3:ncol(pca.df), mean))
sd.pci <- pca.df %>% summarise(across(3:ncol(pca.df), sd))
target_Lbound <- mean.pci - sigma * sd.pci
target_Ubound <- mean.pci + sigma * sd.pci

outlier_IDs <- list()
for(i in 1:(ncol(pca.df)-2)){outlier_IDs[[i]] <- pca.df %>% select(1:2, PC_TARGET = i + 2) %>% mutate(FAILURE = ifelse(between(PC_TARGET, target_Lbound[i] %>% as.numeric(), target_Ubound[i] %>% as.numeric()), 0, 1)) %>% filter(FAILURE == 1) %>% select(1:2)}
bind_rows(outlier_IDs) %>% distinct() %>% write.table(paste0(args$DATA, ".outliers"), quote = F, row.names = F, col.names = F, sep = "\t")
