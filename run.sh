#!/usr/bin/env bash
# Wrapper reproducible: corre el pipeline desde cualquier ubicacion.
# Uso:  ./run.sh                (valores por defecto)
#       ./run.sh --out=salida   (pasa argumentos al script R)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v Rscript >/dev/null 2>&1 || { echo "ERROR: R no esta instalado (falta Rscript)."; echo "macOS: brew install r  |  o https://cran.r-project.org"; exit 1; }
Rscript "$DIR/figuras_tablas_ECOSISTEMAS.R" "$@"
