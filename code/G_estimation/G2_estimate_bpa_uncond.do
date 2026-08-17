//------------------------------------------------------------------------------
// File           : G2_estimate_bpa_uncond.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 23/05/2026
// Description    : Genera 14 tablas anexas en formato 2-paneles (Estimaciones
//                  / Descriptivos) para los 14 indicadores de BPAs no
//                  condicionadas (suelo bpa_1..bpa_4, riego bpa_5..bpa_9,
//                  insumos bpa_10..bpa_14). Cada tabla reporta las 4 specs
//                  ITT-OLS / ITT-DiD / LATE-cluster / LATE-individual con
//                  controles, más medias por grupo × periodo.
//                  Flujo: (1) carga vía prg_load_panel; (2) construye D_c y
//                  P_i; (3) declara labels ; (4) tres loops que invocan 
//					prg_table_2panels con `nosubtitle' (no son
//                  tablas vF — el sufijo "(criterio flexible)" no aplica).
//                  El loop de riego corre sobre la submuestra
//                  riego_tec_prod==1 vía preserve/keep/restore.
//
// Depends        : _utils/prg_load_panel.do
//                  _utils/prg_table_3panels.do  (define _fmt_*)
//                  _utils/prg_table_2panels.do
//                  _utils/fix_table_borders.ps1 (invocado por el programa)
// Input          : Out/5_BDs por grupos de vars/BPAs_CondyNoCond_LByLS.dta (outcome_file)
//                  Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta,
//                  Sociodem_Prod_JH_LB.dta, Viv_Act_SEA_LB.dta,
//                  Demog_Ing_Hog_LB.dta, Productor_Predio_LB.dta (vía prg_load_panel)
// Output         : Tablas/2_Prácticas_Agronómicas/Anexo/B-2-<k>_Tab_BPA_<var>.docx (×14)
//------------------------------------------------------------------------------

cls
version 19.0
clear all

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

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\G2_estimate_bpa_uncond.log"
log using "${ruta_logs}\G2_estimate_bpa_uncond.log", replace text

// Cargar programas (prg_table_3panels primero porque define _fmt_*)
qui do "${ruta_utils}/prg_load_panel.do"
qui do "${ruta_utils}/prg_table_3panels.do"
qui do "${ruta_utils}/prg_table_2panels.do"
qui include "${ruta_setup}/spec.do"

//------------------------------------------------------------------------------
// 1. Cargar la base maestra + outcomes + vars crudas para D_c/P_i
//------------------------------------------------------------------------------
prg_load_panel, ///
	outcome_file("BPAs_CondyNoCond_LByLS") ///
	outcome_vars(bpa_1-bpa_14) ///
	extra_vars(i1aECA_PE_ccpp ptcp_ECA_prod)

//------------------------------------------------------------------------------
// 2. Construir D_c y P_i (definiciones operacionales — explícitas y visibles)
//    D_c: el cluster implementó la 1a ECA en el producto a evaluar
//    P_i: el productor participó de la ECA en cultivo de interés
//    Missings → 0 (no implementación / no participación)
//------------------------------------------------------------------------------
gen byte D_c = (i1aECA_PE_ccpp == 1) if !mi(asig_ccpp)
gen byte P_i = (ptcp_ECA_prod  == 1) if !mi(asig_ccpp)

//------------------------------------------------------------------------------
// 3. Generar las 14 tablas anexas en 3 bloques
//------------------------------------------------------------------------------
local outdir "${ruta_tablas}/2_Prácticas_Agronómicas/Anexo"

// La frase del título se declara por variable, no en una lista paralela
// recorrida con `gettoken'. Emparejadas solo por POSICIÓN, insertar o reordenar
// un outcome desplazaba todos los títulos siguientes y las tablas salían con el
// título de la variable vecina sin que nada avisara.
local ph_bpa_1  "la realización de análisis de suelo"
local ph_bpa_2  "la incorporación de materia orgánica al suelo"
local ph_bpa_3  "la asociación de cultivos"
local ph_bpa_4  "la siembra en surcos a contorno"
local ph_bpa_5  "la estimación de la demanda hídrica del cultivo"
local ph_bpa_6  "la programación de la frecuencia de riego"
local ph_bpa_7  "el ajuste del volumen de agua aplicada"
local ph_bpa_8  "el mantenimiento del sistema de riego"
local ph_bpa_9  "la realización de análisis del agua de riego"
local ph_bpa_10 "el uso de abonos"
local ph_bpa_11 "el uso de fertilizantes"
local ph_bpa_12 "el uso de plaguicidas"
local ph_bpa_13 "la aplicación de control biológico"
local ph_bpa_14 "la implementación de Manejo Integrado de Plagas"

// --- BPA Suelo: bpa_1..bpa_4 (toda la muestra) ---
forvalues k = 1/4 {
	local var bpa_`k'
	local phrase "`ph_`var''"
	if "`phrase'" == "" {
		di as error `"Falta la frase del título de `var' (local ph_`var')."'
		exit 198
	}
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		table_num("B.2-`k'") ///
		out("`outdir'/B-2-`k'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
}

// --- BPA Riego: bpa_5..bpa_9 (submuestra: riego_tec_prod==1) ---
// Pasa outcome_qualifier corto + note_extra con el detalle de la submuestra,
// para mantener el título bajo 20 palabras y la definición operativa en la nota.
local q_riego     "submuestra: riego tecnificado"
local extra_riego "La submuestra incluye productores con al menos un predio bajo riego tecnificado."
preserve
keep if riego_tec_prod == 1
forvalues k = 5/9 {
	local var bpa_`k'
	local phrase "`ph_`var''"
	if "`phrase'" == "" {
		di as error `"Falta la frase del título de `var' (local ph_`var')."'
		exit 198
	}
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		outcome_qualifier("`q_riego'") ///
		note_extra("`extra_riego'") ///
		table_num("B.2-`k'") ///
		out("`outdir'/B-2-`k'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
}
restore

// --- BPA Insumos: bpa_10..bpa_14 (toda la muestra) ---
forvalues k = 10/14 {
	local var bpa_`k'
	local phrase "`ph_`var''"
	if "`phrase'" == "" {
		di as error `"Falta la frase del título de `var' (local ph_`var')."'
		exit 198
	}
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		table_num("B.2-`k'") ///
		out("`outdir'/B-2-`k'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
}

log close