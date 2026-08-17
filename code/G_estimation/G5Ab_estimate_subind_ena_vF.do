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
// Depends        : _utils/prg_load_panel.do
//                  _utils/prg_table_3panels.do   (carga los helpers _fmt_*)
//                  _utils/prg_table_2panels.do
//                  _utils/fix_table_borders.ps1  (invocado por el programa)
// Input          : Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta (outcome_file)
//                  Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta,
//                  Sociodem_Prod_JH_LB.dta, Viv_Act_SEA_LB.dta,
//                  Demog_Ing_Hog_LB.dta, Productor_Predio_LB.dta (vía prg_load_panel)
// Output         : Tablas/4_Indicadores_Compuestos_BPAs/Anexo/B-4-<k+1>_Tab_SubInd_<stub>_vF.docx (×7)
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
cap erase "${ruta_scripts}\G5Ab_estimate_subind_ena_vF.log"
log using "${ruta_logs}\G5Ab_estimate_subind_ena_vF.log", replace text

// Cargar los programas (ruta_utils es GLOBAL definido por config.do)
qui do "${ruta_utils}/prg_load_panel.do"
qui do "${ruta_utils}/prg_table_3panels.do"  // helpers _fmt_b, _fmt_se, _fmt_N, _fmt_F
qui do "${ruta_utils}/prg_table_2panels.do"
qui include "${ruta_setup}/spec.do"

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
// 3. Generar las 7 tablas anexas en un loop sobre los sub-indicadores
//------------------------------------------------------------------------------
// Insumos fijos (no varían entre outcomes)

// vF se reporta en el bloque A-5 de los Anexos. La tabla LLEVA "Robustez. "
// en el título porque es la versión alternativa (flexible) del outcome que
// vive en el cuerpo principal (G5Aa, versión Original).
// La frase del título se declara por sub-indicador, indexada por su stub.
// Antes iba en una lista paralela emparejada solo por POSICIÓN: insertar o
// reordenar un sub-indicador desplazaba todos los títulos siguientes sin aviso.
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
		out("${ruta_tablas}/4_Indicadores_Compuestos_BPAs/Anexo/B-4-`bnum'_Tab_SubInd_`stub'_vF.docx") ///
		z_var(asig_ccpp) ///
		dc_var(D_c) ///
		pi_var(P_i) ///
		post_var(post) ///
		controls("$ctrl_set") ///
		absorb($fe_estrato) ///
		cluster($cl_ccpp)
}

log close