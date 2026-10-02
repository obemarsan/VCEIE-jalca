# VCEIE-jalca — serie de entrada y código

Código en R que reproduce íntegramente los resultados, las tablas y las figuras del manuscrito

> **Valoración económica del impacto ecológico mediante un modelo densidad–área de saturación: aplicación ilustrativa a la fauna voladora del ecosistema jalca, Perú**

El trabajo propone un procedimiento de valoración y lo aplica de forma **ilustrativa**. La serie densidad–superficie (`datos_VCEIE.csv`) es la entrada del modelo y no constituye un inventario faunístico. Los parámetros de `params_VCEIE.csv` (capacidad de carga, individuos de referencia y precios), la fracción de evaluación (2/3), el área (8 218,23 ha), la frecuencia (2 por año) y el factor de representatividad (0,76) son **supuestos de escenario**. Su influencia se cuantifica con un análisis de sensibilidad local y un análisis Monte Carlo.

La Figura 1 (mapa de ubicación) se genera con `figura1_mapa.R` a partir de los límites político-administrativos del INEI (departamentos, provincias y distritos), que no se redistribuyen aquí. El polígono de aplicación está en el distrito de Gregorio Pita, provincia de San Marcos, Cajamarca (7,18278° S; 78,17033° O).

## Modelo

```
P = M / (1 + A · exp(−k · S))          sigmoide de saturación densidad–área
ln(M/P − 1) = ln A − k·S               linealización (M fijado a priori; MCO estima A y k)
S* = ln(A)/k                           superficie de inflexión (P = M/2)
VEIE = P(f·Smáx) · (f·Smáx/10 000) · n · precio,   f = 2/3
VECE_bruto = ΣVEIE · área · frecuencia;   VECE_100 = VECE_bruto / factor
```

`S` es la superficie (m²) y `P` la densidad media (animales/ha). Los IC 95 % de `A` y `k` se obtienen del ajuste por MCO; los de `S*` y del VEIE, por bootstrap de residuos (2 000 réplicas, con `M` fijo).

## Requisitos

- R ≥ 4.3. Los resultados del manuscrito se generaron con **R 4.6.0**; ver `outputs/sessionInfo.txt` tras la corrida.
- Paquetes `ggplot2`, `scales` y `writexl`. La Figura 1 requiere además `sf`, `patchwork` y `ggrepel`. Todos se instalan solos en la primera corrida.

## Contenido

| Archivo | Descripción |
|---|---|
| `datos_VCEIE.csv` | Serie de entrada: `grupo, S (m²), P (animales/ha)` |
| `params_VCEIE.csv` | Parámetros de escenario por grupo: `grupo, M, individuos, precio (S/), Smax (m²)` |
| `pipeline_VCEIE.R` | Ajuste, intervalos, valoración, sensibilidad, Monte Carlo, tablas y figuras 2–8 |
| `grupos_tamano_VCEIE.R` | Grupos de tamaño corporal: lista de especies de GBIF (doi:10.15468/dl.m2ggby) × masa de AVONET (Tobias et al. 2022); cortes 50 g y 500 g; Figura 9 |
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

La lista de GBIF (formato *Species list*, 250 especies, 14 016 registros) se descarga desde https://doi.org/10.15468/dl.m2ggby; AVONET, desde el material suplementario de Tobias et al. (2022). Ninguno se redistribuye aquí. Las 5 equivalencias de nombres resueltas a mano van en `revisar_manual_resuelto.csv`, en la misma carpeta que la lista de GBIF.

Genera en `outputs/`:

- `Figura2_ajuste_G1` … `Figura4_ajuste_G3`: ajuste densidad–área por grupo.
- `Figura5_dPdS_G1` … `Figura7_dPdS_G3`: tasa de cambio dP/dS por grupo.
- `Figura8_sensibilidad`: tornado de la sensibilidad local (±20 %).
- Cada figura en PNG y TIFF (LZW), a 600 ppp y con coma decimal.
- `Tablas_VCEIE.xlsx` con seis hojas: serie de entrada, parámetros con IC 95 %, valoración, sensibilidad, residuos y Monte Carlo.
- `resultados_VCEIE.txt` y `sessionInfo.txt`.

La corrida completa tarda menos de 1 minuto.

## Resultado esperado (escenario base)

| Grupo | n | A | k (m⁻²) | r² (%) | S* (m²) [IC 95 %] | VEIE (S/ por ha) [IC 95 %] |
|---|---|---|---|---|---|---|
| G1 | 7 | 16,251 | 1,310 × 10⁻³ | 97,07 | 2 128,7 [1 974,7–2 286,7] | 187,811 [177,428–195,883] |
| G2 | 11 | 18,812 | 1,351 × 10⁻³ | 98,31 | 2 171,7 [2 037,4–2 293,1] | 221,899 [214,129–229,160] |
| G3 | 8 | 19,606 | 1,349 × 10⁻³ | 98,51 | 2 205,2 [2 086,5–2 315,4] | 80,990 [78,081–84,148] |

- Cuenta física (individuos equivalentes por ha): 15,916; 29,587; 21,313 (total 66,816).
- Grupos de tamaño (162 especies de hábitats abiertos): 94 pequeñas, 51 medianas, 17 grandes.
- VECE bruto: S/ 8 065 376,56 por año.
- **VECE al 100 %: S/ 10 612 337,58 por año.**
- Monte Carlo (10 000 iteraciones, semilla 2026): mediana de S/ 9 984 106,94; percentiles 2,5–97,5 de S/ 5 578 618,05 a 16 552 403,03.
- Parámetros más influyentes: la fracción de evaluación (ρ = 0,843) y el factor de representatividad (ρ = −0,392).

## Licencia

El código se distribuye bajo licencia MIT (ver `LICENSE`). La serie de entrada se distribuye para uso académico con atribución.

## Cómo citar

> Marín-Machuca, O., Vargas Ayala, J., Daga López, R. A., Cabeza Molina, L. F., Alvarado Zambrano, F. A., Vértiz Osores, J. J., Cucho Flores, R. R. and Marín-Sánchez, O. (2026) *VCEIE-jalca: serie de entrada y código para la valoración densidad–área de la fauna voladora del ecosistema jalca* (versión v2.0.0) [Software]. GitHub. Disponible en: https://github.com/obemarsan/VCEIE-jalca
