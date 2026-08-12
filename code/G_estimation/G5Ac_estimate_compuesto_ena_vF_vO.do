//------------------------------------------------------------------------------
// File           : G5Ac_estimate_compuesto_ena_vF_vO.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 25/05/2026
// Description    : Genera las tablas del indicador COMPUESTO ENA agregado
//                  (síntesis que combina los 7 sub-indicadores ENA cubiertos
//                  por G5Aa/G5Ab a nivel desagregado). Definición de E10:
//                  implementa_bpa_ena_v{O,F} = al menos 2 de 3 pilares ENA
//                  (agronómico, insumos, inocuidad) iguales a 1, condicional
//                  a los 3 pilares no-missing.
//                  Tres tablas:
//                    - vO cuerpo (catálogo Ind. ENA 2479/2486/2743/2744) →
//                      3-paneles (F-U/DiD/LATE), numeración 8.2-8.
//                    - vO anexo HetEff por cultivo principal → 2-paneles
//                      saturado con efectos por cultivo, numeración A-7.
//                    - vF anexo (Flexible) → 2-paneles con controles
//                      (4 specs), numeración A-4. Lleva prefijo "Robustez."
//                      porque es la versión alternativa de la del cuerpo.
//                  La versión vE (Estricta) queda fuera por la misma razón
//                  que en G5Ab: pilares vE no estimables (mayoría de
//                  sub-prácticas constantes en 0).
//                  Flujo: (1) carga vía prg_load_panel; (2) construye D_c y
//                  P_i; (3) invoca prg_table_3panels (vO cuerpo), luego
//                  prg_table_3way_het (vO het) y prg_table_2panels (vF anexo).
//
// Output         : Tablas/4_Indicadores_Compuestos_BPAs/8.2-8_Tab_Comp_ENA_vO.docx
//                  Anexos/Indicadores_Compuestos_BPAs/B-1-7_Tab_Comp_ENA_vO_het.docx
//                  Anexos/Indicadores_Compuestos_BPAs/B-4-1_Tab_Comp_ENA_vF.docx
// Depends        : _helpers/prg_load_panel.do
//                  _helpers/prg_table_3panels.do
//                  _helpers/prg_table_3way_het.do
//                  _helpers/prg_table_2panels.do
//                  _helpers/fix_table_borders.ps1 (invocado por los programas)
//------------------------------------------------------------------------------

version 19.0

cls

// Bootstrap del entorno
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

// Redirige el log de stata-batch a 3_Logs/
cap log close
cap erase "${ruta_scripts}\G5Ac_estimate_compuesto_ena_vF_vO.log"
log using "${ruta_logs}\G5Ac_estimate_compuesto_ena_vF_vO.log", replace text


// Cargar programas
qui do "${ruta_helpers}/prg_load_panel.do"
qui do "${ruta_helpers}/prg_table_3panels.do"
qui do "${ruta_helpers}/prg_table_3way_het.do"
qui do "${ruta_helpers}/prg_table_2panels.do"

//------------------------------------------------------------------------------
// 1. Cargar la base maestra + outcomes (vO y vF en paralelo)
//------------------------------------------------------------------------------
prg_load_panel, ///
	outcome_file("BPAs_Compuestos_LByLS") ///
	outcome_vars(implementa_bpa_ena_vO implementa_bpa_ena_vF) ///
	extra_vars(i1aECA_PE_ccpp ptcp_ECA_prod)

//------------------------------------------------------------------------------
// 2. Construir D_c y P_i (definiciones operacionales, idem G5Aa/G5Ab)
//------------------------------------------------------------------------------
gen byte D_c = (i1aECA_PE_ccpp == 1) if !mi(asig_ccpp)
gen byte P_i = (ptcp_ECA_prod  == 1) if !mi(asig_ccpp)

//------------------------------------------------------------------------------
// 3. Labels amigables — sirven como encabezados de columna. El título y la
//    nota se redactan vía outcome_phrase/outcome_qualifier.
//------------------------------------------------------------------------------
lab var implementa_bpa_ena_vO "Compuesto ENA — Original"
lab var implementa_bpa_ena_vF "Compuesto ENA — Flexible"

//------------------------------------------------------------------------------
// 4. Estimar tabla del cuerpo (vO, 3-paneles, F-U/DiD/LATE)
//------------------------------------------------------------------------------
local ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

local phrase_comp "el cumplimiento agregado del catálogo ENA de BPAs"
local extra_comp  "La construcción del indicador exige cumplir al menos 2 de los 3 pilares ENA — agronómico, insumos e inocuidad."

prg_table_3panels, ///
	outcome(implementa_bpa_ena_vO) ///
	outcome_phrase("`phrase_comp'") ///
	outcome_qualifier("indicador compuesto ENA") ///
	note_extra("`extra_comp'") ///
	table_num("8.2-8") ///
	out("${ruta_tablas}/4_Indicadores_Compuestos_BPAs/8.2-8_Tab_Comp_ENA_vO.docx") ///
	z_var(asig_ccpp) ///
	dc_var(D_c) ///
	pi_var(P_i) ///
	post_var(post) ///
	controls("`ctrl_set'") ///
	absorb(cod_rgn_PE) ///
	cluster(cod_cpb)

//------------------------------------------------------------------------------
// 5. Estimar tabla anexa HetEff por cultivo (vO, modelo saturado)
//------------------------------------------------------------------------------
prg_table_3way_het, ///
	outcome(implementa_bpa_ena_vO) ///
	outcome_phrase("`phrase_comp'") ///
	outcome_qualifier("indicador compuesto ENA") ///
	note_extra("`extra_comp'") ///
	table_num("B.1-7") ///
	out("${ruta_anexos}/Indicadores_Compuestos_BPAs/B-1-7_Tab_Comp_ENA_vO_het.docx") ///
	z_var(asig_ccpp) ///
	dc_var(D_c) ///
	pi_var(P_i) ///
	post_var(post) ///
	controls("`ctrl_set'") ///
	absorb(cod_rgn_PE) ///
	cluster(cod_cpb) ///
	het_var(prod_ECA_eval) ///
	het_levels(26 16 19) ///
	het_labels("Cítrico|Papa|Plátano") ///
	het_panel_phrase("cultivos de") ///
	het_short("cultivo")

//------------------------------------------------------------------------------
// 6. Estimar tabla anexa (vF, 2-paneles, con `robustez`)
//------------------------------------------------------------------------------
prg_table_2panels, ///
	outcome(implementa_bpa_ena_vF) ///
	outcome_phrase("`phrase_comp'") ///
	outcome_qualifier("definición flexible") ///
	note_extra("`extra_comp'") ///
	robustez ///
	table_num("B.4-1") ///
	out("${ruta_anexos}/Indicadores_Compuestos_BPAs/B-4-1_Tab_Comp_ENA_vF.docx") ///
	z_var(asig_ccpp) ///
	dc_var(D_c) ///
	pi_var(P_i) ///
	post_var(post) ///
	controls("`ctrl_set'") ///
	absorb(cod_rgn_PE) ///
	cluster(cod_cpb)

log close
