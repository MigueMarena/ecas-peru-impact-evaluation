//------------------------------------------------------------------------------
// File           : G5Aa_estimate_subind_ena_vO.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 25/05/2026
// Description    : Genera tablas con estimaciones ITT en formato de 3 paneles
//                  (F-U / DiD / LATE) para los 7 sub-indicadores ENA de BPAs
//                  en su versión vO (Grupo 2 - Criterios Equilibrados, catálogo
//                  ENA): riego, suelo, fert_abo, plag, biocontrol, mip, inoc.
//                  Flujo: (1) carga la base maestra vía prg_load_panel,
//                  (2) construye las definiciones operacionales D_c y P_i de
//                  forma explícita (decisión metodológica visible),
//                  (3) declara los labels amigables del paper con `lab var`
//                  (single source of truth — sobreescribe los técnicos de E10),
//                  y (4) invoca prg_table_3panels en un loop que lee el label
//                  con `: variable label`.
//                  Complementario a G5Ab_estimate_subind_ena_vF.do, que cubre
//                  la versión vF como robustez en formato 2-paneles para
//                  anexo.
//
// Output         : Tablas/4_Indicadores_Compuestos_BPAs/8.2-<k>_Tab_SubInd_<stub>_vO.docx (×7)
//                  Anexos/Indicadores_Compuestos_BPAs/B-1-<k-1>_Tab_SubInd_<stub>_vO_het.docx (×6;
//                  riego omitido: HetEff por cultivo no estimable en la
//                  submuestra de riego tecnificado, ver nota en el loop)
// Depends        : _helpers/prg_load_panel.do
//                  _helpers/prg_table_3panels.do
//                  _helpers/prg_table_3way_het.do
//                  _helpers/fix_table_borders.ps1 (invocado por los programas)
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
cap erase "${ruta_scripts}\G5Aa_estimate_subind_ena_vO.log"
log using "${ruta_logs}\G5Aa_estimate_subind_ena_vO.log", replace text


// Cargar los programas (ruta_helpers es GLOBAL definido por A_master.do)
qui do "${ruta_helpers}/prg_load_panel.do"
qui do "${ruta_helpers}/prg_table_3panels.do"
qui do "${ruta_helpers}/prg_table_3way_het.do"

//------------------------------------------------------------------------------
// 1. Cargar la base maestra + outcome + vars crudas para D_c/P_i
//------------------------------------------------------------------------------
prg_load_panel, ///
	outcome_file("BPAs_Compuestos_LByLS") ///
	outcome_vars(bpa_ena_*_vO) ///
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
// 3. Label update (versión ENA — vO)
//------------------------------------------------------------------------------
lab var bpa_ena_riego_vO        "Prácticas adecuadas de riego"
lab var bpa_ena_suelo_vO        "Prácticas contra la degradación del suelo"
lab var bpa_ena_fert_abo_vO     "Uso de Fert./Abo. adecuado"
lab var bpa_ena_plag_vO         "Uso de Plag. adecuado"
lab var bpa_ena_biocontrol_vO   "Control biológico adecuado"
lab var bpa_ena_mip_vO          "Manejo Integrado de Plagas adecuado"
lab var bpa_ena_inoc_vO         "Buenas Prácticas de Inocuidad"

//------------------------------------------------------------------------------
// 4. Generar las 7 tablas de sub-indicadores ENA (vO) en un loop
//------------------------------------------------------------------------------
// Set de controles unificado (no varía entre outcomes ni entre helpers).
// Prefijos c./i. explícitos: areg/ivregress los aceptan nativo y
// prg_table_3way_het los reusa directamente para saturar como `tok'#ibn.`het_var'.
local ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

// Loop sobre los 7 sub-indicadores ENA en vO. El label de variable se usa
// como encabezado de columna; la frase del título y la nota se redacta
// explícitamente vía `outcome_phrase' (no se hereda del label).
local stubs    riego suelo fert_abo plag biocontrol mip inoc
local phrases  `" "la adopción de prácticas adecuadas de riego" "la adopción de prácticas contra la degradación del suelo" "el uso adecuado de fertilizantes y abonos" "el uso adecuado de plaguicidas" "la adopción de control biológico" "la adopción de Manejo Integrado de Plagas" "la adopción de buenas prácticas de inocuidad" "'

forvalues k = 1/7 {
	gettoken stub   stubs   : stubs
	gettoken phrase phrases : phrases
	local var bpa_ena_`stub'_vO

	// El sub-indicador de riego se define solo para productores con riego
	// tecnificado (E10); la estimación queda restringida a esa submuestra.
	// Se declara como calificador para que título y nota lo reflejen,
	// coherente con el análisis a nivel de pregunta (G2).
	local qual_opt  ""
	local extra_opt ""
	if "`stub'" == "riego" {
		local qual_opt  `"outcome_qualifier("submuestra: riego tecnificado")"'
		local extra_opt `"note_extra("La submuestra se limita a productores con riego tecnificado en la parcela principal de línea base; el resto queda excluido por definición del sub-indicador.")"'
	}

	// Tabla cuerpo: 3 paneles (F-U / DiD / LATE), numeración 8.2-k
	prg_table_3panels, ///
		outcome(`var') ///
		outcome_phrase("`phrase'") ///
		`qual_opt' `extra_opt' ///
		table_num("8.2-`k'") ///
		out("${ruta_tablas}/4_Indicadores_Compuestos_BPAs/8.2-`k'_Tab_SubInd_`stub'_vO.docx") ///
		z_var(asig_ccpp) ///
		dc_var(D_c) ///
		pi_var(P_i) ///
		post_var(post) ///
		controls("`ctrl_set'") ///
		absorb(cod_rgn_PE) ///
		cluster(cod_cpb)

	// El HetEff por cultivo del sub-indicador de riego NO es estimable: al
	// restringirse a la submuestra con riego tecnificado (~180 obs, ~5% de
	// éxito) y saturar el modelo IV por cultivo, la primera etapa LATE queda
	// no identificada ("equation not identified"). Se omite la tabla (sería B-1-0); la
	// tabla cuerpo 8.2-1 (sin desglose por cultivo) sí corre y se conserva.
	if "`stub'" == "riego" continue

	// Tabla anexa HetEff: efectos heterogéneos por cultivo. La numeración
	// visible sigue el esquema del Anexo B del reporte (B.1-1..B.1-6);
	// como riego (k=1) se omite, el correlativo es k-1 y no deja hueco.
	local bnum = `k' - 1
	prg_table_3way_het, ///
		outcome(`var') ///
		outcome_phrase("`phrase'") ///
		`qual_opt' `extra_opt' ///
		table_num("B.1-`bnum'") ///
		out("${ruta_anexos}/Indicadores_Compuestos_BPAs/B-1-`bnum'_Tab_SubInd_`stub'_vO_het.docx") ///
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
}

log close
