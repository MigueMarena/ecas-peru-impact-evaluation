//------------------------------------------------------------------------------
// File           : run_all.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 12/08/2026
// Description    : Orquestador del pipeline. Corre las fases en orden, de la
//                  ingesta de las encuestas hasta la compilación del reporte.
//
//                  Uso:
//                    do run_all.do              // todo el pipeline
//                    do run_all.do build        // solo una fase
//                    do run_all.do "build estimation"
//
//                  Fases: ingest treatment merge build estimation reporting
//                         diagnostics
//
//                  Este archivo, y no A_master.do, es el que sabe el orden de
//                  ejecución. A_master.do define el entorno y es seguro de
//                  `include`; si el orden viviera ahí, los 35 scripts que le
//                  hacen `include` dispararían recursión infinita.
//
// Depends        : A_master.do (entorno)
// Input          : ver cada script de fase
// Output         : ver cada script de fase
//------------------------------------------------------------------------------

version 19.0
clear all

//==============================================================================
// Step 1: Entorno
//==============================================================================
// A_master.do resuelve ${ECAS} (la raíz del repositorio) y define las rutas.
capture qui include "${ECAS}/2_Scripts/A_setup/A_master.do"
if _rc capture qui include "2_Scripts/A_setup/A_master.do"
if "${ruta_data}" == "" {
	di as error "No encuentro A_master.do. Definí la global ECAS con la ruta a"
	di as error "la raíz del repositorio, o corré Stata desde esa raíz."
	exit 601
}

// El log del orquestador va en un CANAL con nombre. Cada script del pipeline
// abre el suyo con `log using` sin nombre y lo cierra con `cap log close`, así
// que un log anónimo acá quedaría secuestrado por el primer script y el
// orquestador perdería el rastro de qué fase falló — que es justo lo que hay
// que ver cuando algo se rompe.
cap log close _all
log using "${ruta_logs}/run_all.log", replace text name(runall)

//==============================================================================
// Step 2: Qué fases correr
//==============================================================================
local fases_pedidas `0'
if `"`fases_pedidas'"' == "" {
	local fases_pedidas "ingest treatment merge build estimation reporting diagnostics"
}

di as text _n "{hline 78}"
di as text "run_all.do — fases a ejecutar: `fases_pedidas'"
di as text "raíz del proyecto: ${ECAS}"
di as text "{hline 78}" _n

//==============================================================================
// Step 3: Definición de cada fase
//==============================================================================
local f_ingest      B1_ingest_copy_files B2_clean_survey_modules
local f_treatment   C1_make_treated_producers C2_make_ccpp_assignment
local f_merge       D_merge_panels
local f_build       E1_build_obs_chars E2_build_producer_sociodem       ///
                    E3_build_household E4_build_crops E5_build_farm     ///
                    E6_build_bpa_knowledge E7_build_bpa_practices       ///
                    E8_build_records_storage E9_build_food_safety       ///
                    E10_build_composite_bpas
// La fase `validation' (F) quedó vacía el 2026-08-12: F1_test_balance.do se
// movió a Trash porque su tabla no está en el reporte —lo que el reporte cita
// es la Figura 6.1-1, que produce I6— y su función quedó cubierta por I4, I5 e
// I6. La letra F se reserva por si vuelve a haber validación previa a estimar.
local f_estimation  G1_estimate_knowledge_scores G2_estimate_bpa_uncond ///
                    G3_estimate_bpa_cond G4_estimate_records_safety     ///
                    G5Aa_estimate_subind_ena_vO                         ///
                    G5Ab_estimate_subind_ena_vF                         ///
                    G5Ac_estimate_compuesto_ena_vF_vO
local f_diagnostics I1_summary_consort I3_summary_cluster               ///
                    I4_balance_prod_cluster I5_balance_covariates       ///
                    I6_loveplot I7A_summary_cluster_size                ///
                    I7B_summary_deff_outcomes I8_balance_attrition      ///
                    I9_summary_takeup I10_summary_intensity             ///
                    I11_robust_timing
// H1 va al final de todo: consolida las secciones .docx ya terminadas.
// H2_plot_yield_outliers.do se retiró el 2026-08-12: sus 50 gráficos Q-Q por
// cultivo no aparecen en el reporte (que no menciona Q-Q ni cuantiles) y eran
// en su mayoría de cultivos ajenos a los tres del estudio.
local f_reporting   H1_report_compile

//==============================================================================
// Step 4: Ejecución
//==============================================================================
local t_inicio = c(current_time)

foreach fase of local fases_pedidas {
	local scripts : copy local f_`fase'
	if `"`scripts'"' == "" {
		di as error "Fase desconocida: `fase'"
		exit 198
	}

	di as text _n "{hline 78}"
	di as text "FASE: `fase'"
	di as text "{hline 78}"

	// Cada fase vive en su propia subcarpeta. Las globals ${ruta_<fase>} las
	// define A_master.do (Step 2) con el mismo nombre que la fase, así que
	// resuelven directo.
	local carpeta "${ruta_`fase'}"

	foreach s of local scripts {
		local t0 = clock(c(current_time), "hms")
		di as text _n ">>> `s'.do"

		capture noisily do "`carpeta'/`s'.do"
		if _rc {
			di as error _n "El pipeline se detuvo en `s'.do (r(" _rc "))."
			di as error "Revisá ${ruta_logs}/`s'.log."
			cap log close runall
			exit _rc
		}

		local t1 = clock(c(current_time), "hms")
		di as text "    ok — " %6.1f (`t1'-`t0')/1000 " segundos"
	}
}

// El diagnóstico CONSORT necesita Python; queda fuera del loop porque no es un
// .do y su fallo no debe detener el pipeline (solo produce una figura).
if strpos("`fases_pedidas'", "diagnostics") {
	di as text _n ">>> I2_graph_consort.py"
	capture shell python "${ruta_diagnostics}/I2_graph_consort.py"
	if _rc di as error "    I2_graph_consort.py falló (r(" _rc ")); se continúa."
}

di as text _n "{hline 78}"
di as text "Pipeline completo. Inicio `t_inicio' — fin " c(current_time)
di as text "{hline 78}"

cap log close runall
