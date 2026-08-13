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
//                  P_i; (3) declara labels amigables; (4) tres loops que
//                  invocan prg_table_2panels con `nosubtitle' (no son
//                  tablas vF — el sufijo "(criterio flexible)" no aplica).
//                  El loop de riego corre sobre la submuestra
//                  riego_tec_prod==1 vía preserve/keep/restore.
//
// Output         : Tablas/2_Prácticas_Agronómicas/Anexo/B-2-<k>_Tab_BPA_<var>.docx (×14)
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
cap erase "${ruta_scripts}\G2_estimate_bpa_uncond.log"
log using "${ruta_logs}\G2_estimate_bpa_uncond.log", replace text


// Cargar programas (prg_table_3panels primero porque define _fmt_*)
qui do "${ruta_utils}/prg_load_panel.do"
qui do "${ruta_utils}/prg_table_3panels.do"
qui do "${ruta_utils}/prg_table_2panels.do"

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
// 3. Labels amigables — single source of truth. El helper los lee con
//    `: variable label` para componer el título de la tabla.
//------------------------------------------------------------------------------
lab var bpa_1  "Análisis de suelo"
lab var bpa_2  "Suelo + materia orgánica"
lab var bpa_3  "Asociaron cultivos"
lab var bpa_4  "Surcos en contorno"
lab var bpa_5  "Demanda hídrica del cultivo"
lab var bpa_6  "Frecuencia de riego"
lab var bpa_7  "Volumen de agua aplicada"
lab var bpa_8  "Mantenim. sistema de riego"
lab var bpa_9  "Análisis de agua"
lab var bpa_10 "Uso de abonos"
lab var bpa_11 "Uso de fertilizantes"
lab var bpa_12 "Uso de plaguicidas"
lab var bpa_13 "Control biológico"
lab var bpa_14 "Manejo Integrado de Plagas"

//------------------------------------------------------------------------------
// 4. Generar las 14 tablas anexas en 3 bloques
//------------------------------------------------------------------------------
local ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

local outdir "${ruta_tablas}/2_Prácticas_Agronómicas/Anexo"

// --- BPA Suelo: bpa_1..bpa_4 (toda la muestra) ---
local phrases_suelo `" "la realización de análisis de suelo" "la incorporación de materia orgánica al suelo" "la asociación de cultivos" "la siembra en surcos a contorno" "'
forvalues k = 1/4 {
	gettoken phrase phrases_suelo : phrases_suelo
	local var bpa_`k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		table_num("B.2-`k'") ///
		out("`outdir'/B-2-`k'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
}

// --- BPA Riego: bpa_5..bpa_9 (submuestra: riego_tec_prod==1) ---
// Pasa outcome_qualifier corto + note_extra con el detalle de la submuestra,
// para mantener el título bajo 20 palabras y la definición operativa en la nota.
local phrases_riego `" "la estimación de la demanda hídrica del cultivo" "la programación de la frecuencia de riego" "el ajuste del volumen de agua aplicada" "el mantenimiento del sistema de riego" "la realización de análisis del agua de riego" "'
local q_riego     "submuestra: riego tecnificado"
local extra_riego "La submuestra incluye productores con al menos un predio bajo riego tecnificado."
preserve
keep if riego_tec_prod == 1
forvalues k = 5/9 {
	gettoken phrase phrases_riego : phrases_riego
	local var bpa_`k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		outcome_qualifier("`q_riego'") ///
		note_extra("`extra_riego'") ///
		table_num("B.2-`k'") ///
		out("`outdir'/B-2-`k'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
}
restore

// --- BPA Insumos: bpa_10..bpa_14 (toda la muestra) ---
local phrases_insumos `" "el uso de abonos" "el uso de fertilizantes" "el uso de plaguicidas" "la aplicación de control biológico" "la implementación de Manejo Integrado de Plagas" "'
forvalues k = 10/14 {
	gettoken phrase phrases_insumos : phrases_insumos
	local var bpa_`k'
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		table_num("B.2-`k'") ///
		out("`outdir'/B-2-`k'_Tab_BPA_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
}

log close
