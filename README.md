# VCEIE-jalca — serie de entrada y código

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23104525.svg)](https://doi.org/10.5281/zenodo.23104525)

Código en R que reproduce íntegramente los resultados, las tablas y las figuras del manuscrito

> **Modelo paramétrico densidad–área para valorar ecosistemas: prueba de concepto con la avifauna de la jalca, Perú** (versión para la *Revista Peruana de Biología*)

El trabajo propone un procedimiento de valoración y lo aplica de forma **ilustrativa**. La serie densidad–superficie (`datos_VCEIE.csv`) es la entrada del modelo y no constituye un inventario faunístico. Los parámetros de `params_VCEIE.csv` (capacidad de carga, individuos de referencia y precios), la fracción de evaluación (2/3), el área (8218.23 ha), la frecuencia (2 por año) y el factor de representatividad (0.76) son **supuestos de escenario**. Su influencia se cuantifica con un análisis de sensibilidad local y un análisis Monte Carlo.

La Figura 1 (mapa de ubicación) se genera con `figura1_mapa.R` a partir de los límites político-administrativos del INEI (departamentos, provincias y distritos), que no se redistribuyen aquí. El polígono de aplicación está en el distrito de Gregorio Pita, provincia de San Marcos, Cajamarca (7.18278° S; 78.17033° O).

## Modelo

```
P = M / (1 + A · exp(−k · S))          sigmoide de saturación densidad–área
ln(M/P − 1) = ln A − k·S               linealización (M fijado a priori; MCO estima A y k)
S* = ln(A)/k                           superficie de inflexión (P = M/2)
Q    = P(f·Smáx) · (f·Smáx/10000) · n             cuenta física (individuos equivalentes), f = 2/3
VEIE = Q · precio                                  cuenta monetaria
VECE_bruto = ΣVEIE · área · frecuencia;   VECE_100 = VECE_bruto / factor
```

`S` es la superficie (m²) y `P` la densidad media (animales/ha). Los IC 95 % de `A` y `k` se obtienen del ajuste por MCO; los de `S*` y del VEIE, por bootstrap de residuos (2000 réplicas, con `M` fijo).

## Requisitos

- R ≥ 4.3. Los resultados del manuscrito se generaron con **R 4.6.0**; ver `outputs/sessionInfo.txt` tras la corrida.
- Paquetes `ggplot2`, `scales`, `writexl` y `patchwork`; los grupos de tamaño requieren además `readxl`, y la Figura 1, `sf` y `ggrepel`. Todos se instalan solos en la primera corrida.

## Contenido

| Archivo | Descripción |
|---|---|
| `datos_VCEIE.csv` | Serie de entrada: `grupo, S (m²), P (animales/ha)` |
| `params_VCEIE.csv` | Parámetros de escenario por grupo: `grupo, M, individuos, precio (S/), Smax (m²)` |
| `pipeline_VCEIE.R` | Ajuste, intervalos, cuenta física y monetaria, sensibilidad, Monte Carlo; Figuras 3–4, Tabla 2 y Tabla S1 |
| `grupos_tamano_VCEIE.R` | Grupos de tamaño corporal: lista de especies de GBIF (doi:10.15468/dl.m2ggby) × masa de AVONET (Tobias et al. 2022); cortes 50 g y 500 g; Figura 2 y Tabla 1 |
| `figura1_mapa.R` | Figura 1: mapa de ubicación (requiere los shapefiles del INEI) |
| `run.sh` | Ejecución por terminal |

## Uso

```bash
./run.sh
# o bien
Rscript pipeline_VCEIE.R --out=outputs --area=8218.23 --factor=0.76 --veces=2 --boot=2000 --mc=10000 --seed=2026
Rscript figura1_mapa.R --shp=<carpeta_INEI> --lat=-7.18278 --lon=-78.17033
Rscript grupos_tamano_VCEIE.R --gbif=<lista_GBIF>.csv --avonet="AVONET Supplementary dataset 1.xlsx"
```

La lista de GBIF (formato *Species list*, 250 especies, 14016 registros) se descarga desde https://doi.org/10.15468/dl.m2ggby; AVONET, desde el material suplementario de Tobias et al. (2022). Ninguno se redistribuye aquí. Las 5 equivalencias de nombres resueltas a mano van en `revisar_manual_resuelto.csv`, en la misma carpeta que la lista de GBIF.

Genera en `outputs/` (formato RPB: punto decimal, cifras sin separador de millares; figuras de 15 cm de ancho en PDF editable y PNG de 600 ppp):

- `Figura1_mapa_ubicacion`: ubicación del polígono (requiere shapefiles del INEI).
- `Figura2_masa_corporal`: masa corporal de las 162 especies de hábitats abiertos y cortes de 50 g y 500 g.
- `Figura3_ajuste_dPdS`: ajuste densidad–área (A–C) y tasa de cambio dP/dS (D–F) de los tres grupos.
- `Figura4_sensibilidad`: tornado de la sensibilidad local (±20 %).
- `Figura5_comparacion`: VECE al 100 % según la fracción evaluada con densidad de saturación, lineal y constante (A) y diferencia relativa frente a la saturación (B).
- `Tablas_VCEIE.xlsx`: Tabla S1 (serie de entrada), Tabla 2 (parámetros, IC 95 %, cuenta física), Tabla 3 (comparación de la forma del modelo) y anexos (valoración, sensibilidad, curva de la Figura 5, residuos, Monte Carlo).
- `Tablas_grupos_tamano.xlsx`: Tabla 1 (grupos de tamaño) y anexos (criterios, especies, revisión de nombres).
- `resultados_VCEIE.txt` y `sessionInfo.txt`.

## Resultado esperado (escenario base)

| Grupo | n | A | k (m⁻²) | r² (%) | S* (m²) [IC 95 %] | Q | VEIE (S/ por ha) [IC 95 %] |
|---|---|---|---|---|---|---|---|
| 1 (grande) | 7 | 16.251 | 1.310 × 10⁻³ | 97.07 | 2128.7 [1974.7–2286.7] | 15.916 | 187.811 [177.428–195.883] |
| 2 (mediano) | 11 | 18.812 | 1.351 × 10⁻³ | 98.31 | 2171.7 [2037.4–2293.1] | 29.587 | 221.899 [214.129–229.160] |
| 3 (pequeño) | 8 | 19.606 | 1.349 × 10⁻³ | 98.51 | 2205.2 [2086.5–2315.4] | 21.313 | 80.990 [78.081–84.148] |

- Cuenta física total: 66.816 individuos equivalentes por ha.
- Grupos de tamaño (162 especies de hábitats abiertos): 94 pequeñas, 51 medianas, 17 grandes.
- VECE bruto: S/ 8065376.56 por año. **VECE al 100 %: S/ 10612337.58 por año.**
- Monte Carlo (10000 iteraciones, semilla 2026): mediana de S/ 9984106.94; percentiles 2.5–97.5 de S/ 5578618.05 a 16552403.03.
- Parámetros más influyentes: la fracción de evaluación (ρ = 0.843) y el factor de representatividad (ρ = −0.392).
- Comparación de la forma del modelo (f = 2/3): la saturación ajusta mejor que la recta en los tres grupos (AIC −4.41, −9.95 y −16.22 frente a 2.62, 2.37 y 2.24). Con densidad lineal el VECE al 100 % es S/ 9492500.87 (−10.6 %); con densidad constante, S/ 7681341.40 (−27.6 %). Fuera de la serie (f = 1.25) la recta sobrestima en 34.4 %.

## Licencia

El código se distribuye bajo licencia MIT (ver `LICENSE`). La serie de entrada se distribuye para uso académico con atribución.

## Cómo citar

> Marín-Machuca, O., Daga López, R. A., Vargas Ayala, J., Alvarado Zambrano, F. A., Cabeza-Molina, L. F., Vértiz Osores, J. J., Cucho Flores, R. R. y Marín-Sánchez, O. (2026) *VCEIE-jalca: serie de entrada y código para la valoración densidad–área de la fauna voladora del ecosistema jalca* (versión v3.0.0) [Software]. Zenodo. https://doi.org/10.5281/zenodo.23104525 (DOI de concepto; resuelve a la última versión)
