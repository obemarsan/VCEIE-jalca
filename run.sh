#!/usr/bin/env bash
# Ejecuta el pipeline VCEIE desde cualquier ubicación.
# Uso:  ./run.sh                 (valores por defecto)
#       ./run.sh --out=salida    (argumentos opcionales para el script R)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
command -v Rscript >/dev/null 2>&1 || {
  echo "ERROR: R no está instalado (falta Rscript). https://cran.r-project.org" >&2; exit 1; }
Rscript "$DIR/pipeline_VCEIE.R" "$@"
