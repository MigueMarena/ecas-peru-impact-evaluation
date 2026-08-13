//------------------------------------------------------------------------------
// File           : I7A_summary_cluster_size.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Distribución de tamaños de cluster en línea base. Reporta:
//                    - Conteo de clusters por rango (1-4, 5-9, 10-14, 15-19,
//                      20-25) cruzado con brazo.
//                    - Total y estadísticos resumen (media, DE, mediana, P25, P75).
//                    - Test de Kolmogorov-Smirnov de igualdad de distribuciones
//                      (al pie, en las notas).
//                  El cálculo del Design Effect (DEFF) por outcome principal
//                  se reporta en una tabla aparte: I7B_summary_deff_outcomes.do.
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/Anexo/B-5-4_Tabla_Cluster_Size.docx
//------------------------------------------------------------------------------

cls
version 19.0
clear all

//==============================================================================
// Step 1: Load environment
//==============================================================================
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
// A_master.do se incluye SIEMPRE, sin guardarlo tras un `if' sobre alguna
// global: define locales (`outc1', `rawc1', …) y `do' abre un scope nuevo,
// así que los locales del llamador NO llegan hasta acá. Saltarse el include
// porque las globals ya existan deja al script sin rutas y falla con r(601).
// `include' es idempotente: solo redefine rutas y crea carpetas con `cap'.
capture qui include "${ECAS}/2_Scripts/A_setup/A_master.do"
if _rc capture qui include "2_Scripts/A_setup/A_master.do"
if "${ruta_data}" == "" {
	di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
	di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
	exit 601
}

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\\I7A_summary_cluster_size.log"
log using "${ruta_logs}\\I7A_summary_cluster_size.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Cuerpo"
local outanx "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Anexo"

// Convención del proyecto: el tamaño de las notas es siempre (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"
mat widths = (50, 25, 25)

//==============================================================================
// Step 2: Construir base a nivel cluster
//==============================================================================
use Codprod22 post asig_ccpp cod_cpb cod_rgn_PE ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
keep if post == 0

bysort cod_cpb: gen byte _one = 1
collapse (sum) n_prods = _one (firstnm) asig_ccpp cod_rgn_PE, by(cod_cpb)

gen byte rango = .
replace rango = 1 if inrange(n_prods,  1,  4)
replace rango = 2 if inrange(n_prods,  5,  9)
replace rango = 3 if inrange(n_prods, 10, 14)
replace rango = 4 if inrange(n_prods, 15, 19)
replace rango = 5 if inrange(n_prods, 20, 25)
lab def rg 1 "1-4" 2 "5-9" 3 "10-14" 4 "15-19" 5 "20-25"
lab val rango rg

//==============================================================================
// Step 3: Conteos por rango y brazo
//==============================================================================
forval r = 1/5 {
	count if rango == `r' & asig_ccpp == 0
	local rC_`r' = r(N)
	count if rango == `r' & asig_ccpp == 1
	local rT_`r' = r(N)
}
count if asig_ccpp == 0
local nC = r(N)
count if asig_ccpp == 1
local nT = r(N)

foreach b in 0 1 {
	qui summ n_prods if asig_ccpp == `b', detail
	local mean_`b' = r(mean)
	local sd_`b'   = r(sd)
	local p25_`b'  = r(p25)
	local p50_`b'  = r(p50)
	local p75_`b'  = r(p75)
}

//==============================================================================
// Step 4: K-S test
//==============================================================================
qui ksmirnov n_prods, by(asig_ccpp)
local Dks = r(D)
cap local pks = r(p_cor)
if mi(`pks') local pks = r(p)

//==============================================================================
// Step 5: Construir tabla con collect
// (El Design Effect ya no se calcula aquí — se reporta para todos los outcomes
// principales en la tabla D7B, generada por I7B_summary_deff_outcomes.do.)
//==============================================================================
local tag Tabla_Cluster_Size

collect clear
collect create `tag', replace

// Filas de la tabla (cmdset secuencial). Antes de cada bloque insertamos una
// fila vacía cuyo label es el nombre del bloque — esa fila será el "header
// de panel" con shading gris. La numeración de cmdset es:
//   1     Header A: Distribución por rango
//   2-6   Rangos 1-4, 5-9, 10-14, 15-19, 20-25
//   7     Header B: Resúmenes
//   8     Total clusters
//   9     Media
//   10    Desviación estándar
//   11    Mediana
//   12    Percentil 25
//   13    Percentil 75
//   14    Header C: Test de igualdad de distribuciones
//   15    Test K-S

// Header A — celdas missing en cada columna del layout (ctrl y trat) para
// que la fila aparezca en la salida y todas sus celdas hereden el tag
// cmdset[1], permitiendo que el shading se extienda. El missing("")
// aplicado en los estilos oculta los puntos.
local idx_hdrA = 1
qui collect get ctrl=., tags(cmdset[1]) name(`tag')
qui collect get trat=., tags(cmdset[1]) name(`tag')

// Rangos
forval r = 1/5 {
	local row = `r' + 1
	qui collect get ctrl=`rC_`r'', tags(cmdset[`row']) name(`tag')
	qui collect get trat=`rT_`r'', tags(cmdset[`row']) name(`tag')
}

// Header B
local idx_hdrB = 7
qui collect get ctrl=., tags(cmdset[7]) name(`tag')
qui collect get trat=., tags(cmdset[7]) name(`tag')

// Resúmenes
qui collect get ctrl=`nC',     tags(cmdset[8])  name(`tag')
qui collect get trat=`nT',     tags(cmdset[8])  name(`tag')
qui collect get ctrl=`mean_0', tags(cmdset[9])  name(`tag')
qui collect get trat=`mean_1', tags(cmdset[9])  name(`tag')
qui collect get ctrl=`sd_0',   tags(cmdset[10]) name(`tag')
qui collect get trat=`sd_1',   tags(cmdset[10]) name(`tag')
qui collect get ctrl=`p50_0',  tags(cmdset[11]) name(`tag')
qui collect get trat=`p50_1',  tags(cmdset[11]) name(`tag')
qui collect get ctrl=`p25_0',  tags(cmdset[12]) name(`tag')
qui collect get trat=`p25_1',  tags(cmdset[12]) name(`tag')
qui collect get ctrl=`p75_0',  tags(cmdset[13]) name(`tag')
qui collect get trat=`p75_1',  tags(cmdset[13]) name(`tag')

// El test K-S de igualdad de distribuciones reporta UN solo D y UN solo
// p-valor (es un test de dos muestras). Para evitar la confusión visual de
// meterlo bajo encabezados "Control"/"Tratamiento", el resultado se mueve
// a la nota al pie de la tabla. Tampoco se reserva fila ni header de panel.

collect set `tag'

// Etiquetas (incluye headers de panel y filas de variables)
collect label levels cmdset ///
	1  "Distribución del nº de productores por clúster" ///
	2  "Tamaño 1-4"                                      ///
	3  "Tamaño 5-9"                                      ///
	4  "Tamaño 10-14"                                    ///
	5  "Tamaño 15-19"                                    ///
	6  "Tamaño 20-25"                                    ///
	7  "Resúmenes"                                       ///
	8  "Total clústeres"                                  ///
	9  "Media"                                           ///
	10 "Desviación estándar"                             ///
	11 "Mediana"                                         ///
	12 "Percentil 25"                                    ///
	13 "Percentil 75",                                   modify

collect label levels result ///
	ctrl "Control"     ///
	trat "Tratamiento", modify

//==============================================================================
// Step 7: Estilos BID
//==============================================================================
collect style cell, border(right, pattern(nil)) margin(all, width(0pt))
collect style cell cmdset, font(Roboto, size(`size_m') nobold noitalic) halign(left) valign(center)
collect style cell result, font(Roboto, size(`size_m') nobold noitalic) halign(center)

// Datos (items): regular y nformat por tipo de fila.
//   Rangos (cmdset 2-6) y total (cmdset 8): enteros.
//   Media, DE, mediana, P25, P75 (cmdset 9-13): 1 decimal.
collect style cell cell_type[item], font(Roboto, size(`size_m') nobold noitalic) nformat(%9.1f)
collect style cell cmdset[2 3 4 5 6 8], nformat(%9.0f)

// Headers de columna AL FINAL: azul BID + blanco bold.
collect style cell cell_type[corner column-header], ///
	shading(background(0 78 112)) font(Roboto, size(`size_m') color(white) bold noitalic)

// Headers de panel: shading gris BID + label en italic bold.
// El shading via cmdset captura la fila ENTERA porque todas las celdas de
// la fila tienen tag cmdset[idx_hdr]. Para ocultar los puntos de los
// valores missing que insertamos como placeholders en las columnas de
// datos, pintamos el color del texto de esas celdas-item con el mismo
// RGB del shading (211 210 209 = #d3d2d1) → quedan invisibles.
collect style cell cmdset[`idx_hdrA' `idx_hdrB'], ///
	shading(background(211 210 209)) ///
	font(Roboto, size(`size_m') italic bold) halign(left)
collect style cell cmdset[`idx_hdrA' `idx_hdrB']#cell_type[item], ///
	font(Roboto, size(`size_m') color(211 210 209))

collect style column, dups(center)
collect style header cmdset, level(label)
collect style header result, level(label)
collect style row stack, nobinder

//==============================================================================
// Step 8: Title and notes
//==============================================================================
local Dks_f3 : di %5.3f `Dks'
local pks_f3 : di %5.3f `pks'

local titulo "Tabla B.5-4 — Distribución de tamaño de clúster en línea base"
local nota1  "Notas: La tabla reporta la distribución del número de productores observados por centro poblado sobre la muestra analítica en línea base (definida en la Figura 4.2-1)."
local nota2  "Test de Kolmogorov-Smirnov de igualdad de distribuciones entre brazos: D = `Dks_f3', p = `pks_f3' (p corregido por la naturaleza discreta de la distribución)."

collect title "`titulo'"
collect notes "`nota1' `nota2'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.
collect style title, font(Roboto, size(`size_m') bold)
collect style notes, font(Roboto, size(`size_n') italic)

// Sangría en los nombres de variable (row-headers de cmdset). Va AL FINAL,
// después de todos los estilos generales y específicos, para asegurar que
// no la sobreescriba el `margin(all, width(0pt))` global ni los styles de
// los headers de panel.
collect style cell cmdset#cell_type[row-header], margin(left, width(25pt))
collect style cell cmdset[`idx_hdrA' `idx_hdrB']#cell_type[row-header], ///
	margin(left, width(0pt))

//==============================================================================
// Step 9: Layout y export
//==============================================================================
collect layout (cmdset) (result[ctrl trat])

collect style putdocx, name(`tag') width(widths)
collect export "`outanx'\\B-5-4_Tabla_Cluster_Size.docx", as(docx) name(`tag') replace

di as text "Listo: B-5-4_Tabla_Cluster_Size exportada en `outdir'."

log close
