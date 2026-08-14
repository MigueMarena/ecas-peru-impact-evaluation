# Entorno de software

## Stata 19 o superior — no es negociable

Las especificaciones LATE usan `ivregress 2sls` con la opción `absorb()`, que
**existe recién desde Stata 19**. Verificado el 2026-08-12 sobre StataNow 19:

| `version` declarada | `ivregress 2sls y (x = z), absorb(a) cluster(c)` |
|---|---|
| 17 | `option absorb() not allowed` — `r(198)` |
| 18 | `option absorb() not allowed` — `r(198)` |
| **19** | corre |

Los 39 scripts declaran `version 19.0`. Bajarlo no degrada resultados: rompe el
pipeline con un error que aparece cientos de líneas después del punto donde se
declaró la versión y que no menciona versiones.

> **Trampa asociada.** `code/A_setup/A_master.do` se carga con `include`, no con
> `do`, así que su `version` **se propaga a la sesión** del script que lo llama y queda en efecto cuando ese script
> define los programas de `_utils/`. Un valor equivocado ahí no rompe el archivo
> que lo contiene: rompe las estimaciones.

## Comandos de Stata de terceros

Se instalan **una vez por máquina**:

```stata
do code/_utils/install_ado.do
```

| Comando | Fuente | Usado en | Para qué |
|---|---|---|---|
| `reclink2` | SSC | `E2`, `merge_ccpp_status` | Vinculación aproximada de nombres de productor y de centro poblado |
| `labutil` | SSC | `E1` | `labmask` para etiquetar códigos generados |
| `xframeappend` | SSC | `E2` | Concatenar frames |

Las estimaciones principales usan comandos **nativos**: `areg` para ITT-OLS y
DiD, `ivregress 2sls` para LATE, `estat firststage` para el F de primera etapa.
Las tablas se construyen con `putdocx` y `collect`, también nativos. La
dependencia externa del pipeline es deliberadamente corta.

## Python 3.11 o superior

```bash
pip install -r requirements.txt
```

| Paquete | Usado en | Para qué |
|---|---|---|
| `matplotlib` | `I2_graph_consort.py`, `plot_knowledge_distributions.py` | Diagrama CONSORT y distribuciones de puntajes |
| `pandas`, `numpy`, `scipy` | mismos | Manipulación y estadística de apoyo |
| `pyreadstat` | `plot_knowledge_distributions.py` | Lectura de `.dta` desde Python |
| `openpyxl` | `_build_diccionario.py`, `_build_catalogo_policymakers.py` | Genera los diccionarios de variables |
| `lxml` | `check_sections.py` | Valida el XML de los `.docx` antes de compilar |

## Microsoft Word — solo para compilar el reporte

`H1_report_compile.do` pilotea Word por COM (`update_fields_export_pdf.ps1`,
`verify_compiled_docx.ps1`) para resolver los campos de índice y exportar el PDF.

**No tiene sustituto.** Los índices de tablas y figuras se arman por estilo, y un
campo TOC no es texto sino una instrucción que necesita números de página —algo
que solo Word conoce—. Ninguna librería de manipulación de `.docx` los resuelve.

Es una dependencia de Windows, y afecta **solo a la última etapa**: todo el
pipeline de datos y estimación corre sin Word.

## Sistema operativo

El pipeline se desarrolló y se corre en Windows. Las rutas usan separadores
mixtos (`/` y `\`), que Stata acepta en Windows indistintamente. Las etapas de
datos y estimación no tienen dependencias de plataforma; las de reporte sí
(Word por COM, PowerShell).

## Memoria y tiempo de ejecución

Medido en una corrida completa de punta a punta (2026-08-13), con
`run_all.do` sin argumento de fase — desde la ingesta de las encuestas hasta
el reporte compilado y los once diagnósticos. `run_all.do` cronometra cada
script y deja el detalle en `output/logs/run_all.log`.

**Total: 5 minutos 6 segundos.**

| Fase | Scripts | Tiempo | Lo más pesado |
|---|---|---|---|
| Ingesta | `B1`, `B2` | 17 s | `B2` (17 s) — limpia los nueve módulos de encuesta |
| Tratamiento | `C1`, `C2` | 44 s | `C1` (44 s) — vincula nombres con `reclink2` |
| Cruces | `D` | 4 s | — |
| Construcción | `E1`–`E10` | 11 s | `E4` (5 s) — el módulo de cultivos, el más grande |
| Estimación | `G1`–`G5Ac` | 126 s | `G3` (32 s), `G5Aa` (30 s) — más especificaciones por tabla |
| Reporte | `H1` | 64 s | Word por COM: resolver índices y exportar el PDF |
| Diagnóstico | `I1`–`I11` | 38 s | `I3`, `I6` (7-9 s) — estiman `mixed` por clúster |

Los 304 s de la tabla son la suma de lo que cronometra `run_all.do` por
script; el total real de 306 s incluye además `I2_graph_consort.py` (un
script Python, sin cronómetro propio en el orquestador).

La fase de estimación concentra el 41 % del tiempo total, y es la más fácil
de explicar: cada tabla corre entre 4 y 6 especificaciones (ITT-OLS, ITT-DiD,
LATE-cluster, LATE-individual, con y sin controles) por outcome, y varios
scripts iteran sobre 7-37 outcomes. `H1` es la segunda etapa más pesada
porque pilotea Word por COM, no por el volumen de contenido que consolida.

**Máquina de referencia**: AMD Ryzen 9 5900HX, 64 GB RAM, Windows 11, Stata
19.5 (StataSE-64), SSD NVMe (PNY CS3030). Los tiempos son indicativos, no una
garantía:
dependen del disco, de si Word ya está en memoria antes de correr `H1`, y de
cuánto tarda el sistema operativo en resolver rutas de red o de Drive si el
repositorio vive ahí.

**Memoria**: no se perfiló formalmente. Los datos del proyecto son una
encuesta de panel de miles de observaciones —no millones—, con a lo sumo unos
cientos de variables por base; no debería ser una restricción práctica en
ninguna máquina con 8 GB de RAM o más.
