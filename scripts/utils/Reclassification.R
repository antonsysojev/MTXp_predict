### LAST VERSION UPDATE 18 APRIL 2024 (v0.1)
### THIS SCRIPT CONTAINS FUNCTIONS FOR CALCULATING TOTAL RECLASSIFICATION AND NET RECLASSIFICATION

reclassification.total.fun <- function(x1, x2){         #TOTAL RECLASSIFICATION

    x1.yes <- x1 %>% filter(PRED.LABEL == "YES")
    x1.no <- x1 %>% filter(PRED.LABEL == "NO")

    x1.yes.x2 <- x1.yes %>% inner_join(x2 %>% select(pid, PRED.LABEL.2 = PRED.LABEL), by = "pid")
    x1.no.x2 <- x1.no %>% inner_join(x2 %>% select(pid, PRED.LABEL.2 = PRED.LABEL), by = "pid")

    ((x1.yes.x2 %>% filter(PRED.LABEL.2 == "NO") %>% nrow()) + (x1.no.x2 %>% filter(PRED.LABEL.2 == "YES") %>% nrow())) / (x1.yes %>% nrow() + x1.no %>% nrow())
}

reclassification.net.fun <- function(x1, x2){

    x1.yes <- x1 %>% inner_join(x2 %>% select(pid, PRED.LABEL.2 = PRED.LABEL), by = "pid") %>% filter(OUTCOME == "YES")
    x1.yes.reclass <- x1.yes %>% filter(PRED.LABEL != PRED.LABEL.2)    #POSITIVE LABEL WHO RECLASSIFIED
    net.improvement.yes <- (nrow(x1.yes.reclass %>% filter(OUTCOME == PRED.LABEL.2)) - nrow(x1.yes.reclass %>% filter(OUTCOME != PRED.LABEL.2))) / nrow(x1.yes)

    x1.no <- x1 %>% inner_join(x2 %>% select(pid, PRED.LABEL.2 = PRED.LABEL), by = "pid") %>% filter(OUTCOME == "NO")
    x1.no.reclass <- x1.no %>% filter(PRED.LABEL != PRED.LABEL.2)       #NEGATIVE LABEL WHO RECLASSIFIED
    net.improvement.no <- (nrow(x1.no.reclass %>% filter(OUTCOME == PRED.LABEL.2)) - nrow(x1.no.reclass %>% filter(OUTCOME != PRED.LABEL.2))) / nrow(x1.no)

    res.vec <- c(net.improvement.yes, net.improvement.no)
    names(res.vec) <- c("net.improvement.yes", "net.improvement.no")
    res.vec
}

### TO DO:
# 1.1. These can be combined, if we're smart about it, and just use a single function.
# 1.2. Some of these names are hard-coded, that's stupid if you want to re-use it.