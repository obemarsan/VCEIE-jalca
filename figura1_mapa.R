#!/usr/bin/env Rscript
# =============================================================================
# VCEIE-jalca — Figura 1: mapa de ubicación del área de estudio
#   A) Perú, con el departamento de Cajamarca
#   B) Cajamarca, con la provincia de San Marcos
#   C) San Marcos, con el distrito de Gregorio Pita y el área de estudio
# Límites político-administrativos: INEI (shapefiles departamentos, provincias,
# distritos; WGS 84).
#
# USO:
#   Rscript figura1_mapa.R --shp=RUTA/shapefiles --lat=-7.xx --lon=-78.xx
#   Rscript figura1_mapa.R --shp=RUTA/shapefiles --poligono=area_estudio.kml
# Argumentos:
#   --shp=<dir>        carpeta con departamentos.shp, provincias.shp, distritos.shp
#   --lat, --lon       coordenadas (grados decimales, WGS 84) del área de estudio
#   --poligono=<arch>  límite del área de estudio (.shp, .kml, .gpkg); opcional,
#                      tiene prioridad sobre lat/lon
#   --out=<dir>        carpeta de salida [outputs]
# SALIDA: outputs/Figura1_mapa_ubicacion.png y .tiff (600 ppp, 16 × 9 cm)
# Los shapefiles del INEI no se incluyen en el repositorio (ver README).
# =============================================================================

req <- c("sf", "ggplot2", "patchwork", "ggrepel")
faltan <- req[!vapply(req, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) install.packages(faltan, repos = "https://cloud.r-project.org")
suppressPackageStartupMessages({ library(sf); library(ggplot2); library(patchwork); library(ggrepel) })
sf_use_s2(FALSE)

## ---- Argumentos ---------------------------------------------------------------
opt <- list(shp = "shapefiles", lat = NA, lon = NA, poligono = NA, out = "outputs",
            dep = "CAJAMARCA", prov = "SAN MARCOS", dist = "GREGORIO PITA")
for (a in commandArgs(TRUE)) {
  m <- regmatches(a, regexec("^--([^=]+)=(.*)$", a))[[1]]
  if (length(m) == 3 && m[2] %in% names(opt)) opt[[m[2]]] <- m[3]
}
dir.create(opt$out, showWarnings = FALSE, recursive = TRUE)
leer <- function(n) st_read(file.path(opt$shp, paste0(n, ".shp")), quiet = TRUE)
dep  <- leer("departamentos")
prov <- leer("provincias")
dist <- leer("distritos")

## ---- Área de estudio -------------------------------------------------------------
area <- NULL
if (!is.na(opt$poligono)) {
  area <- st_transform(st_zm(st_read(opt$poligono, quiet = TRUE)), 4326)
} else if (!is.na(opt$lat) && !is.na(opt$lon)) {
  area <- st_sf(geometry = st_sfc(st_point(c(as.numeric(opt$lon), as.numeric(opt$lat))),
                                  crs = 4326))
} else {
  message("AVISO: sin coordenadas ni polígono; el panel C se dibuja sin el área de estudio.")
}
if (!is.null(area)) {
  ctr <- suppressWarnings(suppressMessages(st_centroid(st_union(area))))
  d_hit <- dist$DISTRITO[lengths(suppressMessages(st_intersects(dist, ctr))) > 0]
  message("El área de estudio cae en el distrito: ", paste(d_hit, collapse = ", "))
  if (length(d_hit) && !opt$dist %in% d_hit)
    warning("¡El punto NO cae en ", opt$dist, "! Revisa coordenadas o --dist.")
}

## ---- Utilidades -----------------------------------------------------------------
tildes <- c("Jaen" = "Jaén", "Celendin" = "Celendín", "Contumaza" = "Contumazá",
            "Pedro Galvez" = "Pedro Gálvez", "Jose Sabogal" = "José Sabogal",
            "Jose Manuel Quiroz" = "José Manuel Quiroz", "Ichocan" = "Ichocán")
tc <- function(x) {
  y <- tools::toTitleCase(tolower(x))
  ifelse(y %in% names(tildes), tildes[y], y)
}
etiq <- function(x, campo) {
  p <- suppressWarnings(st_point_on_surface(x))
  cbind(st_drop_geometry(p)[campo], st_coordinates(p))
}
tema_mapa <- theme_bw(base_size = 8) +
  theme(panel.grid = element_line(colour = "grey90", linewidth = 0.2),
        axis.title = element_blank(), axis.text = element_text(size = 5.5),
        plot.tag = element_text(face = "bold", size = 10),
        panel.background = element_rect(fill = "grey96"))
g_fill <- "#F5F5F0"; resalte <- "#E69F00"; resalte2 <- "#56B4E9"

norte <- function(x, y, h) {                      # flecha de norte simple
  list(annotate("segment", x = x, xend = x, y = y, yend = y + h,
                arrow = arrow(length = unit(1.5, "mm"), type = "closed"), linewidth = 0.4),
       annotate("text", x = x, y = y + h * 1.25, label = "N", size = 2.6, fontface = "bold"))
}
escala <- function(x0, y0, km, lat) {             # barra de escala en km
  dx <- km / (111.32 * cos(lat * pi / 180))
  list(annotate("rect", xmin = x0, xmax = x0 + dx / 2, ymin = y0, ymax = y0 + dx / 18,
                fill = "black"),
       annotate("rect", xmin = x0 + dx / 2, xmax = x0 + dx, ymin = y0, ymax = y0 + dx / 18,
                fill = "white", colour = "black", linewidth = 0.2),
       annotate("text", x = c(x0, x0 + dx), y = y0 - dx / 12,
                label = c("0", paste(km, "km")), size = 1.9))
}

## ---- Panel A: Perú --------------------------------------------------------------
cj <- dep[dep$DEPARTAMEN == opt$dep, ]
bbA <- st_bbox(dep)
pA <- ggplot() +
  geom_sf(data = dep, fill = g_fill, colour = "grey55", linewidth = 0.15) +
  geom_sf(data = cj, fill = resalte, colour = "grey20", linewidth = 0.3) +
  annotate("text", x = -75.5, y = -9.5, label = "PERÚ", size = 2.4, fontface = "bold",
           colour = "grey30") +
  norte(-80.3, -14.2, 1.4) + escala(-81, -18.2, 300, -18) +
  coord_sf(xlim = bbA[c(1, 3)], ylim = bbA[c(2, 4)], expand = TRUE,
           label_axes = "-NE-") +
  scale_x_continuous(breaks = seq(-80, -70, 5)) + tema_mapa

## ---- Panel B: Cajamarca ----------------------------------------------------------
pv <- prov[prov$DEPARTAMEN == opt$dep, ]
sm <- pv[pv$PROVINCIA == opt$prov, ]
bbB <- st_bbox(pv)
lb <- etiq(pv, "PROVINCIA"); lb$PROVINCIA <- tc(lb$PROVINCIA)
pB <- ggplot() +
  geom_sf(data = dep, fill = "grey93", colour = "grey70", linewidth = 0.15) +
  geom_sf(data = pv, fill = g_fill, colour = "grey45", linewidth = 0.2) +
  geom_sf(data = sm, fill = resalte, colour = "grey20", linewidth = 0.35) +
  geom_text_repel(data = lb, aes(X, Y, label = PROVINCIA), size = 1.6, colour = "grey20",
                  min.segment.length = Inf, box.padding = 0.08, seed = 1) +
  norte(bbB[3] - 0.12, bbB[4] - 0.45, 0.25) +
  escala(bbB[1] + 0.05, bbB[2] + 0.02, 50, -6.5) +
  coord_sf(xlim = bbB[c(1, 3)], ylim = bbB[c(2, 4)], expand = TRUE) +
  scale_x_continuous(breaks = seq(-79.5, -77.5, 1)) + tema_mapa

## ---- Panel C: San Marcos ------------------------------------------------------------
ds <- dist[dist$DEPARTAMEN == opt$dep & dist$PROVINCIA == opt$prov, ]
gp <- ds[ds$DISTRITO == opt$dist, ]
bbC <- st_bbox(ds)
lc <- etiq(ds, "DISTRITO"); lc$DISTRITO <- tc(lc$DISTRITO)
lc$Y[lc$DISTRITO == "Gregorio Pita"] <- lc$Y[lc$DISTRITO == "Gregorio Pita"] - 0.03
pC <- ggplot() +
  geom_sf(data = dist, fill = "grey93", colour = "grey70", linewidth = 0.15) +
  geom_sf(data = ds, fill = g_fill, colour = "grey45", linewidth = 0.25) +
  geom_sf(data = gp, fill = resalte2, colour = "grey20", linewidth = 0.4) +
  geom_text_repel(data = lc, aes(X, Y, label = DISTRITO), size = 1.7, colour = "grey15",
                  min.segment.length = 0.3, segment.size = 0.15, box.padding = 0.15, seed = 1) +
  norte(bbC[3] - 0.04, bbC[2] + 0.01, 0.06) +
  escala(bbC[1] + 0.01, bbC[2] + 0.005, 10, -7.3) + tema_mapa
if (!is.null(area)) {
  pC <- pC + if (inherits(st_geometry(area), "sfc_POINT"))
    list(geom_sf(data = area, shape = 23, size = 2.6, fill = "#D55E00", colour = "black", stroke = 0.4),
         annotate("label", x = st_coordinates(area)[1, 1] - 0.012, y = st_coordinates(area)[1, 2] + 0.03,
                  label = "Área de estudio", size = 1.8, hjust = 1,
                  label.padding = unit(0.8, "mm"), fill = "white"))
  else geom_sf(data = area, fill = "#D55E00", colour = "black", alpha = 0.8, linewidth = 0.3)
}
pC <- pC + coord_sf(xlim = bbC[c(1, 3)], ylim = bbC[c(2, 4)], expand = TRUE)

## ---- Composición y exportación ------------------------------------------------
fig <- (pA | pB | pC) + plot_layout(widths = c(0.75, 0.9, 1.35)) +
  plot_annotation(tag_levels = "A")
for (ext in c("png", "tiff")) {
  args <- list(filename = file.path(opt$out, paste0("Figura1_mapa_ubicacion.", ext)),
               plot = fig, width = 16, height = 9, units = "cm", dpi = 600, bg = "white")
  if (ext == "tiff") args$compression <- "lzw"
  do.call(ggsave, args)
}
cat("Figura 1 guardada en", opt$out, "\n")
