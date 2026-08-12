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
| `qplot` | SSC | `H2` | Gráficos Q-Q de rendimiento por cultivo |
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

Pendiente de medición. La única etapa que se cronometró hasta ahora es
`E4_build_crops.do`, la más pesada de la fase de construcción. `run_all.do`
reporta el tiempo de cada script al correr, así que la tabla se completará con
una corrida limpia de punta a punta.
