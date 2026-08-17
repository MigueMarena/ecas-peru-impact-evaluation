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
// Depends        : _utils/prg_load_panel.do
//                  _utils/prg_table_3panels.do
//                  _utils/prg_table_3way_het.do
//                  _utils/fix_table_borders.ps1 (invocado por los programas)
// Input          : Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta (outcome_file)
//                  Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta,
//                  Sociodem_Prod_JH_LB.dta, Viv_Act_SEA_LB.dta,
//                  Demog_Ing_Hog_LB.dta, Productor_Predio_LB.dta (vía prg_load_panel)
// Output         : Tablas/4_Indicadores_Compuestos_BPAs/Cuerpo/8.2-<k>_Tab_SubInd_<stub>_vO.docx (×7)
//                  Tablas/4_Indicadores_Compuestos_BPAs/Anexo/B-1-<k-1>_Tab_SubInd_<stub>_vO_het.docx (×6;
//                  riego omitido: HetEff por cultivo no estimable en la
//                  submuestra de riego tecnificado, ver nota en el loop)
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
cap erase "${ruta_scripts}\G5Aa_estimate_subind_ena_vO.log"
log using "${ruta_logs}\G5Aa_estimate_subind_ena_vO.log", replace text

// Cargar los programas (ruta_utils es GLOBAL definido por config.do)
qui do "${ruta_utils}/prg_load_panel.do"
qui do "${ruta_utils}/prg_table_3panels.do"
qui do "${ruta_utils}/prg_table_3way_het.do"
qui include "${ruta_setup}/spec.do"

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
// 3. Generar las 7 tablas de sub-indicadores ENA (vO) en un loop
//------------------------------------------------------------------------------
// La frase del título y de la nota se declara por sub-indicador, indexada por
// su stub. Antes iban en una lista paralela recorrida con `gettoken', emparejada
// con los stubs solo por POSICIÓN: insertar o reordenar un sub-indicador sin
// tocar la otra lista desplazaba todos los títulos siguientes, y las tablas
// salían con el título de la variable vecina sin que nada avisara.
local stubs riego suelo fert_abo plag biocontrol mip inoc

local ph_riego      "la adopción de prácticas adecuadas de riego"
local ph_suelo      "la adopción de prácticas contra la degradación del suelo"
local ph_fert_abo   "el uso adecuado de fertilizantes y abonos"
local ph_plag       "el uso adecuado de plaguicidas"
local ph_biocontrol "la adopción de control biológico"
local ph_mip        "la adopción de Manejo Integrado de Plagas"
local ph_inoc       "la adopción de buenas prácticas de inocuidad"

local k = 0
foreach stub of local stubs {
	local ++k
	local phrase "`ph_`stub''"
	if "`phrase'" == "" {
		di as error "Falta la frase del título para el sub-indicador `stub'."
		di as error `"Declarala arriba como: local ph_`stub' "...""'
		exit 198
	}
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
		out("${ruta_tablas}/4_Indicadores_Compuestos_BPAs/Cuerpo/8.2-`k'_Tab_SubInd_`stub'_vO.docx") ///
		z_var(asig_ccpp) ///
		dc_var(D_c) ///
		pi_var(P_i) ///
		post_var(post) ///
		controls("$ctrl_set") ///
		absorb($fe_estrato) ///
		cluster($cl_ccpp)

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
		out("${ruta_tablas}/4_Indicadores_Compuestos_BPAs/Anexo/B-1-`bnum'_Tab_SubInd_`stub'_vO_het.docx") ///
		z_var(asig_ccpp) ///
		dc_var(D_c) ///
		pi_var(P_i) ///
		post_var(post) ///
		controls("$ctrl_set") ///
		absorb($fe_estrato) ///
		cluster($cl_ccpp) ///
		het_var(prod_ECA_eval) ///
		het_levels(26 16 19) ///
		het_labels("Cítrico|Papa|Plátano") ///
		het_panel_phrase("cultivos de") ///
		het_short("cultivo")
}

log close