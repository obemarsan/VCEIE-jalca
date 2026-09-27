# VCEIE-jalca — datos y código

Datos crudos y código en R que reproducen íntegramente los resultados, las tablas y las figuras 2–7 del manuscrito

> **Valoración económica del impacto ecológico mediante un modelo densidad–área de la fauna voladora del ecosistema jalca, Perú**
> enviado a *South Sustainability* (Universidad Científica del Sur).

La Figura 1 (mapa de ubicación) se elaboró en un sistema de información geográfica y no forma parte de este pipeline.

## Modelo

Para cada grupo de fauna voladora se ajusta un sigmoide de saturación densidad–área:

```
P = M / (1 + A · exp(−k · S))
```

donde `S` es la superficie (m²), `P` la densidad media (animales/ha) y `M` la capacidad de carga (fija por grupo). El ajuste se hace por linealización y mínimos cuadrados ordinarios: `ln(M/P − 1) = ln A − k·S`. Se derivan la superficie de inflexión `S* = ln(A)/k` (donde `P = M/2`), el valor económico por grupo (`VEIE`) y el valor corporativo del ecosistema (`VECE`).

## Requisitos

- R ≥ 4.3 (resultados del manuscrito generados con **R 4.6.0**; ver `outputs/sessionInfo.txt` tras la corrida).
- Paquetes `ggplot2`, `scales` y `writexl` (se instalan solos en la primera corrida).

## Contenido

| Archivo | Descripción |
|---|---|
| `datos_VCEIE.csv` | Datos crudos: `grupo, S (m²), P (animales/ha)` |
| `params_VCEIE.csv` | Parámetros por grupo: `grupo, M, individuos, precio (S/), Smax (m²)` |
| `pipeline_VCEIE.R` | Pipeline completo (ajuste, valoración, tablas y figuras) |
| `run.sh` | Ejecución por terminal |

## Uso

```bash
./run.sh
# o bien
Rscript pipeline_VCEIE.R --out=outputs --area=8218.23 --factor=0.76 --veces=2
```

Genera en `outputs/`:

- `Figura2_ajuste_G1` … `Figura4_ajuste_G3`: ajuste densidad–área por grupo.
- `Figura5_dPdS_G1` … `Figura7_dPdS_G3`: tasa de cambio dP/dS por grupo.
- Cada figura en PNG y TIFF (LZW), 600 ppp, 16 × 11 cm, coma decimal.
- `Tablas_VCEIE.xlsx` (datos, parámetros, valoración y residuos), `resultados_VCEIE.txt` y `sessionInfo.txt`.

## Resultado esperado (parámetros por defecto)

| Grupo | Individuos | A | k (m⁻²) | r² (%) | S* (m²) | VEIE (S/ por ha) |
|---|---|---|---|---|---|---|
| G1 | 7 | 16,251 | 1,310 × 10⁻³ | 97,07 | 2 128,7 | 187,811 |
| G2 | 11 | 18,812 | 1,351 × 10⁻³ | 98,31 | 2 171,7 | 221,899 |
| G3 | 8 | 19,606 | 1,349 × 10⁻³ | 98,51 | 2 205,2 | 80,990 |

VEIE total = S/ 490,700 por ha · VECE bruto = S/ 8 065 376,56 por año · **VECE al 100 % = S/ 10 612 337,58 por año**

## Licencia

Código bajo licencia MIT (ver `LICENSE`). Los datos se distribuyen para uso académico con atribución.

## Cómo citar

> Marín-Machuca, O., Vargas Ayala, J., Daga López, R. A., Pisco Moro, J. F., Alvarado Zambrano, F. A., Vértiz Osores, J. J., Cucho Flores, R. R. and Marín-Sánchez, O. (2026) *VCEIE-jalca: datos y código para la valoración densidad–área de la fauna voladora del ecosistema jalca* (versión v1.0.0) [Software]. GitHub. Disponible en: https://github.com/obemarsan/VCEIE-jalca
