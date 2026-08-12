//------------------------------------------------------------------------------
// File           : _helpers/prg_table_3way_het.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 25/05/2026
// Description    : Programa reusable que genera una tabla docx de efectos
//                  heterogéneos sobre una dimensión categórica de 3 niveles
//                  (ej. cultivo principal, tamaño de predio, región, etc.)
//                  en formato de 3 paneles verticales. Cada panel corresponde a
//                  un nivel de la variable de heterogeneidad y presenta las 4
//                  especificaciones con controles (ITT-OLS / ITT-DiD /
//                  LATE-cluster / LATE-individual), más un sub-panel compacto
//                  de descriptivos de la variable resultado para ese subgrupo.
//
//                  Estrategia de estimación: los efectos para los 3 subgrupos
//                  se estiman CONJUNTAMENTE en una sola regresión por
//                  especificación, interactuando el instrumento (Z) con los
//                  indicadores de subgrupo (D_gi). Esto es econométricamente
//                  equivalente a estimar en sub-muestras bajo homocedasticidad,
//                  pero permite testear la igualdad de efectos entre subgrupos
//                  y es más eficiente.
//
//                  Modelo saturado: además de interactuar el tratamiento ×
//                  subgrupo, se interactúan también los controles × subgrupo
//                  (via `tok'#ibn.het_var) y, en DiD, el período × subgrupo
//                  (Per_gi). Esto produce 3 conjuntos de slopes independientes
//                  — uno por subgrupo — y comparte cluster s.e.
//
//                  Especificaciones (los D_gi son intercepto subgrupo, D_g3 ref.):
//                    ITT-OLS:    areg Y (Z_g1 Z_g2 Z_g3) D_g1 D_g2
//                                ctrls_sat [if post==1], a(FE) cl(cluster)
//                    ITT-DiD:    areg Y (DID_g1 DID_g2 DID_g3) (Z_g1 Z_g2 Z_g3)
//                                (Per_g1 Per_g2 Per_g3) D_g1 D_g2
//                                ctrls_sat, a(FE) cl(cluster)
//                                (DID_gi ≡ Z_gi × post; Per_gi ≡ post × D_gi;
//                                 NO `post' suelto: ΣPer_gi = post → dummy trap)
//                    LATE-clu:   ivregress 2sls Y (Dc_g1 Dc_g2 Dc_g3 = Z_g1 Z_g2 Z_g3)
//                                D_g1 D_g2 ctrls_sat [if post==1], absorb(FE) cl(cluster)
//                    LATE-ind:   ivregress 2sls Y (Pi_g1 Pi_g2 Pi_g3 = Z_g1 Z_g2 Z_g3)
//                                D_g1 D_g2 ctrls_sat [if post==1], absorb(FE) cl(cluster)
//                    F primera etapa LATE: `estat firststage, all' (la opción
//                    `all' es necesaria para poblar r(singleresults) con F
//                    por endógena bajo cluster s.e. + múltiples endógenas).
//
//                  Nomenclatura tempvars: D_gi (g=grupo de heterogeneidad,
//                  i=índice del nivel 1..3). Los 3 niveles son exhaustivos
//                  dentro de la muestra analítica: D_g1 + D_g2 + D_g3 == 1.
//
// Estructura de la tabla (33 filas × 5 columnas):
//   Fila  1-2: Header BID (super-header + sub-header de numeración) — una sola vez
//   Por cada subgrupo i ∈ {1, 2, 3} (10 filas × 3 = 30 filas):
//     Fila +1: SEP GRIS "Panel X — Productores de {het_panel_phrase} {label_i}"
//     Fila +2: Coef.
//     Fila +3: Err. Est.
//     Fila +4: F primera etapa (border top single; solo LATE)
//     Fila +5: Observaciones (N del subgrupo, no N total del modelo)
//     Fila +6: # Clusters (clusters del subgrupo, no clusters totales)
//     Fila +7: SEP sub-panel "Descriptivos de Variable Resultado" (italic, border top single)
//     Fila +8: Sub-header BID | t = 0 | t = 1 | Δ (t=1−t=0) (colspan 2)
//     Fila +9: Media | Control
//     Fila +10: Media | Tratado (doble línea abajo)
//   Fila 33: Notas al pie (colspan 5)
//
// Contrato: el programa NO carga ni transforma data. Asume que el caller dejó
//   en memoria el panel balanceado con outcome, z_var, dc_var, pi_var, post_var,
//   controles, FE y la variable de heterogeneidad declarada en `het_var'.
//   Genera internamente tempvars de interacción (auto-eliminadas al salir).
//
// Sintaxis:
//   prg_table_3way_het, ///
//       outcome(varname) outcome_phrase("string") ///
//       table_num("string") out("filepath") ///
//       z_var(varname) dc_var(varname) pi_var(varname) post_var(varname) ///
//       controls("string") absorb(varname) cluster(varname) ///
//       het_var(varname) het_levels(numlist) het_labels("a|b|c") ///
//       het_panel_phrase("string") het_short("string") ///
//       [ outcome_qualifier("string") note_extra("string") het_intro("string") ]
//
// Argumentos específicos de heterogeneidad:
//   het_var          : variable categórica que define los subgrupos.
//   het_levels       : 3 valores numéricos de `het_var' en orden de display.
//   het_labels       : 3 etiquetas legibles separadas por pipe (|), en el
//                      mismo orden que het_levels. Aparecen en el título de
//                      cada panel.
//   het_panel_phrase : frase que se inserta entre "Productores de" y la
//                      etiqueta del subgrupo en el título del panel.
//                      Ej.: "cultivos de" → "Productores de cultivos de Papa".
//                      Ej.: "tamaño"      → "Productores de tamaño Mediano".
//   het_short        : sustantivo corto (1 palabra) para referencias compactas
//                      en notas. Ej.: "cultivo", "tamaño", "región".
//   het_intro [opc]  : cláusula descriptiva para la oración 1 de la nota.
//                      Default: "el `het_short' principal del productor".
//                      Pasar explícito si la cláusula default no aplica.
//
// Argumentos restantes: idénticos a prg_table_2panels (ver ese archivo).
//
// `controls' debe pasarse con prefijos c./i. EXPLÍCITOS (ej. "c.edad i.sexo
// c.educ i.mes_enc"), porque el helper los reusa directamente como
// `tok'#ibn.`het_var'. Sin prefijos, Stata trataría indicadoras como continuas
// y la saturación no respetaría su naturaleza factor.
//
// Dependencias:
//   - Global ${ruta_helpers} (definido por A_master.do)
//   - Helper PowerShell ${ruta_helpers}/fix_table_borders.ps1
//   - `het_var' en memoria
//   - _fmt_b, _fmt_se, _fmt_N, _fmt_F: definidos por prg_table_3panels.do
//     (el caller debe cargar ese helper antes de invocar este programa)
//------------------------------------------------------------------------------

cap program drop prg_table_3way_het
program define prg_table_3way_het
	syntax , ///
		outcome(varname) ///
		outcome_phrase(string) ///
		table_num(string) ///
		out(string) ///
		z_var(varname) ///
		dc_var(varname) ///
		pi_var(varname) ///
		post_var(varname) ///
		controls(string) ///
		absorb(varname) ///
		cluster(varname) ///
		het_var(varname) ///
		het_levels(numlist min=3 max=3) ///
		het_labels(string) ///
		het_panel_phrase(string) ///
		het_short(string) ///
		[ outcome_qualifier(string) note_extra(string) het_intro(string) ]

	// Constantes visuales BID
	local font_main "Roboto"
	local size_m    9.5
	local size_n    8

	if "${ruta_helpers}" == "" {
		di as error "Global \${ruta_helpers} no está definido. El caller debe"
		di as error "haber hecho `qui include \"\${CONSULT}\\BID\\HRC0052956\\2_Scripts\\A_master.do\"`."
		exit 198
	}
	if `"`controls'"' == "" {
		di as error "prg_table_3way_het requiere controls() no-vacío."
		exit 198
	}

	// Construcción del paréntesis aclaratorio y del extra de nota
	local qual_str  = cond(`"`outcome_qualifier'"' != "", " (`outcome_qualifier')", "")
	local extra_str = cond(`"`note_extra'"' != "", " `note_extra'", "")

	// Default para het_intro si no se pasó
	if `"`het_intro'"' == "" {
		local het_intro "el `het_short' principal del productor"
	}

	// Parseo de het_levels y het_labels en arrays indexados (1..3)
	tokenize "`het_levels'"
	local cod_1 = `1'
	local cod_2 = `2'
	local cod_3 = `3'

	// het_labels viene como "lbl1|lbl2|lbl3" — parseo por pipe
	gettoken lbl_1 rest : het_labels, parse("|")
	gettoken sep    rest : rest, parse("|")
	gettoken lbl_2 rest : rest, parse("|")
	gettoken sep    rest : rest, parse("|")
	gettoken lbl_3 rest : rest, parse("|")
	local lbl_1 = trim("`lbl_1'")
	local lbl_2 = trim("`lbl_2'")
	local lbl_3 = trim("`lbl_3'")

	// Claves de iteración (g1, g2, g3) — usadas en loops internos
	local het_keys "g1 g2 g3"

	//==========================================================================
	// Step 1: Tempvars de interacción tratamiento × subgrupo, período × subgrupo
	// y subgrupo. D_g3 = categoría de referencia (intercepto subgrupo).
	//==========================================================================
	tempvar D_g1   D_g2   D_g3
	tempvar Z_g1   Z_g2   Z_g3
	tempvar Per_g1 Per_g2 Per_g3
	tempvar DID_g1 DID_g2 DID_g3
	tempvar Dc_g1  Dc_g2  Dc_g3
	tempvar Pi_g1  Pi_g2  Pi_g3

	qui gen byte `D_g1' = (`het_var' == `cod_1')
	qui gen byte `D_g2' = (`het_var' == `cod_2')
	qui gen byte `D_g3' = (`het_var' == `cod_3')

	qui gen byte `Z_g1' = `z_var' * `D_g1'
	qui gen byte `Z_g2' = `z_var' * `D_g2'
	qui gen byte `Z_g3' = `z_var' * `D_g3'

	qui gen byte `Per_g1' = `post_var' * `D_g1'
	qui gen byte `Per_g2' = `post_var' * `D_g2'
	qui gen byte `Per_g3' = `post_var' * `D_g3'

	qui gen byte `DID_g1' = `Z_g1' * `post_var'
	qui gen byte `DID_g2' = `Z_g2' * `post_var'
	qui gen byte `DID_g3' = `Z_g3' * `post_var'

	qui gen byte `Dc_g1' = `dc_var' * `D_g1'
	qui gen byte `Dc_g2' = `dc_var' * `D_g2'
	qui gen byte `Dc_g3' = `dc_var' * `D_g3'

	qui gen byte `Pi_g1' = `pi_var' * `D_g1'
	qui gen byte `Pi_g2' = `pi_var' * `D_g2'
	qui gen byte `Pi_g3' = `pi_var' * `D_g3'

	//==========================================================================
	// Step 2: Saturación de controles × subgrupo.
	// Cada token de `controls' (con prefijo c./i. del caller) se cruza con
	// #ibn.`het_var' para producir 3 slopes — una por subgrupo — sin generar
	// main effect compartido.
	//==========================================================================
	local ctrls_sat
	foreach tok of local controls {
		local ctrls_sat `ctrls_sat' `tok'#ibn.`het_var'
	}

	//==========================================================================
	// Step 3: Estimaciones — 4 specs saturadas, una regresión por spec
	//==========================================================================
	tempname FS_lc FS_li

	// --- (1) ITT-OLS — sección cruzada (post==1) ---
	qui areg `outcome' ///
		`Z_g1' `Z_g2' `Z_g3' ///
		`D_g1' `D_g2' ///
		`ctrls_sat' ///
		if `post_var'==1, a(`absorb') cl(`cluster')
	foreach k of local het_keys {
		local b_itt_`k'  = _b[`Z_`k'']
		local se_itt_`k' = _se[`Z_`k'']
		local p_itt_`k'  = 2*ttail(e(df_r), abs(`b_itt_`k'' / `se_itt_`k''))
	}
	local N_cs_total  = e(N)
	local Nc_cs_total = e(N_clust)

	// --- (2) ITT-DiD — panel balanceado, simétricamente saturado (Per_gi) ---
	// NO incluye `post_var' suelto: Per_g1+Per_g2+Per_g3 = post → dummy trap.
	qui areg `outcome' ///
		`DID_g1' `DID_g2' `DID_g3' ///
		`Z_g1' `Z_g2' `Z_g3' ///
		`Per_g1' `Per_g2' `Per_g3' ///
		`D_g1' `D_g2' ///
		`ctrls_sat', ///
		a(`absorb') cl(`cluster')
	foreach k of local het_keys {
		local b_did_`k'  = _b[`DID_`k'']
		local se_did_`k' = _se[`DID_`k'']
		local p_did_`k'  = 2*ttail(e(df_r), abs(`b_did_`k'' / `se_did_`k''))
	}
	local N_did_total  = e(N)
	local Nc_did_total = e(N_clust)

	// --- (3) LATE-cluster — 2SLS, 3 endógenas (Dc_gi) ---
	qui ivregress 2sls `outcome' ///
		(`Dc_g1' `Dc_g2' `Dc_g3' = `Z_g1' `Z_g2' `Z_g3') ///
		`D_g1' `D_g2' ///
		`ctrls_sat' ///
		if `post_var'==1, absorb(`absorb') cl(`cluster')
	foreach k of local het_keys {
		local b_lc_`k'  = _b[`Dc_`k'']
		local se_lc_`k' = _se[`Dc_`k'']
		local p_lc_`k'  = 2*ttail(e(N_clust)-1, abs(`b_lc_`k'' / `se_lc_`k''))
	}
	// `all' es clave: sin esto, r(singleresults) queda vacía bajo cluster + 3 endógenas
	qui estat firststage, all
	mat `FS_lc' = r(singleresults)
	local F_lc_g1 = `FS_lc'[1, 4]
	local F_lc_g2 = `FS_lc'[2, 4]
	local F_lc_g3 = `FS_lc'[3, 4]

	// --- (4) LATE-individual — 2SLS, 3 endógenas (Pi_gi) ---
	qui ivregress 2sls `outcome' ///
		(`Pi_g1' `Pi_g2' `Pi_g3' = `Z_g1' `Z_g2' `Z_g3') ///
		`D_g1' `D_g2' ///
		`ctrls_sat' ///
		if `post_var'==1, absorb(`absorb') cl(`cluster')
	foreach k of local het_keys {
		local b_li_`k'  = _b[`Pi_`k'']
		local se_li_`k' = _se[`Pi_`k'']
		local p_li_`k'  = 2*ttail(e(N_clust)-1, abs(`b_li_`k'' / `se_li_`k''))
	}
	qui estat firststage, all
	mat `FS_li' = r(singleresults)
	local F_li_g1 = `FS_li'[1, 4]
	local F_li_g2 = `FS_li'[2, 4]
	local F_li_g3 = `FS_li'[3, 4]

	//==========================================================================
	// Step 3b: Diagnóstico al log (verificable visualmente post-corrida)
	//==========================================================================
	di as text _n "=== Diagnóstico modelo saturado: `outcome' (het_var=`het_var') ==="
	di as text "N (sección cruzada): " %9.0fc `N_cs_total' ///
		"   N (DiD panel): " %9.0fc `N_did_total'
	di as text "F primera etapa por endógena (g1=`lbl_1', g2=`lbl_2', g3=`lbl_3'):"
	di as text "  LATE-cluster:    g1=" %6.2f `F_lc_g1' ///
		"  g2=" %6.2f `F_lc_g2' "  g3=" %6.2f `F_lc_g3'
	di as text "  LATE-individual: g1=" %6.2f `F_li_g1' ///
		"  g2=" %6.2f `F_li_g2' "  g3=" %6.2f `F_li_g3'
	foreach k of local het_keys {
		if `F_lc_`k'' < 10 di as error "  ⚠ F LATE-cluster `k' = " %6.2f `F_lc_`k'' " (<10, instrumento posiblemente débil)"
		if `F_li_`k'' < 10 di as error "  ⚠ F LATE-indiv   `k' = " %6.2f `F_li_`k'' " (<10, instrumento posiblemente débil)"
	}

	//==========================================================================
	// Step 4: Estadísticas de muestra y descriptivos por subgrupo
	//==========================================================================
	foreach k of local het_keys {
		qui count if `post_var'==1 & `D_`k''==1
		local N_cs_`k'  = r(N)
		local N_did_`k' = 2 * `N_cs_`k''

		qui tab `cluster' if `post_var'==1 & `D_`k''==1
		local Nc_k_`k' = r(r)

		qui summ `outcome' if `z_var'==0 & `post_var'==0 & `D_`k''==1
		local m_c0_`k' = r(mean)
		qui summ `outcome' if `z_var'==0 & `post_var'==1 & `D_`k''==1
		local m_c1_`k' = r(mean)
		qui summ `outcome' if `z_var'==1 & `post_var'==0 & `D_`k''==1
		local m_t0_`k' = r(mean)
		qui summ `outcome' if `z_var'==1 & `post_var'==1 & `D_`k''==1
		local m_t1_`k' = r(mean)
		local d_c_`k'  = `m_c1_`k'' - `m_c0_`k''
		local d_t_`k'  = `m_t1_`k'' - `m_t0_`k''
	}

	//==========================================================================
	// Step 5: Pre-formatear strings (con stars y trim())
	//==========================================================================
	foreach k of local het_keys {
		foreach est in itt did lc li {
			_fmt_b  `b_`est'_`k''  `p_`est'_`k''
			local s_b_`est'_`k'  = r(out)
			_fmt_se `se_`est'_`k''
			local s_se_`est'_`k' = r(out)
		}
		_fmt_F `F_lc_`k''
		local s_F_lc_`k' = r(out)
		_fmt_F `F_li_`k''
		local s_F_li_`k' = r(out)

		_fmt_N `N_cs_`k''
		local s_N_cs_`k'  = r(out)
		_fmt_N `N_did_`k''
		local s_N_did_`k' = r(out)
		_fmt_N `Nc_k_`k''
		local s_Nc_`k'    = r(out)

		foreach stat in c0 c1 t0 t1 {
			local s_m_`stat'_`k' : di %9.3f `m_`stat'_`k''
			local s_m_`stat'_`k' = trim("`s_m_`stat'_`k''")
		}
		local s_d_c_`k' : di %9.3f `d_c_`k''
		local s_d_c_`k' = trim("`s_d_c_`k''")
		local s_d_t_`k' : di %9.3f `d_t_`k''
		local s_d_t_`k' = trim("`s_d_t_`k''")
	}

	//==========================================================================
	// Step 6: Construir el .docx — 33 filas × 5 columnas
	//==========================================================================
	local outdir = substr("`out'", 1, strrpos("`out'", "/") - 1)
	if "`outdir'" == "" local outdir = substr("`out'", 1, strrpos("`out'", "\") - 1)
	cap mkdir "`outdir'"

	putdocx clear
	putdocx begin, pagesize(A4) ///
		margin(left, 1.0) margin(right, 1.0) ///
		margin(top, 0.8)  margin(bottom, 0.8)

	// Título
	putdocx paragraph, halign(left) spacing(after, 0)
	putdocx text ("Tabla `table_num' — Efecto del programa de ECAs sobre `outcome_phrase'`qual_str'"), ///
		bold font("`font_main'", `size_m')

	tempname T_widths
	mat `T_widths' = (32, 17, 17, 17, 17)
	putdocx table T = (33, 5), border(all, nil) layout(autofitwindow) width(`T_widths')

	// Filas 1-2: Header BID
	putdocx table T(1, 1), shading(0 78 112)
	putdocx table T(1, 2) = ("ITT-OLS"),         bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(1, 2), shading(0 78 112)
	putdocx table T(1, 3) = ("ITT-DiD"),         bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(1, 3), shading(0 78 112)
	putdocx table T(1, 4) = ("LATE-clúster"),    bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(1, 4), shading(0 78 112)
	putdocx table T(1, 5) = ("LATE-individual"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(1, 5), shading(0 78 112)

	putdocx table T(2, 1), shading(0 78 112) border(bottom, single)
	forvalues i = 1/4 {
		local c = `i' + 1
		putdocx table T(2, `c'), shading(0 78 112) border(bottom, single)
		putdocx table T(2, `c') = ("(`i')"), bold font("`font_main'", `size_m', "white") halign(center)
	}

	// 3 paneles (10 filas cada uno)
	local p = 0
	foreach k of local het_keys {
		local ++p
		local panel_letter = word("A B C", `p')
		local base_row     = 2 + (`p'-1)*10
		local lbl_p        "`lbl_`p''"

		// Fila +1: SEP GRIS del panel
		local r = `base_row' + 1
		putdocx table T(`r', 1), colspan(5) shading(211 210 209) ///
			border(top, double, "black", 1.5)
		putdocx table T(`r', 1) = ("Panel `panel_letter' — Productores de `het_panel_phrase' `lbl_p'"), ///
			italic bold font("`font_main'", `size_m') halign(left)

		// Fila +2: Coef.
		local r = `base_row' + 2
		putdocx table T(`r', 1) = ("Coef."),         font("`font_main'", `size_m') halign(left)
		putdocx table T(`r', 2) = ("`s_b_itt_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 3) = ("`s_b_did_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 4) = ("`s_b_lc_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 5) = ("`s_b_li_`k''"),  font("`font_main'", `size_m') halign(center)

		// Fila +3: Err. Est.
		local r = `base_row' + 3
		putdocx table T(`r', 1) = ("Err. Est."),      font("`font_main'", `size_m') halign(left)
		putdocx table T(`r', 2) = ("`s_se_itt_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 3) = ("`s_se_did_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 4) = ("`s_se_lc_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 5) = ("`s_se_li_`k''"),  font("`font_main'", `size_m') halign(center)

		// Fila +4: F primera etapa (solo LATE)
		local r = `base_row' + 4
		putdocx table T(`r', 1) = ("F primera etapa"), ///
			font("`font_main'", `size_m') halign(left) border(top, single)
		putdocx table T(`r', 2), border(top, single)
		putdocx table T(`r', 3), border(top, single)
		putdocx table T(`r', 4) = ("`s_F_lc_`k''"), ///
			font("`font_main'", `size_m') halign(center) border(top, single)
		putdocx table T(`r', 5) = ("`s_F_li_`k''"), ///
			font("`font_main'", `size_m') halign(center) border(top, single)

		// Fila +5: Observaciones
		local r = `base_row' + 5
		putdocx table T(`r', 1) = ("Observaciones"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r', 2) = ("`s_N_cs_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 3) = ("`s_N_did_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 4) = ("`s_N_cs_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 5) = ("`s_N_cs_`k''"),  font("`font_main'", `size_m') halign(center)

		// Fila +6: # Clusters
		local r = `base_row' + 6
		putdocx table T(`r', 1) = ("# Clústeres"),  font("`font_main'", `size_m') halign(left)
		putdocx table T(`r', 2) = ("`s_Nc_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 3) = ("`s_Nc_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 4) = ("`s_Nc_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 5) = ("`s_Nc_`k''"),  font("`font_main'", `size_m') halign(center)

		// Fila +7: SEP sub-panel descriptivos
		local r = `base_row' + 7
		putdocx table T(`r', 1), colspan(5) border(top, single)
		putdocx table T(`r', 1) = ("Descriptivos de Variable Resultado"), ///
			italic font("`font_main'", `size_m') halign(left)

		// Fila +8: Sub-header (t=0 | t=1 | Δ cols 4-5 fusionadas)
		local r = `base_row' + 8
		putdocx table T(`r', 4) = ("Δ (t=1 − t=0)"), ///
			bold font("`font_main'", `size_m', "white") halign(center)
		putdocx table T(`r', 4), colspan(2) shading(0 78 112) border(bottom, single)
		putdocx table T(`r', 3) = ("t = 1"), ///
			bold font("`font_main'", `size_m', "white") halign(center)
		putdocx table T(`r', 3), shading(0 78 112) border(bottom, single)
		putdocx table T(`r', 2) = ("t = 0"), ///
			bold font("`font_main'", `size_m', "white") halign(center)
		putdocx table T(`r', 2), shading(0 78 112) border(bottom, single)
		putdocx table T(`r', 1), shading(0 78 112) border(bottom, single)

		// Fila +9: Media | Control
		local r = `base_row' + 9
		putdocx table T(`r', 4) = ("`s_d_c_`k''"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 4), colspan(2)
		putdocx table T(`r', 3) = ("`s_m_c1_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 2) = ("`s_m_c0_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 1) = ("Media | Control"), font("`font_main'", `size_m') halign(left)

		// Fila +10: Media | Tratado (doble línea abajo)
		local r = `base_row' + 10
		putdocx table T(`r', 4) = ("`s_d_t_`k''"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r', 4), colspan(2) border(bottom, double, "black", 1.5)
		putdocx table T(`r', 3) = ("`s_m_t1_`k''"), ///
			font("`font_main'", `size_m') halign(center) border(bottom, double, "black", 1.5)
		putdocx table T(`r', 2) = ("`s_m_t0_`k''"), ///
			font("`font_main'", `size_m') halign(center) border(bottom, double, "black", 1.5)
		putdocx table T(`r', 1) = ("Media | Tratado"), ///
			font("`font_main'", `size_m') halign(left) border(bottom, double, "black", 1.5)
	}

	// ==============================================================
	// Fila 33: Notas al pie
	// ==============================================================
	local n1 "Esta tabla reporta el efecto del programa de Escuelas de Campo Agrícolas (ECAs) sobre `outcome_phrase'`qual_str', diferenciado por `het_intro'.`extra_str'"
	local n2 "Los tres paneles no provienen de tres regresiones separadas: cada especificación se estima en una sola regresión sobre toda la muestra, en la que `het_intro' se interactúa con el tratamiento, con el periodo (en DiD) y con el conjunto de controles. Así, cada panel recupera el efecto dentro de su propio `het_short' —como si se hubiera estimado por separado—, pero con errores estándar comunes a los tres. La columna (1) estima la intención de tratamiento (ITT) por OLS en la línea de seguimiento; la columna (2), la misma ITT por diferencias en diferencias (DiD) sobre el panel balanceado. Las columnas (3) y (4) estiman el efecto promedio local del tratamiento (LATE) por 2SLS, usando la asignación aleatoria del centro poblado como instrumento de, respectivamente, la implementación efectiva de la ECA en el centro poblado y la participación individual del productor."
	local n3 "El bloque al pie de cada panel reporta las medias de la variable de resultado de ese `het_short', por grupo y periodo, y su variación entre periodos."
	local n4 "Todas las especificaciones incluyen efectos fijos de diseño (estrato región-cultivo principal), mes de encuesta y las covariables de línea base del productor, su hogar y su predio, todos interactuados con `het_intro'."
	local n5 "Los errores estándar, agrupados a nivel de centro poblado, se reportan entre paréntesis. * p<0.10, ** p<0.05, *** p<0.01."
	local nota_text "Notas. `n1' `n2' `n3' `n4' `n5'"

	putdocx table T(33, 1) = ("`nota_text'"), colspan(5) ///
		border(top, double, "black", 1.5) ///
		italic font("`font_main'", `size_n')

	// Alineación final
	forvalues r = 1/33 {
		if !inlist(`r', 33) {
			cap putdocx table T(`r', 1), halign(left) valign(center)
			forvalues c = 2/5 {
				cap putdocx table T(`r', `c'), halign(center) valign(center)
			}
		}
	}

	//==========================================================================
	// Step 7: Guardar y post-procesar (dobles líneas + justify en notas)
	//==========================================================================
	putdocx save "`out'", replace
	shell powershell -NoProfile -ExecutionPolicy Bypass ///
		-File "${ruta_helpers}/fix_table_borders.ps1" "`out'"

	di as text "Archivo guardado: " as result "`out'"
end
