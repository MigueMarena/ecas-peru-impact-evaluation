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

Es honesto decirlo arriba y no enterrado en una nota: **este paquete todavía no corre
de punta a punta en una máquina distinta a la del autor.** El pipeline fue escrito
para uso interno y arrastra rutas absolutas hacia el entorno de desarrollo original.
La corrección de esas rutas está en curso.

| | Estado |
|---|---|
| Código del pipeline completo, auditable línea por línea | Sí |
| Documentación de qué produce cada script y dónde | Sí |
| Salidas ya generadas (89 tablas, figuras, logs) | Sí |
| Microdatos | No — ver *Disponibilidad de datos* |
| Ejecutable de punta a punta por un tercero | **Todavía no** |

Lo que sí permite hoy: leer exactamente cómo se construyó cada variable, cada
indicador compuesto y cada estimación, y contrastarlo contra las tablas publicadas.

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
| Diccionarios de variables e instrumentos | Codebook, cuestionarios, tests | — | **Incluidos** en `docs/codebook/` |

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

**Stata 17 o superior.** Comandos de terceros usados por el pipeline:

| Comando | Fuente | Usado en |
|---|---|---|
| `reclink2` | SSC | `E2`, `merge_ccpp_status` — vinculación aproximada de nombres |
| `qplot` | SSC | `H2` — gráficos Q-Q de rendimiento |
| `reghdfe`, `ppmlhdfe` | SSC | `prg_ppmlhdfe_cf` — control function con efectos fijos |
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
config/     Rutas, parámetros de especificación e instalación de comandos
code/       Pipeline Stata, en subcarpetas por fase
  A_setup/       Rutas y estructura de carpetas
  B_ingest/      Ingesta y limpieza de módulos de encuesta
  C_treatment/   Identificación de tratados y asignación de conglomerados
  D_merge/       Construcción de los paneles
  E_build/       Construcción de variables de resultado (10 scripts temáticos)
  F_validation/  Test de balance
  G_estimation/  Estimación y generación de tablas
  H_reporting/   Compilación del reporte y figuras
  I_diagnostics/ CONSORT, balance, atrición, cumplimiento, robustez
  _utils/        Helpers y programas reusables
docs/       Documentación del pipeline y codebook
output/     Tablas, figuras y logs ya generados
```

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

89 tablas en formato `.docx`, bajo `output/tables/`:

| Bloque | Tablas | Contenido |
|---|---|---|
| Cuerpo — conocimiento agronómico | 1 | Puntajes del test, 4 paneles |
| Cuerpo — indicadores compuestos BPA | 8 | 7 sub-indicadores ENA (vO) + compuesto agregado |
| Cuerpo — diseño y diagnóstico | 8 | CONSORT, descriptivos por conglomerado, atrición, cumplimiento, robustez al timing |
| Anexo — prácticas agronómicas | 37 | Una tabla por indicador de BPA |
| Anexo — registros e inocuidad | 14 | Una tabla por indicador |
| Anexo — indicadores compuestos | 15 | Efectos heterogéneos por cultivo (vO) y robustez (vF) |
| Anexo — diagnóstico del diseño | 6 | Balance de covariables, tamaño de conglomerado, efecto de diseño |

Figuras en `output/figures/`: diagrama CONSORT, love plot de balance, etapas de
selección de centros poblados, y gráficos Q-Q de rendimiento por cultivo.

Logs de ejecución de Stata en `output/logs/`.

---

## Licencia y citación

Ver `LICENSE` y `CITATION.cff`.

Los productos del análisis (tablas, figuras y el reporte final) son entregables de una
consultoría para el Banco Interamericano de Desarrollo. Los derechos sobre esos
productos y sobre los datos subyacentes corresponden al BID y al SENASA; la licencia
de este repositorio cubre el código.
