library(plyr)
library(tidyverse)
library(stringr)
library(arm)
library(msm)

#############
##FUNCTIONS##
#############

#imputations#
impute <- function(i, data, newvar, inputs) {
  ivs <- colnames(coef(inputs))[-1]
  fix.coefs <- coef(inputs)[i,]
  random.u <- sigma.hat(inputs)[i]
  data$intercept <- 1
  ivs <- c("intercept",ivs)
  upper.bound <- ifelse(str_detect(newvar, ".pc"), 1, Inf)
  data[,newvar] <- rtnorm(dim(data)[1], 
                       as.matrix(data[,ivs]) %*% fix.coefs, random.u,
                                         lower=0, upper=upper.bound)
  data$intercept <- NULL
  data[,c("cntyname","mcdname","vtdname","name","stf","psid","cd2016","cdnew",newvar)]
}

#summary stats#
stats <- function(x, random.order, total.districts) {
  x$turnout.var <- x[,grep(".t.est", names(x))]
  x$percent.var <- x[,grep(".pc.est", names(x))]
  n <- dim(x)[1]
  x <- x[random.order,]
  x$district <- rep(1, n)*c(1:total.districts)
  x <- ddply(x, .(district), summarize,
             v=sum(turnout.var*percent.var)/sum(turnout.var),
             s=as.integer(v>=0.5))
  output <- data.frame(v=mean(x$v), s=mean(x$s), eg=(mean(x$s)-0.5)-2*(mean(x$v)-0.5),
                       comp=mean(x$v<0.55 & x$v>0.45))
}

#clean up numbers#
number.clean <- function(char.vector) {
  output <- str_trim(char.vector) %>% str_replace_all("%", "") %>%
    str_replace_all("\\$", "") %>% str_replace_all(",", "")
}

#Remove commas from numbers#
strip.commas <- function(char.vector) {
  output <- str_replace_all(char.vector, ",", "")
}

#race transformations#
party.pc <- function(var.root, d) {
  names2 <- names(d)
  vars <- names2[str_detect(names2, paste0(var.root, "[.]([d r])"))]
  if(length(vars)>1) {
    dem <- vars[str_detect(vars, paste0(var.root, ".d"))]
    rep <- vars[str_detect(vars, paste0(var.root, ".r"))]
    d[,paste0(var.root, ".t")] <- d[,dem] + d[,rep]
    d[,paste0(var.root, ".pc")] <- d[,dem]/(d[,dem] + d[,rep])
    select <- (d[,paste0(var.root, ".pc")] == 1) | (d[,paste0(var.root, ".pc")] == 0)
    select[is.na(select)] <- FALSE
    d[select,paste0(var.root, ".pc")] <- NA
    select <- is.na(d[,paste0(var.root, ".pc")])
    d[select,paste0(var.root, ".t")] <- NA
  }
  return(d)
}

##############
##FORMATTING##
##############

setwd("XXXX") #enter appropriate working directory

var.names <- read.csv("PA-Precinct-variable-names.csv", header=F, stringsAsFactors=F)

d <- read.csv("PA-Precinct-Level-Results--2016-11-08--General.csv",
              header=T, stringsAsFactors=F)
d <- d[!str_detect(d$JP.Districts, ","),] %>% mutate(JP.Districts=as.numeric(JP.Districts))
d <- d[!str_detect(d$PA5.Districts, ","),] %>% mutate(PA5.Districts=as.numeric(PA5.Districts))
names(d) <- var.names[,2]
start <- which(names(d)=="white")
end <- dim(d)[2]
d[,start:end] <- sapply(d[,start:end], number.clean) %>% sapply(as.numeric) #formatting numbers
names <- names(d) %>% .[str_detect(., "[.]([d r])")] %>% #rename vars
  str_replace("[.]([d r])", "") %>% unique(.)
for(i in 1:length(names)) { #calculate proportions for every race
  d <- party.pc(names[i], d)
}
d <- mutate(d, white=white/100, 
            whiteva=whiteva/100,
            uncontested=(cd2016==3 | cd2016==13 | cd2016==18)) %>%
  filter(!is.na(us.pres.2016.pc), !is.na(whiteva))
d$us.hse.2016.pc <- d$us.hse.2016.d/(d$us.hse.2016.d+d$us.hse.2016.r)
d$us.hse.2016.pc[d$uncontested] <- NA

############
##ANALYSIS##
############

nsims <- 1000 #number of simulations

##US House##
#turnout#
model <- lm(us.hse.2016.t ~ us.pres.2016.t, data=d)
random.coefs <- sim(model, nsims)
output1 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "us.hse.2016.t.est", 
                  random.coefs)

turnout <- Reduce(function(x,y) 
  merge(x, y, 
        by=c("cntyname","mcdname","vtdname","name","stf","psid","cd2016","cdnew")), 
  output1)
write.csv(turnout, "PA-Precinct-Model.US-House-2016.turnout.csv")

#dem proportion#
model <- lm(us.hse.2016.pc ~ us.pres.2016.pc + whiteva, data=d)
random.coefs <- sim(model, nsims)
output2 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "us.hse.2016.pc.est", 
                  random.coefs)
imputes <- lapply(1:nsims, function(i) 
  merge(output1[[i]], output2[[i]], 
        by=c("cntyname","mcdname","vtdname","name","stf","psid","cd2016","cdnew")))
proportion <- Reduce(function(x,y) 
  merge(x, y, 
        by=c("cntyname","mcdname","vtdname","name","stf","psid","cd2016","cdnew")), 
  output2)
write.csv(proportion, "PA-Precinct-Model.US-House-2016.propD.csv")

##PA House##
#turnout#
model <- lm(pa.hse.2016.t ~ us.pres.2016.t, data=d)
random.coefs <- sim(model, nsims)
output1 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.hse.2016.t.est", random.coefs)

turnout <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output1)
write.csv(turnout, "PA-Precinct-Model.PA-House-2016.turnout.csv")

#dem proportion#
model <- lm(pa.hse.2016.pc ~ us.pres.2016.pc + whiteva, data=d)
random.coefs <- sim(model, nsims)
output2 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.hse.2016.pc.est", random.coefs)
imputes <- lapply(1:nsims, function(i) 
  merge(output1[[i]], output2[[i]], by=c("cntyname","mcdname","vtdname","name","stf","psid")))
proportion <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output2)
write.csv(proportion, "PA-Precinct-Model.PA-House-2016.propD.csv")

##PA Senate##
#turnout#
model <- lm(pa.sen.2016.t ~ us.pres.2016.t, data=d)
random.coefs <- sim(model, nsims)
output1 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.sen.2016.t.est", random.coefs)

turnout <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output1)
write.csv(turnout, "PA-Precinct-Model.PA-Senate-2016.turnout.csv")

#dem proportion#
model <- lm(pa.sen.2016.pc ~ us.pres.2016.pc + whiteva, data=d)
random.coefs <- sim(model, nsims)
output2 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.sen.2016.pc.est", random.coefs)
imputes <- lapply(1:nsims, function(i) 
  merge(output1[[i]], output2[[i]], by=c("cntyname","mcdname","vtdname","name","stf","psid")))
proportion <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output2)
write.csv(proportion, "PA-Precinct-Model.PA-Senate-2016.propD.csv")



