//------------------------------------------------------------------------------
// File           : G5Ab_estimate_subind_ena_vF.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 25/05/2026
// Description    : Genera tablas anexas con estimaciones ITT en formato de 2
//                  paneles (Estimaciones / Descriptivos) para los 7 sub-
//                  indicadores ENA de BPAs en su versión vF (Flexible:
//                  >=N de M sub-prácticas). Estas tablas complementan a G5Aa
//                  (versión vO en la sección principal) como anexos de
//                  robustez.
//                  La versión vE (Estricta: AND de todas las sub-prácticas)
//                  no se genera: en la muestra analítica, 5 de 7 sub-ind.
//                  tienen tasas de éxito <1% (riego_vE es perfectamente
//                  constante en 0), lo que hace las estimaciones no
//                  estimables o sin poder. Ver diagnóstico en log del
//                  2026-05-21.
//                  Flujo: (1) carga vía prg_load_panel; (2) construye D_c y
//                  P_i de forma explícita; (3) declara los labels amigables
//                  del paper una sola vez con `lab var` (single source of
//                  truth — sobreescribe los labels técnicos de E10); (4)
//                  itera con `forvalues k` invocando prg_table_2panels.
//
// Output         : Anexos/Indicadores_Compuestos_BPAs/B-4-<k+1>_Tab_SubInd_<stub>_vF.docx (×7)
// Depends        : _helpers/prg_load_panel.do
//                  _helpers/prg_table_3panels.do   (carga los helpers _fmt_*)
//                  _helpers/prg_table_2panels.do
//                  _helpers/fix_table_borders.ps1  (invocado por el programa)
//------------------------------------------------------------------------------

version 19.0

cls

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
cap erase "${ruta_scripts}\G5Ab_estimate_subind_ena_vF.log"
log using "${ruta_logs}\G5Ab_estimate_subind_ena_vF.log", replace text


// Cargar los programas (ruta_helpers es GLOBAL definido por A_master.do)
qui do "${ruta_helpers}/prg_load_panel.do"
qui do "${ruta_helpers}/prg_table_3panels.do"  // helpers _fmt_b, _fmt_se, _fmt_N, _fmt_F
qui do "${ruta_helpers}/prg_table_2panels.do"

//------------------------------------------------------------------------------
// 1. Cargar la base maestra + outcomes vF + vars crudas para D_c/P_i
//------------------------------------------------------------------------------
prg_load_panel, ///
	outcome_file("BPAs_Compuestos_LByLS") ///
	outcome_vars(bpa_ena_*_vF) ///
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
// 3. Label update — single source of truth para los 7 outcomes
//    Los labels técnicos de E10 ("BPA riego (>=2 de 5 practicas) - Flexible")
//    no son apropiados para títulos del paper. Aquí declaramos los amigables
//    una sola vez por sub-indicador. El loop los lee con `: variable label`
//    (no se mantiene una lista paralela).
//------------------------------------------------------------------------------
lab var bpa_ena_riego_vF      "Prácticas adecuadas de riego"
lab var bpa_ena_suelo_vF      "Prácticas contra la degradación del suelo"
lab var bpa_ena_fert_abo_vF   "Uso de Fert./Abo. adecuado"
lab var bpa_ena_plag_vF       "Uso de Plag. adecuado"
lab var bpa_ena_biocontrol_vF "Control biológico adecuado"
lab var bpa_ena_mip_vF        "Manejo Integrado de Plagas adecuado"
lab var bpa_ena_inoc_vF       "Buenas Prácticas de Inocuidad"

//------------------------------------------------------------------------------
// 4. Generar las 7 tablas anexas en un loop sobre los sub-indicadores
//------------------------------------------------------------------------------
// Insumos fijos (no varían entre outcomes)
local ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

// vF se reporta en el bloque A-5 de los Anexos. La tabla LLEVA "Robustez. "
// en el título porque es la versión alternativa (flexible) del outcome que
// vive en el cuerpo principal (G5Aa, versión Original).
local stubs    riego suelo fert_abo plag biocontrol mip inoc
local phrases  `" "la adopción de prácticas adecuadas de riego" "la adopción de prácticas contra la degradación del suelo" "el uso adecuado de fertilizantes y abonos" "el uso adecuado de plaguicidas" "la adopción de control biológico" "la adopción de Manejo Integrado de Plagas" "la adopción de buenas prácticas de inocuidad" "'

forvalues k = 1/7 {
	gettoken stub   stubs   : stubs
	gettoken phrase phrases : phrases
	local var bpa_ena_`stub'_vF

	// El sub-indicador de riego se define solo para productores con riego
	// tecnificado (E10); la estimación queda restringida a esa submuestra.
	// Se añade al calificador y a la nota, coherente con G2.
	local qual "definición flexible"
	local extra_opt ""
	if "`stub'" == "riego" {
		local qual "definición flexible; submuestra: riego tecnificado"
		local extra_opt `"note_extra("La submuestra se limita a productores con riego tecnificado en la parcela principal de línea base; el resto queda excluido por definición del sub-indicador.")"'
	}

	// Numeración visible según el Anexo B del reporte: B.4-2..B.4-8
	// (B.4-1 es el compuesto agregado vF, producido por G5Ac).
	local bnum = `k' + 1
	prg_table_2panels, ///
		outcome(`var') ///
		outcome_phrase("`phrase'") ///
		outcome_qualifier("`qual'") ///
		`extra_opt' ///
		robustez ///
		table_num("B.4-`bnum'") ///
		out("${ruta_anexos}/Indicadores_Compuestos_BPAs/B-4-`bnum'_Tab_SubInd_`stub'_vF.docx") ///
		z_var(asig_ccpp) ///
		dc_var(D_c) ///
		pi_var(P_i) ///
		post_var(post) ///
		controls("`ctrl_set'") ///
		absorb(cod_rgn_PE) ///
		cluster(cod_cpb)
}

log close
