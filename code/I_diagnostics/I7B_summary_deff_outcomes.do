//------------------------------------------------------------------------------
// File           : I7B_summary_deff_outcomes.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Reporta el coeficiente de correlación intraclúster (ICC)
//                  y el Design Effect (DEFF) para cada outcome principal
//                  vO de Buenas Prácticas Agrícolas medido en línea base. La
//                  fórmula del DEFF es:
//                      DEFF = 1 + CV²_m + (m̄ − 1) · ρ
//                  donde m̄ y CV²_m son la media y el coeficiente de variación
//                  cuadrático del tamaño de cluster (compartidos entre todos
//                  los outcomes), y ρ es el ICC de la variable de resultado.
//                  Práctica estándar en evaluaciones de impacto cluster-RCT
//                  (Bruhn & McKenzie 2009; Athey & Imbens 2017): reportar
//                  ICC y DEFF para múltiples outcomes principales permite
//                  cuantificar la heterogeneidad del clustering y facilita
//                  cálculos de poder a futuros investigadores.
// Depends        : (ninguno)
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
//                  Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/Anexo/B-5-5_Tabla_DEFF_Outcomes.docx
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
cap erase "${ruta_scripts}\\I7B_summary_deff_outcomes.log"
log using "${ruta_logs}\\I7B_summary_deff_outcomes.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Cuerpo"
local outanx "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Anexo"

// Convención del proyecto: notas a (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"
mat widths = (50, 25, 25)

local outcomes ///
	bpa_ena_riego_vO bpa_ena_suelo_vO bpa_ena_fert_abo_vO ///
	bpa_ena_plag_vO bpa_ena_biocontrol_vO bpa_ena_mip_vO bpa_ena_inoc_vO ///
	ena_pilar_agro_vO ena_pilar_insumos_vO ena_pilar_inoc_vO implementa_bpa_ena_vO

local outc_lbls `" "BPA Riego" "BPA Suelo" "BPA Fertilizantes/Abonos" "BPA Plaguicidas" "BPA Control biológico" "BPA Manejo integrado" "BPA Inocuidad" "Pilar Agro" "Pilar Insumos" "Pilar Inocuidad" "Compuesto final" "'

//==============================================================================
// Step 2: Tamaños de cluster — m̄ y CV²_m (constantes a todos los outcomes)
//==============================================================================
use Codprod22 post asig_ccpp cod_cpb ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
// Panel balanceado: los diagnósticos deben describir la MISMA muestra que
// estiman las tablas de resultados. prg_load_panel.do hace `keep if n_obs == 2';
// sin esta restricción el balance se reporta sobre los 1,445 encuestados en
// línea base mientras las estimaciones corren sobre los 1,282 del panel.
bys Codprod22: gen byte _en_panel = (_N == 2)
keep if post == 0 & _en_panel
drop _en_panel

bysort cod_cpb: gen byte _one = 1
preserve
	collapse (sum) n_prods = _one, by(cod_cpb)
	qui summ n_prods
	local m_bar = r(mean)
	local sd_n  = r(sd)
	local CV2   = (`sd_n' / `m_bar')^2
restore

di as text "m̄ = `m_bar'   CV²_m = `CV2'"

//==============================================================================
// Step 3: Construir base con los 11 outcomes vO + cod_cpb (post = 0)
//==============================================================================
keep Codprod22 post cod_cpb
merge 1:1 Codprod22 post using "`outc5'\\BPAs_Compuestos_LByLS.dta", ///
	keepus(`outcomes') keep(3) nogen

tempfile master
save `master'

//==============================================================================
// Step 4: Estimar ICC y DEFF por outcome
//==============================================================================
tempname Mres
matrix `Mres' = J(`:word count `outcomes'', 2, .)
matrix colnames `Mres' = "ICC" "DEFF"

local i = 1
foreach v of local outcomes {
	use `master', clear
	cap scalar drop _icc_v
	scalar _icc_v = .
	cap mixed `v' || cod_cpb:
	if _rc == 0 {
		cap estat icc
		if _rc == 0 scalar _icc_v = r(icc2)
	}
	matrix `Mres'[`i', 1] = _icc_v
	if !mi(_icc_v) {
		matrix `Mres'[`i', 2] = 1 + `CV2' + (`m_bar' - 1) * _icc_v
	}
	local ++i
}
matlist `Mres', title("ICC y DEFF por variable resultado principal vO")

//==============================================================================
// Step 5: Construir tabla con collect
//==============================================================================
local tag Tabla_DEFF_Outcomes_B5_5

collect clear
collect create `tag', replace

forval i = 1/11 {
	local lbl : word `i' of `outc_lbls'
	local icc_v  = `Mres'[`i', 1]
	local deff_v = `Mres'[`i', 2]
	qui collect get icc =`icc_v',  tags(cmdset[`i']) name(`tag')
	qui collect get deff=`deff_v', tags(cmdset[`i']) name(`tag')
	collect label levels cmdset `i' "`lbl'", modify
}

collect set `tag'

collect label levels result ///
	icc  "ICC"   ///
	deff "DEFF", modify

//==============================================================================
// Step 6: Estilos BID
//==============================================================================

// Estilo de casa BID (Roboto, encabezado azul, bordes y tamaños).
// Lo que se declare DESPUÉS de esta línea se superpone.
do "${ruta_utils}\collect_style_bid.do" `_pt_dat'

collect style cell result[icc],  nformat(%5.3f)
collect style cell result[deff], nformat(%5.2f)



//==============================================================================
// Step 7: Title and notes
//==============================================================================
local mb_f  : di %5.2f `m_bar'
local CV2_f : di %5.3f `CV2'

local titulo "Tabla B.5-5 — ICC y efecto de diseño (DEFF) por variable de resultado principal (versión ENA)"
local nota1  "Notas: La tabla reporta el coeficiente de correlación intraclúster (ICC) y el efecto de diseño aproximado (DEFF) para las variables de resultado principales del estudio (Buenas Prácticas Agrícolas, versión ENA), medidos en línea base sobre la panel balanceado (los productores con observación en ambas rondas; ver Figura 4.2-1)."
local nota2  "El ICC se estima con un modelo lineal de efectos aleatorios a nivel de centro poblado sobre la panel balanceado en línea base (los productores con observación en ambas rondas)."
local nota3  "El DEFF se calcula como DEFF = 1 + CV²_m + (m̄ − 1)·ρ, donde ρ es el ICC de la variable de resultado y m̄, CV²_m son la media y el coeficiente de variación cuadrático del número de productores por centro poblado (m̄ = `mb_f', CV²_m = `CV2_f')."
local nota4  "Un DEFF mayor a 1 indica que el agrupamiento reduce el tamaño efectivo de muestra: por ejemplo, DEFF = 2 implica que el N efectivo es la mitad del N nominal a fines de inferencia. La heterogeneidad del DEFF entre variables de resultado refleja la heterogeneidad del agrupamiento subyacente."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3' `nota4'"

//==============================================================================
// Step 8: Layout y export
//==============================================================================
collect layout (cmdset) (result[icc deff])

collect style putdocx, name(`tag') width(widths)
collect export "`outanx'\\B-5-5_Tabla_DEFF_Outcomes.docx", as(docx) name(`tag') replace

di as text "Listo: B-5-5_Tabla_DEFF_Outcomes exportada en `outdir'."

log close