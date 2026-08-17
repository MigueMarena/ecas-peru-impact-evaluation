# Pipeline — de las encuestas al reporte

Qué corre, en qué orden, y qué produce cada etapa. El orden autoritativo vive en
`code/run_all.do`; este documento explica por qué está en ese orden.

Para las **llaves y relaciones entre bases**, ver [`data_map.md`](data_map.md).
Para **qué script produce cada tabla**, ver [`table_map.csv`](table_map.csv).

## Punto de entrada

```stata
do code/run_all.do                    // todo el pipeline
do code/run_all.do build              // solo una fase
do code/run_all.do "build estimation" // varias
```

Requiere la global `ECAS` con la ruta a la raíz del repositorio, o correr Stata
desde esa raíz. Ver *Cómo correrlo* en el README.

## Flujo

```mermaid
flowchart TB
    subgraph FUENTE["Fuentes"]
        S1["Encuesta LB 2021"]
        S2["Encuesta LS 2022"]
        S3["Registros ECAs<br/>SENASA 2019-2023"]
        S4["Padrón de CCPPs<br/>aleatorizados"]
    end

    subgraph B["B · Ingesta"]
        B1["B1 copia a Raw/"]
        B2["B2 limpia módulos<br/>→ pcl_*.dta"]
    end

    subgraph C["C · Tratamiento"]
        C1["C1 productores tratados"]
        C2["C2 asignación y<br/>cumplimiento por CCPP"]
    end

    subgraph D["D · Cruces"]
        D1["D arma 4 paneles<br/>Inicio · Personas · Parcelas · Cultivos"]
    end

    subgraph E["E · Construcción de variables"]
        E1["E1 características de la observación<br/>efectos fijos, exposición"]
        E23["E2-E3 productor y hogar"]
        E45["E4-E5 cultivos y predio"]
        E69["E6-E9 conocimiento · BPAs ·<br/>registros · inocuidad"]
        E10["E10 indicadores compuestos<br/>propio + ENA vF/vO/vE"]
    end

    subgraph G["G · Estimación"]
        G1["G1 puntajes de conocimiento"]
        G24["G2-G4 BPAs y registros<br/>(anexos)"]
        G5["G5Aa-G5Ac sub-indicadores<br/>y compuesto ENA"]
    end

    subgraph I["I · Diagnóstico del diseño"]
        I1["CONSORT · balance · atrición<br/>cumplimiento · robustez"]
    end

    subgraph H["H · Reporte"]
        H1["H1 compila cuerpo y anexos<br/>→ .docx + .pdf"]
    end

    S1 & S2 --> B1 --> B2 --> D1
    S3 & S4 --> C1 --> C2 --> D1
    D1 --> E1 --> E23 --> E45 --> E69 --> E10
    E10 --> G1 & G24 & G5
    E10 --> I1
    G1 & G24 & G5 & I1 --> H1
```

## Las fases, una por una

| Fase | Scripts | Qué hace | Escribe en |
|---|---|---|---|
| **B · Ingesta** | `B1`, `B2` | Copia las fuentes a `Raw/` y estandariza los nueve módulos de encuesta: limpia strings, convierte categorías negativas a missing, verifica identificadores | `Out/1_`, `Out/2_` |
| **C · Tratamiento** | `C1`, `C2` | Identifica qué productores participaron y qué centros poblados implementaron una ECA. Cruza registros de SENASA con el padrón aleatorizado | `Out/3_` |
| **D · Cruces** | `D` | Arma los cuatro paneles LB-LS y asigna el estatus de tratamiento a nivel de CCPP y de productor | `Out/4_` |
| **E · Construcción** | `E1`–`E10` | Diez módulos temáticos que construyen las variables de resultado y los controles de línea base | `Out/5_` |
| **G · Estimación** | `G1`–`G5Ac` | ITT, DiD y LATE. Escribe las tablas directamente en `.docx` | `Tablas/<tema>/{Cuerpo,Anexo}/` |
| **I · Diagnóstico** | `I1`–`I11` | CONSORT, balance, atrición, cumplimiento, intensidad, robustez al timing | `Tablas/0_Diseño_y_Diagnóstico/{Cuerpo,Anexo}/` |
| **H · Reporte** | `H1` | Compilación final del documento | `Versiones/` |

La fase **F (validación)** está vacía desde el 2026-08-12: `F1_test_balance.do`
se retiró porque su tabla no está en el reporte y su función quedó cubierta por
`I4`, `I5` e `I6`. La letra se reserva.

## Por qué ese orden

`E1` va primero dentro de su fase porque construye los efectos fijos (estrato
región × cultivo, centro poblado, mes de encuesta) que todas las demás consumen.
`E4` va antes que `E5` porque el predio necesita el valor de la cosecha que
calcula el módulo de cultivos. `E10` va al final porque los indicadores
compuestos se arman sobre lo que producen `E7`, `E8` y `E9`.

`H1` concatena las secciones `.docx` ya terminadas —con sus tablas y figuras
embebidas— y **no reconstruye ninguna tabla**. Lee de `Secciones/`, no de
`Tablas/`, así que regenerar tablas nunca cambia el consolidado: para que un
resultado nuevo llegue al reporte hay que insertarlo antes en la sección que
corresponda. En el orden por defecto `reporting` corre *antes* que
`diagnostics`, y da lo mismo, justamente por eso.

## Dependencias entre fases

Cada script declara en su cabecera qué lee (`Input`), qué escribe (`Output`) y de
qué helpers depende (`Depends`). Esa cabecera es la fuente de
[`table_map.csv`](table_map.csv), que se regenera con:

```bash
python code/_utils/build_table_map.py
```

El generador además **verifica cada salida declarada contra el disco**. Una
declaración sin archivo correspondiente es una señal, no ruido: así se detectó
que `H2_plot_yield_outliers.do` declaraba `.png` cuando exportaba `.emf` —y, al
revisarlo, que sus gráficos no aparecían en el reporte, lo que llevó a
retirarlo—; y así se cazaron las cabeceras que quedaron desactualizadas al
reorganizar las carpetas de tablas.
