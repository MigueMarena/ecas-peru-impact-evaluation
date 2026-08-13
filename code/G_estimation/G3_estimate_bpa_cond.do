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
// Output         : Tablas/2_Prácticas_Agronómicas/Anexo/B-2-<k>_Tab_BPA_<var>.docx (×23)
// Depends        : _utils/prg_load_panel.do
//                  _utils/prg_table_3panels.do  (define _fmt_*)
//                  _utils/prg_table_2panels.do
//                  _utils/fix_table_borders.ps1 (invocado por el programa)
//------------------------------------------------------------------------------

version 19.0

cls

// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
if "${ruta_data}" == "" {
	capture qui include "${ECAS}/2_Scripts/A_setup/A_master.do"
	if _rc capture qui include "2_Scripts/A_setup/A_master.do"
	if "${ruta_data}" == "" {
		di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
		di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
		exit 601
	}
}

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\G3_estimate_bpa_cond.log"
log using "${ruta_logs}\G3_estimate_bpa_cond.log", replace text


// Cargar programas (prg_table_3panels primero porque define _fmt_*)
qui do "${ruta_utils}/prg_load_panel.do"
qui do "${ruta_utils}/prg_table_3panels.do"
qui do "${ruta_utils}/prg_table_2panels.do"

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
// 3. Labels amigables — single source of truth
//------------------------------------------------------------------------------
lab var bpa_10_1 "Abonos: usaron lo necesario"
lab var bpa_10_2 "Abonos: de buena calidad"
lab var bpa_10_3 "Abonos: recomendado por especialista"
lab var bpa_10_4 "Abonos: dosis recomendada"
lab var bpa_10_5 "Abonos: almacenamiento adecuado"

lab var bpa_11_1 "Fertilizantes: usaron lo necesario"
lab var bpa_11_2 "Fertilizantes: de buena calidad"
lab var bpa_11_3 "Fertilizantes: recomendado por especialista"
lab var bpa_11_4 "Fertilizantes: dosis recomendada"
lab var bpa_11_5 "Fertilizantes: almacenamiento adecuado"

lab var bpa_12_1 "Plaguicidas: usaron lo necesario"
lab var bpa_12_2 "Plaguicidas: de buena calidad"
lab var bpa_12_3 "Plaguicidas: recomendado por especialista"
lab var bpa_12_4 "Plaguicidas: usaron plaguicida químico"

lab var bpa_12_q_1 "Plag. químico: tiene etiqueta en envase"
lab var bpa_12_q_2 "Plag. químico: leyeron info en envase"
lab var bpa_12_q_3 "Plag. químico: dosis recomendada"
lab var bpa_12_q_4 "Plag. químico: cultivo indicado en envase"
lab var bpa_12_q_5 "Plag. químico: cumplieron carencia"
lab var bpa_12_q_6 "Plag. químico: almacenam. adecuado"
lab var bpa_12_q_7 "Plag. químico: usaron protección"

lab var bpa_13_1 "Evaluación de plagas para control biológico"
lab var bpa_14_1 "Combinaron tipos de control de plagas"

//------------------------------------------------------------------------------
// 4. Generar las 23 tablas anexas en 6 bloques (numeración continúa desde G2)
//------------------------------------------------------------------------------
local ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

local outdir "${ruta_tablas}/2_Prácticas_Agronómicas/Anexo"

// Convención de redacción: cada bloque comparte la misma frase nominal del
// título (`phrase`) — el sub-práctica específica entra como `outcome_qualifier`
// entre paréntesis. Esto evita repetir "el uso adecuado de abonos:" en el
// label y produce títulos fluidos como "...sobre el uso adecuado de abonos
// (dosis recomendada)".

// --- Cond. al uso de abono: bpa_10_1..bpa_10_5 → A-2-15..19 ---
// Condicionamiento histórico: bpa_10==1 (comentado; estima sobre muestra completa).
// Para reactivar: envolver con `preserve` / `keep if bpa_10==1` / `restore`.
local p_abono "el uso adecuado de abonos"
local q_abono `" "cantidad necesaria" "buena calidad" "recomendación de especialista" "dosis recomendada" "almacenamiento adecuado" "'
forvalues k = 1/5 {
	gettoken q q_abono : q_abono
	local var bpa_10_`k'
	local idx = 14 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_abono'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
}

// --- Cond. al uso de fertilizantes: bpa_11_1..bpa_11_5 → A-2-20..24 ---
local p_fert "el uso adecuado de fertilizantes"
local q_fert `" "cantidad necesaria" "buena calidad" "recomendación de especialista" "dosis recomendada" "almacenamiento adecuado" "'
forvalues k = 1/5 {
	gettoken q q_fert : q_fert
	local var bpa_11_`k'
	local idx = 19 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_fert'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
}

// --- Cond. al uso de plaguicidas (general): bpa_12_1..bpa_12_4 → A-2-25..28 ---
local p_plag "el uso adecuado de plaguicidas"
local q_plag `" "cantidad necesaria" "buena calidad" "recomendación de especialista" "uso específico de plaguicida químico" "'
forvalues k = 1/4 {
	gettoken q q_plag : q_plag
	local var bpa_12_`k'
	local idx = 24 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_plag'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
}

// --- Cond. al uso de plaguicidas químicos: bpa_12_q_1..bpa_12_q_7 → A-2-29..35 ---
// Condicionamiento histórico: bpa_12_4==1 (comentado; estima sobre muestra completa).
local p_plagq "el uso seguro de plaguicidas químicos"
local q_plagq `" "etiqueta visible en el envase" "lectura de la información del envase" "dosis recomendada" "cultivo indicado en el envase" "cumplimiento del periodo de carencia" "almacenamiento adecuado" "uso de equipo de protección" "'
forvalues k = 1/7 {
	gettoken q q_plagq : q_plagq
	local var bpa_12_q_`k'
	local idx = 28 + `k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`p_plagq'") outcome_qualifier("`q'") ///
		table_num("B.2-`idx'") ///
		out("`outdir'/B-2-`idx'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
}

// --- Cond. al control biológico: bpa_13_1 → A-2-36 ---
prg_table_2panels, ///
	outcome(bpa_13_1) outcome_phrase("la evaluación previa de plagas para definir el control biológico") ///
	table_num("B.2-36") ///
	out("`outdir'/B-2-36_Tab_BPA_bpa_13_1.docx") ///
	z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
	controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)

// --- Cond. al uso de MIP: bpa_14_1 → A-2-37 ---
prg_table_2panels, ///
	outcome(bpa_14_1) outcome_phrase("la combinación de tipos de control de plagas (MIP)") ///
	table_num("B.2-37") ///
	out("`outdir'/B-2-37_Tab_BPA_bpa_14_1.docx") ///
	z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
	controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)

log close
