//------------------------------------------------------------------------------
// File           : I1_summary_consort.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/05/2026
// Description    : Calcula los conteos duales (clusters / productores) en cada
//                  etapa del flujo CONSORT del cluster-RCT — variante con
//                  atritos paralelos. La aleatorización abarca todos los
//                  centros poblados; los atritos sin línea base se separan
//                  como exit terminal de cada brazo. Dentro de la submuestra
//                  con baseline, se distinguen cumplidores (con sub-categoría
//                  de desviación temporal en T) y no cumplidores (con derrame
//                  en T; ECA temprana y caso gris en C). La muestra analítica
//                  es la unión de cumplidores y no cumplidores con baseline.
//                  Exporta xlsx (long, consumido por I2_graph_consort.py) y
//                  docx formateado con el framework collect (estándar BID).
//
//                  Definiciones operativas (todas a nivel CCPP salvo derrame,
//                  que se identifica a nivel productor):
//                    Atritos sin BL   : aleatorizados − presentes en línea base
//                    Cumplidor (T,C)  : cumpl_est_ccpp == 1
//                    No cumplidor     : cumpl_est_ccpp == 0
//                    T-cumpl desv.    : T-cumpl & per_1aECA_PE_ccpp < 2
//                                       (ECA implementada antes del periodo
//                                       de evaluación = 2021II-2022I)
//                    T-no-cumpl drr.  : T-no-cumpl & el CCPP tiene ≥1 productor
//                                       con prod_ECA en cultivos del estudio
//                                       (inlist 11,12,15,16,19,26) y al menos
//                                       una sesión asistida (ssns_as_prod ≥ 1)
//                    C-no-cumpl ECAt  : C-no-cumpl & cat agrupada de la 1ª ECA
//                                       (Papa=16, Plátano=19, Cítrico={11,12,
//                                       15,26}) == prod_ECA_eval & implementada
//                                       en periodo ≤ 2021II-2022I
//                    C-no-cumpl gris  : C-no-cumpl & cat agrupada distinta a
//                                       prod_ECA_eval (ECA en cultivo del
//                                       estudio distinto al asignado)
// Depends        : (ninguno)
// Input          : Out/3_Centros Poblados.../CCPP/CCPPALEAy1AECA_ESTAT_CUMPL.dta
//                  Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/Cuerpo/D1_Tabla_CONSORT.xlsx
//                  Tablas/0_Diseño_y_Diagnóstico/Cuerpo/D1_Tabla_CONSORT.docx
//------------------------------------------------------------------------------

cls
version 19.0
clear all

//==============================================================================
// Step 1: Load environment
//==============================================================================
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver config.do).
// config.do se incluye SIEMPRE, sin guardarlo tras un `if' sobre alguna
// global: define locales (`outc1', `rawc1', …) y `do' abre un scope nuevo,
// así que los locales del llamador NO llegan hasta aquí. Saltarse el include
// porque las globals ya existan deja al script sin rutas y falla con r(601).
// `include' es idempotente: solo redefine rutas y crea carpetas con `cap'.
capture qui include "${ECAS}/2_Scripts/A_setup/config.do"
if _rc capture qui include "2_Scripts/A_setup/config.do"
if "${ruta_data}" == "" {
	di as error "No encuentro config.do. Define la global ECAS con la ruta"
	di as error "a la raíz del repositorio, o ejecuta Stata desde esa raíz."
	exit 601
}

// Parámetros del diseño: $fe_estrato (estrato de aleatorización) y
// $cl_ccpp (nivel de agrupamiento de los errores estándar). Vienen de
// spec.do para que diagnóstico y estimación no puedan divergir.
qui include "${ruta_setup}/spec.do"

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\\I1_summary_consort.log"
log using "${ruta_logs}\\I1_summary_consort.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Cuerpo"

// Convención del proyecto: el tamaño de las notas es siempre (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"

//==============================================================================
// Step 2: Conteos de CCPPs aleatorizados (universo total)
//==============================================================================
use "`outc3ccpp'\\CCPPALEAy1AECA_ESTAT_CUMPL.dta", clear
keep if !mi(asig_ccpp)
duplicates drop nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp, force

count if asig_ccpp == 0
local n_alea_clu_C = r(N)
count if asig_ccpp == 1
local n_alea_clu_T = r(N)
local n_alea_clu_Tot = `n_alea_clu_C' + `n_alea_clu_T'

//==============================================================================
// Step 3: Construcción de flags a nivel observación y conteos por subgrupo
//==============================================================================
use "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
cap drop __0*  // limpieza de variables fantasma residuales del build

// Categoría agrupada del 1er ECA del CCPP (compatible con prod_ECA_eval).
// prod_1aECA_ccpp desagrega cítricos (Limón=11, Mandarina=12, Naranja=15,
// Cítrico=26) y otros cultivos no-estudio (Manzana=13, Leche=9, Carne=4).
// La agrupamos a la trinaria {Papa=16, Plátano=19, Cítrico=26} que comparte
// con prod_ECA_eval.
gen byte _cat_1aECA = .
replace _cat_1aECA = 16 if prod_1aECA_ccpp == 16
replace _cat_1aECA = 19 if prod_1aECA_ccpp == 19
replace _cat_1aECA = 26 if inlist(prod_1aECA_ccpp, 11, 12, 15, 26)

// Flag a nivel observación: productor asistió a alguna ECA en cultivo del
// estudio (Limón/Mandarina/Naranja/Papa/Plátano/Cítrico) con ≥1 sesión.
gen byte _asist_otra_ECA = inlist(prod_ECA, 11, 12, 15, 16, 19, 26) & ///
                           ssns_as_prod >= 1 & !mi(ssns_as_prod)

// Marcador a nivel CCPP: ≥1 productor del CCPP cumple la condición de
// derrame. Propaga el flag a todas las filas del cluster.
bys cod_cpb: egen _ccpp_tiene_derrame = max(_asist_otra_ECA)

// Estado del CCPP por brazo y BL
gen byte _bl_T = (asig_ccpp == 1 & pste_ccpp_lb == 1)
gen byte _bl_C = (asig_ccpp == 0 & pste_ccpp_lb == 1)

// Cajas principales (a nivel observación; luego se cuentan por unique CCPP
// y unique Codprod22)
gen byte _T_cumpl       = _bl_T & cumpl_est_ccpp == 1
gen byte _T_nocumpl     = _bl_T & cumpl_est_ccpp == 0
gen byte _C_cumpl       = _bl_C & cumpl_est_ccpp == 1
gen byte _C_nocumpl     = _bl_C & cumpl_est_ccpp == 0

// Subgrupos.
//   T-cumpl desv. temporal, C-ECA temprana, C-caso gris: flag a nivel CCPP
//   (las variables que los identifican son cluster-level), por lo que el
//   conteo de productores es "todos los productores en clústeres marcados".
//
//   T-no-cumpl derrame: la condición se identifica a nivel productor
//   (asistió a otra ECA del estudio). El cluster se marca como derrame si
//   tiene al menos 1 productor con flag. Reportamos:
//     - clusters: con _ccpp_tiene_derrame == 1 (al menos 1 productor)
//     - productores: solo los que tienen flag _asist_otra_ECA
gen byte _T_cumpl_desv     	= _T_cumpl & per_1aECA_PE_ccpp < 2 & !mi(per_1aECA_PE_ccpp)
gen byte _T_nocumpl_drr_clu = _T_nocumpl & _ccpp_tiene_derrame == 1
gen byte _T_nocumpl_drr_ind = _T_nocumpl & _asist_otra_ECA == 1
gen byte _C_eca_temp       	= _C_nocumpl & _cat_1aECA == prod_ECA_eval & ///
                             !mi(_cat_1aECA) & inlist(per_1aECA_PE_ccpp, 0, 1, 2)
gen byte _C_caso_gris      	= _C_nocumpl & !mi(_cat_1aECA) & !mi(prod_ECA_eval) & ///
                             _cat_1aECA != prod_ECA_eval

//------------------------------------------------------------------------------
// Conteos por nivel
//------------------------------------------------------------------------------
// Helper: cuenta con `if' y guarda en una local. Evita repetir `r(N)' a mano.
cap program drop _cnt
program define _cnt
    args macname expr
    qui count if `expr'
    c_local `macname' = r(N)
end

// (a) Productores únicos (1 fila por Codprod22)
preserve
  bys Codprod22: keep if _n==1
  _cnt n_bl_ind_T            "_bl_T"
  _cnt n_bl_ind_C            "_bl_C"
  _cnt n_cumpl_ind_T         "_T_cumpl"
  _cnt n_cumpl_desv_ind_T    "_T_cumpl_desv"
  _cnt n_nocumpl_ind_T       "_T_nocumpl"
  _cnt n_nocumpl_drr_ind_T   "_T_nocumpl_drr_ind"
  _cnt n_cumpl_ind_C         "_C_cumpl"
  _cnt n_nocumpl_ind_C       "_C_nocumpl"
  _cnt n_nocumpl_etmp_ind_C  "_C_eca_temp"
  _cnt n_nocumpl_gris_ind_C  "_C_caso_gris"
restore

// (b) Clusters únicos (1 fila por cod_cpb)
preserve
  bys cod_cpb: keep if _n==1
  _cnt n_bl_clu_T            "_bl_T"
  _cnt n_bl_clu_C            "_bl_C"
  _cnt n_cumpl_clu_T         "_T_cumpl"
  _cnt n_cumpl_desv_clu_T    "_T_cumpl_desv"
  _cnt n_nocumpl_clu_T       "_T_nocumpl"
  _cnt n_nocumpl_drr_clu_T   "_T_nocumpl_drr_clu"
  _cnt n_cumpl_clu_C         "_C_cumpl"
  _cnt n_nocumpl_clu_C       "_C_nocumpl"
  _cnt n_nocumpl_etmp_clu_C  "_C_eca_temp"
  _cnt n_nocumpl_gris_clu_C  "_C_caso_gris"
restore

// (c) Atritos sin BL = aleatorizados − con BL
local n_atrito_clu_T = `n_alea_clu_T' - `n_bl_clu_T'
local n_atrito_clu_C = `n_alea_clu_C' - `n_bl_clu_C'

// (d) Muestra analítica = cumplidores + no cumplidores
local n_analit_clu_T = `n_cumpl_clu_T' + `n_nocumpl_clu_T'
local n_analit_clu_C = `n_cumpl_clu_C' + `n_nocumpl_clu_C'
local n_analit_ind_T = `n_cumpl_ind_T' + `n_nocumpl_ind_T'
local n_analit_ind_C = `n_cumpl_ind_C' + `n_nocumpl_ind_C'

di as txt "==================== Conteos CONSORT v2 ===================="
di "Aleatorización :  T = `n_alea_clu_T' clu   C = `n_alea_clu_C' clu   Total = `n_alea_clu_Tot'"
di "Atritos sin BL :  T = `n_atrito_clu_T' clu   C = `n_atrito_clu_C' clu"
di "Con línea base :  T = `n_bl_clu_T' clu / `n_bl_ind_T' ind   C = `n_bl_clu_C' clu / `n_bl_ind_C' ind"
di "T-cumplidores  :  `n_cumpl_clu_T' clu / `n_cumpl_ind_T' ind"
di "   └ desv.temp :  `n_cumpl_desv_clu_T' clu / `n_cumpl_desv_ind_T' ind"
di "T-no-cumpl     :  `n_nocumpl_clu_T' clu / `n_nocumpl_ind_T' ind"
di "   └ derrame   :  `n_nocumpl_drr_clu_T' clu / `n_nocumpl_drr_ind_T' ind"
di "C-cumplidores  :  `n_cumpl_clu_C' clu / `n_cumpl_ind_C' ind"
di "C-no-cumpl     :  `n_nocumpl_clu_C' clu / `n_nocumpl_ind_C' ind"
di "   └ ECA temp  :  `n_nocumpl_etmp_clu_C' clu / `n_nocumpl_etmp_ind_C' ind"
di "   └ caso gris :  `n_nocumpl_gris_clu_C' clu / `n_nocumpl_gris_ind_C' ind"
di "Muestra anal.  :  T = `n_analit_clu_T' clu / `n_analit_ind_T' ind   C = `n_analit_clu_C' clu / `n_analit_ind_C' ind"

//==============================================================================
// Step 4: Export xlsx en formato long (consumido por I2_graph_consort.py)
//==============================================================================
// Esquema: una fila por (etapa, brazo, nivel). La columna `padre` indica la
// jerarquía para reconstruir el flujo en el grafo. Valor `n` numérico.
// Uso postfile (no input) porque `input` no expande locales en sus filas.
tempfile fres
postfile pf str20 etapa str10 padre str3 brazo str3 nivel int n using "`fres'", replace

post pf ("alea")            ("")        ("T")   ("clu")  (`n_alea_clu_T')
post pf ("alea")            ("")        ("C")   ("clu")  (`n_alea_clu_C')
post pf ("alea")            ("")        ("Tot") ("clu")  (`n_alea_clu_Tot')
post pf ("atrito")          ("alea")    ("T")   ("clu")  (`n_atrito_clu_T')
post pf ("atrito")          ("alea")    ("C")   ("clu")  (`n_atrito_clu_C')
post pf ("bl")              ("alea")    ("T")   ("clu")  (`n_bl_clu_T')
post pf ("bl")              ("alea")    ("C")   ("clu")  (`n_bl_clu_C')
post pf ("bl")              ("alea")    ("T")   ("ind")  (`n_bl_ind_T')
post pf ("bl")              ("alea")    ("C")   ("ind")  (`n_bl_ind_C')
post pf ("cumpl")           ("bl")      ("T")   ("clu")  (`n_cumpl_clu_T')
post pf ("cumpl")           ("bl")      ("C")   ("clu")  (`n_cumpl_clu_C')
post pf ("cumpl")           ("bl")      ("T")   ("ind")  (`n_cumpl_ind_T')
post pf ("cumpl")           ("bl")      ("C")   ("ind")  (`n_cumpl_ind_C')
post pf ("cumpl_desv")      ("cumpl")   ("T")   ("clu")  (`n_cumpl_desv_clu_T')
post pf ("cumpl_desv")      ("cumpl")   ("T")   ("ind")  (`n_cumpl_desv_ind_T')
post pf ("nocumpl")         ("bl")      ("T")   ("clu")  (`n_nocumpl_clu_T')
post pf ("nocumpl")         ("bl")      ("C")   ("clu")  (`n_nocumpl_clu_C')
post pf ("nocumpl")         ("bl")      ("T")   ("ind")  (`n_nocumpl_ind_T')
post pf ("nocumpl")         ("bl")      ("C")   ("ind")  (`n_nocumpl_ind_C')
post pf ("nocumpl_derrame") ("nocumpl") ("T")   ("clu")  (`n_nocumpl_drr_clu_T')
post pf ("nocumpl_derrame") ("nocumpl") ("T")   ("ind")  (`n_nocumpl_drr_ind_T')
post pf ("nocumpl_ecatemp") ("nocumpl") ("C")   ("clu")  (`n_nocumpl_etmp_clu_C')
post pf ("nocumpl_ecatemp") ("nocumpl") ("C")   ("ind")  (`n_nocumpl_etmp_ind_C')
post pf ("nocumpl_gris")    ("nocumpl") ("C")   ("clu")  (`n_nocumpl_gris_clu_C')
post pf ("nocumpl_gris")    ("nocumpl") ("C")   ("ind")  (`n_nocumpl_gris_ind_C')
post pf ("analitica")       ("bl")      ("T")   ("clu")  (`n_analit_clu_T')
post pf ("analitica")       ("bl")      ("C")   ("clu")  (`n_analit_clu_C')
post pf ("analitica")       ("bl")      ("T")   ("ind")  (`n_analit_ind_T')
post pf ("analitica")       ("bl")      ("C")   ("ind")  (`n_analit_ind_C')
postclose pf

use "`fres'", clear

lab var etapa "Etapa"
lab var padre "Padre"
lab var brazo "Brazo"
lab var nivel "Nivel"
lab var n     "Conteo"

export excel using "`outdir'\\D1_Tabla_CONSORT.xlsx", ///
  firstrow(variables) sheet("CONSORT") sheetreplace

//==============================================================================
// Step 5: Build docx via collect framework (BID style)
//==============================================================================
// Tabla jerárquica con 8 filas (cmdset 1-8) × 4 columnas (clu T / clu C /
// ind T / ind C). Celdas no aplicables quedan vacías.
//
//   1   Aleatorización                              (solo clusters)
//   2   Atritos sin línea base                      (solo clusters)
//   3   Cumplidores                                 (dual)
//   4     └ con desviación temporal (implementación temprana) (solo T, dual)
//   5   No cumplidores                              (dual)
//   6     └ con derrame (T) / ECA temprana (C)       (dual)
//   7     └ con caso gris (C)                       (solo C, dual)
//   8   Muestra analítica                           (dual)
local tag Tabla_CONSORT

collect clear
collect create `tag', replace

// (1) Aleatorización
qui collect get value=`n_alea_clu_T'        , tags(cmdset[1] nivel[clu] arm[T]) name(`tag')
qui collect get value=`n_alea_clu_C'        , tags(cmdset[1] nivel[clu] arm[C]) name(`tag')

// (2) Atritos sin BL
qui collect get value=`n_atrito_clu_T'      , tags(cmdset[2] nivel[clu] arm[T]) name(`tag')
qui collect get value=`n_atrito_clu_C'      , tags(cmdset[2] nivel[clu] arm[C]) name(`tag')

// (3) Cumplidores
qui collect get value=`n_cumpl_clu_T'       , tags(cmdset[3] nivel[clu] arm[T]) name(`tag')
qui collect get value=`n_cumpl_clu_C'       , tags(cmdset[3] nivel[clu] arm[C]) name(`tag')
qui collect get value=`n_cumpl_ind_T'       , tags(cmdset[3] nivel[ind] arm[T]) name(`tag')
qui collect get value=`n_cumpl_ind_C'       , tags(cmdset[3] nivel[ind] arm[C]) name(`tag')

// (4) Cumpl con desv. temporal (solo T)
qui collect get value=`n_cumpl_desv_clu_T'  , tags(cmdset[4] nivel[clu] arm[T]) name(`tag')
qui collect get value=`n_cumpl_desv_ind_T'  , tags(cmdset[4] nivel[ind] arm[T]) name(`tag')

// (5) No cumplidores
qui collect get value=`n_nocumpl_clu_T'     , tags(cmdset[5] nivel[clu] arm[T]) name(`tag')
qui collect get value=`n_nocumpl_clu_C'     , tags(cmdset[5] nivel[clu] arm[C]) name(`tag')
qui collect get value=`n_nocumpl_ind_T'     , tags(cmdset[5] nivel[ind] arm[T]) name(`tag')
qui collect get value=`n_nocumpl_ind_C'     , tags(cmdset[5] nivel[ind] arm[C]) name(`tag')

// (6) No cumpl con derrame (T) / ECA temprana (C)
qui collect get value=`n_nocumpl_drr_clu_T' , tags(cmdset[6] nivel[clu] arm[T]) name(`tag')
qui collect get value=`n_nocumpl_etmp_clu_C', tags(cmdset[6] nivel[clu] arm[C]) name(`tag')
qui collect get value=`n_nocumpl_drr_ind_T' , tags(cmdset[6] nivel[ind] arm[T]) name(`tag')
qui collect get value=`n_nocumpl_etmp_ind_C', tags(cmdset[6] nivel[ind] arm[C]) name(`tag')

// (7) No cumpl con caso gris (solo C)
qui collect get value=`n_nocumpl_gris_clu_C', tags(cmdset[7] nivel[clu] arm[C]) name(`tag')
qui collect get value=`n_nocumpl_gris_ind_C', tags(cmdset[7] nivel[ind] arm[C]) name(`tag')

// (8) Muestra analítica
qui collect get value=`n_analit_clu_T'      , tags(cmdset[8] nivel[clu] arm[T]) name(`tag')
qui collect get value=`n_analit_clu_C'      , tags(cmdset[8] nivel[clu] arm[C]) name(`tag')
qui collect get value=`n_analit_ind_T'      , tags(cmdset[8] nivel[ind] arm[T]) name(`tag')
qui collect get value=`n_analit_ind_C'      , tags(cmdset[8] nivel[ind] arm[C]) name(`tag')

collect set `tag'

collect label levels cmdset                                       ///
  1 "Aleatorización"                                              ///
  2 "Atritos sin línea base"                                      ///
  3 "Cumplidores"                                                 ///
  4 "   — con desviación temporal (implementación temprana)"              ///
  5 "No cumplidores"                                              ///
  6 "   — con derrame (T) / ECA temprana (C)"                     ///
  7 "   — con caso gris (C)"                                      ///
  8 "Muestra analítica", modify

collect label levels nivel                                        ///
  ind "Productores" ///
  clu "Clústeres",   modify

collect label levels arm                                          ///
  C   "Control"     ///
  T   "Tratamiento", modify

//==============================================================================
// Step 6: Estilos BID
//==============================================================================
mat widths = (48, 13, 13, 13, 13)  // suma debe ser 100 (requisito de putdocx)

// Estilo de casa BID (Roboto, encabezado azul, bordes y tamaños).
// Lo que se declare DESPUÉS de esta línea se superpone.
do "${ruta_utils}\collect_style_bid.do" `_pt_dat'

collect style cell nivel,  font(Roboto, size(`size_m')) halign(center)
collect style cell arm,    font(Roboto, size(`size_m')) halign(center)
collect style cell result, nformat(%9.0fc)

// Datos (items): regular, sin negrita

// Headers (incluye corner): negrita blanca sobre azul BID

collect style header nivel,  level(label)
collect style header arm,    level(label)

//==============================================================================
// Step 7: Title and notes
//==============================================================================
local titulo "Tabla D1 — Flujo CONSORT del estudio — variante con atritos paralelos"
local nota1  "Notas: La tabla reporta los conteos duales (clústeres y productores) en cada etapa del flujo CONSORT del clúster-RCT."
local nota2  "Los atritos sin línea base corresponden a centros poblados aleatorizados que no fueron alcanzados por la encuesta de línea base; al carecer de medición pretratamiento, no se reportan productores en esta etapa y quedan excluidos de la muestra analítica."
local nota3  "Cumplimiento estricto a nivel clúster: tratamiento exige ECA en el producto a evaluar en el periodo 2021II-2022I; control exige no haber recibido ECA en ningún producto del estudio en 2021."
local nota4  "Subgrupos en tratamiento: desviación temporal = cumplidores cuya ECA fue implementada antes del periodo de evaluación; derrame = clústeres no cumplidores con al menos un productor que asistió a una ECA en algún cultivo del estudio."
local nota5  "Subgrupos en control: ECA temprana = clústeres no cumplidores que implementaron ECA en el mismo cultivo asignado en el periodo de evaluación o antes; caso gris = clústeres no cumplidores con ECA en un cultivo del estudio distinto al asignado."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3' `nota4' `nota5'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.

//==============================================================================
// Step 8: Layout y export
//==============================================================================
collect layout (cmdset) (nivel[clu ind]#arm[T C])

collect style putdocx, name(`tag') width(widths)
collect export "`outdir'\\D1_Tabla_CONSORT.docx", as(docx) name(`tag') replace

di as text "Listo: D1_Tabla_CONSORT exportada (xlsx + docx) en `outdir'."

log close
