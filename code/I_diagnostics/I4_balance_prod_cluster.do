//------------------------------------------------------------------------------
// File           : I4_balance_prod_cluster.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Genera la tabla descriptiva y de balance del número de
//                  productores por cluster (centro poblado) por brazo:
//                  media (DE), mediana, min y máx. Incluye diferencia, SMD y
//                  p-valor (regresión a nivel cluster con FE de estrato; el
//                  p-valor proviene de un test heterocedástico-robusto, dado
//                  que cada cluster es una observación y no hay anidamiento).
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/2_Cluster_Descriptivos/D3_Tabla_Balance_Prod_Cluster.docx
//------------------------------------------------------------------------------

cls
version 19.0
clear all

//==============================================================================
// Step 1: Load environment
//==============================================================================
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
if "${ruta_data}" == "" {
	capture qui include "${ECAS}/2_Scripts/A_master.do"
	if _rc capture qui include "2_Scripts/A_master.do"
	if "${ruta_data}" == "" {
		di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
		di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
		exit 601
	}
}

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\\I4_balance_prod_cluster.log"
log using "${ruta_logs}\\I4_balance_prod_cluster.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\2_Cluster_Descriptivos"

// Convención del proyecto: el tamaño de las notas es siempre (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"
// 14 columnas: cmdset + arm[C]#stat[m sd p50 min max] + arm[T]#stat[m sd p50 min max] + arm[bal]#result[diff smd pv].
// Suma 100. Variable más estrecha (etiqueta corta); m y sd un poco más grandes que p50/min/max.
mat widths = (18, 10, 6, 5, 4, 5, 10, 6, 5, 4, 5, 7, 7, 8)

//==============================================================================
// Step 2: Construir base a nivel cluster
//==============================================================================
use Codprod22 post asig_ccpp cod_cpb cod_rgn_PE ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
keep if post == 0

bysort cod_cpb: gen byte _one = 1
collapse (sum) n_prods = _one (mean) asig_ccpp (firstnm) cod_rgn_PE, by(cod_cpb)
lab var n_prods "Productores por clúster"

//==============================================================================
// Step 3: Estadísticos por brazo
//==============================================================================
foreach b in 0 1 {
	qui summ n_prods if asig_ccpp == `b', detail
	local mean_`b' = r(mean)
	local sd_`b'   = r(sd)
	local med_`b'  = r(p50)
	local min_`b'  = r(min)
	local max_`b'  = r(max)
}

//==============================================================================
// Step 4: Diferencia, SMD y p-valor
//==============================================================================
qui reg n_prods asig_ccpp i.cod_rgn_PE, robust
local diff = _b[asig_ccpp]
local p    = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))

qui summ n_prods if asig_ccpp == 0
local sd_pool0 = r(sd)
qui summ n_prods if asig_ccpp == 1
local sd_pool1 = r(sd)
local sd_pool  = sqrt((`sd_pool0'^2 + `sd_pool1'^2) / 2)
local smd      = `diff' / `sd_pool'

//==============================================================================
// Step 5: Construir tabla con collect
//==============================================================================
local tag Tabla_Balance_Prod_Cluster

collect clear
collect create `tag', replace

// Una sola fila ("Productores por clúster"), una sola variable
local i = 1
local v n_prods

// Estadísticos por brazo (arm × stat)
qui collect get value=`mean_0', tags(cmdset[`i'] arm[C] stat[m])    name(`tag')
qui collect get value=`sd_0',   tags(cmdset[`i'] arm[C] stat[sd])   name(`tag')
qui collect get value=`med_0',  tags(cmdset[`i'] arm[C] stat[p50])  name(`tag')
qui collect get value=`min_0',  tags(cmdset[`i'] arm[C] stat[min])  name(`tag')
qui collect get value=`max_0',  tags(cmdset[`i'] arm[C] stat[max])  name(`tag')

qui collect get value=`mean_1', tags(cmdset[`i'] arm[T] stat[m])    name(`tag')
qui collect get value=`sd_1',   tags(cmdset[`i'] arm[T] stat[sd])   name(`tag')
qui collect get value=`med_1',  tags(cmdset[`i'] arm[T] stat[p50])  name(`tag')
qui collect get value=`min_1',  tags(cmdset[`i'] arm[T] stat[min])  name(`tag')
qui collect get value=`max_1',  tags(cmdset[`i'] arm[T] stat[max])  name(`tag')

// Resumen del balance — anidado bajo arm[bal] para que el header "Balance"
// agrupe Dif./SMD/p-valor (simétrico con Control y Tratamiento).
qui collect get diff=`diff', tags(cmdset[`i'] arm[bal])  name(`tag')
qui collect get smd =`smd',  tags(cmdset[`i'] arm[bal])  name(`tag')
qui collect get pv  =`p',    tags(cmdset[`i'] arm[bal])  name(`tag')

collect set `tag'

// Etiquetas
collect label levels cmdset 1 "Productores por clúster", modify

collect label levels arm ///
	C   "Control"      ///
	T   "Tratamiento"  ///
	bal "Balance",     modify

collect label levels stat ///
	m   "Media"   ///
	sd  "DE"      ///
	p50 "Mediana" ///
	min "Mín."    ///
	max "Máx.",   modify

collect label levels result ///
	diff "Dif."     ///
	smd  "SMD"      ///
	pv   "p-valor", modify

//==============================================================================
// Step 6: Estilos BID
//==============================================================================
collect style cell, border(right, pattern(nil)) margin(all, width(0pt))
collect style cell cmdset, font(Roboto, size(`size_m')) halign(left)  valign(center)
collect style cell stat,   font(Roboto, size(`size_m')) halign(center)
collect style cell arm,    font(Roboto, size(`size_m')) halign(center)
collect style cell result, font(Roboto, size(`size_m')) halign(center)
collect style cell stat[m sd p50 min max] arm[C T], nformat(%9.2f)
collect style cell result[diff smd], nformat(%9.3f)
collect style cell result[pv],       nformat(%9.3f)

// Datos (items): regular
collect style cell cell_type[item], font(Roboto, size(`size_m') nobold)

// Headers: negrita blanca sobre azul BID
collect style cell cell_type[corner column-header], ///
	shading(background(0 78 112)) font(Roboto, size(`size_m') color(white) bold)

collect style column, dups(center)
collect style header cmdset, level(label)
collect style header arm,    level(label)
collect style header stat,   level(label)
collect style header result, level(label)
collect style row stack, nobinder

//==============================================================================
// Step 7: Title and notes
//==============================================================================
local titulo "Tabla D3 — Estadísticas descriptivas y balance de productores por clúster"
local nota1  "Notas: La tabla reporta estadísticos descriptivos del número de productores por centro poblado, calculados a nivel de clúster (una observación por centro poblado) sobre la muestra analítica en línea base (definida en la Figura 4.2-1)."
local nota2  "La columna 'Dif.' corresponde al coeficiente de una regresión del número de productores sobre el indicador de tratamiento, con efectos fijos del estrato de aleatorización y errores estándar robustos."
local nota3  "La columna 'SMD' reporta la diferencia estandarizada de medias: la diferencia entre brazos dividida entre la desviación estándar combinada de ambos brazos (raíz cuadrada del promedio simple de las varianzas en control y tratamiento)."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.
collect style title, font(Roboto, size(`size_m') bold)
collect style notes, font(Roboto, size(`size_n') italic)

//==============================================================================
// Step 8: Layout y export
//==============================================================================
collect layout (cmdset) ///
	(arm[C T]#stat[m sd p50 min max] arm[bal]#result[diff smd pv])

collect style putdocx, name(`tag') width(widths)
collect export "`outdir'\\D3_Tabla_Balance_Prod_Cluster.docx", as(docx) name(`tag') replace

di as text "Listo: D3_Tabla_Balance_Prod_Cluster exportada en `outdir'."

log close
