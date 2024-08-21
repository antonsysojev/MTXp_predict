#!/usr/bin/env Rscript
### LAST VERSION UPDATE 1 MAY 2024 (v2.0).
### THIS SCRIPT CONSTRUCTS PRS THROUGH A PCA-C+T APPROACH AS IN Coombes et al. (2020).

.libPaths("/home2/genetics/antobe/software/RLibrary")
suppressWarnings(suppressMessages(library(argparser)))
suppressWarnings(suppressMessages(library(bigsnpr)))
suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(purrr)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(stringr)))

args <- arg_parser('') %>% add_argument('CLUMP', help = 'PATH TO .clumped FILE', type = 'character') %>% add_argument('BED', help = 'FILEPATH TO THE .bed FILE', type = 'character') %>% parse_args()

GWAS.df <- read_tsv(str_replace(args$CLUMP, "clumped", "tsv"), show_col_types = F) %>% mutate(SNP = str_extract(variant, "^[^\\:]+\\:[^\\:]+"), PAIR = str_extract(variant, "[^\\:]+\\:[^\\:]+$"), EA = str_extract(PAIR, "^[^\\:]+"),  RA = str_extract(PAIR, "[^\\:]+$")) %>% select(SNP, EA, RA, beta)
CLUMP.df <- read.table(args$CLUMP, header = T)[, 1:11] %>% as_tibble() %>% inner_join(GWAS.df %>% distinct(SNP, beta, EA, RA), by = "SNP") %>% arrange(CHR, BP) %>% select(SNP, P, beta, EA, RA)

snp_readBed(args$BED, "TMP/tmp-2/bed")
BFILE <- snp_attach("TMP/tmp-2/bed.rds")
GENLINK <- data.frame(GEN.IDX = 1:ncol(BFILE$genotypes), SNP = str_c(BFILE$map$chromosome, ":", BFILE$map$physical.pos), A1 = BFILE$map$allele1, A2 = BFILE$map$allele2) %>% as_tibble()
FAMLINK <- data.frame(FAM.IDX = 1:nrow(BFILE$genotypes), FID = BFILE$fam$family.ID, IID = BFILE$fam$sample.ID) %>% as_tibble()
rm(GWAS.df)

### 1. THRESHOLDING VARIANTS INTO SUBSETS

WEIGHTS.df <- GENLINK %>% inner_join(CLUMP.df, by = "SNP", relationship = "many-to-many") %>%    #The many-to-many join is resolved by the matching below...
    mutate(BETA.CORR = case_when(A1 == EA & A2 == RA ~ beta, A1 == RA & A2 == EA ~ -1 * beta, .default = NA)) %>% 
    filter(!is.na(BETA.CORR)) %>%     #Washes out variants that may be resolvable, but testing indicated these to be minor overall
    select(GEN.IDX, SNP, P, BETA = BETA.CORR)

THRESHOLD.vec <- c(5e-10, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 5e-2, 1e-1, 5e-1, 1+00)		#SAME GRID AS IS USED WITHIN Coombes et al. AND RECOMMENDED IN THEIR DISCUSSION AS STABLE
CT.list <- map(THRESHOLD.vec, function(x) WEIGHTS.df %>% filter(P <= x))

### 2. COMPUTING POLYGENIC RISK SCORES WITHIN EACH THRESHOLDED SUBSET

PRS.df <- FAMLINK
for(i in 1:length(CT.list)){

    if(nrow(CT.list[[i]]) > 0){    #Safety belt - skip subsets where no variant was below the threshold

        BFILE.sub <- BFILE$genotypes[, CT.list[[i]]$GEN.IDX]
        BFILE.sub[is.na(BFILE.sub)] <- 0    #Sets all missing effects to zero to allow computation of a score (identical in practice to using `na.rm = T` in the matrix multiplication)
        BFILE.sub <- as.matrix(BFILE.sub)    #Forces format to be matrix, even in the case of a singular variant

        PRS.raw <- BFILE.sub %*% CT.list[[i]]$BETA %>% as.data.frame()
        colnames(PRS.raw) <- str_c("PRS.", i)
        PRS.standardized <- PRS.raw %>% mutate(FAM.IDX = 1:nrow(PRS.raw), .before = everything()) %>% mutate(across(-FAM.IDX, ~ (.x - mean(.x, na.rm = T)))) %>% mutate(across(-FAM.IDX, ~ (.x / sd(.x, na.rm = T)))) %>% as_tibble()

        PRS.df <- PRS.df %>% left_join(PRS.standardized, by = "FAM.IDX")
        rm(BFILE.sub); rm(PRS.raw); rm(PRS.standardized)

    }

}

### 3. TRANSFORM POLYGENIC RISK SCORES THROUGH PRINCIPAL COMPONENTS

PRS.sub.df <- PRS.df %>% select(starts_with("PRS")) %>% as.data.frame()
rownames(PRS.sub.df) <- PRS.df$FAM.IDX
prcomp.res <- prcomp(PRS.sub.df, center = T, scale = T)

PRSPCA.df <- data.frame(FAM.IDX = rownames(prcomp.res$x) %>% as.numeric(), PRSPCA.1 = prcomp.res$x[, 1]) %>% right_join(FAMLINK, by = "FAM.IDX") %>% select(FID, IID, PRSPCA.1)
colnames(PRSPCA.df) <- c("FID", "IID", str_c("PRSPCA.", str_extract(args$CLUMP, "[^\\/]+\\.clumped") %>% str_remove("\\.clumped")))
write.table(PRSPCA.df, str_replace(args$CLUMP, "clumped", "PRSPCA"), col.names = T, row.names = F, quote = F, sep = "\t")

### TO DO:
### NOTES: