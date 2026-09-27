#!/usr/bin/env Rscript
# =============================================================================
# VCEIE-jalca — Pipeline reproducible de resultados, tablas y figuras
# Manuscrito: "Valoración económica del impacto ecológico mediante un modelo
#   densidad–área de la fauna voladora del ecosistema jalca, Perú"
#   (South Sustainability, Universidad Científica del Sur)
#
# Modelo densidad–área (sigmoide de saturación):
#     P = M / (1 + A * exp(-k * S))
# Ajuste por linealización y mínimos cuadrados ordinarios (M fijo por grupo):
#     ln(M/P - 1) = ln(A) - k * S
# Derivados:  S* = ln(A)/k (inflexión, P = M/2)
#             VEIE = P(2/3 Smax) * (2/3 Smax / 10 000) * individuos * precio
#             VECE_bruto = sum(VEIE) * área (ha) * muestreos/año
#             VECE_100   = VECE_bruto / factor de representatividad
#
# USO (terminal):
#   Rscript pipeline_VCEIE.R
#   Rscript pipeline_VCEIE.R --out=outputs --area=8218.23 --factor=0.76 --veces=2
#   ./run.sh
#
# SALIDAS (carpeta outputs/):
#   Figura2_ajuste_G1 … Figura4_ajuste_G3   (ajuste densidad–área)
#   Figura5_dPdS_G1   … Figura7_dPdS_G3     (tasa de cambio dP/dS)
#     cada una en PNG y TIFF (LZW), 600 ppp, 16 × 11 cm
#   Tablas_VCEIE.xlsx       (datos, parámetros, valoración, residuos)
#   resultados_VCEIE.txt    (resumen numérico)
#   sessionInfo.txt         (versión de R y paquetes usados)
#
# Formato: coma decimal (texto en español), paleta Okabe-Ito apta para
# daltonismo. La Figura 1 (mapa de ubicación) se elabora en SIG, fuera de
# este pipeline.
# =============================================================================

## ---- 0. Paquetes -----------------------------------------------------------
req <- c("ggplot2", "scales", "writexl")
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
            out = "outputs", area = "8218.23", factor = "0.76", veces = "2")
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
dir.create(out, showWarnings = FALSE, recursive = TRUE)

stopifnot(file.exists(data_csv), file.exists(params_csv))
dat <- read.csv(data_csv, stringsAsFactors = FALSE)
par <- read.csv(params_csv, stringsAsFactors = FALSE)
stopifnot(all(c("grupo", "S", "P") %in% names(dat)),
          all(c("grupo", "M", "individuos", "precio", "Smax") %in% names(par)))

## ---- 2. Ajuste y valoración por grupo --------------------------------------
fit_grupo <- function(gn) {
  d <- dat[dat$grupo == gn, ]
  p <- par[par$grupo == gn, ]
  y <- log(p$M / d$P - 1)
  m <- lm(y ~ S, data = data.frame(S = d$S, y = y))
  A <- exp(unname(coef(m)[1]))
  k <- -unname(coef(m)[2])
  n <- nrow(d)
  r <- cor(d$S, y)
  R2 <- summary(m)$r.squared
  tcal <- abs(r) * sqrt((n - 2) / (1 - r^2))
  ttab <- qt(0.95, df = n - 2)                 # unilateral, alfa = 0,05
  Sinf  <- log(A) / k
  Seval <- (2 / 3) * p$Smax
  Peval <- p$M / (1 + A * exp(-k * Seval))
  VEIE  <- Peval * (Seval / 10000) * p$individuos * p$precio
  list(grupo = gn, M = p$M, ind = p$individuos, precio = p$precio, Smax = p$Smax,
       A = A, k = k, r = r, R2 = R2, n = n, tcal = tcal, ttab = ttab,
       Sinf = Sinf, Seval = Seval, Peval = Peval, VEIE = VEIE,
       dPmax = p$M * k / 4)
}
grupos <- par$grupo
fits <- setNames(lapply(grupos, fit_grupo), grupos)
gv <- function(x) vapply(fits, function(f) f[[x]], numeric(1))

VEIE_tot <- sum(gv("VEIE"))
VECE_raw <- VEIE_tot * AREA_HA * VECES
VECE_100 <- VECE_raw / FACTOR

## ---- 3. Tablas (Excel) -----------------------------------------------------
maxn <- max(table(dat$grupo))
T1 <- as.data.frame(do.call(cbind, lapply(grupos, function(gn) {
  d <- dat[dat$grupo == gn, ]
  setNames(data.frame(c(d$S, rep(NA, maxn - nrow(d))),
                      c(d$P, rep(NA, maxn - nrow(d)))),
           c(paste0("S_", gn, " (m2)"), paste0("P_", gn, " (animales/ha)")))
})), check.names = FALSE)

T2 <- data.frame(
  Grupo = c(grupos, "Total"),
  Individuos = c(gv("ind"), sum(gv("ind"))),
  M = c(gv("M"), NA),
  A = c(round(gv("A"), 3), NA),
  `k (m-2)` = c(signif(gv("k"), 4), NA),
  r = c(round(gv("r"), 3), NA),
  `r2 (%)` = c(round(gv("R2") * 100, 2), NA),
  t_cal = c(round(gv("tcal"), 3), NA),
  `t_tab (gl = n-2)` = c(round(gv("ttab"), 3), NA),
  `S* (m2)` = c(round(gv("Sinf"), 1), NA),
  `P(2/3 Smax) (animales/ha)` = c(round(gv("Peval"), 3), NA),
  `VEIE (S/ por ha)` = c(round(gv("VEIE"), 3), round(VEIE_tot, 3)),
  check.names = FALSE)

T3 <- data.frame(
  Concepto = c("VEIE total (S/ por ha)", "Área (ha)", "Muestreos por año",
               "VECE bruto (S/ por año)", "Factor de representatividad",
               "VECE al 100 % (S/ por año)"),
  Valor = c(round(VEIE_tot, 3), AREA_HA, VECES, round(VECE_raw, 2), FACTOR,
            round(VECE_100, 2)))

TS1 <- do.call(rbind, lapply(grupos, function(gn) {
  d <- dat[dat$grupo == gn, ]; f <- fits[[gn]]
  Pest <- f$M / (1 + f$A * exp(-f$k * d$S))
  data.frame(Grupo = gn, `S (m2)` = d$S, `P observada` = d$P,
             `P estimada` = round(Pest, 3), Residuo = round(d$P - Pest, 3),
             check.names = FALSE)
}))

write_xlsx(list(T1_datos = T1, T2_parametros = T2, T3_valoracion = T3,
                TS1_residuos = TS1),
           file.path(out, "Tablas_VCEIE.xlsx"))

## ---- 4. Figuras (Figuras 2–7 del manuscrito) --------------------------------
dec <- function(x, d) formatC(x, format = "f", digits = d, big.mark = " ",
                              decimal.mark = ",")
eje <- label_number(decimal.mark = ",", big.mark = " ")
sci_pm <- function(x) {                       # "1,310 %*% 10^-3" para plotmath
  e <- floor(log10(abs(x))); m <- x / 10^e
  sprintf('"%s" %%*%% 10^%d', dec(m, 3), e)
}
col <- c(G1 = "#0072B2", G2 = "#D55E00", G3 = "#009E73")
xs  <- seq(0, 5200, length.out = 500)
tema <- theme_bw(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 11),
        panel.grid.minor = element_blank())

guardar <- function(g, nombre) {
  ggsave(file.path(out, paste0(nombre, ".png")), g,
         width = 16, height = 11, units = "cm", dpi = 600, bg = "white")
  ggsave(file.path(out, paste0(nombre, ".tiff")), g,
         width = 16, height = 11, units = "cm", dpi = 600, bg = "white",
         device = "tiff", compression = "lzw")
}

fig_ajuste <- function(gn, num) {
  f <- fits[[gn]]; d <- dat[dat$grupo == gn, ]
  curva <- data.frame(S = xs, P = f$M / (1 + f$A * exp(-f$k * xs)))
  caja <- c(
    'italic(P) == frac(italic(M), 1 + italic(A) * e^{-italic(k) * italic(S)})',
    sprintf('italic(M) == "%s" * "; " ~ italic(A) == "%s"', dec(f$M, 1), dec(f$A, 2)),
    sprintf('italic(k) == %s ~ m^-2', sci_pm(f$k)),
    sprintf('italic(r)^2 == "%s %%" * "; " ~ italic(n) == %d', dec(f$R2 * 100, 2), f$n))
  yc <- f$M * c(0.36, 0.25, 0.16, 0.07)
  g <- ggplot() +
    geom_hline(yintercept = f$M, linetype = "dotted", colour = "grey45") +
    annotate("text", x = 150, y = f$M, vjust = -0.5, hjust = 0, size = 3.2,
             colour = "grey30", parse = TRUE,
             label = sprintf('italic(M) == "%s"', dec(f$M, 1))) +
    geom_vline(xintercept = f$Sinf, linetype = "dashed", colour = "grey55") +
    geom_line(data = curva, aes(S, P), colour = col[[gn]], linewidth = 1) +
    geom_point(data = d, aes(S, P), colour = col[[gn]], size = 2.4) +
    geom_point(aes(x = f$Sinf, y = f$M / 2), shape = 21, fill = "white",
               colour = col[[gn]], size = 3.4, stroke = 1.2) +
    annotate("text", x = f$Sinf - 150, y = f$M / 2, hjust = 1, vjust = -0.6,
             size = 3.2, parse = TRUE,
             label = sprintf('italic(S)^"*" == "%s" ~ m^2', dec(f$Sinf, 1))) +
    geom_point(aes(x = f$Seval, y = f$Peval), shape = 8, size = 3.2, stroke = 1) +
    annotate("text", x = f$Seval + 120, y = f$Peval, hjust = 0, vjust = 1.6,
             size = 3.2, parse = TRUE, label = 'frac(2, 3) * italic(S)["máx"]') +
    annotate("rect", xmin = 3080, xmax = 5180, ymin = 0.02 * f$M,
             ymax = 0.44 * f$M, fill = "white", colour = "grey40",
             linewidth = 0.3) +
    annotate("text", x = 3150, y = yc, hjust = 0, size = 3, parse = TRUE,
             label = caja) +
    scale_x_continuous(labels = eje, limits = c(0, 5200),
                       expand = expansion(mult = c(0.01, 0.02))) +
    scale_y_continuous(labels = eje, limits = c(0, f$M * 1.08)) +
    labs(title = sprintf("Grupo %s (%d individuos)", sub("G", "", gn), f$ind),
         x = expression("Superficie, " * italic(S) * " (m"^2 * ")"),
         y = expression("Densidad, " * italic(P) * " (animales ha"^-1 * ")")) +
    tema
  guardar(g, sprintf("Figura%d_ajuste_%s", num, gn))
}

fig_deriv <- function(gn, num) {
  f <- fits[[gn]]
  dv <- function(S) f$M * f$A * f$k * exp(-f$k * S) / (1 + f$A * exp(-f$k * S))^2
  curva <- data.frame(S = xs, dP = dv(xs))
  ymax <- f$dPmax * 1.45
  caja <- c(
    'frac(italic(dP), italic(dS)) == frac(italic(M) * italic(A) * italic(k) * e^{-italic(k) * italic(S)}, (1 + italic(A) * e^{-italic(k) * italic(S)})^2)',
    sprintf('(italic(dP)/italic(dS))["máx"] == %s', sci_pm(f$dPmax)),
    sprintf('italic(S)^"*" == "%s" ~ m^2', dec(f$Sinf, 1)))
  g <- ggplot() +
    geom_vline(xintercept = f$Sinf, linetype = "dashed", colour = "grey55") +
    geom_line(data = curva, aes(S, dP), colour = col[[gn]], linewidth = 1) +
    geom_point(aes(x = f$Sinf, y = f$dPmax), shape = 8, size = 3.2, stroke = 1) +
    annotate("rect", xmin = 3250, xmax = 5180, ymin = ymax * 0.60,
             ymax = ymax * 0.985, fill = "white", colour = "grey40",
             linewidth = 0.3) +
    annotate("text", x = 3320, y = ymax * c(0.885, 0.735, 0.645), hjust = 0,
             size = 3, parse = TRUE, label = caja) +
    scale_x_continuous(labels = eje, limits = c(0, 5200),
                       expand = expansion(mult = c(0.01, 0.02))) +
    scale_y_continuous(labels = label_number(decimal.mark = ",", accuracy = 0.001),
                       limits = c(0, ymax)) +
    labs(title = sprintf("Grupo %s (%d individuos)", sub("G", "", gn), f$ind),
         x = expression("Superficie, " * italic(S) * " (m"^2 * ")"),
         y = expression(italic(dP) / italic(dS) * " (animales ha"^-1 * " m"^-2 * ")")) +
    tema
  guardar(g, sprintf("Figura%d_dPdS_%s", num, gn))
}

for (i in seq_along(grupos)) fig_ajuste(grupos[i], i + 1)   # Figuras 2–4
for (i in seq_along(grupos)) fig_deriv(grupos[i], i + 4)    # Figuras 5–7

## ---- 5. Resumen y trazabilidad ----------------------------------------------
res <- c(
  sprintf("%s: A = %s; k = %.4e; r = %s; r2 = %s %%; t_cal = %s; S* = %s m2; VEIE = %s S/ por ha",
          grupos, dec(gv("A"), 3), gv("k"), dec(gv("r"), 3), dec(gv("R2") * 100, 2),
          dec(gv("tcal"), 3), dec(gv("Sinf"), 1), dec(gv("VEIE"), 3)),
  sprintf("VEIE total = %s S/ por ha", dec(VEIE_tot, 3)),
  sprintf("VECE bruto = %s S/ por año", dec(VECE_raw, 2)),
  sprintf("VECE al 100 %% = %s S/ por año", dec(VECE_100, 2)),
  "", R.version.string)
writeLines(res, file.path(out, "resultados_VCEIE.txt"))
writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
cat(res, sep = "\n")
cat("\nSalidas en: ", out, "\n", sep = "")
