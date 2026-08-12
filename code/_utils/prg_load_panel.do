//------------------------------------------------------------------------------
// File           : _helpers/prg_load_panel.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Description    : Carga la base maestra del proyecto para las tablas de
//                  estimación (G1-G6B): identificadores + efectos fijos +
//                  treatment vars + controles de línea base + el outcome_file
//                  especificado. Restringe al panel balanceado (productores
//                  con observación en LB y LS). Deja la data en memoria para
//                  que el caller construya D_c/P_i y luego invoque
//                  prg_table_3panels.
//
//                  Responsabilidad única: I/O de datos (use + merges +
//                  restricción a panel balanceado). NO construye D_c/P_i
//                  (eso es una decisión metodológica que debe ser explícita
//                  en el caller) ni corre estimaciones.
//
// Sintaxis:
//   prg_load_panel, ///
//       outcome_file("string") outcome_vars(varlist_string) ///
//       extra_vars(varlist_string)
//
// Argumentos:
//   outcome_file   Nombre del .dta (sin extensión) donde viven los outcomes.
//                  Se asume ubicado en `outc5' (5_BDs por grupos de vars).
//                  Ej.: "BPAs_Compuestos_LByLS".
//   outcome_vars   Variables de resultado a traer del outcome_file. Una o
//                  varias (ej.: "bpa_ena_riego_vO bpa_ena_suelo_vO").
//   extra_vars     Variables adicionales a traer de Caract_Obs_Trat_ECA
//                  (típicamente las crudas para construir D_c/P_i en el
//                  caller, ej.: "i1aECA_PE_ccpp ptcp_ECA_prod"). Explícito,
//                  sin default — el caller pide exactamente lo que necesita.
//
// Deja en memoria (panel balanceado, productor × periodo):
//   - Identificadores/FE: Codprod22 post cod_rgn_PE cod_cpb mes_enc
//                         asig_ccpp prod_ECA_eval
//   - Controles LB:       edad edadsq sexo educ castell ilogsact icondvid
//                         tot_miem_1564 tot_miem_depen tot_has_prod
//                         años_tenen_prod riego_tec_prod
//   - extra_vars (las que pida el caller, de Caract_Obs_Trat_ECA)
//   - outcome_vars (del outcome_file)
//
// Dependencias:
//   - Global ${ruta_data} (definido por A_master.do).
//   - Archivos en `outc5': Caract_Obs_Trat_ECA.dta, Sociodem_Prod_JH_LB.dta,
//     Viv_Act_SEA_LB.dta, Demog_Ing_Hog_LB.dta, Productor_Predio_LB.dta,
//     y el `outcome_file' que se pase.
//------------------------------------------------------------------------------

cap program drop prg_load_panel
program define prg_load_panel
	syntax , ///
		outcome_file(string) ///
		outcome_vars(string) ///
		extra_vars(string)

	// Construir `outc5' desde ${ruta_data} (global que A_master.do define con
	// `global`). No usamos `include` aquí porque Stata no lo permite dentro de
	// un program (r(9611)).
	if "${ruta_data}" == "" {
		di as error "Global \${ruta_data} no está definido. El caller debe"
		di as error "hecho el bootstrap del entorno (ver A_master.do)."
		exit 198
	}
	local outc5 "${ruta_data}/Out/5_BDs por grupos de vars"

	// Variables base (identificadores, FE, treatment)
	local vbase Codprod22 post cod_rgn_PE cod_cpb mes_enc asig_ccpp prod_ECA_eval
	// Controles de línea base
	local vsoc  edad edadsq sexo educ castell
	local vviv  ilogsact icondvid
	local vdem  tot_miem_1564 tot_miem_depen
	local vpre  tot_has_prod años_tenen_prod riego_tec_prod

	use `vbase' `extra_vars' using "`outc5'/Caract_Obs_Trat_ECA.dta", clear
	merge m:1 Codprod22 using "`outc5'/Sociodem_Prod_JH_LB.dta", ///
		keepus(`vsoc') keep(3) nogen
	merge m:1 Codprod22 using "`outc5'/Viv_Act_SEA_LB.dta", ///
		keepus(`vviv') keep(3) nogen
	merge m:1 Codprod22 using "`outc5'/Demog_Ing_Hog_LB.dta", ///
		keepus(`vdem') keep(3) nogen
	merge m:1 Codprod22 using "`outc5'/Productor_Predio_LB.dta", ///
		keepus(`vpre') keep(3) nogen
	merge 1:1 Codprod22 post using "`outc5'/`outcome_file'.dta", ///
		keepus(`outcome_vars') keep(3) nogen

	// Restringir a panel balanceado (productores con LB y LS)
	bys Codprod22 : gen n_obs = _N
	qui count if n_obs != 2
	di as text "Obs. descartadas por panel no balanceado: " as result r(N)
	keep if n_obs == 2
	drop n_obs

	sort Codprod22 post
end
