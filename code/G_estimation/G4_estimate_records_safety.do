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
// Output         : Anexos/Registros_e_Inocuidad_Alimentaria/B-3-<k>_Tab_<var>.docx (×14)
// Depends        : _helpers/prg_load_panel.do
//                  _helpers/prg_table_3panels.do  (define _fmt_*)
//                  _helpers/prg_table_2panels.do
//                  _helpers/fix_table_borders.ps1 (invocado por el programa)
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
cap erase "${ruta_scripts}\G4_estimate_records_safety.log"
log using "${ruta_logs}\G4_estimate_records_safety.log", replace text


// Cargar programas (prg_table_3panels primero porque define _fmt_*)
qui do "${ruta_helpers}/prg_load_panel.do"
qui do "${ruta_helpers}/prg_table_3panels.do"
qui do "${ruta_helpers}/prg_table_2panels.do"

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
	       ino_info_conta_alim) ///
	keep(3) nogen

//------------------------------------------------------------------------------
// 2. Construir D_c y P_i (definiciones operacionales)
//------------------------------------------------------------------------------
gen byte D_c = (i1aECA_PE_ccpp == 1) if !mi(asig_ccpp)
gen byte P_i = (ptcp_ECA_prod  == 1) if !mi(asig_ccpp)

//------------------------------------------------------------------------------
// 3. Labels amigables — single source of truth
//------------------------------------------------------------------------------
lab var regis_1          "Registros de abonos/fertilizantes"
lab var regis_2          "Registros de plaguicidas"
lab var regis_3          "Registros de control biológico"
lab var regis_4          "Registros de riego"
lab var regis_5          "Registros de producción cosechada"
lab var regis_6          "Kardex de almacén"
lab var regis_7          "Registros de trazabilidad"
lab var tot_cond_min_alm "Condiciones mín. almacén de agroquímicos"

lab var ino_resid_cult_v2 "Manejo de residuos de cultivos"
lab var ino_resid_anim_v2 "Manejo de residuos de animales"
lab var ino_alim_prod_v2  "Almacenamiento de alimentos"
lab var ino_etiq_alim     "Etiquetado de alimentos"
lab var ino_cert_cal      "Alimentos certificados"
lab var ino_info_conta_alim "Información sobre contaminación de alimentos"

//------------------------------------------------------------------------------
// 4. Generar las 13 tablas anexas en un loop sobre la varlist consolidada
//------------------------------------------------------------------------------
local ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

local outdir "${ruta_anexos}/Registros_e_Inocuidad_Alimentaria"

// Varlist en el orden de numeración A-3-1..14 (cuatro registros de aplicación,
// cuatro de gestión/almacén, seis de inocuidad). Frases redactadas en paralelo.
local vars     regis_1 regis_2 regis_3 regis_4 ///
	regis_5 regis_6 regis_7 tot_cond_min_alm ///
	ino_resid_cult_v2 ino_resid_anim_v2 ino_alim_prod_v2 ino_etiq_alim ino_cert_cal ///
	ino_info_conta_alim
local phrases  `" "el registro de aplicación de abonos y fertilizantes" "el registro de aplicación de plaguicidas" "el registro de aplicación del control biológico" "el registro del manejo del riego" "el registro de la producción cosechada" "la llevanza de un kardex del almacén" "el registro de trazabilidad" "el cumplimiento de las condiciones mínimas del almacén de agroquímicos" "el manejo adecuado de los residuos de cultivos" "el manejo adecuado de los residuos de animales" "el almacenamiento adecuado de los alimentos producidos" "el etiquetado de los alimentos producidos" "el uso de alimentos certificados" "el conocimiento sobre fuentes de contaminación de los alimentos" "'

local k = 1
foreach var of local vars {
	gettoken phrase phrases : phrases
	prg_table_2panels, ///
		outcome(`var') outcome_phrase("`phrase'") ///
		table_num("B.3-`k'") ///
		out("`outdir'/B-3-`k'_Tab_`var'.docx") ///
		z_var(asig_ccpp) dc_var(D_c) pi_var(P_i) post_var(post) ///
		controls("`ctrl_set'") absorb(cod_rgn_PE) cluster(cod_cpb)
	local ++k
}

log close
