//------------------------------------------------------------------------------
// File           : G3_estimate_bpa_cond.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 23/05/2026
// Description    : Genera 23 tablas anexas en formato 2-paneles (Estimaciones
//                  / Descriptivos) para los indicadores de BPAs condicionadas
//                  al uso de abono, fertilizantes, plaguicidas (general),
//                  plaguicidas químicos, control biológico y MIP. Cada tabla
//                  reporta las 4 specs ITT-OLS / ITT-DiD / LATE-cluster /
//                  LATE-individual con controles, más medias por grupo ×
//                  periodo. Continúa la numeración A-2 abierta por G2 (los
//                  37 indicadores de BPA — no cond. y cond. — comparten el
//                  bloque temático de Prácticas Agronómicas en los anexos).
//                  Flujo: (1) carga vía prg_load_panel; (2) construye D_c y
//                  P_i; (3) declara labels amigables; (4) seis loops que
//                  invocan prg_table_2panels con `nosubtitle'.
//                  Los condicionamientos por uso del insumo (bpa_10==1,
//                  bpa_12_4==1, etc.) están comentados — replican la
//                  convención del código previo donde las estimaciones se
//                  corren sobre la muestra completa. Si se quieren reactivar,
//                  envolver el loop con preserve/keep if/restore.
//
// Depends        : _utils/prg_load_panel.do
//                  _utils/prg_table_3panels.do  (define _fmt_*)
//                  _utils/prg_table_2panels.do
//                  _utils/fix_table_borders.ps1 (invocado por el programa)
// Input          : Out/5_BDs por grupos de vars/BPAs_CondyNoCond_LByLS.dta (outcome_file)
//                  Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta,
//                  Sociodem_Prod_JH_LB.dta, Viv_Act_SEA_LB.dta,
//                  Demog_Ing_Hog_LB.dta, Productor_Predio_LB.dta (vía prg_load_panel)
// Output         : Tablas/2_Prácticas_Agronómicas/Anexo/B-2-<k>_Tab_BPA_<var>.docx (×23)
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
cap erase "${ruta_scripts}\G3_estimate_bpa_cond.log"
log using "${ruta_logs}\G3_estimate_bpa_cond.log", replace text

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
	outcome_vars(bpa_10_1-bpa_10_5 bpa_11_1-bpa_11_5 bpa_12_1-bpa_12_4 bpa_12_q_1-bpa_12_q_7 bpa_13_1 bpa_14_1) ///
	extra_vars(i1aECA_PE_ccpp ptcp_ECA_prod)

//------------------------------------------------------------------------------
// 2. Construir D_c y P_i (definiciones operacionales)
//------------------------------------------------------------------------------
gen byte D_c = (i1aECA_PE_ccpp == 1) if !mi(asig_ccpp)
gen byte P_i = (ptcp_ECA_prod  == 1) if !mi(asig_ccpp)

//------------------------------------------------------------------------------
// 3. Generar las 23 tablas anexas en 6 bloques (numeración continúa desde G2)
//------------------------------------------------------------------------------

local outdir "${ruta_tablas}/2_Prácticas_Agronómicas/Anexo"

// El calificador de cada sub-práctica se declara indexado por variable, no en
// una lista paralela recorrida con `gettoken'. Emparejados solo por POSICIÓN,
// insertar o reordenar una sub-práctica desplazaba todos los calificadores
// siguientes y las tablas salían con el paréntesis de la variable vecina.
local q_bpa_10_1 "cantidad necesaria"
local q_bpa_10_2 "buena calidad"
local q_bpa_10_3 "recomendación de especialista"
local q_bpa_10_4 "dosis recomendada"
local q_bpa_10_5 "almacenamiento adecuado"

local q_bpa_11_1 "cantidad necesaria"
local q_bpa_11_2 "buena calidad"
local q_bpa_11_3 "recomendación de especialista"
local q_bpa_11_4 "dosis recomendada"
local q_bpa_11_5 "almacenamiento adecuado"

local q_bpa_12_1 "cantidad necesaria"
local q_bpa_12_2 "buena calidad"
local q_bpa_12_3 "recomendación de especialista"
local q_bpa_12_4 "uso específico de plaguicida químico"

local q_bpa_12_q_1 "etiqueta visible en el envase"
local q_bpa_12_q_2 "lectura de la información del envase"
local q_bpa_12_q_3 "dosis recomendada"
local q_bpa_12_q_4 "cultivo indicado en el envase"
local q_bpa_12_q_5 "cumplimiento del periodo de carencia"
local q_bpa_12_q_6 "almacenamiento adecuado"
local q_bpa_12_q_7 "uso de equipo de protección"

// Convención de redacción: cada bloque comparte la misma frase nominal del
// título (`phrase`) — el sub-práctica específica entra como `outcome_qualifier`
// entre paréntesis. Esto evita repetir "el uso adecuado de abonos:" en el
// label y produce títulos fluidos como "...sobre el uso adecuado de abonos
// (dosis recomendada)".

// --- Cond. al uso de abono: bpa_10_1..bpa_10_5 → A-2-15..19 ---
// Condicionamiento histórico: bpa_10==1 (comentado; estima sobre muestra completa).
// Para reactivar: envolver con `preserve` / `keep if bpa_10==1` / `restore`.
local p_abono "el uso adecuado de abonos"
forvalues k = 1/5 {
	local var bpa_10_`k'
	local q "`q_`var''"
	if "`q'" == "" {
		di as error `"Falta el calificador de `var' (local q_`var')."'
		exit 198
	}
	local idx = 14 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_abono'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
}

// --- Cond. al uso de fertilizantes: bpa_11_1..bpa_11_5 → A-2-20..24 ---
local p_fert "el uso adecuado de fertilizantes"
forvalues k = 1/5 {
	local var bpa_11_`k'
	local q "`q_`var''"
	if "`q'" == "" {
		di as error `"Falta el calificador de `var' (local q_`var')."'
		exit 198
	}
	local idx = 19 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_fert'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
}

// --- Cond. al uso de plaguicidas (general): bpa_12_1..bpa_12_4 → A-2-25..28 ---
local p_plag "el uso adecuado de plaguicidas"
forvalues k = 1/4 {
	local var bpa_12_`k'
	local q "`q_`var''"
	if "`q'" == "" {
		di as error `"Falta el calificador de `var' (local q_`var')."'
		exit 198
	}
	local idx = 24 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_plag'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
}

// --- Cond. al uso de plaguicidas químicos: bpa_12_q_1..bpa_12_q_7 → A-2-29..35 ---
// Condicionamiento histórico: bpa_12_4==1 (comentado; estima sobre muestra completa).
local p_plagq "el uso seguro de plaguicidas químicos"
forvalues k = 1/7 {
	local var bpa_12_q_`k'
	local q "`q_`var''"
	if "`q'" == "" {
		di as error `"Falta el calificador de `var' (local q_`var')."'
		exit 198
	}
	local idx = 28 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_plagq'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
}

// --- Cond. al control biológico: bpa_13_1 → A-2-36 ---
prg_table_2panels, ///
	outcome(bpa_13_1) outcome_phrase("la evaluación previa de plagas para definir el control biológico") ///
	table_num("B.2-36") ///
	out("`outdir'/B-2-36_Tab_BPA_bpa_13_1.docx") ///
	z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
	controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)

// --- Cond. al uso de MIP: bpa_14_1 → A-2-37 ---
prg_table_2panels, ///
	outcome(bpa_14_1) outcome_phrase("la combinación de tipos de control de plagas (MIP)") ///
	table_num("B.2-37") ///
	out("`outdir'/B-2-37_Tab_BPA_bpa_14_1.docx") ///
	z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
	controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)

log close