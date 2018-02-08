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
  data[,c("cntyname","mcdname","vtdname","name","stf","psid",newvar)]
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
    select <- (d[,paste0(var.root, ".pc")] > 0.95) | (d[,paste0(var.root, ".pc")] < 0.05)
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

setwd("/Users/ericmcghee/Dropbox/Redistricting/PlanScore/Data")

var.names <- read.csv("PA Variable names.csv", header=F, stringsAsFactors=F)

d <- read.csv("Pennsylvania Precinct-Level Results - 2016-11-08 General.csv",
              header=T, stringsAsFactors=F)
names(d) <- var.names[,2]
start <- which(names(d)=="white")
end <- dim(d)[2]
d[,start:end] <- sapply(d[,start:end], number.clean) %>% sapply(as.numeric) #formatting numbers
names <- names(d) %>% .[str_detect(., "[.]([d r])")] %>% #rename vars
  str_replace("[.]([d r])", "") %>% unique(.)
for(i in 1:length(names)) { #calculate proportions for every race
  d <- party.pc(names[i], d)
}
d <- mutate(d, white=white/100, whiteva=whiteva/100) %>%
  filter(!is.na(us.pres.2016.pc), !is.na(whiteva))

############
##ANALYSIS##
############

nsims <- 1000

##PA House##
#turnout#
model <- lm(pa.hse.2016.t ~ us.pres.2016.t, data=d)
random.coefs <- sim(model, nsims)
output1 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.hse.2016.t.est", random.coefs)

turnout <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output1)
write.csv(turnout, "PA Precinct Model.PA House 2016.turnout.csv")

#dem proportion#
model <- lm(pa.hse.2016.pc ~ us.pres.2016.pc, data=d)
random.coefs <- sim(model, nsims)
output2 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.hse.2016.pc.est", random.coefs)
imputes <- lapply(1:nsims, function(i) 
  merge(output1[[i]], output2[[i]], by=c("cntyname","mcdname","vtdname","name","stf","psid")))
proportion <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output2)
write.csv(proportion, "PA Precinct Model.PA House 2016.propD.csv")

#predictions vs actual#
setwd("/Users/ericmcghee/Dropbox/PPIC/CA Commission EG/Data")
actual <- read.csv("Legislative Elections 2002-2016.csv", header=T, stringsAsFactors=F)[,-1] %>%
  filter(statenm=="pennsylvania", year==2016, chamber==0) %>%
  dplyr::select(distnum, canvt.d, canvt.r, vote)

setwd("/Users/ericmcghee/Dropbox/Redistricting/PlanScore/Data")
predicted <- read.csv("2018.01.19 Wisconsin Predictions - Sheet1.csv", header=T,
                     stringsAsFactors=F) %>%
  mutate(canvt.d.pred=as.numeric(strip.commas(Democratic.Votes)),
         canvt.r.pred=as.numeric(strip.commas(Republican.Votes)),
         vote.pred=canvt.d.pred/(canvt.d.pred+canvt.r.pred)) %>%
  merge(actual, by.x=c("Assembly.District"), by.y=c("distnum"))

plot(predicted$vote, predicted$vote.pred, xlab="Actual Vote Share", ylab="Predicted Vote Share")
abline(a=0, b=1)
plot(predicted$canvt.d[!is.na(predicted$vote)], predicted$canvt.d.pred[!is.na(predicted$vote)],
     xlab="Actual Democratic Vote", ylab="Predicted Democratic Vote")
abline(a=0, b=1)
plot(predicted$canvt.r[!is.na(predicted$vote)], predicted$canvt.r.pred[!is.na(predicted$vote)],
     xlab="Actual Republican Vote", ylab="Predicted Republican Vote")
abline(a=0, b=1)

##PA Senate##
#turnout#
model <- lm(pa.sen.2016.t ~ us.pres.2016.t, data=d)
random.coefs <- sim(model, nsims)
output1 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.sen.2016.t.est", random.coefs)

turnout <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output1)
write.csv(turnout, "PA Precinct Model.PA Senate 2016.turnout.csv")

#dem proportion#
model <- lm(pa.sen.2016.pc ~ us.pres.2016.pc, data=d)
random.coefs <- sim(model, nsims)
output2 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "pa.sen.2016.pc.est", random.coefs)
imputes <- lapply(1:nsims, function(i) 
  merge(output1[[i]], output2[[i]], by=c("cntyname","mcdname","vtdname","name","stf","psid")))
proportion <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output2)
write.csv(proportion, "PA Precinct Model.PA Senate 2016.propD.csv")

##US House##
#turnout#
model <- lm(us.hse.2016.t ~ us.pres.2016.t, data=d)
random.coefs <- sim(model, nsims)
output1 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "us.hse.2016.t.est", random.coefs)

turnout <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output1)
write.csv(turnout, "PA Precinct Model.US House 2016.turnout.csv")

#dem proportion#
model <- lm(us.hse.2016.pc ~ us.pres.2016.pc, data=d)
random.coefs <- sim(model, nsims)
output2 <- lapply(1:nsims, function(w,x,y,z) impute(w,x,y,z), d, "us.hse.2016.pc.est", random.coefs)
imputes <- lapply(1:nsims, function(i) 
  merge(output1[[i]], output2[[i]], by=c("cntyname","mcdname","vtdname","name","stf","psid")))
proportion <- Reduce(function(x,y) 
  merge(x, y, by=c("cntyname","mcdname","vtdname","name","stf","psid")), output2)
write.csv(proportion, "PA Precinct Model.US House 2016.propD.csv")

##Evaluations##
#votes, seats, eg for random districts#
scramble <- sample(1:dim(imputes[[1]])[1], dim(imputes[[1]])[1]) #for random districts

sv <- ldply(lapply(imputes, function(x,y,z) stats(x,y,z), scramble, 13))
results.ushse <- data.frame(V=round(median(sv$v),3),V.moe=round(2*sd(sv$v),3),
                            S=round(median(sv$s),3),S.moe=round(2*sd(sv$s),3),
                            EG=round(median(sv$eg),3),EG.moe=round(2*sd(sv$eg),3),
                            Competitive=round(median(sv$comp),3),
                            Competitive.moe=round(2*sd(sv$comp),3))

##combining all the results##
results <- rbind(results.nchse, results.ncsen, results.ushse)
rownames(results) <- c("NC House", "NC Senate", "US House")
print(results)


