#!/usr/bin/env Rscript
# =============================================================================
# VCEIE-jalca — Pipeline reproducible de resultados, tablas y figuras (v3.0, RPB)
# Procedimiento de valoración económica basado en un modelo densidad–área de
# saturación, aplicado de forma ilustrativa a la fauna voladora de la jalca
# (Gregorio Pita, San Marcos, Cajamarca, Perú).
#
# Modelo densidad–área (sigmoide de saturación):
#     P = M / (1 + A * exp(-k * S))
# M se FIJA a priori por grupo (no se estima). Con M fijo, la linealización
#     ln(M/P - 1) = ln(A) - k * S
# se ajusta por mínimos cuadrados ordinarios y solo estima A y k.
# Derivados:  S* = ln(A)/k (inflexión, P = M/2)
#             Q    = P(f*Smax) * (f*Smax / 10 000) * n   (cuenta física)
#             VEIE = Q * precio                              (cuenta monetaria), f = 2/3
#             VECE_bruto = sum(VEIE) * área (ha) * frecuencia anual
#             VECE_100   = VECE_bruto / factor de representatividad
# M, n (individuos de referencia), precio, f, factor, área y frecuencia son
# PARÁMETROS SUPUESTOS del escenario; su efecto se cuantifica en las
# secciones 4 y 5 (sensibilidad local ±20 % y análisis Monte Carlo).
#
# USO (terminal):
#   Rscript pipeline_VCEIE.R
#   Rscript pipeline_VCEIE.R --out=outputs --area=8218.23 --factor=0.76 --veces=2
#   ./run.sh
#
# SALIDAS (carpeta outputs/):
#   Figura3_ajuste_dPdS   (A–C ajuste densidad–área; D–F tasa de cambio dP/dS)
#   Figura4_sensibilidad  (tornado, sensibilidad local)
#   Figura5_comparacion   (saturación frente a densidad lineal y constante)
#     PDF editable (texto como texto) + PNG 600 ppp, 15 cm de ancho máximo
#   (Figura 1: figura1_mapa.R; Figura 2: grupos_tamano_VCEIE.R)
#   Tablas_VCEIE.xlsx       (serie de entrada, parámetros con IC 95 %,
#                            valoración, sensibilidad, Monte Carlo, residuos)
#   resultados_VCEIE.txt    (resumen numérico)
#   sessionInfo.txt         (versión de R y paquetes usados)
#
# Formato Revista Peruana de Biología: punto decimal, cifras sin separador de
# millares (10612337.58); figuras de R en PDF editable, ancho <= 15 cm;
# paleta Okabe-Ito apta para daltonismo. La Figura 1 (mapa de ubicación) se genera con figura1_mapa.R.
# =============================================================================

## ---- 0. Paquetes -----------------------------------------------------------
req <- c("ggplot2", "scales", "writexl", "patchwork")
faltan <- req[!vapply(req, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) {
  message("Instalando paquetes faltantes: ", paste(faltan, collapse = ", "))
  install.packages(faltan, repos = "https://cloud.r-project.org")
}
suppressPackageStartupMessages({
  library(ggplot2); library(scales); library(writexl)
})

## ---- 1. Argumentos y rutas -------------------------------------------------
script_dir <- {
  fa <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(sub("^--file=", "", fa[1]))) else getwd()
}
opt <- list(data = "datos_VCEIE.csv", params = "params_VCEIE.csv",
            out = "outputs", area = "8218.23", factor = "0.76", veces = "2",
            frac = "0.6666666667", boot = "2000", mc = "10000", seed = "2026")
for (a in commandArgs(TRUE)) {
  m <- regmatches(a, regexec("^--([^=]+)=(.*)$", a))[[1]]
  if (length(m) == 3 && m[2] %in% names(opt)) opt[[m[2]]] <- m[3]
}
abspath <- function(p) if (grepl("^(/|[A-Za-z]:)", p)) p else file.path(script_dir, p)
data_csv   <- abspath(opt$data)
params_csv <- abspath(opt$params)
out        <- abspath(opt$out)
AREA_HA <- as.numeric(opt$area)
FACTOR  <- as.numeric(opt$factor)
VECES   <- as.numeric(opt$veces)
FRAC    <- as.numeric(opt$frac)
NBOOT   <- as.integer(opt$boot)
NMC     <- as.integer(opt$mc)
SEED    <- as.integer(opt$seed)
dir.create(out, showWarnings = FALSE, recursive = TRUE)

stopifnot(file.exists(data_csv), file.exists(params_csv))
dat <- read.csv(data_csv, stringsAsFactors = FALSE)
par <- read.csv(params_csv, stringsAsFactors = FALSE)
stopifnot(all(c("grupo", "S", "P") %in% names(dat)),
          all(c("grupo", "M", "individuos", "precio", "Smax") %in% names(par)))
grupos <- par$grupo
Pmax <- vapply(grupos, function(g) max(dat$P[dat$grupo == g]), numeric(1))
if (any(par$M <= Pmax)) stop("M debe superar la densidad máxima de la serie en cada grupo.")

## ---- 2. Núcleo del modelo --------------------------------------------------
# Ajuste con M fijo; devuelve A y k
ajusta <- function(S, P, M) {
  y <- log(M / P - 1)
  b <- coef(lm(y ~ S))
  c(A = exp(unname(b[1])), k = -unname(b[2]))
}
# Valor económico por grupo (S/ por ha)
veie <- function(A, k, M, Smax, n, precio, frac = FRAC) {
  Se <- frac * Smax
  Pe <- M / (1 + A * exp(-k * Se))
  unname(Pe * (Se / 10000) * n * precio)
}
# VECE al 100 % para un juego completo de parámetros (vectores por grupo)
vece100 <- function(M, n, precio, frac = FRAC, area = AREA_HA, veces = VECES,
                    factor = FACTOR) {
  tot <- 0
  for (i in seq_along(grupos)) {
    d <- dat[dat$grupo == grupos[i], ]
    ak <- ajusta(d$S, d$P, M[i])
    tot <- tot + veie(ak[["A"]], ak[["k"]], M[i], par$Smax[i], n[i], precio[i], frac)
  }
  tot * area * veces / factor
}

## ---- 3. Ajuste, intervalos y valoración por grupo ---------------------------
set.seed(SEED)
fit_grupo <- function(gn) {
  d <- dat[dat$grupo == gn, ]
  p <- par[par$grupo == gn, ]
  y <- log(p$M / d$P - 1)
  m <- lm(y ~ S, data = data.frame(S = d$S, y = y))
  A <- exp(unname(coef(m)[1]))
  k <- -unname(coef(m)[2])
  ci <- confint(m, level = 0.95)                 # IC 95 % de ln(A) y -k
  n <- nrow(d)
  r <- cor(d$S, y)
  R2 <- summary(m)$r.squared                     # escala linealizada
  Pest <- p$M / (1 + A * exp(-k * d$S))
  R2P <- 1 - sum((d$P - Pest)^2) / sum((d$P - mean(d$P))^2)  # escala original
  tcal <- abs(r) * sqrt((n - 2) / (1 - r^2))
  ttab <- qt(0.95, df = n - 2)                   # unilateral, alfa = 0,05
  Sinf  <- log(A) / k
  Seval <- FRAC * p$Smax
  Peval <- p$M / (1 + A * exp(-k * Seval))
  VEIE  <- veie(A, k, p$M, p$Smax, p$individuos, p$precio)
  # Bootstrap de residuos (M fijo): IC 95 % de S* y VEIE
  yh <- fitted(m); e <- resid(m); S <- d$S
  bt <- t(replicate(NBOOT, {
    yb <- yh + sample(e, replace = TRUE)
    b <- coef(lm(yb ~ S)); Ab <- exp(b[[1]]); kb <- -b[[2]]
    c(log(Ab) / kb, veie(Ab, kb, p$M, p$Smax, p$individuos, p$precio))
  }))
  qS <- quantile(bt[, 1], c(0.025, 0.975)); qV <- quantile(bt[, 2], c(0.025, 0.975))
  list(grupo = gn, M = p$M, ind = p$individuos, precio = p$precio, Smax = p$Smax,
       A = A, A_lo = exp(ci[1, 1]), A_hi = exp(ci[1, 2]),
       k = k, k_lo = -ci[2, 2], k_hi = -ci[2, 1],
       r = r, R2 = R2, R2P = R2P, n = n, tcal = tcal, ttab = ttab,
       Sinf = Sinf, Sinf_lo = unname(qS[1]), Sinf_hi = unname(qS[2]),
       Seval = Seval, Peval = Peval, VEIE = VEIE,
       Q = Peval * (Seval / 10000) * p$individuos,   # cuenta física (individuos equivalentes)
       VEIE_lo = unname(qV[1]), VEIE_hi = unname(qV[2]),
       dPmax = p$M * k / 4)
}
fits <- setNames(lapply(grupos, fit_grupo), grupos)
gv <- function(x) vapply(fits, function(f) f[[x]], numeric(1))

VEIE_tot <- sum(gv("VEIE"))
VECE_raw <- VEIE_tot * AREA_HA * VECES
VECE_100 <- VECE_raw / FACTOR
base <- list(M = par$M, n = par$individuos, precio = par$precio)
stopifnot(abs(vece100(base$M, base$n, base$precio) - VECE_100) < 1e-6)

## ---- 4. Sensibilidad local (un parámetro a la vez) --------------------------
# Cada parámetro se lleva a -20 % y +20 % de su valor base (en los tres grupos
# a la vez), manteniendo los demás fijos. Para M, el extremo inferior es el
# mínimo admisible (densidad máxima de la serie + 0,1 animales/ha), porque con
# M <= max(P) la linealización queda indefinida.
M_lo <- pmax(0.8 * par$M, Pmax + 0.1)
fmt1 <- function(x) formatC(x, format = "f", digits = 1)
oat <- data.frame(
  Parametro = c("Capacidad de carga (M)", "Precio por individuo",
                "Individuos de referencia (n)", "Fracción de evaluación (2/3)",
                "Factor de representatividad (0.76)", "Área de extrapolación"),
  Bajo = c(paste0("M mínimo admisible (", paste(fmt1(M_lo), collapse = "; "), ")"),
           "-20 %", "-20 %", "-20 %", "-20 %", "-20 %"),
  Alto = rep("+20 %", 6),
  VECE_bajo = c(vece100(M_lo, base$n, base$precio),
                vece100(base$M, base$n, 0.8 * base$precio),
                vece100(base$M, 0.8 * base$n, base$precio),
                vece100(base$M, base$n, base$precio, frac = 0.8 * FRAC),
                vece100(base$M, base$n, base$precio, factor = 0.8 * FACTOR),
                vece100(base$M, base$n, base$precio, area = 0.8 * AREA_HA)),
  VECE_alto = c(vece100(1.2 * base$M, base$n, base$precio),
                vece100(base$M, base$n, 1.2 * base$precio),
                vece100(base$M, 1.2 * base$n, base$precio),
                vece100(base$M, base$n, base$precio, frac = 1.2 * FRAC),
                vece100(base$M, base$n, base$precio, factor = 1.2 * FACTOR),
                vece100(base$M, base$n, base$precio, area = 1.2 * AREA_HA)),
  stringsAsFactors = FALSE)
oat$Cambio_bajo_pct <- 100 * (oat$VECE_bajo / VECE_100 - 1)
oat$Cambio_alto_pct <- 100 * (oat$VECE_alto / VECE_100 - 1)
oat$Rango_pct <- abs(oat$Cambio_alto_pct - oat$Cambio_bajo_pct)
oat <- oat[order(-oat$Rango_pct), ]

## ---- 5. Incertidumbre conjunta (Monte Carlo) ---------------------------------
# Muestreo uniforme e independiente de los parámetros supuestos:
#   M_g ~ U(max(P_g) + 0,1 ; 1,2 M_g);  precio_g, n_g ~ U(0,8 ; 1,2) x base;
#   fracción ~ U(0.8 ; 1.2) x 2/3;  factor ~ U(0.8 ; 1.2) x 0.76.
# Área y frecuencia se mantienen fijas (definen el escenario; su efecto es
# proporcional). Importancia: correlación de rangos de Spearman con VECE_100.
set.seed(SEED)
G <- length(grupos)
unif_mat <- function(lo, hi, nm) {
  x <- vapply(seq_len(G), function(j) runif(NMC, lo[j], hi[j]), numeric(NMC))
  colnames(x) <- paste0(nm, "_", grupos); x
}
X <- data.frame(unif_mat(Pmax + 0.1, 1.2 * par$M, "M"),
                unif_mat(0.8 * par$precio, 1.2 * par$precio, "precio"),
                unif_mat(0.8 * par$individuos, 1.2 * par$individuos, "n"),
                fraccion = runif(NMC, 0.8, 1.2) * FRAC,
                factor   = runif(NMC, 0.8, 1.2) * FACTOR)
Xm <- as.matrix(X)
cM <- paste0("M_", grupos); cP <- paste0("precio_", grupos); cN <- paste0("n_", grupos)
Y <- vapply(seq_len(NMC), function(i)
  vece100(Xm[i, cM], Xm[i, cN], Xm[i, cP], frac = Xm[i, "fraccion"],
          factor = Xm[i, "factor"]), numeric(1))
qMC <- quantile(Y, c(0.025, 0.5, 0.975))
rho <- vapply(X, function(v) cor(v, Y, method = "spearman"), numeric(1))
mc_tab <- data.frame(Parametro = names(rho), rho_Spearman = round(rho, 3))
mc_tab <- mc_tab[order(-abs(mc_tab$rho_Spearman)), ]

## ---- 5b. Comparación de la forma del modelo densidad–área ------------------
# El escalamiento convencional supone que la densidad no depende del área.
# Se comparan tres formas de obtener P(f*Smax), con la misma cuenta física y
# monetaria y los mismos parámetros supuestos:
#   (a) saturación logística (modelo propuesto; M fijo, A y k estimados);
#   (b) lineal, P = a + b*S por MCO (densidad creciente sin límite);
#   (c) constante, P = media de la serie (valor por hectárea constante).
# (a) y (b) estiman dos parámetros de la serie, de modo que su ajuste se compara
# con RMSE y AIC en la escala original de P (K = 3, incluida la varianza).
P_sat <- function(gn, S) { f <- fits[[gn]]; f$M / (1 + f$A * exp(-f$k * S)) }
lin_fit <- setNames(lapply(grupos, function(gn) lm(P ~ S, data = dat[dat$grupo == gn, ])), grupos)
P_lin <- function(gn, S) unname(predict(lin_fit[[gn]], data.frame(S = S)))
P_con <- function(gn, S) rep(mean(dat$P[dat$grupo == gn]), length(S))
modelos <- list(Saturación = P_sat, Lineal = P_lin, Constante = P_con)
vece_modelo <- function(Pfun, frac = FRAC) {
  tot <- 0
  for (i in seq_along(grupos)) {
    Se <- frac * par$Smax[i]
    tot <- tot + Pfun(grupos[i], Se) * (Se / 10000) * par$individuos[i] * par$precio[i]
  }
  tot * AREA_HA * VECES / FACTOR
}
stopifnot(abs(vece_modelo(P_sat) - VECE_100) < 1e-6)
aic_n <- function(rss, n, K = 3) n * log(rss / n) + 2 * K
cmp_g <- do.call(rbind, lapply(grupos, function(gn) {
  d <- dat[dat$grupo == gn, ]; n <- nrow(d); Se <- FRAC * par$Smax[par$grupo == gn]
  rs <- sum((d$P - P_sat(gn, d$S))^2); rl <- sum(resid(lin_fit[[gn]])^2)
  data.frame(Grupo = gn,
             RMSE_sat = sqrt(rs / n), RMSE_lin = sqrt(rl / n),
             AIC_sat = aic_n(rs, n), AIC_lin = aic_n(rl, n),
             P_sat = P_sat(gn, Se), P_lin = P_lin(gn, Se), P_con = P_con(gn, Se))
}))
VECE_mod <- vapply(modelos, vece_modelo, numeric(1))
dif_mod  <- 100 * (VECE_mod / VECE_100 - 1)
# Curva del VECE al 100 % según la fracción evaluada (0.1–1.25 de Smax);
# por encima de 1 el modelo se usa fuera del intervalo de la serie.
fr <- seq(0.10, 1.25, by = 0.01)
curva_f <- data.frame(fraccion = fr,
                      Saturación = vapply(fr, function(x) vece_modelo(P_sat, x), numeric(1)),
                      Lineal     = vapply(fr, function(x) vece_modelo(P_lin, x), numeric(1)),
                      Constante  = vapply(fr, function(x) vece_modelo(P_con, x), numeric(1)))
curva_f$dif_lin_pct <- 100 * (curva_f$Lineal / curva_f$Saturación - 1)
curva_f$dif_con_pct <- 100 * (curva_f$Constante / curva_f$Saturación - 1)
dif_en <- function(x) curva_f[which.min(abs(curva_f$fraccion - x)), c("dif_lin_pct", "dif_con_pct")]

## ---- 6. Tablas (Excel) -----------------------------------------------------
maxn <- max(table(dat$grupo))
T1 <- as.data.frame(do.call(cbind, lapply(grupos, function(gn) {
  d <- dat[dat$grupo == gn, ]
  setNames(data.frame(c(d$S, rep(NA, maxn - nrow(d))),
                      c(d$P, rep(NA, maxn - nrow(d)))),
           c(paste0("S_", gn, " (m2)"), paste0("P_", gn, " (animales/ha)")))
})), check.names = FALSE)

r3 <- function(x) round(x, 3)
T2 <- data.frame(
  Grupo = c(grupos, "Total"),
  `Individuos de referencia (n)` = c(gv("ind"), sum(gv("ind"))),
  `M (fijado)` = c(gv("M"), NA),
  A = c(r3(gv("A")), NA),
  `A IC95 %` = c(paste0(r3(gv("A_lo")), "–", r3(gv("A_hi"))), NA),
  `k (m-2)` = c(signif(gv("k"), 4), NA),
  `k IC95 %` = c(paste0(signif(gv("k_lo"), 4), "–", signif(gv("k_hi"), 4)), NA),
  r = c(r3(gv("r")), NA),
  `r2 linealizado (%)` = c(round(gv("R2") * 100, 2), NA),
  `R2 escala original (%)` = c(round(gv("R2P") * 100, 2), NA),
  t_cal = c(r3(gv("tcal")), NA),
  `t_tab (gl = n-2)` = c(r3(gv("ttab")), NA),
  `S* (m2)` = c(round(gv("Sinf"), 1), NA),
  `S* IC95 % (bootstrap)` = c(paste0(round(gv("Sinf_lo"), 1), "–", round(gv("Sinf_hi"), 1)), NA),
  `P(2/3 Smax) (animales/ha)` = c(r3(gv("Peval")), NA),
  `Q cuenta física (individuos equivalentes)` = c(r3(gv("Q")), r3(sum(gv("Q")))),
  `VEIE (S/ por ha)` = c(r3(gv("VEIE")), r3(VEIE_tot)),
  `VEIE IC95 % (bootstrap)` = c(paste0(r3(gv("VEIE_lo")), "–", r3(gv("VEIE_hi"))), NA),
  check.names = FALSE)

T3 <- data.frame(
  Concepto = c("VEIE total (S/ por ha)", "Área de extrapolación (ha)", "Frecuencia anual",
               "VECE bruto (S/ por año)", "Factor de representatividad",
               "VECE al 100 % (S/ por año)",
               "Monte Carlo: percentil 2.5", "Monte Carlo: mediana",
               "Monte Carlo: percentil 97.5"),
  Valor = c(r3(VEIE_tot), AREA_HA, VECES, round(VECE_raw, 2), FACTOR,
            round(VECE_100, 2), round(unname(qMC), 2)))

T4 <- data.frame(Parametro = oat$Parametro, Bajo = oat$Bajo, Alto = oat$Alto,
                 `VECE bajo (S/)` = round(oat$VECE_bajo, 2),
                 `VECE alto (S/)` = round(oat$VECE_alto, 2),
                 `Cambio bajo (%)` = round(oat$Cambio_bajo_pct, 1),
                 `Cambio alto (%)` = round(oat$Cambio_alto_pct, 1),
                 check.names = FALSE)

TS1 <- do.call(rbind, lapply(grupos, function(gn) {
  d <- dat[dat$grupo == gn, ]; f <- fits[[gn]]
  Pest <- f$M / (1 + f$A * exp(-f$k * d$S))
  data.frame(Grupo = gn, `S (m2)` = d$S, `P serie` = d$P,
             `P estimada` = r3(Pest), Residuo = r3(d$P - Pest),
             check.names = FALSE)
}))

T5 <- rbind(
  data.frame(Grupo = cmp_g$Grupo,
             `RMSE saturación` = r3(cmp_g$RMSE_sat), `RMSE lineal` = r3(cmp_g$RMSE_lin),
             `AIC saturación` = round(cmp_g$AIC_sat, 2), `AIC lineal` = round(cmp_g$AIC_lin, 2),
             `P(2/3 Smax) saturación` = r3(cmp_g$P_sat), `P(2/3 Smax) lineal` = r3(cmp_g$P_lin),
             `P(2/3 Smax) constante` = r3(cmp_g$P_con), check.names = FALSE),
  NULL)
T5b <- data.frame(Modelo = names(VECE_mod), `VECE al 100 % (S/ por año)` = round(VECE_mod, 2),
                  `Diferencia frente a saturación (%)` = round(dif_mod, 1), check.names = FALSE)
TS5 <- data.frame(fraccion = fr, round(curva_f[, -1], 2), check.names = FALSE)

write_xlsx(list(TablaS1_serie_entrada = T1, Tabla2_parametros = T2,
                Tabla3_comparacion_grupos = T5, Tabla3_comparacion_VECE = T5b,
                TS_valoracion = T3, TS_sensibilidad_Fig4 = T4,
                TS_comparacion_Fig5 = TS5, TS_residuos = TS1, TS_montecarlo = mc_tab),
           file.path(out, "Tablas_VCEIE.xlsx"))

## ---- 7. Figuras (formato Revista Peruana de Biología) ------------------------
# Números: punto decimal y cifras juntas, sin separador de millares (30302)
dec <- function(x, d) formatC(x, format = "f", digits = d, big.mark = "")
eje <- function(x) ifelse(is.na(x), NA, dec(x, ifelse(all(abs(x - round(x)) < 1e-9, na.rm = TRUE), 0,
                                                      max(0, min(3, ceiling(-log10(min(diff(sort(unique(x)))))))))))
sci_pm <- function(x) {                       # "1.310 %*% 10^-3" para plotmath
  e <- floor(log10(abs(x))); m <- x / 10^e
  sprintf('"%s" %%*%% 10^%d', dec(m, 3), e)
}
col <- c(G1 = "#0072B2", G2 = "#D55E00", G3 = "#009E73")
nombre_g <- c(G1 = "Grupo 1 (grande)", G2 = "Grupo 2 (mediano)", G3 = "Grupo 3 (pequeño)")
xs  <- seq(0, 5200, length.out = 500)
tema <- theme_bw(base_size = 7) +
  theme(plot.title = element_text(face = "bold", size = 7),
        panel.grid.minor = element_blank(),
        plot.tag = element_text(face = "bold", size = 9))

# PDF vectorial editable (requisito RPB para gráficos de R) + PNG 600 ppp
# para insertar en el manuscrito Word. Ancho máximo 15 cm.
guardar <- function(g, nombre, w = 15, h = 10) {
  stopifnot(w <= 15)
  ggsave(file.path(out, paste0(nombre, ".pdf")), g,
         width = w, height = h, units = "cm", device = cairo_pdf, bg = "white")
  ggsave(file.path(out, paste0(nombre, ".png")), g,
         width = w, height = h, units = "cm", dpi = 600, bg = "white")
}

panel_ajuste <- function(gn) {
  f <- fits[[gn]]; d <- dat[dat$grupo == gn, ]
  curva <- data.frame(S = xs, P = f$M / (1 + f$A * exp(-f$k * xs)))
  ggplot() +
    geom_hline(yintercept = f$M, linetype = "dotted", colour = "grey45") +
    annotate("text", x = 100, y = f$M, vjust = -0.5, hjust = 0, size = 2.3,
             colour = "grey30", parse = TRUE,
             label = sprintf('italic(M) == "%s"', dec(f$M, 1))) +
    geom_vline(xintercept = f$Sinf, linetype = "dashed", colour = "grey55") +
    geom_line(data = curva, aes(S, P), colour = col[[gn]], linewidth = 0.7) +
    geom_point(data = d, aes(S, P), colour = col[[gn]], size = 1.3) +
    geom_point(aes(x = f$Sinf, y = f$M / 2), shape = 21, fill = "white",
               colour = col[[gn]], size = 2, stroke = 0.8) +
    annotate("text", x = f$Sinf + 120, y = f$M / 2, hjust = 0, vjust = 1.3, size = 2.3,
             parse = TRUE, label = sprintf('italic(S)^"*" == "%s"', dec(f$Sinf, 1))) +
    geom_point(aes(x = f$Seval, y = f$Peval), shape = 8, size = 1.8, stroke = 0.6) +
    annotate("text", x = 5150, y = 0.06 * f$M, hjust = 1, size = 2.2, parse = TRUE,
             label = sprintf('italic(r)^2 == "%s %%"', dec(f$R2 * 100, 2))) +
    scale_x_continuous(labels = eje, limits = c(0, 5200), breaks = seq(0, 5000, 1000),
                       expand = expansion(mult = c(0.01, 0.02))) +
    scale_y_continuous(labels = eje, limits = c(0, f$M * 1.1)) +
    labs(title = nombre_g[[gn]],
         x = expression("Superficie, " * italic(S) * " (m"^2 * ")"),
         y = expression("Densidad, " * italic(P) * " (animales ha"^-1 * ")")) +
    tema
}

panel_deriv <- function(gn) {
  f <- fits[[gn]]
  dv <- function(S) f$M * f$A * f$k * exp(-f$k * S) / (1 + f$A * exp(-f$k * S))^2
  curva <- data.frame(S = xs, dP = dv(xs))
  ggplot() +
    geom_vline(xintercept = f$Sinf, linetype = "dashed", colour = "grey55") +
    geom_line(data = curva, aes(S, dP), colour = col[[gn]], linewidth = 0.7) +
    geom_point(aes(x = f$Sinf, y = f$dPmax), shape = 8, size = 1.8, stroke = 0.6) +
    annotate("text", x = f$Sinf, y = f$dPmax * 1.13, hjust = 0.5, size = 2.1,
             parse = TRUE, label = sprintf('"máx" == %s', sci_pm(f$dPmax))) +
    scale_x_continuous(labels = eje, limits = c(0, 5200), breaks = seq(0, 5000, 1000),
                       expand = expansion(mult = c(0.01, 0.02))) +
    scale_y_continuous(labels = function(x) dec(x, 3), limits = c(0, f$dPmax * 1.3)) +
    labs(title = nombre_g[[gn]],
         x = expression("Superficie, " * italic(S) * " (m"^2 * ")"),
         y = expression(italic(dP) / italic(dS) * " (animales ha"^-1 * " m"^-2 * ")")) +
    tema
}

fig_tornado <- function() {
  tor <- oat
  niv <- rev(tor$Parametro)
  long <- rbind(
    data.frame(Parametro = tor$Parametro, Extremo = "Valor bajo", Cambio = tor$Cambio_bajo_pct),
    data.frame(Parametro = tor$Parametro, Extremo = "Valor alto", Cambio = tor$Cambio_alto_pct))
  long$Parametro <- factor(long$Parametro, levels = niv)
  long$Extremo <- factor(long$Extremo, levels = c("Valor bajo", "Valor alto"))
  lim <- max(abs(long$Cambio)) * 1.3
  g <- ggplot(long, aes(x = Cambio, y = Parametro, fill = Extremo)) +
    geom_col(width = 0.6, colour = "grey30", linewidth = 0.2, position = "identity") +
    geom_vline(xintercept = 0, colour = "grey20", linewidth = 0.4) +
    geom_text(aes(label = paste0(ifelse(Cambio > 0, "+", ""), dec(Cambio, 1), " %"),
                  hjust = ifelse(Cambio >= 0, -0.12, 1.12)), size = 2.3) +
    scale_fill_manual(values = c("Valor bajo" = "#56B4E9", "Valor alto" = "#E69F00"),
                      name = NULL) +
    scale_x_continuous(labels = function(x) paste0(dec(x, 0), " %"), limits = c(-lim, lim)) +
    labs(x = "Cambio del VECE al 100 % frente al escenario base", y = NULL) +
    theme_bw(base_size = 8) +
    theme(panel.grid.minor = element_blank(), legend.position = "bottom")
  guardar(g, "Figura4_sensibilidad", w = 15, h = 8)
}

suppressPackageStartupMessages(library(patchwork))
fig3 <- (panel_ajuste("G1") | panel_ajuste("G2") | panel_ajuste("G3")) /
        (panel_deriv("G1") | panel_deriv("G2") | panel_deriv("G3")) +
  plot_annotation(tag_levels = "A")
guardar(fig3, "Figura3_ajuste_dPdS", w = 15, h = 11)       # Figura 3
fig_tornado()                                               # Figura 4

fig_comparacion <- function() {                             # Figura 5
  colm <- c("Saturación" = "#0072B2", "Lineal" = "#D55E00", "Constante" = "#009E73")
  lt   <- c("Saturación" = "solid", "Lineal" = "dashed", "Constante" = "dotdash")
  lv <- names(colm)
  la <- do.call(rbind, lapply(lv, function(m)
    data.frame(fraccion = curva_f$fraccion, Modelo = m, VECE = curva_f[[m]] / 1e6)))
  la$Modelo <- factor(la$Modelo, levels = lv)
  # La saturación es la referencia (0 %); se dibuja para que ambas leyendas sean
  # idénticas y patchwork las combine en una sola (ggplot2 >= 3.5 no las une si difieren)
  lb <- rbind(data.frame(fraccion = curva_f$fraccion, Modelo = "Saturación", Dif = 0),
              data.frame(fraccion = curva_f$fraccion, Modelo = "Lineal", Dif = curva_f$dif_lin_pct),
              data.frame(fraccion = curva_f$fraccion, Modelo = "Constante", Dif = curva_f$dif_con_pct))
  lb$Modelo <- factor(lb$Modelo, levels = lv)
  extra <- annotate("rect", xmin = 1, xmax = 1.25, ymin = -Inf, ymax = Inf,
                    fill = "grey90", alpha = 0.7)
  marca <- geom_vline(xintercept = FRAC, linetype = "dotted", colour = "grey30")
  ejef <- scale_x_continuous(breaks = c(0.25, 0.5, 2/3, 1, 1.25),
                             labels = c("0.25", "0.50", "2/3", "1", "1.25"))
  gA <- ggplot(la, aes(fraccion, VECE, colour = Modelo, linetype = Modelo)) +
    extra + marca + geom_line(linewidth = 0.6) +
    scale_colour_manual(values = colm, name = "Densidad") +
    scale_linetype_manual(values = lt, name = "Densidad") + ejef +
    scale_y_continuous(labels = function(x) dec(x, 0)) +
    labs(x = expression("Fracción evaluada, " * italic(f) * " (" * italic(S) * "/" * italic(S)[max] * ")"),
         y = expression("VECE al 100 % (millones de S/ año"^-1 * ")")) + tema
  gB <- ggplot(lb, aes(fraccion, Dif, colour = Modelo, linetype = Modelo)) +
    extra + marca + geom_line(linewidth = 0.6) +
    scale_colour_manual(values = colm, name = "Densidad") +
    scale_linetype_manual(values = lt, name = "Densidad") + ejef +
    scale_y_continuous(labels = function(x) paste0(dec(x, 0), " %"),
                       breaks = seq(-50, 100, 25)) +
    # eje recortado: con f < 0.3 la densidad constante supera a la saturación en >100 %
    coord_cartesian(ylim = c(-55, 100)) +
    labs(x = expression("Fracción evaluada, " * italic(f) * " (" * italic(S) * "/" * italic(S)[max] * ")"),
         y = "Diferencia frente a saturación") + tema
  g <- (gA | gB) + plot_layout(guides = "collect") +
    plot_annotation(tag_levels = "A") & theme(legend.position = "bottom")
  guardar(g, "Figura5_comparacion", w = 15, h = 7.5)
}
fig_comparacion()

## ---- 8. Resumen y trazabilidad ----------------------------------------------
res <- c(
  sprintf("%s: A = %s (IC95 %s–%s); k = %.4e (IC95 %.4e–%.4e); r = %s; r2 lin = %s %%; R2 orig = %s %%; t_cal = %s; S* = %s m2 (IC95 %s–%s); P(2/3Smax) = %s; VEIE = %s S/ por ha (IC95 %s–%s)",
          grupos, dec(gv("A"), 3), dec(gv("A_lo"), 3), dec(gv("A_hi"), 3),
          gv("k"), gv("k_lo"), gv("k_hi"), dec(gv("r"), 3),
          dec(gv("R2") * 100, 2), dec(gv("R2P") * 100, 2), dec(gv("tcal"), 3),
          dec(gv("Sinf"), 1), dec(gv("Sinf_lo"), 1), dec(gv("Sinf_hi"), 1),
          dec(gv("Peval"), 3),
          dec(gv("VEIE"), 3), dec(gv("VEIE_lo"), 3), dec(gv("VEIE_hi"), 3)),
  sprintf("Cuenta física Q (individuos equivalentes): %s; total = %s", paste(grupos, dec(gv("Q"), 3), collapse = "; "), dec(sum(gv("Q")), 3)),
  sprintf("VEIE total = %s S/ por ha", dec(VEIE_tot, 3)),
  sprintf("VECE bruto = %s S/ por año", dec(VECE_raw, 2)),
  sprintf("VECE al 100 %% = %s S/ por año", dec(VECE_100, 2)),
  "", "Sensibilidad local (VECE al 100 %, cambio % bajo / alto):",
  sprintf("  %s [%s]: %s %% / %s %%", oat$Parametro, oat$Bajo,
          dec(oat$Cambio_bajo_pct, 1), dec(oat$Cambio_alto_pct, 1)),
  "", sprintf("Monte Carlo (%d iteraciones, semilla %d): mediana = %s; P2.5–P97.5 = %s – %s S/ por año",
              NMC, SEED, dec(qMC[2], 2), dec(qMC[1], 2), dec(qMC[3], 2)),
  sprintf("  rho Spearman %s = %s", mc_tab$Parametro, dec(mc_tab$rho_Spearman, 3)),
  "", "Comparación de la forma del modelo densidad–área (f = 2/3):",
  sprintf("  %s: RMSE sat = %s, lin = %s; AIC sat = %s, lin = %s; P sat = %s, lin = %s, const = %s",
          cmp_g$Grupo, dec(cmp_g$RMSE_sat, 3), dec(cmp_g$RMSE_lin, 3),
          dec(cmp_g$AIC_sat, 2), dec(cmp_g$AIC_lin, 2),
          dec(cmp_g$P_sat, 3), dec(cmp_g$P_lin, 3), dec(cmp_g$P_con, 3)),
  sprintf("  VECE al 100 %% %s = %s S/ por año (%s %% frente a saturación)",
          names(VECE_mod), dec(VECE_mod, 2), dec(dif_mod, 1)),
  sprintf("  Diferencia lineal / constante frente a saturación en f = %s: %s %% / %s %%",
          c("0.25", "0.50", "1.00", "1.25"),
          vapply(c(0.25, 0.5, 1, 1.25), function(x) dec(dif_en(x)$dif_lin_pct, 1), ""),
          vapply(c(0.25, 0.5, 1, 1.25), function(x) dec(dif_en(x)$dif_con_pct, 1), "")),
  "", R.version.string)
writeLines(res, file.path(out, "resultados_VCEIE.txt"))
writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
cat(res, sep = "\n")
cat("\nSalidas en: ", out, "\n", sep = "")
