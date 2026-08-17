//------------------------------------------------------------------------------
// File           : G4_estimate_records_safety.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 23/05/2026
// Description    : Genera 14 tablas anexas en formato 2-paneles (Estimaciones
//                  / Descriptivos) para indicadores de registros agrícolas
//                  (aplicación + gestión + almacén) e inocuidad alimentaria.
//                  Para inocuidad se usa la versión Intermedia/Original ENA
//                  (sufijo _v2) de las cadenas vF/vO/vE, consistente con el
//                  sub-indicador ENA vO consumido por G5Aa. Cada tabla
//                  reporta las 4 specs ITT-OLS / ITT-DiD / LATE-cluster /
//                  LATE-individual con controles, más medias por grupo ×
//                  periodo.
//                  Flujo: (1) carga vía prg_load_panel para registros;
//                  (2) merge adicional con Inocuidad_LByLS (prg_load_panel
//                  acepta un solo outcome_file); (3) construye D_c y P_i;
//                  (4) declara labels amigables; (5) loop sobre las 13 vars
//                  invocando prg_table_2panels con `nosubtitle'.
//
// Depends        : _utils/prg_load_panel.do
//                  _utils/prg_table_3panels.do  (define _fmt_*)
//                  _utils/prg_table_2panels.do
//                  _utils/fix_table_borders.ps1 (invocado por el programa)
// Input          : Out/5_BDs por grupos de vars/Registros_Almacen_LByLS.dta (outcome_file)
//                  Out/5_BDs por grupos de vars/Inocuidad_LByLS.dta (merge adicional)
//                  Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta,
//                  Sociodem_Prod_JH_LB.dta, Viv_Act_SEA_LB.dta,
//                  Demog_Ing_Hog_LB.dta, Productor_Predio_LB.dta (vía prg_load_panel)
// Output         : Tablas/3_Registros_e_Inocuidad_Alimentaria/Anexo/B-3-<k>_Tab_<var>.docx (×14)
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
cap erase "${ruta_scripts}\G4_estimate_records_safety.log"
log using "${ruta_logs}\G4_estimate_records_safety.log", replace text

// Cargar programas (prg_table_3panels primero porque define _fmt_*)
qui do "${ruta_utils}/prg_load_panel.do"
qui do "${ruta_utils}/prg_table_3panels.do"
qui do "${ruta_utils}/prg_table_2panels.do"
qui include "${ruta_setup}/spec.do"

//------------------------------------------------------------------------------
// 1. Cargar la base maestra + registros vía prg_load_panel
//------------------------------------------------------------------------------
prg_load_panel, ///
	outcome_file("Registros_Almacen_LByLS") ///
	outcome_vars(regis_1-regis_7 tot_cond_min_alm) ///
	extra_vars(i1aECA_PE_ccpp ptcp_ECA_prod)

// 1b. Merge adicional con Inocuidad_LByLS (prg_load_panel solo acepta un
//     outcome_file; el panel ya quedó balanceado, este merge solo añade vars).
local outc5 "${ruta_data}/Out/5_BDs por grupos de vars"
merge 1:1 Codprod22 post using "`outc5'/Inocuidad_LByLS.dta", ///
	keepus(ino_resid_cult_v2 ino_resid_anim_v2 ino_alim_prod_v2 ino_etiq_alim ino_cert_cal ///
	       ino_info_conta_alim) keep(3) nogen

//------------------------------------------------------------------------------
// 2. Construir D_c y P_i (definiciones operacionales)
//------------------------------------------------------------------------------
gen byte D_c = (i1aECA_PE_ccpp == 1) if !mi(asig_ccpp)
gen byte P_i = (ptcp_ECA_prod  == 1) if !mi(asig_ccpp)

//------------------------------------------------------------------------------
// 3. Generar las 13 tablas anexas en un loop sobre la varlist consolidada
//------------------------------------------------------------------------------

local outdir "${ruta_tablas}/3_Registros_e_Inocuidad_Alimentaria/Anexo"

// Varlist en el orden de numeración B-3-1..14 (siete registros de aplicación y
// gestión, condiciones de almacén, y seis de inocuidad).
local vars  regis_1 regis_2 regis_3 regis_4 regis_5 regis_6 regis_7 tot_cond_min_alm ///
	ino_resid_cult_v2 ino_resid_anim_v2 ino_alim_prod_v2 ino_etiq_alim ino_cert_cal ///
	ino_info_conta_alim

// La frase del título se declara por variable, no en una lista paralela
// recorrida con `gettoken'. Emparejadas solo por POSICIÓN, insertar o reordenar
// un outcome desplazaba todos los títulos siguientes sin que nada avisara.
local ph_regis_1            "el registro de aplicación de abonos y fertilizantes"
local ph_regis_2            "el registro de aplicación de plaguicidas"
local ph_regis_3            "el registro de aplicación del control biológico"
local ph_regis_4            "el registro del manejo del riego"
local ph_regis_5            "el registro de la producción cosechada"
local ph_regis_6            "la llevanza de un kardex del almacén"
local ph_regis_7            "el registro de trazabilidad"
local ph_tot_cond_min_alm   "el cumplimiento de las condiciones mínimas del almacén de agroquímicos"
local ph_ino_resid_cult_v2  "el manejo adecuado de los residuos de cultivos"
local ph_ino_resid_anim_v2  "el manejo adecuado de los residuos de animales"
local ph_ino_alim_prod_v2   "el almacenamiento adecuado de los alimentos producidos"
local ph_ino_etiq_alim      "el etiquetado de los alimentos producidos"
local ph_ino_cert_cal       "el uso de alimentos certificados"
local ph_ino_info_conta_alim "el conocimiento sobre fuentes de contaminación de los alimentos"

local k = 1
foreach var of local vars {
	local phrase "`ph_`var''"
	if "`phrase'" == "" {
		di as error `"Falta la frase del título de `var' (local ph_`var')."'
		exit 198
	}
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		table_num("B.3-`k'") ///
		out("`outdir'/B-3-`k'_Tab_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("$ctrl_set") absorb($fe_estrato) cluster($cl_ccpp)
	local ++k
}

log close