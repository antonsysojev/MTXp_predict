### LAST VERSION UPDATE 6 MAY 2024 (v0.2) - UPDATED ID FOR OUTCOME TO BE 'OUTCOME' instead of 'LABEL'.
### THIS SCRIPT CONTAINS A FUNCTION FOR COMPUTING THE YOUDEN'S J INDEX FOR A GIVEN DATA FRAME AND CUT-OFF

#! Problem with empty...

YoudenJ.fun <- function(cut, x){

    x.sum <- x %>% mutate(PRED.LABEL = ifelse(PROB >= cut, "YES", "NO")) %>% group_by(OUTCOME, PRED.LABEL) %>% summarise(N = n(), .groups = "drop")
    
    sensitivity <- (x.sum %>% filter(OUTCOME == PRED.LABEL & OUTCOME == "YES"))$N / sum((x.sum %>% filter(OUTCOME == "YES"))$N)
    specificity <- (x.sum %>% filter(OUTCOME == PRED.LABEL & OUTCOME == "NO"))$N / sum((x.sum %>% filter(OUTCOME == "NO"))$N)
    ppv <- (x.sum %>% filter(OUTCOME == PRED.LABEL & PRED.LABEL == "YES"))$N / sum((x.sum %>% filter(PRED.LABEL == "YES"))$N)
    npv <- (x.sum %>% filter(OUTCOME == PRED.LABEL & PRED.LABEL == "NO"))$N / sum((x.sum %>% filter(PRED.LABEL == "NO"))$N)

    if(length(sensitivity) == 0) sensitivity <- 0
    if(length(specificity) == 0) specificity <- 0
    if(length(ppv) == 0) ppv <- 0
    if(length(npv) == 0) npv <- 0
    YoudenJ <- sensitivity + specificity - 1
    
    res <- c(sensitivity, specificity, ppv, npv, YoudenJ, cut)
    names(res) <- c("sensitivity", "specificity", "ppv", "npv", "YoudenJ", "cutoff")
    return(res)

}
