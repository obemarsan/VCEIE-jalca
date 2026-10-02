#!/usr/bin/env Rscript
# =============================================================================
# VCEIE-jalca — Grupos de tamaño corporal a partir de datos públicos
#
# Une la lista de especies de aves registradas en el polígono (descarga
# "Species list" de GBIF, citable por su DOI) con la masa corporal publicada
# en AVONET (Tobias et al. 2022, Ecology Letters, doi:10.1111/ele.13898), y
# asigna cada especie a un grupo de tamaño con cortes FIJADOS A PRIORI:
#     pequeño < 50 g ;  50 g <= mediano < 500 g ;  grande >= 500 g
# (cortes en escala logarítmica, una década de ancho para el grupo mediano).
# Sensibilidad: terciles de log10(masa) de la propia lista local.
# Subconjunto principal: especies de hábitats abiertos según AVONET
# (Grassland, Shrubland, Wetland, Rock, Human Modified, Riverine), como
# aproximación a la jalca; se reporta también la lista completa del recuadro.
# No requiere captura ni medición de individuos.
#
# USO:
#   Rscript grupos_tamano_VCEIE.R --gbif=datos_publicos/<descarga>.csv \
#           --avonet="datos_publicos/AVONET Supplementary dataset 1.xlsx" \
#           --minreg=1 --out=outputs
# SALIDAS (outputs/):
#   especies_poligono_masa.csv   especie, registros, masa, hábitat, grupo
#   revisar_manual.csv           nombres sin coincidencia exacta en AVONET
#   resumen_grupos.csv           especies y masa mediana por grupo
#   Tablas_grupos_tamano.xlsx    Tabla 3 del manuscrito + anexos (resumen, especies, nombres)
#   Figura9_masa_corporal.png/.tiff  (especies de hábitats abiertos)
# =============================================================================
suppressPackageStartupMessages({
  for (p in c("readxl", "ggplot2", "scales", "writexl"))
    if (!requireNamespace(p, quietly = TRUE)) install.packages(p, repos = "https://cloud.r-project.org")
  library(readxl); library(ggplot2); library(scales); library(writexl)
})

opt <- list(gbif = NA, avonet = "AVONET Supplementary dataset 1.xlsx", out = "outputs",
            minreg = "1", corte1 = "50", corte2 = "500",
            habitats = "Grassland,Shrubland,Wetland,Rock,Human Modified,Riverine")
for (a in commandArgs(TRUE)) {
  m <- regmatches(a, regexec("^--([^=]+)=(.*)$", a))[[1]]
  if (length(m) == 3 && m[2] %in% names(opt)) opt[[m[2]]] <- m[3]
}
stopifnot(!is.na(opt$gbif), file.exists(opt$gbif), file.exists(opt$avonet))
dir.create(opt$out, showWarnings = FALSE, recursive = TRUE)
HAB <- trimws(strsplit(opt$habitats, ",")[[1]])
C1 <- as.numeric(opt$corte1); C2 <- as.numeric(opt$corte2); MINREG <- as.integer(opt$minreg)

## ---- 1. Lista GBIF -------------------------------------------------------------
primera <- readLines(opt$gbif, n = 1, warn = FALSE)
sep <- if (grepl("\t", primera)) "\t" else ","
g <- read.delim(opt$gbif, sep = sep, quote = "", stringsAsFactors = FALSE,
                check.names = FALSE, fileEncoding = "UTF-8")
names(g) <- tolower(names(g))
binomio <- function(x) vapply(strsplit(trimws(x), "\\s+"), function(w)
  if (length(w) >= 2) paste(w[1], w[2]) else NA_character_, character(1))
sp <- if ("species" %in% names(g) && any(nzchar(g$species))) g$species else
  if ("acceptedscientificname" %in% names(g)) binomio(g$acceptedscientificname) else
  binomio(g$scientificname)
sp[!nzchar(sp)] <- NA
nreg <- if ("numberofoccurrences" %in% names(g)) as.numeric(g$numberofoccurrences) else
  if ("occurrencecount" %in% names(g)) as.numeric(g$occurrencecount) else 1
lista <- aggregate(nreg ~ especie, data = data.frame(especie = sp, nreg = nreg)[!is.na(sp), ], FUN = sum)
lista <- lista[lista$nreg >= MINREG, ]
message("Especies (binomios) en la lista GBIF: ", nrow(lista))

## ---- 2. AVONET y cruce de nombres ---------------------------------------------
eb <- read_excel(opt$avonet, sheet = "AVONET2_eBird")
bl <- read_excel(opt$avonet, sheet = "AVONET1_BirdLife")
cw <- read_excel(opt$avonet, sheet = "BirdLife-eBird crosswalk")
cols <- c("Mass", "Habitat", "Trophic.Niche", "Primary.Lifestyle", "Migration")
i_eb <- match(lista$especie, eb$Species2)
i_bl <- match(lista$especie, bl$Species1)
lista$cruce <- ifelse(!is.na(i_eb), "eBird/Clements exacto",
               ifelse(!is.na(i_bl), "BirdLife exacto", NA))
for (cc in cols) {
  v <- eb[[cc]][i_eb]
  v[is.na(i_eb)] <- bl[[cc]][i_bl[is.na(i_eb)]]
  lista[[cc]] <- v
}
# Coincidencia por epíteto (cambio de género), solo como sugerencia a revisar
sin <- which(is.na(lista$cruce))
sug <- vapply(lista$especie[sin], function(s) {
  ep <- substr(sub("^\\S+\\s+", "", s), 1, 6)   # raíz del epíteto (tolera cambio de género)
  c2 <- eb$Species2[substr(sub("^\\S+\\s+", "", eb$Species2), 1, 6) == ep]
  if (length(c2)) paste(c2, collapse = " | ") else ""
}, character(1))
revisar <- data.frame(especie_GBIF = lista$especie[sin], registros = lista$nreg[sin],
                      sugerencia_AVONET_eBird = sug, nombre_AVONET_asignado = "",
                      stringsAsFactors = FALSE)
write.csv(revisar, file.path(opt$out, "revisar_manual.csv"), row.names = FALSE)

# Correcciones manuales opcionales: archivo revisar_manual_resuelto.csv con
# columnas especie_GBIF, nombre_AVONET_asignado (nombre eBird/Clements)
res_man <- file.path(dirname(opt$gbif), "revisar_manual_resuelto.csv")
if (file.exists(res_man)) {
  rm_ <- read.csv(res_man, stringsAsFactors = FALSE)
  rm_ <- rm_[nzchar(rm_$nombre_AVONET_asignado), ]
  for (j in seq_len(nrow(rm_))) {
    i <- match(rm_$especie_GBIF[j], lista$especie); k <- match(rm_$nombre_AVONET_asignado[j], eb$Species2)
    if (!is.na(i) && !is.na(k)) {
      lista$cruce[i] <- "manual"; for (cc in cols) lista[[cc]][i] <- eb[[cc]][k]
    }
  }
}

## ---- 3. Grupos de tamaño -------------------------------------------------------
ok <- !is.na(lista$Mass)
lista$grupo_fijo <- cut(lista$Mass, c(0, C1, C2, Inf), right = FALSE,
                        labels = c("Pequeño", "Mediano", "Grande"))
tq <- quantile(log10(lista$Mass[ok]), c(1/3, 2/3))
lista$grupo_tercil <- cut(log10(lista$Mass), c(-Inf, tq, Inf), right = FALSE,
                          labels = c("Pequeño", "Mediano", "Grande"))
lista <- lista[order(-lista$Mass), ]
ok <- !is.na(lista$Mass)                       # recalcular tras ordenar
# Hábitats abiertos (aproximación a la jalca): variable Habitat de AVONET
lista$habitat_abierto <- lista$Habitat %in% HAB
write.csv(lista, file.path(opt$out, "especies_poligono_masa.csv"), row.names = FALSE)

resumen <- do.call(rbind, lapply(list(c("grupo_fijo", "todas"), c("grupo_tercil", "todas"),
                                      c("grupo_fijo", "abiertos"), c("grupo_tercil", "abiertos")), function(cg) {
  gc <- cg[1]
  d <- lista[ok & (cg[2] == "todas" | lista$habitat_abierto), ]
  do.call(rbind, lapply(levels(d[[gc]]), function(lv) {
    x <- d[which(d[[gc]] == lv), ]
    data.frame(criterio = gc, especies_incluidas = cg[2], grupo = lv, especies = nrow(x),
               masa_mediana_g = round(median(x$Mass), 1),
               masa_min_g = round(min(x$Mass), 1), masa_max_g = round(max(x$Mass), 1),
               registros_GBIF = sum(x$nreg))
  }))
}))
write.csv(resumen, file.path(opt$out, "resumen_grupos.csv"), row.names = FALSE)

# Tabla 3 del manuscrito y anexos en Excel
t3 <- resumen[resumen$criterio == "grupo_fijo" & resumen$especies_incluidas == "abiertos", ]
dec1 <- function(x) formatC(x, format = "f", digits = 1, big.mark = " ", decimal.mark = ",")
T3 <- data.frame(
  Grupo = c("1 (grande)", "2 (mediano)", "3 (pequeño)"),
  `Masa (g)` = c(paste0(">= ", C2), paste0(C1, "–", C2), paste0("< ", C1)),
  Especies = t3$especies[match(c("Grande", "Mediano", "Pequeño"), t3$grupo)],
  `Masa mediana (g) (intervalo)` = with(t3[match(c("Grande", "Mediano", "Pequeño"), t3$grupo), ],
    paste0(dec1(masa_mediana_g), " (", dec1(masa_min_g), "–", dec1(masa_max_g), ")")),
  `Registros GBIF` = t3$registros_GBIF[match(c("Grande", "Mediano", "Pequeño"), t3$grupo)],
  check.names = FALSE)
write_xlsx(list(Tabla3_grupos_tamano = T3, TS_resumen_criterios = resumen,
                TS_especies = lista, TS_revision_nombres = revisar),
           file.path(opt$out, "Tablas_grupos_tamano.xlsx"))

ref <- c("Coragyps atratus", "Falco sparverius", "Spinus magellanicus")
refs <- lista[lista$especie %in% ref, c("especie", "Mass", "grupo_fijo", "grupo_tercil")]

## ---- 4. Figura ------------------------------------------------------------------
dec <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = " ", decimal.mark = ",")
g9 <- ggplot(lista[ok & lista$habitat_abierto, ], aes(Mass)) +
  geom_histogram(bins = 30, fill = "grey75", colour = "grey35", linewidth = 0.2) +
  geom_vline(xintercept = c(C1, C2), linetype = "dashed", colour = "grey20") +
  geom_point(data = refs, aes(x = Mass, y = 0), shape = 25, size = 3,
             fill = "#D55E00", colour = "black", inherit.aes = FALSE) +
  geom_text(data = refs, aes(x = Mass, y = 0, label = especie), angle = 90, hjust = -0.15,
            vjust = 0.4, size = 2.8, fontface = "italic", inherit.aes = FALSE) +
  annotate("text", x = sqrt(c(min(lista$Mass[ok]) * C1, C1 * C2, C2 * max(lista$Mass[ok]))),
           y = Inf, vjust = 1.6, size = 3.2, label = c("Pequeño", "Mediano", "Grande")) +
  scale_x_log10(labels = label_number(decimal.mark = ",", big.mark = " ")) +
  labs(x = "Masa corporal (g, escala logarítmica)", y = "Número de especies") +
  theme_bw(base_size = 11) + theme(panel.grid.minor = element_blank())
for (ext in c("png", "tiff")) {
  a <- list(filename = file.path(opt$out, paste0("Figura9_masa_corporal.", ext)), plot = g9,
            width = 16, height = 10, units = "cm", dpi = 600, bg = "white")
  if (ext == "tiff") a$compression <- "lzw"
  do.call(ggsave, a)
}

## ---- 5. Resumen en pantalla ------------------------------------------------------
cat("Especies en la lista GBIF:", nrow(lista), "\n")
cat("En hábitats abiertos (", paste(HAB, collapse = ", "), "):", sum(ok & lista$habitat_abierto), "\n")
cat("Con masa en AVONET:", sum(ok), "(", dec(100 * mean(ok), 1), "% )\n")
cat("Sin coincidencia exacta (revisar_manual.csv):", nrow(revisar), "\n")
cat("Cortes fijos:", C1, "g y", C2, "g; terciles log10:", dec(10^tq, 1), "g\n\n")
print(resumen, row.names = FALSE)
cat("\nEspecies de referencia del manuscrito:\n"); print(refs, row.names = FALSE)
