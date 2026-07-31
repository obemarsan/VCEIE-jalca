## Bootstrap de paquetes
req <- c("ggplot2", "writexl")
faltan <- req[!vapply(req, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) install.packages(faltan, repos = "https://cloud.r-project.org")
suppressMessages({library(ggplot2); library(writexl)})

## Argumentos CLI + rutas
script_dir <- {
  fa <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(sub("^--file=", "", fa[1]))) else getwd()
}
opt <- list(data="datos_VCEIE.csv", params="params_VCEIE.csv",
            out="outputs", area="8218.23", factor="0.76", veces="2")
for (a in commandArgs(TRUE)) {
  m <- regmatches(a, regexec("^--([^=]+)=(.*)$", a))[[1]]
  if (length(m)==3 && m[2] %in% names(opt)) opt[[m[2]]] <- m[3]
}
abspath <- function(p) if (grepl("^(/|[A-Za-z]:)", p)) p else file.path(script_dir, p)
data_csv<-abspath(opt$data); params_csv<-abspath(opt$params); out<-abspath(opt$out)
AREA_HA<-as.numeric(opt$area); FACTOR<-as.numeric(opt$factor); VECES<-as.numeric(opt$veces)
if (!dir.exists(out)) dir.create(out, showWarnings=FALSE, recursive=TRUE)

dat <- read.csv(data_csv, stringsAsFactors=FALSE)
par <- read.csv(params_csv, stringsAsFactors=FALSE)

## Ajuste + valoracion
fit_grupo <- function(gn){
  d<-dat[dat$grupo==gn,]; p<-par[par$grupo==gn,]
  y<-log(p$M/d$P-1); m<-lm(y~d$S)
  A<-exp(unname(coef(m)[1])); k<--unname(coef(m)[2])
  r<-cor(d$S,y); R2<-summary(m)$r.squared; n<-nrow(d)
  tcal<-abs(r)/sqrt(1-r^2)*sqrt(n-2); ttab<-qt(0.95,df=n-2)
  Sinf<-log(A)/k; Seval<-(2/3)*p$Smax; Peval<-p$M/(1+A*exp(-k*Seval))
  VEIE<-(Peval*Seval/10000)*p$especies*p$precio
  list(grupo=gn,M=p$M,esp=p$especies,precio=p$precio,Smax=p$Smax,A=A,k=k,r=r,
       R2=R2,n=n,tcal=tcal,ttab=ttab,Sinf=Sinf,Seval=Seval,Peval=Peval,VEIE=VEIE)
}
grupos<-par$grupo; fits<-setNames(lapply(grupos,fit_grupo),grupos)
VEIE_tot<-sum(vapply(fits,function(f)f$VEIE,numeric(1)))
VECE_raw<-VEIE_tot*AREA_HA*VECES; VECE_100<-VECE_raw/FACTOR

## Tablas
sci<-function(k) formatC(k,format="e",digits=3)
maxn<-max(table(dat$grupo)); wide<-list()
for (gn in grupos){ d<-dat[dat$grupo==gn,]
  wide[[paste0("S_",gn)]]<-c(d$S,rep(NA,maxn-nrow(d)))
  wide[[paste0("P_",gn)]]<-c(round(d$P,3),rep(NA,maxn-nrow(d))) }
T1<-as.data.frame(wide,check.names=FALSE)
gv<-function(f,x) vapply(fits,function(z)z[[x]],numeric(1))
T2<-data.frame(Grupo=c(grupos,"Total"), M=c(gv(fits,"M"),NA), A=c(round(gv(fits,"A"),3),NA),
  `k (m^-2)`=c(sci(gv(fits,"k")),NA), r=c(round(gv(fits,"r"),3),NA),
  `R2 (%)`=c(round(gv(fits,"R2")*100,2),NA), `t_cal`=c(round(gv(fits,"tcal"),3),NA),
  `t_tab (gl=n-2)`=c(round(gv(fits,"ttab"),3),NA), `S_inflexion (m2)`=c(round(gv(fits,"Sinf"),2),NA),
  `P(2/3 Smax) (an/ha)`=c(round(gv(fits,"Peval"),3),NA),
  `VEIE (soles/ha)`=c(round(gv(fits,"VEIE"),3),round(VEIE_tot,3)), check.names=FALSE)
T2_tot<-data.frame(Concepto=c("VECE_raw (S/ = VEIE_tot x area x veces)","Factor de representatividad",
  "VECE_100 (S/ = VECE_raw / factor)"), Valor=c(round(VECE_raw,2),FACTOR,round(VECE_100,2)))
TS1<-do.call(rbind,lapply(grupos,function(gn){ d<-dat[dat$grupo==gn,]; f<-fits[[gn]]
  Pest<-f$M/(1+f$A*exp(-f$k*d$S))
  data.frame(Grupo=gn,`S (m2)`=d$S,`P_exp (an/ha)`=round(d$P,3),
             `P_est (an/ha)`=round(Pest,3),`Residuo`=round(d$P-Pest,3),check.names=FALSE)}))
write_xlsx(list(T1_datos_crudos=T1,T2_sintesis=T2,T2_totales=T2_tot,TS1_exp_vs_est=TS1),
           file.path(out,"Tablas_ECOSISTEMAS_VCEIE.xlsx"))

## Figuras 600 dpi
okabe<-c("#0072B2","#E69F00","#009E73")
lab<-setNames(sprintf("Grupo %s (%d esp - S/ %.2f)",sub("G","",grupos),par$especies,par$precio),grupos)
colmap<-setNames(okabe[seq_along(grupos)],lab[grupos])
mk<-function(gn,xs){f<-fits[[gn]]; f$M/(1+f$A*exp(-f$k*xs))}; xs<-seq(0,5200,length.out=400)
ptsdf<-do.call(rbind,lapply(grupos,function(gn){d<-dat[dat$grupo==gn,]; data.frame(Grupo=unname(lab[gn]),S=d$S,P=d$P)}))
curvedf<-do.call(rbind,lapply(grupos,function(gn) data.frame(Grupo=unname(lab[gn]),S=xs,P=mk(gn,xs))))
infdf<-do.call(rbind,lapply(grupos,function(gn) data.frame(Grupo=unname(lab[gn]),Sinf=fits[[gn]]$Sinf)))
evdf<-do.call(rbind,lapply(grupos,function(gn) data.frame(Grupo=unname(lab[gn]),S=fits[[gn]]$Seval,P=fits[[gn]]$Peval)))
f1<-ggplot()+
  geom_vline(data=infdf,aes(xintercept=Sinf),linetype="dashed",colour="grey55")+
  geom_line(data=curvedf,aes(S,P,colour=Grupo),linewidth=0.9)+
  geom_point(data=ptsdf,aes(S,P,colour=Grupo),size=1.8)+
  geom_point(data=evdf,aes(S,P),shape=8,size=2.6,stroke=0.9,colour="black")+
  facet_wrap(~Grupo,nrow=1)+scale_colour_manual(values=colmap,guide="none")+
  labs(x=expression("Superficie, S ("*m^2*")"),y="Promedio, P (animales/ha)")+
  theme_bw(base_size=10)+theme(strip.text=element_text(size=8))
ggsave(file.path(out,"Figura1_ajuste_P_vs_S.png"),f1,width=19,height=7,units="cm",dpi=600)
deriv<-function(gn,xs){f<-fits[[gn]]; f$M*f$A*f$k*exp(-f$k*xs)/(1+f$A*exp(-f$k*xs))^2}
dcurve<-do.call(rbind,lapply(grupos,function(gn) data.frame(Grupo=unname(lab[gn]),S=xs,dP=deriv(gn,xs))))
dmax<-do.call(rbind,lapply(grupos,function(gn){f<-fits[[gn]]; data.frame(Grupo=unname(lab[gn]),S=f$Sinf,dP=deriv(gn,f$Sinf))}))
f2<-ggplot()+
  geom_line(data=dcurve,aes(S,dP,colour=Grupo),linewidth=0.9)+
  geom_point(data=dmax,aes(S,dP),shape=8,size=2.6,stroke=0.9,colour="black")+
  geom_text(data=dmax,aes(S,dP,label=paste0("S* = ",round(S,0)," m2")),hjust=-0.12,vjust=0.3,size=2.5)+
  facet_wrap(~Grupo,nrow=1)+scale_colour_manual(values=colmap,guide="none")+
  scale_y_continuous(expand=expansion(mult=c(0.05,0.12)))+
  scale_x_continuous(expand=expansion(mult=c(0.03,0.06)))+
  labs(x=expression("Superficie, S ("*m^2*")"),y=expression("dP/dS (animales "*ha^-1*" "*m^-2*")"))+
  theme_bw(base_size=10)+theme(strip.text=element_text(size=8))
ggsave(file.path(out,"Figura2_dPdS_vs_S.png"),f2,width=19,height=7,units="cm",dpi=600)

cat("\n==== PARAMETROS Y VALORACION ====\n")
for (gn in grupos){f<-fits[[gn]]
  cat(sprintf("%s: A=%.4f k=%.3e r=%.5f R2=%.2f%% Sinf=%.1f Peval=%.4f VEIE=%.3f\n",
      gn,f$A,f$k,f$r,f$R2*100,f$Sinf,f$Peval,f$VEIE))}
cat(sprintf("VEIE_tot=%.3f  VECE_raw=%.2f  VECE_100=%.2f\n",VEIE_tot,VECE_raw,VECE_100))
cat("Salidas en: ",out,"\n",sep="")
