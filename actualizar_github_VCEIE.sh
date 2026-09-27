#!/usr/bin/env bash
# =============================================================================
# actualizar_github_VCEIE.sh — corre el pipeline con tu R, verifica los
# resultados y publica el repositorio VCEIE-jalca con la versión v1.0.0.
# Uso (Terminal del Mac):
#   bash ~/Desktop/ACADEMOS/ECOSISTEMAS/analisis_VCEIE/pipeline_VCEIE/actualizar_github_VCEIE.sh
# =============================================================================
set -euo pipefail
REPO="$HOME/Desktop/ACADEMOS/ECOSISTEMAS/analisis_VCEIE/pipeline_VCEIE"
ENVIO="$HOME/Desktop/ACADEMOS/ECOSISTEMAS/analisis_VCEIE/envio_SouthSustainability/figuras_V10"
cd "$REPO"

echo "== 1. Comprobaciones =="
command -v Rscript >/dev/null || { echo "Falta R"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Esta carpeta no es un repositorio git"; exit 1; }
echo "R:      $(R --version | head -1)"
echo "Remoto: $(git remote get-url origin)"

echo "== 2. Ejecutando el pipeline =="
chmod +x run.sh
rm -rf outputs
./run.sh

echo "== 3. Verificando resultados contra el manuscrito =="
grep -q "VECE al 100 % = 10 612 337,58" outputs/resultados_VCEIE.txt \
  && echo "OK: VECE al 100 % = S/ 10 612 337,58" \
  || { echo "ERROR: el resultado no coincide con el manuscrito. No se publica nada."; exit 1; }

echo "== 4. Copiando figuras para el envío =="
mkdir -p "$ENVIO"
cp outputs/Figura*.tiff outputs/Figura*.png "$ENVIO"/
echo "Figuras copiadas en: $ENVIO"

echo "== 5. Preparando el commit =="
for f in figuras_tablas_ECOSISTEMAS.R generar_VCEIE.sh .pipeline_VCEIE.R; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 && git rm -q "$f" && echo "Eliminado del repo: $f"
  [ -f "$f" ] && mv "$f" "$f.antiguo" || true
done
git add README.md LICENSE .gitignore datos_VCEIE.csv params_VCEIE.csv pipeline_VCEIE.R run.sh actualizar_github_VCEIE.sh
git status --short
echo
read -r -p "¿Publicar en GitHub (commit + push + versión v1.0.0)? [s/N] " ok
[ "$ok" = "s" ] || [ "$ok" = "S" ] || { echo "Cancelado. Nada se subió."; exit 0; }

git commit -m "Pipeline para South Sustainability: figuras 2-7 a 600 ppp, coma decimal, individuos, 8 autores"
git push origin HEAD
if git rev-parse v1.0.0 >/dev/null 2>&1; then
  echo "AVISO: la etiqueta v1.0.0 ya existe; no se reescribe."
else
  git tag -a v1.0.0 -m "Versión citada en el manuscrito enviado a South Sustainability"
  git push origin v1.0.0
fi
if command -v gh >/dev/null 2>&1; then
  gh release create v1.0.0 --title "v1.0.0" --notes "Datos y código del manuscrito VCEIE-jalca (South Sustainability)." || true
else
  echo "Crea la release en: https://github.com/obemarsan/VCEIE-jalca/releases/new?tag=v1.0.0"
fi
echo "== Listo =="
