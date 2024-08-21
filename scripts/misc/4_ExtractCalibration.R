### LAST VERSION UPDATED 15 MAY 2024 (v1.0).
### THIS SCRIPTS COMPUTES STATISTICS OF CALIBRATION FOR THE REFIT DATA.

.libPaths("H:/Programs/RLibrary/")
library(dplyr)
library(readr)
library(stringr)
library(ggplot2)
library(gridExtra)

outcomes <- c("persistence_d365", "persistence_d1096"); cal.list <- list(); df.list <- list()
for(i in 1:length(outcomes)){
  
  inner.cal.list <- list()
  train.df <- read_tsv(str_c("H:/Projects/MTX_PREDICT/data/output/res/", outcomes[i], "/TRAIN2.PredRes.refit.tsv"), show_col_types = F) %>% 
    mutate(OUTCOME = case_when(OUTCOME == "YES" ~ 1, OUTCOME == "NO" ~ 0, .default = NA))
  
  ### 1. CALIBRATION
  
  inner.cal.list[[1]] <- mean(train.df$OUTCOME) - mean(train.df$PROB)
  
  cal.int.raw <- (glm(OUTCOME ~ I(PROB), data = train.df, family = binomial(link = "logit")) %>% coef())[1]
  cal.int <- exp(cal.int.raw) %>% as.numeric()
  inner.cal.list[[2]] <- cal.int
  
  cal.slope.raw <- (glm(OUTCOME ~ PROB, data = train.df, family = binomial(link = "logit")) %>% coef())[2]
  inner.cal.list[[3]] <- cal.slope <- exp(cal.slope.raw) / (1 + exp(cal.slope.raw)) %>% as.numeric()
  
  ### 2. RESCALING - PLATT, ISO AND BETA
  
  platt.prob <- glm(OUTCOME ~ PROB, data = train.df, family = binomial(link = "logit"))$fitted
  
  source("H:/Projects/MTX_PREDICT/TMP/fit.isoreg.R")    #THIS COMES FROM THE `betacal` GITHUB PAGE...
  train.df.uniq <- train.df %>% group_by(PROB) %>% filter(n() == 1) %>% ungroup()
  iso.reg <- isoreg(train.df.uniq$PROB, train.df.uniq$OUTCOME)
  iso.prob <- fit.isoreg(iso.reg, train.df.uniq$PROB)
  iso.df <- data.frame(PROB = train.df.uniq$PROB, PROB.ISO = iso.prob)
  
  library(betacal)
  bc <- beta_calibration(train.df$PROB, train.df$OUTCOME, parameters = "abm")
  beta.prob <- beta_predict(train.df$PROB, bc)
  
  train.df$PROB.PLATT <- platt.prob
  train.df$PROB.BETA <- beta.prob
  train.df.complete <- train.df %>% left_join(iso.df, by = "PROB")
  
  df.list[[i]] <- train.df.complete %>% mutate(TYPE = outcomes[i])
  
  ### 3. GRAPHICAL VISUALIZATION
  
  type <- c("PROB", "PROB.PLATT", "PROB.ISO", "PROB.BETA"); plot.list <- list()
  for(j in 1:length(type)){
    
    clean.type <- c("Untransformed Probabilities", "Probabilities after Platt Scaling", "Probabilities after Isotonic Regression", "Probabilities after Beta Scaling")
    train.df.loop <- train.df.complete %>% select(OUTCOME, PROBABILITY = all_of(type[j]))
    
    cal.df <- train.df.loop %>% mutate(decile = ntile(PROBABILITY, 10)) %>%
      group_by(decile) %>% summarise(obsRate = mean(OUTCOME == 1), obsRate.se = sd(OUTCOME == 1) / sqrt(n()), obs.n = n(), predRate = mean(PROBABILITY)) %>% ungroup() %>%
      mutate(obsRate.LCI = obsRate - qnorm(1 - 0.05 / 2) * obsRate.se, obsRate.UCI = obsRate + qnorm(1 - 0.05 / 2) * obsRate.se) %>%
      select(decile, obsRate, obsRate.LCI, obsRate.UCI, predRate)
    
    plot.list[[j]] <- ggplot(train.df.loop, aes(x = PROBABILITY, y = OUTCOME)) + 
      geom_smooth(method = "loess", se = F, color = "Grey 3", size = 1.25) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "Grey 3", alpha = 0.75) +
      geom_point(data = cal.df, aes(x = predRate, y = obsRate), size = 2) + 
      geom_errorbar(data = cal.df, aes(x = predRate, y = obsRate, ymin = obsRate.LCI, ymax = obsRate.UCI), alpha = 0.35) +
      xlab("Predicted Probability") + ylab("Proportion Positive Labels") + ggtitle(clean.type[j]) + 
      coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
      theme_classic() + theme(plot.title = element_text(size = 14))
    
  }
  
  inner.cal.list[[4]] <- plot.list
  cal.list[[i]] <- inner.cal.list
  
}

print("NUMERIC CALIBRATION ESTIMATES FOR PERSISTENCE AT ONE YEAR: "); cal.list[[1]][1:3]
print("NUMERIC CALIBRATION ESTIMATES FOR PERSISTENCE AT THREE YEARS: "); cal.list[[2]][1:3]

cal.fig.1 <- grid.arrange(cal.list[[1]][[4]][[1]], cal.list[[1]][[4]][[2]], cal.list[[1]][[4]][[3]], cal.list[[1]][[4]][[4]], nrow = 4)
cal.fig.2 <- grid.arrange(cal.list[[2]][[4]][[1]], cal.list[[2]][[4]][[2]], cal.list[[2]][[4]][[3]], cal.list[[2]][[4]][[4]], nrow = 4)

ggsave("H:/Projects/MTX_PREDICT/TMP/CalFig1.tiff", plot = cal.fig.1, width = 12, height = 22, units = "cm")
ggsave("H:/Projects/MTX_PREDICT/TMP/CalFig2.tiff", plot = cal.fig.2, width = 12, height = 22, units = "cm")

df.list %>% bind_rows() %>% arrange(pid) %>% write.table("H:/Projects/MTX_PREDICT/TMP/PROB.tsv", sep = "\t", col.names = T, row.names = F, quote = F)
