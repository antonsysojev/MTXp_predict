### LAST VERSION UPDATED 23 MAY 2024 (v1.0).
### THIS SCRIPT EXTRACTS A FEATURE IMPORTANCE PLOT PER THE INFERRED SHAP-VALUES.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(ggplot2)
library(stringr)
library(openxlsx)

outcomes <- c("persistence_d365", "persistence_d1096")

for(i in 1:length(outcomes)){
  
  ### 1. READ AND CLEAN DATA
  
  #shap.res <- readRDS("H:/Projects/MTX_PREDICT/TMP/SHAP-dev/SHAP.res.rds")
  shap.res <- readRDS(str_c("H:/Projects/MTX_PREDICT/data/output/res/TRAIN2.glmnet.", outcomes[i], ".kernelshap.rds"))
  
  shap.yes.abs <- shap.res$S$YES %>% apply(MARGIN = 2, FUN = function(x) mean(abs(x)))
  shap.yes.mean <- shap.res$S$YES %>% apply(MARGIN = 2, FUN = mean)
  
  shap.no.abs <- shap.res$S$NO %>% apply(MARGIN = 2, FUN = function(x) mean(abs(x)))
  shap.no.mean <- shap.res$S$NO %>% apply(MARGIN = 2, FUN = mean)
  
  shap.yes.df <- data.frame(VAR = names(shap.yes.abs), SHAP.ABS = shap.yes.abs, SHAP.MEAN = shap.yes.mean) %>% as_tibble() %>% arrange(desc(SHAP.ABS)) %>% mutate(POS.ID = 1:nrow(.))
  shap.no.df <- data.frame(VAR = names(shap.no.abs), SHAP.ABS = shap.no.abs, SHAP.MEAN = shap.no.mean) %>% as_tibble() %>% arrange(desc(SHAP.ABS)) %>% mutate(POS.ID = 1:nrow(.))
  
  ### 2. CLEANING VAR NAMES FOR PRESENTATION...
  
  demo.clinvar.names <- data.frame(RAW = colnames(shap.res$X)[1:19], CLEAN = c("Sex", "Age", "Born in Sweden", "First-degree relative with RA", "Disease duration (months)", 
                                                                               "Days on Disability Pension", "Days on Sick Leave", "Days Hospitalized", "Drug Expenses (SEK)", 
                                                                               "Swollen Joint Count (28)", "Tender Joint Count (28)", "Erythrocyte Sedimentation Rate", "C-reactive Protein", 
                                                                               "Patient Global Health", "Health Assessment Questionaire Index", "Pain (VAS)", "Seropositivity", "Corticosteroids", "NSAIDs"))
  
  icd10.names <- read.xlsx("H:/Projects/MTX_PREDICT/TMP/ICD10.ids.xlsx", colNames = F) %>% 
    mutate(ICD.raw = str_extract(X1, "\\([A-Z]+\\d+\\-[A-Z]+\\d+\\)")) %>%
    mutate(ICD = str_remove(ICD.raw, "\\(") %>% str_remove("\\)") %>% str_replace("-", "_")) %>% select(RAW = ICD, CLEAN = X1)
  
  atc.names <- read.xlsx("H:/Projects/MTX_PREDICT/TMP/ATC.ids.xlsx", colNames = F) %>%
    mutate(ATC.raw = str_extract(X1, "\\([A-Z]+\\d+[A-Z]+\\)")) %>%
    mutate(ATC = str_remove(ATC.raw, "\\(") %>% str_remove("\\)")) %>% select(RAW = ATC, CLEAN = X1)
  
  remainder.names <- data.frame(RAW = colnames(shap.res$X)[104:126], CLEAN = c("das28", "das28-CRP", "Educational level 9-12 years", "Educational level > 12 years", "Previous smoker", "Current smoker",
                                                                               "PRS for Asthma", "PRS for Bipolar Disorder", "PRS for BMI", "PRS for Chronic Obstructive Pulmonary Disorder", "PRS for Crohns",
                                                                               "PRS for C-reactive protein levels", "PRS for Major Depressive Disorder", "PRS for Hypertension", "PRS for Hyperthyroidism", 
                                                                               "PRS for Rheumatoid Arthrits", "PRS for Schizophrenia", "PRS for smoking status", "PRS for Type 1 Diabetes", "PRS for Type 2 Diabetes", 
                                                                               "PRS for Ulcerative Colitis", "PRS for Duodenal Ulcer", "PRS for Gastric Ulcer"))
  
  shap.yes.df.clean <- demo.clinvar.names %>% bind_rows(icd10.names) %>% bind_rows(atc.names) %>% bind_rows(remainder.names) %>% right_join(shap.yes.df, by = c("RAW" = "VAR")) %>% as_tibble() %>% 
    mutate(CLEAN = str_trim(CLEAN)) %>%
    arrange(POS.ID)
  
  shap.no.df.clean <- demo.clinvar.names %>% bind_rows(icd10.names) %>% bind_rows(atc.names) %>% bind_rows(remainder.names) %>% right_join(shap.no.df, by = c("RAW" = "VAR")) %>% as_tibble() %>% 
    mutate(CLEAN = str_trim(CLEAN)) %>%
    arrange(POS.ID)
  
  ### 3. CREATE THE FIGURE...
  
  if(outcomes[i] == "persistence_d365"){
    
    importance.plot.yes <- ggplot(data = shap.yes.df.clean, aes(y = rev(factor(POS.ID)), x = SHAP.ABS, fill = SHAP.MEAN)) + geom_col(col = "Grey 3") + 
      scale_y_discrete(labels = str_wrap(rev((shap.yes.df.clean)$CLEAN), width = 40, indent = 0), expand = expansion(c(0.05, 0.055)), position = "right") +
      scale_x_continuous(expand = expansion(c(0.1, 0.1))) +
      scale_fill_gradient2(low = rgb(110 / 255, 175 / 255, 250 / 255), mid = rgb(1, 1, 1), high = rgb(255 / 255, 135 / 255, 50 / 255)) +
      ylab("") + xlab("Mean absolute SHAP") + ggtitle("Persistence at one year") + 
      coord_cartesian(ylim = c(nrow(shap.yes.df.clean), (nrow(shap.yes.df.clean) - 9))) +
      theme(panel.background = element_blank(), legend.position = "none", plot.title = element_text(face = "italic", size = 10), axis.text.x = element_text(size = 6), axis.text.y = element_text(size = 6), axis.title.x = element_text(size = 6))
    
    importance.plot.no <- ggplot(data = shap.no.df.clean, aes(y = rev(factor(POS.ID)), x = SHAP.ABS, fill = SHAP.MEAN)) + geom_col(col = "Grey 3") + 
      scale_y_discrete(labels = str_wrap(rev((shap.no.df.clean)$CLEAN), width = 40, indent = 0), expand = expansion(c(0.05, 0.055)), position = "right") +
      scale_x_continuous(expand = expansion(c(0.1, 0.1))) +
      scale_fill_gradient2(low = rgb(110 / 255, 175 / 255, 250 / 255), mid = rgb(1, 1, 1), high = rgb(255 / 255, 135 / 255, 50 / 255)) +
      ylab("") + xlab("Mean absolute SHAP") + ggtitle("Persistence at one year") + 
      coord_cartesian(ylim = c(nrow(shap.no.df.clean), (nrow(shap.no.df.clean) - 9))) +
      theme(panel.background = element_blank(), legend.position = "none", plot.title = element_text(face = "italic", size = 10), axis.text.x = element_text(size = 6), axis.text.y = element_text(size = 6), axis.title.x = element_text(size = 6))  
  }
  
  if(outcomes[i] == "persistence_d1096"){
    
    importance.plot.yes <- ggplot(data = shap.yes.df.clean, aes(y = rev(factor(POS.ID)), x = SHAP.ABS, fill = SHAP.MEAN)) + geom_col(col = "Grey 3") + 
      scale_y_discrete(labels = str_wrap(rev((shap.yes.df.clean)$CLEAN), width = 40, indent = 0), expand = expansion(c(0.05, 0.055))) +
      scale_x_continuous(expand = expansion(c(0.001, 0.1))) +
      scale_fill_gradient2(low = rgb(110 / 255, 175 / 255, 250 / 255), mid = rgb(1, 1, 1), high = rgb(255 / 255, 135 / 255, 50 / 255)) +
      ylab("") + xlab("Mean absolute SHAP") + ggtitle("Persistence at three years") + 
      coord_cartesian(ylim = c(nrow(shap.yes.df.clean), (nrow(shap.yes.df.clean) - 8.9))) +
      theme(panel.background = element_blank(), legend.position = "none", plot.title = element_text(face = "italic", size = 10), axis.text.x = element_text(size = 6), axis.text.y = element_text(size = 6), axis.title.x = element_text(size = 6))
    
    importance.plot.no <- ggplot(data = shap.no.df.clean, aes(y = rev(factor(POS.ID)), x = SHAP.ABS, fill = SHAP.MEAN)) + geom_col(col = "Grey 3") + 
      scale_y_discrete(labels = str_wrap(rev((shap.no.df.clean)$CLEAN), width = 40, indent = 0), expand = expansion(c(0.05, 0.055))) +
      scale_x_continuous(expand = expansion(c(0.001, 0.1))) +
      scale_fill_gradient2(low = rgb(110 / 255, 175 / 255, 250 / 255), mid = rgb(1, 1, 1), high = rgb(255 / 255, 135 / 255, 50 / 255)) +
      ylab("") + xlab("Mean absolute SHAP") + ggtitle("Persistence at three years") + 
      coord_cartesian(ylim = c(nrow(shap.no.df.clean), (nrow(shap.no.df.clean) - 8.9))) +
      theme(panel.background = element_blank(), legend.position = "none", plot.title = element_text(face = "italic", size = 10), axis.text.x = element_text(size = 6), axis.text.y = element_text(size = 6), axis.title.x = element_text(size = 6))
    
  }
  
  legend.plot <- data.frame(Y = seq(-1, 1, length.out = 100), X = rep(1, 100)) %>% 
    ggplot(aes(y = Y, x = X, fill = Y)) + geom_point(alpha = 0) +  
    scale_fill_gradient2(low = rgb(110 / 255, 175 / 255, 250 / 255), mid = rgb(1, 1, 1), high = rgb(255 / 255, 135 / 255, 50 / 255), name = "", labels = c("Negative impact", "", "Ambiguous impact", "", "Positive impact")) +
    theme(panel.background = element_blank(), axis.ticks = element_blank(), axis.text = element_blank(), axis.title = element_blank(), legend.text = element_text(size = 12))
  
  #ggsave(str_c("C:/Users/antsys/Desktop/plots/importance.yes.", outcomes[i], ".tiff"), importance.plot.yes, width = 2000, height = 2250, units = "px")
  #ggsave(str_c("C:/Users/antsys/Desktop/plots/importance.no.", outcomes[i], ".tiff"), importance.plot.no, width = 2000, height = 2250, units = "px")
  #ggsave("C:/Users/antsys/Desktop/plots/legend.tiff", legend.plot)
  ggsave(str_c("H:/Projects/MTX_PREDICT/TMP/importance.yes.", outcomes[i], ".tiff"), importance.plot.yes, width = 1225, height = 700, units = "px")
  ggsave(str_c("H:/Projects/MTX_PREDICT/TMP/importance.no.", outcomes[i], ".tiff"), importance.plot.no, width = 1225, height = 700, units = "px")
}