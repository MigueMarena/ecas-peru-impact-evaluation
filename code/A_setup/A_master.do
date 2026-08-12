//------------------------------------------------------------------------------
// File             : A_master.do
// Author           : Carlos Marena
// Email            : carlosmarena1995@gmail.com
// Last Mod. Date   : 15/04/2026
// Description      : Script maestro que inicializa el entorno del
// proyecto. Define rutas de directorios globales y locales, crea la
// estructura de carpetas para datos crudos (Raw/) y procesados
// (Out/), y establece macros locales para referenciar bases de datos
// clave en las distintas etapas del procesamiento. Debe ejecutarse
// antes que cualquier otro script.
//------------------------------------------------------------------------------

//==============================================================================
// Step 1: Load personal profile
//==============================================================================
// Carga macros globales (ej. ${CONSULT})
qui do "C:\\Users\\carlo\\ado\\personal\\profile.do"

//==============================================================================
// Step 2: Set up absolute and relative paths
//==============================================================================
local hrn HRC0052956

// Ruta absoluta del proyecto
global ruta_abs "${CONSULT}\\BID\\`hrn'"

// Rutas relativas
global ruta_share   "${ruta_abs}\\0_1 Compartidos"
global ruta_data	"${ruta_abs}\\1_Data"	
global ruta_scripts "${ruta_abs}\\2_Scripts"
global ruta_logs	"${ruta_abs}\\3_Logs"
global ruta_trash   "${ruta_abs}\\4_Trash"
global ruta_deliv   "${ruta_abs}\\5_Entregables"

global ruta_images  "${ruta_deliv}\\Reporte Final_VPaper\\Imágenes"
global ruta_tablas  "${ruta_deliv}\\Reporte Final_VPaper\\Tablas"
global ruta_anexos	"${ruta_deliv}\\Reporte Final_VPaper\\Anexos"
global ruta_seccio  "${ruta_deliv}\\Reporte Final_VPaper\\Secciones"
global ruta_report  "${ruta_deliv}\\Reporte Final_VPaper\\Versiones"

global ruta_docum   "${ruta_share}\\01-CSD-RND\\CSD-RND_ECAs_documentacion"

// Ruta de scripts auxiliares (helpers)
global ruta_helpers "${ruta_scripts}\\_helpers"

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\A_master.log"
log using "${ruta_logs}\A_master.log", replace text


//==============================================================================
// Step 3: Create directory structure and define path references
//==============================================================================
local raw 	"${ruta_data}\\Raw"
local out	"${ruta_data}\\Out"

// Carpetas en Raw
cap mkdir "`raw'\\1_Encu Linea Base"
cap mkdir "`raw'\\2_Encu Linea Segui"
cap mkdir "`raw'\\3_Centros Poblados y su Estatus de Tratamiento"

// Carpetas en Out
cap mkdir "`out'\\1_Encu Linea Base"
cap mkdir "`out'\\2_Encu Linea Segui"
cap mkdir "`out'\\3_Centros Poblados y su Estatus de Tratamiento"
cap mkdir "`out'\\4_BDs Fusionadas"
cap mkdir "`out'\\5_BDs por grupos de vars"
cap mkdir "`out'\\6_Temporales"

// Referencias locales a subcarpetas
local c1 	"1_Encu Linea Base"
local c2 	"2_Encu Linea Segui"
local c3    "3_Centros Poblados y su Estatus de Tratamiento"
local c4 	"4_BDs Fusionadas"
local c5 	"5_BDs por grupos de vars"
local c6	"6_Temporales"
local rawc1 "`raw'\\`c1'"
local outc1 "`out'\\`c1'"
local rawc2 "`raw'\\`c2'"
local outc2 "`out'\\`c2'"
local rawc3 "`raw'\\`c3'"
local outc3 "`out'\\`c3'"
local outc4 "`out'\\`c4'"
local outc5 "`out'\\`c5'"
local outc6 "`out'\\`c6'"

local outc3prod "`outc3'\\Productor"
local outc3ccpp "`outc3'\\CCPP"

// Subcarpetas especificas dentro de Out
cap mkdir "`outc3'\\Productor"
cap mkdir "`outc3'\\CCPP"

// Carpetas de Tablas (Reporte Final): una carpeta plana por categoría.
// Las tablas 3-paneles producidas por prg_table_3panels unifican F-U/DiD/LATE
// en un solo .docx; la subdivisión por estimador (antes 1_ITT/ y 2_LATE/)
// quedó obsoleta y fue removida del pipeline.
local tab_cats `" "1_Conocimiento_Agronómico" "2_Prácticas_Agronómicas" "3_Registros_e_Inocuidad_Alimentaria" "4_Indicadores_Compuestos_BPAs" "5_Resultados_Productivos_y_Económicos" "'

foreach cat of local tab_cats {
	cap mkdir "${ruta_tablas}\\`cat'"
}

// Carpetas de Anexos
cap mkdir "${ruta_anexos}\\Prácticas_Agronómicas"
cap mkdir "${ruta_anexos}\\Registros_e_Inocuidad_Alimentaria"
cap mkdir "${ruta_anexos}\\Indicadores_Compuestos_BPAs"
cap mkdir "${ruta_anexos}\\Diagnóstico_del_Diseño"

// Carpetas de Diseño y Diagnóstico (scripts 30-40)
local diag_cats `" "1_CONSORT" "2_Cluster_Descriptivos" "3_Balance" "4_Atricion" "5_Compliance" "6_Robustez_Timing" "'
cap mkdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico"
foreach cat of local diag_cats {
	cap mkdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\`cat'"
}

// Carpetas de Imágenes para Diseño y Diagnóstico
cap mkdir "${ruta_images}\\Gráfico_Consort"
cap mkdir "${ruta_images}\\Gráfico_Loveplot"

// Bases para fusionar en 4_BDs Fusionadas
local basesInicio	""`outc1'\pcl_Inicio_LB"   	"`outc2'\pcl_Inicio_LS""
local basesPersonas ""`outc1'\pcl_Personas_LB" 	"`outc2'\pcl_NuevosIntegrantes_LS""
local basesParcela  ""`outc1'\pcl_Parcela_LB" 	"`outc2'\pcl_Parcela_LS""
local basesCultivo  ""`outc1'\pcl_Cultivo_LB" 	"`outc2'\pcl_Cultivo_LS""

//==============================================================================
// Step 4: Define pipeline execution order (commented reference)
//==============================================================================
// --- Fase 1: Ingest ---
// do "${ruta_scripts}\\B1_ingest_copy_files.do"
// do "${ruta_scripts}\\B2_clean_survey_modules.do"

// --- Fase 2: Treatment identification ---
// do "${ruta_scripts}\\C1_make_treated_producers.do"
// do "${ruta_scripts}\\C2_make_ccpp_assignment.do"

// --- Fase 3: Merge ---
// do "${ruta_scripts}\\D_merge_panels.do"

// --- Fase 4: Build outcome variables ---
// do "${ruta_scripts}\\E1_build_obs_chars.do"
// do "${ruta_scripts}\\E2_build_producer_sociodem.do"
// do "${ruta_scripts}\\E3_build_household.do"
// do "${ruta_scripts}\\E4_build_crops.do"
// do "${ruta_scripts}\\E5_build_farm.do"
// do "${ruta_scripts}\\E6_build_bpa_knowledge.do"
// do "${ruta_scripts}\\E7_build_bpa_practices.do"
// do "${ruta_scripts}\\E8_build_records_storage.do"
// do "${ruta_scripts}\\E9_build_food_safety.do"
// do "${ruta_scripts}\\E10_build_composite_bpas.do"

// --- Fase 5: Validation ---
// do "${ruta_scripts}\\F1_test_balance.do"

// --- Fase 6: Estimation ---
// do "${ruta_scripts}\\G1_estimate_knowledge_scores.do"
// do "${ruta_scripts}\\G2_estimate_bpa_uncond.do"
// do "${ruta_scripts}\\G3_estimate_bpa_cond.do"
// do "${ruta_scripts}\\G4_estimate_records_safety.do"
// do "${ruta_scripts}\\G5Aa_estimate_subind_ena_vO.do"
// do "${ruta_scripts}\\G5Ab_estimate_subind_ena_vF.do"
// do "${ruta_scripts}\\G5Ac_estimate_compuesto_ena_vF_vO.do"

// --- Fase 7: Reporting ---
// H1 va AL FINAL de todo: consolida las secciones .docx ya terminadas en dos
// documentos (cuerpo y anexos). Tras correrlo hay un paso manual en Word:
// Ctrl+E y F9 para resolver los índices, y luego exportar a PDF.
// do "${ruta_scripts}\\H1_report_compile.do"
// do "${ruta_scripts}\\H2_plot_yield_outliers.do"

// --- Fase 8: Diagnostics (diseño y robustez para sección metodológica del paper) ---
// do "${ruta_scripts}\\I1_summary_consort.do"
// shell python "${ruta_scripts}\\I2_graph_consort.py"
// do "${ruta_scripts}\\I3_summary_cluster.do"
// do "${ruta_scripts}\\I4_balance_prod_cluster.do"
// do "${ruta_scripts}\\I5_balance_covariates.do"
// do "${ruta_scripts}\\I6_loveplot.do"
// do "${ruta_scripts}\\I7A_summary_cluster_size.do"
// do "${ruta_scripts}\\I7B_summary_deff_outcomes.do"
// do "${ruta_scripts}\\I8_balance_attrition.do"
// do "${ruta_scripts}\\I9_summary_takeup.do"
// do "${ruta_scripts}\\I10_summary_intensity.do"
// do "${ruta_scripts}\\I11_robust_timing.do"

//==============================================================================
// Step 5 (opcional, no activo): Migración futura a subcarpetas por fase
//==============================================================================
// Convención actual: nombres con prefijo de fase (A, B, C, ...). Cuando se
// decida agrupar fisicamente los scripts en subcarpetas, activar las globals
// abajo, mover los archivos con `git mv` y reemplazar ${ruta_scripts} por la
// global de la fase correspondiente en las llamadas del Step 4. Los nombres
// de archivo permanecen iguales (siguen siendo autodescriptivos).
//
// global ruta_setup   "${ruta_scripts}\\A_setup"
// global ruta_ingest  "${ruta_scripts}\\B_ingest"
// global ruta_treat   "${ruta_scripts}\\C_treatment"
// global ruta_merge   "${ruta_scripts}\\D_merge"
// global ruta_build   "${ruta_scripts}\\E_build"
// global ruta_valid   "${ruta_scripts}\\F_validation"
// global ruta_estim   "${ruta_scripts}\\G_estimation"
// global ruta_report  "${ruta_scripts}\\H_reporting"
// global ruta_diag    "${ruta_scripts}\\I_diagnostics"
//
// Ejemplo de migración una línea del Step 4:
//   antes: do "${ruta_scripts}\\E1_build_obs_chars.do"
//   despues: do "${ruta_build}\\E1_build_obs_chars.do"

log close
