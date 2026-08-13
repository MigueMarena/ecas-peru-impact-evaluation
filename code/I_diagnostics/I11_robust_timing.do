//------------------------------------------------------------------------------
// File           : I11_robust_timing.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Robustez al timing de recolección. Para cada variable
//                  tiempo-sensible (outcomes ENA vO en línea base), reporta tres
//                  especificaciones del coeficiente de tratamiento:
//                    (i)  Cruda:           reg X treat i.cod_rgn_PE, cluster(cod_cpb)
//                    (ii) Ajustada:        reg X treat i.cod_rgn_PE i.mes_enc, cluster(cod_cpb)
//                    (iii) Ventana común:  (i) restringido a meses donde T y C
//                                          tuvieron cobertura simultánea.
//                  Reporta coef y p-valor en cada especificación, más la
//                  diferencia (i) − (ii) para cuantificar el efecto del ajuste
//                  por timing.
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
//                  Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/Cuerpo/D14_Tabla_Robustez_Timing.docx (+ xlsx)
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
cap erase "${ruta_scripts}\\I11_robust_timing.log"
log using "${ruta_logs}\\I11_robust_timing.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Cuerpo"

// Convención del proyecto: el tamaño de las notas es siempre (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"

local outc_vO   bpa_ena_riego_vO bpa_ena_suelo_vO bpa_ena_fert_abo_vO ///
                bpa_ena_plag_vO bpa_ena_biocontrol_vO bpa_ena_mip_vO ///
                bpa_ena_inoc_vO ena_pilar_agro_vO ena_pilar_insumos_vO ///
                ena_pilar_inoc_vO implementa_bpa_ena_vO

//==============================================================================
// Step 2: Construir base maestra
//==============================================================================
use Codprod22 post asig_ccpp cod_cpb cod_rgn_PE mes_enc ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
keep if post == 0
duplicates drop Codprod22, force

merge 1:1 Codprod22 post using "`outc5'\\BPAs_Compuestos_LByLS.dta", ///
	keepus(`outc_vO') keep(3) nogen

// Etiquetas
lab var bpa_ena_riego_vO       "BPA Riego"
lab var bpa_ena_suelo_vO       "BPA Suelo"
lab var bpa_ena_fert_abo_vO    "BPA Fertilizantes/Abonos"
lab var bpa_ena_plag_vO        "BPA Plaguicidas"
lab var bpa_ena_biocontrol_vO  "BPA Control biológico"
lab var bpa_ena_mip_vO         "BPA Manejo integrado"
lab var bpa_ena_inoc_vO        "BPA Inocuidad"
lab var ena_pilar_agro_vO      "Pilar Agro"
lab var ena_pilar_insumos_vO   "Pilar Insumos"
lab var ena_pilar_inoc_vO      "Pilar Inocuidad"
lab var implementa_bpa_ena_vO  "Compuesto final"

// Identificar meses con cobertura simultánea T y C.
// `collapse` no acepta expresiones del lado derecho del `=` — solo nombres
// de variable. Por eso construimos las binarias _anyT y _anyC antes del
// collapse y luego colapsamos con (max).
preserve
	gen byte _anyT = (asig_ccpp == 1)
	gen byte _anyC = (asig_ccpp == 0)
	collapse (max) _anyT _anyC, by(mes_enc)
	gen byte ventana_comun = (_anyT == 1 & _anyC == 1)
	keep mes_enc ventana_comun
	tempfile vc
	save `vc'
restore
merge m:1 mes_enc using `vc', keep(1 3) nogen

//------------------------------------------------------------------------------
// Diagnóstico de la ventana común — para verificar si (iii) realmente
// restringe la muestra respecto a (i). Si todos los meses tienen cobertura
// simultánea, (iii) y (i) coincidirán por construcción (no es un bug).
//------------------------------------------------------------------------------
qui count
local n_total = r(N)
qui count if ventana_comun == 1
local n_vc = r(N)
qui count if ventana_comun == 0
local n_no_vc = r(N)
qui count if mi(ventana_comun)
local n_mi = r(N)

qui levelsof mes_enc, local(_meses)
local n_meses : word count `_meses'
qui levelsof mes_enc if ventana_comun == 1, local(_meses_vc)
local n_meses_vc : word count `_meses_vc'

di _n as text "{hline 70}"
di as text "Diagnóstico de la ventana común (especificación iii):"
di as text "{hline 70}"
di as text "  Observaciones totales:                  `n_total'"
di as text "  Observaciones en ventana común (T y C): `n_vc'"
di as text "  Observaciones fuera de ventana común:   `n_no_vc'"
di as text "  Observaciones con ventana_comun missing:`n_mi'"
di as text "  Meses-encuesta totales:                 `n_meses'"
di as text "  Meses con cobertura simultánea T y C:   `n_meses_vc'"
if `n_no_vc' == 0 & `n_mi' == 0 {
	di as text "  >> Todos los meses tuvieron cobertura simultánea de ambos brazos."
	di as text "  >> Por construcción, (iii) Ventana común usa la misma muestra que (i)."
	di as text "  >> Resultados idénticos entre (i) y (iii) son esperables (no es un bug)."
}
else if `n_mi' > 0 {
	di as error "  >> ALERTA: hay observaciones con ventana_comun missing. Revisar merge."
}
else {
	di as text "  >> Hay meses sin cobertura simultánea — (iii) restringe la muestra."
}
di as text "{hline 70}" _n

tempfile master
save `master'

//==============================================================================
// Step 3: Iterar y construir tabla con collect + xlsx
//==============================================================================
local tag Tabla_Robust_Timing_D14

collect clear
collect create `tag', replace

tempfile resul
clear
gen int     _orden    = .
gen str40   variable  = ""
gen str40   etiqueta  = ""
gen double  coef_i    = .
gen double  p_i       = .
gen double  coef_ii   = .
gen double  p_ii      = .
gen double  coef_iii  = .
gen double  p_iii     = .
gen double  diff_i_ii = .
save `resul', emptyok

local idx = 1
foreach v of local outc_vO {
	use `master', clear

	// (i) Cruda
	qui reg `v' asig_ccpp i.cod_rgn_PE, cluster(cod_cpb)
	local c_i = _b[asig_ccpp]
	local p_i = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))

	// (ii) Ajustada
	qui reg `v' asig_ccpp i.cod_rgn_PE i.mes_enc, cluster(cod_cpb)
	local c_ii = _b[asig_ccpp]
	local p_ii = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))

	// (iii) Ventana común
	qui reg `v' asig_ccpp i.cod_rgn_PE if ventana_comun == 1, cluster(cod_cpb)
	local c_iii = _b[asig_ccpp]
	local p_iii = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))

	local diff = `c_i' - `c_ii'

	// Cargar a collect
	qui collect get coef=`c_i',   tags(cmdset[`idx'] spec[i])    name(`tag')
	qui collect get pv  =`p_i',   tags(cmdset[`idx'] spec[i])    name(`tag')
	qui collect get coef=`c_ii',  tags(cmdset[`idx'] spec[ii])   name(`tag')
	qui collect get pv  =`p_ii',  tags(cmdset[`idx'] spec[ii])   name(`tag')
	qui collect get coef=`c_iii', tags(cmdset[`idx'] spec[iii])  name(`tag')
	qui collect get pv  =`p_iii', tags(cmdset[`idx'] spec[iii])  name(`tag')
	qui collect get diff=`diff',  tags(cmdset[`idx'] spec[delta]) name(`tag')

	local lbl : variable label `v'
	if "`lbl'" == "" local lbl "`v'"
	collect label levels cmdset `idx' "`lbl'", modify

	// Append to xlsx data — guardamos `idx' en una columna `_orden' para
	// poder restablecer el orden original de las variables después del
	// append (que las invierte).
	preserve
		clear
		set obs 1
		gen int     _orden    = `idx'
		gen str40   variable  = "`v'"
		gen str40   etiqueta  = "`lbl'"
		gen double  coef_i    = `c_i'
		gen double  p_i       = `p_i'
		gen double  coef_ii   = `c_ii'
		gen double  p_ii      = `p_ii'
		gen double  coef_iii  = `c_iii'
		gen double  p_iii     = `p_iii'
		gen double  diff_i_ii = `diff'
		append using `resul'
		save `resul', replace
	restore

	local ++idx
}

use `resul', clear
sort _orden
drop _orden
export excel using "`outdir'\\D14_Tabla_Robustez_Timing.xlsx", ///
	firstrow(variables) sheet("Robustez_Timing") sheetreplace

//==============================================================================
// Step 4: Estilos BID
//==============================================================================
collect set `tag'

collect label levels spec ///
	i     "(i) Cruda"               ///
	ii    "(ii) Ajustada (mes-enc)" ///
	iii   "(iii) Ventana común"     ///
	delta "(i) − (ii)",             modify

collect label levels result ///
	coef "Coef."  ///
	pv   "p"      ///
	diff "Δ",     modify

collect stars pv 0.01 "***" 0.05 "**" 0.10 "*", attach(pv)

collect style cell, border(right, pattern(nil)) margin(all, width(0pt))
collect style cell cmdset, font(Roboto, size(`size_m')) halign(left)  valign(center)
collect style cell spec,   font(Roboto, size(`size_m')) halign(center)
collect style cell result, font(Roboto, size(`size_m')) halign(center)
collect style cell result[coef diff], nformat(%9.4f)
collect style cell result[pv],        nformat(%9.3f)

// Datos (items): regular
collect style cell cell_type[item], font(Roboto, size(`size_m') nobold)

// Headers: negrita blanca sobre azul BID
collect style cell cell_type[corner column-header], ///
	shading(background(0 78 112)) font(Roboto, size(`size_m') color(white) bold)

collect style column, dups(center)
collect style header cmdset, level(label)
collect style header spec,   level(label)
collect style header result, level(label)
collect style row stack, nobinder

//==============================================================================
// Step 5: Title and notes
//==============================================================================
local titulo "Tabla D14 — Robustez al momento de recolección — variables de resultado en versión ENA, en línea base"
local nota1 "Notas: La tabla reporta tres especificaciones del coeficiente de la asignación al tratamiento para evaluar la robustez al momento de recolección, estimadas sobre la muestra analítica en línea base (definida en la Figura 4.2-1). Todas las regresiones usan errores estándar agrupados a nivel de centro poblado."
local nota2 "La especificación (i) Cruda incluye solo efectos fijos del estrato de aleatorización. La (ii) Ajustada agrega efectos fijos del mes de encuesta. La (iii) Ventana común replica (i) pero restringe la muestra a los meses con cobertura simultánea de control y tratamiento."
local nota3 "La columna Δ = (i) − (ii) cuantifica el aporte del ajuste por momento de recolección al coeficiente. Si las tres especificaciones convergen, el efecto es robusto al momento de recolección."
local nota4 "Significancia: *** p<0.01, ** p<0.05, * p<0.10."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3' `nota4'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.
collect style title, font(Roboto, size(`size_m') bold)
collect style notes, font(Roboto, size(`size_n') italic)

//==============================================================================
// Step 6: Layout y export
//==============================================================================
collect layout (cmdset) (spec[i ii iii]#result[coef pv] spec[delta]#result[diff])

// 8 columnas: cmdset + spec[i ii iii]#result[coef pv] (=6 cols) + spec[delta]#result[diff].
// Suma 100. Variable más ancha; (coef pv) iguales para los tres specs; delta un poco más amplio.
mat widths = (34, 9, 9, 9, 9, 9, 9, 12)
collect style putdocx, name(`tag') width(widths)
collect export "`outdir'\\D14_Tabla_Robustez_Timing.docx", as(docx) name(`tag') replace

di as text "Listo: D14_Tabla_Robustez_Timing exportada en `outdir'."

log close
