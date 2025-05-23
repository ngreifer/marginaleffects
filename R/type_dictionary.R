
#' internal function to build the type dictionary
#'
#' @noRd
type_dictionary_build <- function() {
text <-
'class,type
bam,response
bam,link
bart,ev
bart,ppd
betareg,response
betareg,link
betareg,precision
betareg,quantile
betareg,variance
bife,response
bife,link
bracl,probs
brglmFit,response
brglmFit,link
brmsfit,response
brmsfit,link
brmsfit,prediction
brmsfit,average
brmultinom,probs
brmultinom,class
clm,prob
clm,cum.prob
clm,linear.predictor
clogit,expected
clogit,lp
clogit,risk
clogit,survival
coxph,survival
coxph,expected
coxph,lp
coxph,risk
coxph_weightit,survival
coxph_weightit,expected
coxph_weightit,lp
coxph_weightit,risk
crch,response
crch,location
crch,scale
crch,density
hetprob,pr
hetprob,xb
hxlr,location
hxlr,cumprob
hxlr,scale
hxlr,density
ivpml,pr
ivpml,xb
flexsurvreg,survival,
flexsurvreg,response,
flexsurvreg,mean,
flexsurvreg,link,
flexsurvreg,lp,
flexsurvreg,linear,
flexsurvreg,rmst,
flexsurvreg,hazard,
flexsurvreg,cumhaz,
fixest,invlink(link)
fixest,response
fixest,link
hurdle,response
hurdle,prob
hurdle,count
hurdle,zero
iv_robust,response
lm,response
gam,response
gam,link
Gam,invlink(link)
Gam,response
Gam,link
geeglm,response
geeglm,link
Gls,lp
glimML,response
glimML,link
glm,invlink(link)
glm,response
glm,link
glmerMod,response
glmerMod,link
glmgee,response
glmrob,response
glmrob,link
glmmTMB,response
glmmTMB,link
glmmTMB,conditional
glmmTMB,zprob
glmmTMB,zlink
glmmTMB,disp
glmmPQL,response
glmmPQL,link
glmx,response
glm_weightit,invlink(link)
glm_weightit,probs
glm_weightit,response
glm_weightit,lp
glm_weightit,link
ivreg,response
lmerMod,response
lmerModLmerTest,response
lmrob,response
lm_robust,response
lrm,fitted
lrm,lp
lrm,mean
mblogit,response
mblogit,latent
mblogit,link
mclogit,response
mclogit,latent
mclogit,link
MCMCglmm,response
model_fit,numeric
model_fit,prob
model_fit,class
workflow,numeric
workflow,prob
workflow,class
multinom,probs
multinom,latent
multinom_weightit,probs
multinom_weightit,response
multinom_weightit,mean
mhurdle,E
mhurdle,Ep
mhurdle,p
mlogit,response
mvgam,response
mvgam,link
mvgam,expected
mvgam,detection
mvgam,latent_N
negbin,invlink(link)
negbin,response
negbin,link
ols,lp
"oohbchoice", "probability",
"oohbchoice", "utility",
orm,fitted
orm,mean
orm,lp
ordinal_weightit,probs
ordinal_weightit,response
ordinal_weightit,link
ordinal_weightit,lp
ordinal_weightit,mean
polr,probs
rendo.base,response
rendo.base,link
rlm,response
selection,response
selection,link
selection,unconditional
speedlm,response
speedglm,response
speedglm,link
stanreg,response
stanreg,link
survreg,response
survreg,link
survreg,quantile
svyglm,response
svyglm,link
svyolr,probs
tobit,response
tobit1,expvalue
tobit1,linpred
tobit1,prob
zeroinfl,response
zeroinfl,prob
zeroinfl,count
zeroinfl,zero'
out <- utils::read.csv(
    text = text,
    colClasses = c("character", "character"))
for (i in 1:2) {
    out[[i]] <- trimws(out[[i]])
}
return(out)
}


#' type dictionary
#'
#' insight::get_predict accepts a `predict` argument
#' stats::predict accepts a `type` argument
#' this dictionary converts
#' @noRd
type_dictionary <- type_dictionary_build()
