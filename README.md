# Evaluación de impacto de las Escuelas de Campo Agrícolas (ECAs) en Perú

Paquete de replicación del análisis de impacto del programa de **Escuelas de Campo
Agrícolas** implementado por SENASA en el marco del proyecto PRODESA (Proyecto de
Desarrollo de la Sanidad Agraria e Inocuidad Agroalimentaria), financiado por el
Banco Interamericano de Desarrollo.

El diseño es un **ensayo aleatorizado por conglomerados**: la asignación al
tratamiento se hizo a nivel de centro poblado (CCPP), y los resultados se miden a
nivel de productor agrícola sobre un panel de dos rondas (línea base 2021, línea de
seguimiento 2022).

---

## Estado de este repositorio

| | Estado |
|---|---|
| Código del pipeline completo, auditable línea por línea | Sí |
| Corre en cualquier máquina con Stata 19 | Sí |
| Documentación del flujo, las llaves y qué produce cada script | Sí |
| Salidas ya generadas (89 tablas, figuras, logs) | Sí |
| Microdatos | No — ver *Disponibilidad de datos* |
| Reproducción numérica de los resultados por un tercero | **No, sin los datos** |

El pipeline ya no depende del entorno de su autor: `${ECAS}` es la única entrada
de configuración y todo lo demás se deriva de ella. Lo que impide reproducir los
números no es el código sino el acceso a los microdatos, que son de SENASA y del
BID.

Lo que sí permite hoy: leer exactamente cómo se construyó cada variable, cada
indicador compuesto y cada estimación, y contrastarlo contra las tablas
publicadas en `output/`.

## Cómo correrlo

```stata
* 1. Una vez por máquina: instalar los comandos externos
do code/_utils/install_ado.do

* 2. Indicar dónde está el repositorio (una sola vez por sesión)
global ECAS "D:/ruta/al/repositorio"

* 3. Correr
do code/run_all.do                    // todo el pipeline
do code/run_all.do build              // solo una fase
do code/run_all.do "build estimation" // varias
```

Alternativa sin configurar nada: abrir Stata con el directorio de trabajo en la
raíz del repositorio y correr `do code/run_all.do`. `code/A_setup/A_master.do`
detecta la raíz por sí solo. Si no la encuentra, aborta con un mensaje que dice qué hacer,
en lugar de fallar más adelante con un error de archivo no encontrado.

Fases disponibles: `ingest`, `treatment`, `merge`, `build`, `estimation`,
`reporting`, `diagnostics`.

---

## Contexto y diseño

- **Intervención**: Escuelas de Campo Agrícolas — capacitación grupal en Buenas
  Prácticas Agrícolas (BPA), presencial y en parcela, a lo largo de una campaña.
  Cada ECA es acotada: un cultivo, una comunidad, contenido adaptado al contexto local.
- **Cultivos evaluados**: papa, cítricos y plátano.
- **Unidad de aleatorización**: centro poblado.
- **Unidad de análisis**: productor agrícola.
- **Identificación**: la asignación aleatoria del centro poblado identifica el efecto
  de la *oferta* del programa (intención de tratar, ITT). Bajo supuestos adicionales
  se recuperan efectos locales (LATE) a nivel de conglomerado y de participación.

### Muestra analítica

| | Total | Tratamiento | Control |
|---|---|---|---|
| Centros poblados | 128 | 65 | 63 |
| Productores (panel balanceado) | 1,445 | 691 | 754 |

Cumplimiento a nivel de conglomerado: 70.8 % en tratamiento, 88.9 % en control
(el control se lee como ausencia de implementación). Atrición entre rondas: 11.3 %,
no diferencial entre brazos. Take-up bruto a nivel de productor: 44.0 %.

### Variables de resultado

1. **Conocimiento agronómico** — puntajes de un test sobre BPA aplicado en seguimiento.
2. **Adopción de BPA** — suelo, riego e insumos (no condicionadas); abonos,
   fertilizantes, plaguicidas, control biológico y MIP (condicionadas al uso).
3. **Registros e inocuidad alimentaria** — registros de aplicación y de gestión,
   almacenamiento, etiquetado, certificación.
4. **Indicadores compuestos de BPA** — dos familias. Una propia (AND estricto de
   cuatro pilares) y una alineada al catálogo de la Encuesta Nacional Agropecuaria
   (ENA), en tres versiones de agregación: Flexible (vF), Original ENA (vO) y
   Estricta (vE).

---

## Disponibilidad de datos y procedencia

**Este repositorio no contiene microdatos.**

| Fuente | Contenido | Titularidad | Estado |
|---|---|---|---|
| Encuesta de línea base (2021) | Productor, hogar, predio, cultivos | SENASA / BID | No incluida |
| Encuesta de seguimiento (2022) | Mismos módulos + test de conocimiento | SENASA / BID | No incluida |
| Registros administrativos de ECAs (2019-2023) | Implementación y asistencia | SENASA | No incluida |
| Padrón de centros poblados aleatorizados | Asignación al tratamiento | SENASA / BID | No incluida |
| Instrumentos de recolección | Cuestionarios y tests de conocimiento | — | **Incluidos** en `docs/codebook/` |

Dos razones, distintas entre sí:

1. **Titularidad.** Los microdatos son de SENASA y del BID, no del autor. Su
   publicación no es una decisión que corresponda a este repositorio.
2. **Datos personales.** Las bases de origen contienen DNI, nombres y apellidos,
   teléfono, correo, dirección y coordenadas GPS de los productores encuestados.

Se hizo un inventario de datos personales sobre las 130 bases del proyecto. Vale la
pena registrar el resultado porque acota qué haría falta para publicar datos si
alguna vez se autoriza: **la capa de análisis está libre de datos personales.** Las
18 bases que consumen los scripts de estimación se llavean por un código de encuesta
seudónimo (`Codprod22`) y un código de centro poblado, sin ningún identificador
directo. Los datos personales se concentran en las capas de ingesta y de
identificación de tratados, aguas arriba del análisis.

Dos archivos de código aplican correcciones manuales sobre identificadores nominales
(`code/_utils/fix_dni_names.do`, `code/_utils/fix_producer_names.do`). Se publican en
**versión redactada**: los valores están reemplazados por marcadores, pero el archivo
se conserva porque la existencia de esas correcciones es información metodológica —
las bases fueron parchadas a mano antes de los cruces, y quien audite el pipeline
necesita saberlo.

### Para acceder a los datos

Las solicitudes corresponden al **Servicio Nacional de Sanidad Agraria (SENASA)** del
Perú y a la **División de Agricultura y Desarrollo Rural (CSD-RND) del BID**, como
titulares de las encuestas y de los registros administrativos.

---

## Requisitos computacionales

### Software

**Stata 19 o superior.** No es una preferencia: las especificaciones LATE usan
`ivregress 2sls` con la opción `absorb()`, que existe recién desde Stata 19. Bajo
`version 17` o `version 18` el pipeline aborta con `option absorb() not allowed`.
Todos los scripts declaran `version 19.0`.

Comandos de terceros usados por el pipeline:

| Comando | Fuente | Usado en |
|---|---|---|
| `reclink2` | SSC | `E2`, `merge_ccpp_status` — vinculación aproximada de nombres |
| `labutil` | SSC | `E1` |
| `xframeappend` | SSC | `E2` |

Las estimaciones principales usan comandos nativos (`areg`, `ivregress 2sls`) y la
construcción de tablas usa `putdocx` y `collect`, también nativos.

**Python 3.11 o superior**, con las dependencias de `requirements.txt`.

**Microsoft Word** — requerido solo por la etapa de compilación del reporte (`H1`),
que pilotea Word por COM para resolver los campos de índice y exportar el PDF. Es una
dependencia de Windows y no tiene sustituto: los índices por estilo necesitan los
números de página, que solo Word conoce. El resto del pipeline no la necesita.

### Aleatoriedad

El análisis no usa simulación ni remuestreo: todas las estimaciones son cerradas
(OLS, 2SLS) y no dependen de una semilla. La aleatorización del experimento es previa
a este pipeline y viene dada en los datos.

### Memoria y tiempo de ejecución

Pendiente de medición. Se completará cuando se cronometre cada etapa desde cero.

---

## Estructura

```
code/
  run_all.do       Punto de entrada. Acepta una fase opcional
  A_setup/         A_master.do: resuelve la raíz y define todas las rutas
  B_ingest/        Ingesta y limpieza de los módulos de encuesta
  C_treatment/     Identificación de tratados y asignación de conglomerados
  D_merge/         Construcción de los cuatro paneles LB-LS
  E_build/         Variables de resultado (10 scripts temáticos)
  G_estimation/    Estimación y generación de tablas
  H_reporting/     Gráficos y compilación del reporte
  I_diagnostics/   CONSORT, balance, atrición, cumplimiento, robustez
  _utils/          Programas reusables e instalación de comandos externos
docs/              Documentación del pipeline y codebook
output/            Tablas, figuras y logs ya generados
```

La fase **F (validación)** no aparece porque quedó vacía: su único script se
retiró cuando se verificó que la tabla que producía no está en el reporte. La
letra se reserva.

### Documentación

| Documento | Qué contiene |
|---|---|
| [`docs/pipeline.md`](docs/pipeline.md) | Flujo completo de fuentes a reporte, por qué las fases van en ese orden |
| [`docs/data_map.md`](docs/data_map.md) | Las cinco llaves del estudio y dónde ocurre cada cruce |
| [`docs/table_map.csv`](docs/table_map.csv) | Qué script produce cada tabla y figura, verificado contra disco |
| [`docs/software.md`](docs/software.md) | Entorno, comandos de terceros, y por qué hace falta Stata 19 |
| `docs/codebook/` | Cuestionarios de ambas rondas y tests de conocimiento por cultivo |

### Cómo leer el pipeline

Los scripts llevan un prefijo de fase (`A` a `I`) y el orden de ejecución
autoritativo vive en el orquestador, no en el nombre del archivo. Cada script declara
en su cabecera de qué depende, qué lee y qué escribe — esa cabecera es la fuente del
mapa de tablas.

Los helpers de `code/_utils/` no se ejecutan solos; los invocan los scripts del
pipeline. Los más relevantes para entender las salidas son los generadores de tabla
`prg_table_2panels`, `prg_table_3panels`, `prg_table_4panels` y `prg_table_3way_het`,
que producen los formatos de tabla del reporte, y `prg_load_panel`, que define
exactamente qué variables entran a cada estimación.

---

## Salidas

89 tablas en formato `.docx` bajo `output/tables/`. **El tema manda y dentro se
separa cuerpo de anexo**: la tabla principal de un resultado y su robustez viven
en la misma carpeta, que es como se las consulta.

| Tema | Cuerpo | Anexo | Contenido |
|---|---|---|---|
| `0_diseno_y_diagnostico/` | 8 | 6 | CONSORT, descriptivos por conglomerado, atrición, cumplimiento, robustez al timing · balance de covariables, tamaño de clúster, efecto de diseño |
| `1_conocimiento_agronomico/` | 1 | — | Puntajes del test, 4 paneles |
| `2_practicas_agronomicas/` | — | 37 | Una tabla por indicador de BPA |
| `3_registros_e_inocuidad_alimentaria/` | — | 14 | Una tabla por indicador |
| `4_indicadores_compuestos_bpas/` | 8 | 15 | 7 sub-indicadores ENA (vO) + compuesto · efectos heterogéneos por cultivo y robustez (vF) |

Figuras en `output/figures/`: diagrama CONSORT, love plot de balance y etapas de
selección de centros poblados — las tres que cita el reporte.

**Los logs de ejecución no se publican.** Un log de Stata registra todo lo que el
script echó por pantalla, y eso incluye el código de los helpers que ejecuta: el
del cruce de paneles queda con decenas de líneas de DNIs y apellidos reales,
porque ejecuta las correcciones manuales de identificadores. Garantizar que un
log futuro esté limpio depende de qué eche cada script, así que la regla es no
publicarlos.

---

## Licencia y citación

Ver `LICENSE` y `CITATION.cff`.

Los productos del análisis (tablas, figuras y el reporte final) son entregables de una
consultoría para el Banco Interamericano de Desarrollo. Los derechos sobre esos
productos y sobre los datos subyacentes corresponden al BID y al SENASA; la licencia
de este repositorio cubre el código.
