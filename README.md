# VCEIE-jalca — datos y código

Datos crudos y código en R que reproducen íntegramente los resultados, tablas y figuras del
manuscrito *Valoración Corporativa Económica del Impacto Ecológico (VCEIE) de una parte del
ecosistema jalca*, enviado a la revista **ECOSISTEMAS** (AEET).

## Modelo

Por cada grupo de fauna voladora se ajusta un sigmoide de saturación densidad–área

```
P = M / (1 + A · exp(-k · S))
```

donde `S` es la superficie (m²) y `P` la densidad media (animales/ha). El ajuste se hace por
linealización OLS: `y = ln(M/P − 1) = ln A − k·S`, con `M` fijo por grupo. Se derivan la
superficie de inflexión `S* = ln(A)/k`, el valor económico por grupo (`VEIE`) y el valor
corporativo total del ecosistema (`VECE`).

## Requisitos

- **R ≥ 4.0** con `Rscript` en el PATH.
- Paquetes `ggplot2` y `writexl` — el script los instala solo en la primera corrida.

## Contenido

| Archivo | Rol |
|---|---|
| `datos_VCEIE.csv` | Datos crudos (`grupo, S, P`) |
| `params_VCEIE.csv` | Parámetros por grupo (`grupo, M, especies, precio, Smax`) |
| `figuras_tablas_ECOSISTEMAS.R` | Pipeline principal (CLI) |
| `run.sh` | Wrapper de terminal |
| `generar_VCEIE.sh` | Script bash autocontenido (opcional) |

## Uso

```bash
./run.sh
# o
Rscript figuras_tablas_ECOSISTEMAS.R --data=datos_VCEIE.csv --out=outputs \
        --area=8218.23 --factor=0.76 --veces=2
```

Genera en `outputs/`: `Tablas_ECOSISTEMAS_VCEIE.xlsx` (4 hojas) y las figuras
`Figura1_ajuste_P_vs_S.png` y `Figura2_dPdS_vs_S.png` (600 dpi, 19 cm).

## Resultado esperado (parámetros por defecto)

```
VEIE_tot = 490.700   VECE_raw = 8 065 376.56   VECE_100 = 10 612 337.58
```

## Licencia

Código bajo licencia **MIT** (ver `LICENSE`). Los datos se distribuyen para uso académico con
atribución.

## Cómo citar

> Marín-Machuca, O., Marín-Sánchez, O., Vargas Ayala, J., Daga López, R. A., Pisco Moro, J. F.,
> Alvarado Zambrano, F. A., & Vértiz Osores, J. J. (2026). *VCEIE-jalca: datos y código para la
> valoración densidad–área de la fauna voladora del ecosistema jalca* (versión v1.0.0) [Software].
> GitHub. https://github.com/<usuario>/VCEIE-jalca

Reemplazar `<usuario>` por el usuario/organización de GitHub tras publicar, y citar la **release
etiquetada v1.0.0** para garantizar trazabilidad de la versión.
