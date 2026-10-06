#!/usr/bin/env bash
# =============================================================================
# run.sh — genera todas las figuras (PDF editable + PNG 600 ppp, 15 cm) y tablas
# (xlsx) del manuscrito VCEIE-jalca (formato Revista Peruana de Biología).
#   Figuras 3–5 y Tablas_VCEIE.xlsx         -> pipeline_VCEIE.R
#   Figura 2 y Tablas_grupos_tamano.xlsx    -> grupos_tamano_VCEIE.R (GBIF + AVONET)
#   Figura 1                                -> figura1_mapa.R (shapefiles INEI)
# Uso:   ./run.sh
# Rutas configurables por variables de entorno (valores por defecto del Mac de Obert):
#   GBIF_CSV, AVONET_XLSX, SHP_DIR, OUT
# =============================================================================
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
DATOS="$HOME/Desktop/ACADEMOS/ECOSISTEMAS/analisis_VCEIE/reformulacion_v2/datos_publicos"
GBIF_CSV="${GBIF_CSV:-$DATOS/gbif_0007959/0007959-260928105237408.csv}"
AVONET_XLSX="${AVONET_XLSX:-$DATOS/AVONET Supplementary dataset 1.xlsx}"
SHP_DIR="${SHP_DIR:-$HOME/Desktop/ACADEMOS/shapefiles}"
OUT="${OUT:-$DIR/outputs}"
command -v Rscript >/dev/null 2>&1 || { echo "ERROR: falta R (Rscript). https://cran.r-project.org" >&2; exit 1; }
mkdir -p "$OUT"

echo "== Figuras 3–5 y Tablas_VCEIE.xlsx =="
Rscript "$DIR/pipeline_VCEIE.R" --out="$OUT"

echo "== Figura 2 y Tablas_grupos_tamano.xlsx =="
if [ -f "$GBIF_CSV" ] && [ -f "$AVONET_XLSX" ]; then
  Rscript "$DIR/grupos_tamano_VCEIE.R" --gbif="$GBIF_CSV" --avonet="$AVONET_XLSX" --out="$OUT"
else
  echo "AVISO: falta la lista GBIF o AVONET; se omite la Figura 2." >&2
  echo "       GBIF_CSV=$GBIF_CSV" >&2; echo "       AVONET_XLSX=$AVONET_XLSX" >&2
fi

echo "== Figura 1 =="
if [ -f "$SHP_DIR/departamentos.shp" ]; then
  Rscript "$DIR/figura1_mapa.R" --shp="$SHP_DIR" --lat=-7.18278 --lon=-78.17033 --out="$OUT"
else
  echo "AVISO: no se encontraron los shapefiles del INEI en $SHP_DIR; se omite la Figura 1." >&2
fi
echo "== Listo: salidas en $OUT =="
ls "$OUT"
