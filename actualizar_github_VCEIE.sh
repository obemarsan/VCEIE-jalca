#!/usr/bin/env bash
# =============================================================================
# actualizar_github_VCEIE.sh — regenera figuras y tablas con tu R, verifica los
# resultados contra el manuscrito v2.1, copia las figuras a la carpeta del
# manuscrito y publica la versión v2.0.0 en GitHub.
# Uso (Terminal del Mac):
#   bash ~/Desktop/ACADEMOS/ECOSISTEMAS/analisis_VCEIE/pipeline_VCEIE/actualizar_github_VCEIE.sh
# =============================================================================
set -euo pipefail
TAG="v2.0.0"
REPO="$HOME/Desktop/ACADEMOS/ECOSISTEMAS/analisis_VCEIE/pipeline_VCEIE"
DESTINO="$HOME/Desktop/ACADEMOS/ECOSISTEMAS/analisis_VCEIE/reformulacion_v2/figuras_tablas"
cd "$REPO"

echo "== 1. Comprobaciones =="
command -v Rscript >/dev/null || { echo "Falta R"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Esta carpeta no es un repositorio git"; exit 1; }
echo "R:      $(R --version | head -1)"
echo "Remoto: $(git remote get-url origin)"

echo "== 2. Generando figuras y tablas (≈1 min) =="
chmod +x run.sh
rm -rf outputs
./run.sh

echo "== 3. Verificando resultados contra el manuscrito =="
ok=1
chk() { if grep -q "$2" "outputs/$1"; then echo "OK: $2"; else echo "NO COINCIDE: $2"; ok=0; fi; }
chk resultados_VCEIE.txt "VECE al 100 % = 10 612 337,58"
chk resultados_VCEIE.txt "mediana = 9 984 106,94"
chk resultados_VCEIE.txt "5 578 618,05 – 16 552 403,03"
chk resultados_VCEIE.txt "total = 66,816"
chk resumen_grupos.csv '"grupo_fijo","abiertos","Pequeño",94'
chk resumen_grupos.csv '"grupo_fijo","abiertos","Mediano",51'
chk resumen_grupos.csv '"grupo_fijo","abiertos","Grande",17'
for f in Figura1_mapa_ubicacion Figura2_ajuste_G1 Figura8_sensibilidad Figura9_masa_corporal; do
  [ -f "outputs/$f.png" ] && echo "OK: $f.png" || { echo "FALTA: $f.png"; ok=0; }
done
[ "$ok" = 1 ] || { echo "ERROR: algo no coincide con el manuscrito. No se publica nada."; exit 1; }

echo "== 4. Copiando figuras y tablas a la carpeta del manuscrito =="
mkdir -p "$DESTINO"
cp outputs/Figura*.png outputs/Figura*.tiff outputs/Tablas_*.xlsx outputs/resultados_VCEIE.txt "$DESTINO"/
echo "Copiado en: $DESTINO"

echo "== 5. Preparando el commit (sin datos de terceros: GBIF/AVONET/INEI no se suben) =="
git add README.md LICENSE .gitignore datos_VCEIE.csv params_VCEIE.csv pipeline_VCEIE.R \
        grupos_tamano_VCEIE.R figura1_mapa.R run.sh actualizar_github_VCEIE.sh
git status --short
echo
read -r -p "¿Publicar en GitHub (commit + push + versión $TAG)? [s/N] " resp
[ "$resp" = "s" ] || [ "$resp" = "S" ] || { echo "Cancelado. Nada se subió."; exit 0; }

git commit -m "v2.0.0: propuesta metodológica; grupos de tamaño (GBIF + AVONET), cuenta física/monetaria, IC bootstrap, sensibilidad y Monte Carlo"
git push origin HEAD
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "AVISO: la etiqueta $TAG ya existe; no se reescribe."
else
  git tag -a "$TAG" -m "Versión citada en el manuscrito v2.1 (propuesta metodológica)"
  git push origin "$TAG"
fi
if command -v gh >/dev/null 2>&1; then
  gh release create "$TAG" --title "$TAG" --notes "Código del manuscrito VCEIE-jalca v2.1: grupos de tamaño con GBIF (doi:10.15468/dl.m2ggby) y AVONET, cuenta física y monetaria, IC bootstrap, sensibilidad local y Monte Carlo." || true
else
  echo "Crea la release en: https://github.com/obemarsan/VCEIE-jalca/releases/new?tag=$TAG"
fi
echo "== Listo =="
