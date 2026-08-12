//------------------------------------------------------------------------------
// File           : I9_summary_takeup.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Genera la Tabla D11 — Cobertura del programa. Reporta por
//                  categoría de exposición, n y % calculado sobre el brazo
//                  asignado correspondiente:
//                    - Asignados a tratamiento (denominador 100%).
//                    - Asistieron ≥1 sesión (cobertura bruta).
//                    - Take-up efectivo (asistió ≥75% sesiones).
//                    - Sin asistencia.
//                    - Contaminación en control (recibió alguna sesión).
// Input          : Out/4_BDs Fusionadas/Panel_Inicio.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/5_Compliance/D11_Tabla_TakeUp.docx (+ xlsx)
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
cap erase "${ruta_scripts}\\I9_summary_takeup.log"
log using "${ruta_logs}\\I9_summary_takeup.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\5_Compliance"

// Convención del proyecto: el tamaño de las notas es siempre (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"
mat widths = (50, 25, 25)

//==============================================================================
// Step 2: Construir base a nivel productor
//==============================================================================
use Codprod22 post asig_ccpp ssns_as_prod pct_ssns_as ///
	using "`outc4'\\Panel_Inicio.dta", clear

bysort Codprod22 (post): egen sesiones    = max(ssns_as_prod)
bysort Codprod22 (post): egen pct_sesiones = max(pct_ssns_as)
duplicates drop Codprod22, force

count if asig_ccpp == 1
local n_asig_T = r(N)
count if asig_ccpp == 0
local n_asig_C = r(N)

count if asig_ccpp == 1 & sesiones >= 1 & !mi(sesiones)
local n_at1 = r(N)

count if asig_ccpp == 1 & pct_sesiones >= 75 & !mi(pct_sesiones)
local n_at75 = r(N)

count if asig_ccpp == 1 & (mi(sesiones) | sesiones < 1)
local n_atSin = r(N)

count if asig_ccpp == 0 & sesiones >= 1 & !mi(sesiones)
local n_contam = r(N)

local p_asigT = 100.0
local p_at1   = 100 * `n_at1'   / `n_asig_T'
local p_at75  = 100 * `n_at75'  / `n_asig_T'
local p_atSin = 100 * `n_atSin' / `n_asig_T'
local p_cont  = 100 * `n_contam'/ `n_asig_C'

//==============================================================================
// Step 3: Export xlsx
//==============================================================================
preserve
	clear
	set obs 5
	gen str60 categoria = ""
	gen long  n         = .
	gen double pct      = .

	replace categoria = "Asignados a tratamiento"                          in 1
	replace n         = `n_asig_T'                                         in 1
	replace pct       = `p_asigT'                                          in 1

	replace categoria = "Asistieron ≥1 sesión (cobertura bruta)"             in 2
	replace n         = `n_at1'                                            in 2
	replace pct       = `p_at1'                                            in 2

	replace categoria = "Cobertura efectiva (≥75% sesiones)"                 in 3
	replace n         = `n_at75'                                           in 3
	replace pct       = `p_at75'                                           in 3

	replace categoria = "Sin asistencia"                                   in 4
	replace n         = `n_atSin'                                          in 4
	replace pct       = `p_atSin'                                          in 4

	replace categoria = "Contaminación en control (recibió alguna sesión)" in 5
	replace n         = `n_contam'                                         in 5
	replace pct       = `p_cont'                                           in 5

	export excel using "`outdir'\\D11_Tabla_TakeUp.xlsx", ///
		firstrow(variables) sheet("Take-up") sheetreplace
restore

//==============================================================================
// Step 4: Construir tabla con collect
//==============================================================================
local tag Tabla_TakeUp_D11

collect clear
collect create `tag', replace

qui collect get n=`n_asig_T', tags(cmdset[1]) name(`tag')
qui collect get p=`p_asigT',  tags(cmdset[1]) name(`tag')

qui collect get n=`n_at1',    tags(cmdset[2]) name(`tag')
qui collect get p=`p_at1',    tags(cmdset[2]) name(`tag')

qui collect get n=`n_at75',   tags(cmdset[3]) name(`tag')
qui collect get p=`p_at75',   tags(cmdset[3]) name(`tag')

qui collect get n=`n_atSin',  tags(cmdset[4]) name(`tag')
qui collect get p=`p_atSin',  tags(cmdset[4]) name(`tag')

qui collect get n=`n_contam', tags(cmdset[5]) name(`tag')
qui collect get p=`p_cont',   tags(cmdset[5]) name(`tag')

collect set `tag'

collect label levels cmdset ///
	1 "Asignados a tratamiento"                            ///
	2 "Asistieron ≥1 sesión (cobertura bruta)"               ///
	3 "Cobertura efectiva (≥75% sesiones)"                   ///
	4 "Sin asistencia"                                     ///
	5 "Contaminación en control (recibió alguna sesión)",  modify

collect label levels result ///
	n "n"                            ///
	p "% del brazo asignado",        modify

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

local titulo "Tabla D11 — Cobertura del programa"
local nota1 "Notas: La tabla reporta la cobertura del programa de Escuelas de Campo Agrícolas. El porcentaje en cada fila se calcula sobre el brazo asignado correspondiente (tratamiento para las filas de cobertura; control para la fila de contaminación)."
local nota2 "La cobertura bruta corresponde a los productores asignados al tratamiento que asistieron al menos a una sesión, mientras que la cobertura efectiva corresponde a quienes asistieron al menos al 75% de las sesiones."
local nota3 "La contaminación se define como la fracción de productores en centros poblados de control que recibieron al menos una sesión del programa."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.
collect style title, font(Roboto, size(`size_m') bold)
collect style notes, font(Roboto, size(`size_n') italic)

collect layout (cmdset) (result[n p])

collect style putdocx, name(`tag') width(widths)
collect export "`outdir'\\D11_Tabla_TakeUp.docx", as(docx) name(`tag') replace

di as text "Listo: D11_Tabla_TakeUp exportada en `outdir'."

log close
