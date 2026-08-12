//------------------------------------------------------------------------------
// File           : I10_summary_intensity.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Genera dos tablas de intensidad de exposición restringidas
//                  a productores que asistieron al menos una sesión:
//                    D12. Estadísticos descriptivos (media, DE, mediana, P90)
//                         de: nº sesiones asistidas, % asistencia, días entre
//                         primera y última sesión (tiempo_d_1aECA).
//                    D13. Distribución por categorías de asistencia:
//                         ≥90% (cumplidores estrictos), 50-89% (parcial),
//                         <50% (bajo compliance).
// Input          : Out/4_BDs Fusionadas/Panel_Inicio.dta
// Output         : Anexos/Diagnóstico_del_Diseño/B-5-6_Tabla_Intensidad_Stats.docx
//                  Tablas/0_Diseño_y_Diagnóstico/5_Compliance/D13_Tabla_Intensidad_Categorias.docx
//------------------------------------------------------------------------------

cls
clear all

//==============================================================================
// Step 1: Load environment
//==============================================================================
// Bootstrap robusto en batch fresh (fix bug ${ruta_scripts}; ver script 30).
if "${CONSULT}" == "" qui do "C:\\Users\\carlo\\ado\\personal\\profile.do"
qui include "${CONSULT}\\BID\\HRC0052956\\2_Scripts\\A_master.do"

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\\I10_summary_intensity.log"
log using "${ruta_logs}\\I10_summary_intensity.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\5_Compliance"
local outanx "${ruta_anexos}\\Diagnóstico_del_Diseño"

// Convención del proyecto: el tamaño de las notas es siempre (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"

//==============================================================================
// Step 2: Construir base a nivel productor (asistentes ≥1 sesión)
//==============================================================================
use Codprod22 post asig_ccpp ssns_as_prod pct_ssns_as tiempo_d_1aECA ///
	using "`outc4'\\Panel_Inicio.dta", clear

bysort Codprod22 (post): egen sesiones    = max(ssns_as_prod)
bysort Codprod22 (post): egen pct_sesiones = max(pct_ssns_as)
bysort Codprod22 (post): egen dias_eca    = max(tiempo_d_1aECA)
duplicates drop Codprod22, force

keep if sesiones >= 1 & !mi(sesiones)

count
local n_asist = r(N)

//==============================================================================
// Step 3: Tabla B.5-6 — estadísticos
//==============================================================================
local tag11 Tabla_Intensidad_Stats_D12

collect clear
collect create `tag11', replace

local idx = 1
foreach v of varlist sesiones pct_sesiones dias_eca {
	qui summ `v', detail
	local m   = r(mean)
	local sd  = r(sd)
	local p50 = r(p50)
	local p90 = r(p90)

	qui collect get media   =`m',   tags(cmdset[`idx']) name(`tag11')
	qui collect get sd      =`sd',  tags(cmdset[`idx']) name(`tag11')
	qui collect get mediana =`p50', tags(cmdset[`idx']) name(`tag11')
	qui collect get p90     =`p90', tags(cmdset[`idx']) name(`tag11')

	local ++idx
}

collect set `tag11'

collect label levels cmdset ///
	1 "Sesiones asistidas (de 15)"             ///
	2 "% de asistencia"                        ///
	3 "Días entre primera y última sesión",    modify

collect label levels result ///
	media   "Media"   ///
	sd      "DE"      ///
	mediana "Mediana" ///
	p90     "P90",    modify

collect style cell, border(right, pattern(nil)) margin(all, width(0pt))
collect style cell cmdset, font(Roboto, size(`size_m')) halign(left)  valign(center)
collect style cell result, font(Roboto, size(`size_m')) halign(center) nformat(%9.2f)

// Datos (items): regular
collect style cell cell_type[item], font(Roboto, size(`size_m') nobold)

// Headers: negrita blanca sobre azul BID
collect style cell cell_type[corner column-header], ///
	shading(background(0 78 112)) font(Roboto, size(`size_m') color(white) bold)

collect style column, dups(center)
collect style header cmdset, level(label)
collect style header result, level(label)
collect style row stack, nobinder

local titulo "Tabla B.5-6 — Intensidad de exposición entre quienes asistieron (n = `n_asist')"
local nota1 "Notas: La tabla reporta estadísticos descriptivos de intensidad de exposición restringidos a los productores que asistieron al menos a una sesión del programa (n = `n_asist')."
local nota2 "La variable 'Días entre primera y última sesión' corresponde a la duración (en días) de la primera ECA en el centro poblado donde reside cada productor."

collect title "`titulo'"
collect notes "`nota1' `nota2'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.
collect style title, font(Roboto, size(`size_m') bold)
collect style notes, font(Roboto, size(`size_n') italic)

collect layout (cmdset) (result[media sd mediana p90])

mat widths = (50, 12, 12, 13, 13)
collect style putdocx, name(`tag11') width(widths)
collect export "`outanx'\\B-5-6_Tabla_Intensidad_Stats.docx", as(docx) name(`tag11') replace

//==============================================================================
// Step 4: Tabla D13 — categorías
//==============================================================================
gen byte cat = .
replace cat = 1 if pct_sesiones >= 90 & !mi(pct_sesiones)
replace cat = 2 if pct_sesiones >= 50 & pct_sesiones < 90 & !mi(pct_sesiones)
replace cat = 3 if pct_sesiones <  50 & !mi(pct_sesiones)

forval c = 1/3 {
	count if cat == `c'
	local n_`c' = r(N)
	local p_`c' = 100 * `n_`c'' / `n_asist'
}

local tag12 Tabla_Intensidad_Cat_D13

collect clear
collect create `tag12', replace

forval c = 1/3 {
	qui collect get n =`n_`c'', tags(cmdset[`c']) name(`tag12')
	qui collect get p =`p_`c'', tags(cmdset[`c']) name(`tag12')
}

collect set `tag12'

collect label levels cmdset ///
	1 "Asistencia ≥90% (cumplidores estrictos)" ///
	2 "Asistencia 50-89% (parcial)"             ///
	3 "Asistencia <50% (bajo cumplimiento)",      modify

collect label levels result ///
	n "Frecuencia" ///
	p "%",         modify

collect style cell, border(right, pattern(nil)) margin(all, width(0pt))
collect style cell cmdset, font(Roboto, size(`size_m')) halign(left)  valign(center)
collect style cell result, font(Roboto, size(`size_m')) halign(center)
collect style cell result[n], nformat(%9.0f)
collect style cell result[p], nformat(%9.1f)

// Datos (items): regular
collect style cell cell_type[item], font(Roboto, size(`size_m') nobold)

// Headers: negrita blanca sobre azul BID
collect style cell cell_type[corner column-header], ///
	shading(background(0 78 112)) font(Roboto, size(`size_m') color(white) bold)

collect style column, dups(center)
collect style header cmdset, level(label)
collect style header result, level(label)
collect style row stack, nobinder

local titulo "Tabla D13 — Distribución por categoría de asistencia (n = `n_asist')"
local nota1 "Notas: La tabla reporta la distribución de los productores asistentes según su porcentaje de asistencia a las sesiones del programa. El denominador corresponde a los productores que asistieron al menos a una sesión (n = `n_asist')."
local nota2 "Las tres categorías son mutuamente excluyentes y exhaustivas."

collect title "`titulo'"
collect notes "`nota1' `nota2'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.
collect style title, font(Roboto, size(`size_m') bold)
collect style notes, font(Roboto, size(`size_n') italic)

collect layout (cmdset) (result[n p])

mat widths = (60, 20, 20)
collect style putdocx, name(`tag12') width(widths)
collect export "`outdir'\\D13_Tabla_Intensidad_Categorias.docx", as(docx) name(`tag12') replace

di as text "Listo: D12 (intensidad-stats) y D13 (intensidad-categorías) exportadas en `outdir'."

log close
