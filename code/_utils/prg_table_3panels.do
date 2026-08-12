//------------------------------------------------------------------------------
// File           : _helpers/prg_table_3panels.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Description    : Programa reusable que genera una tabla docx de 3 paneles
//                  (Sección Cruzada / Diferencias en Diferencias / Descriptivos)
//                  con la especificación de 4 estimadores × 2 (sin/con
//                  controles) para un outcome binario o continuo.
//                  Estilo visual: estilo D4 (separators grises con label de
//                  panel en italic-bold, header BID azul, cell merges en
//                  Paneles B y C, doble línea en inicio/fin/antes-de-panel,
//                  línea fina entre Coef-SE y stats).
//                  Invocable desde G1-G6B del pipeline.
//
// Estructura de la tabla (21 filas × 7 columnas):
//   Fila  1: SEP GRIS  — "Panel A — Sección Cruzada (t=1)" (colspan 7)
//   Fila  2: BID HDR   — | ITT-OLS (cs2) | LATE-cluster (cs2) | LATE-individual (cs2)
//   Fila  3: BID HDR   — | (1) | (2) | (3) | (4) | (5) | (6)
//   Filas 4-9          — datos Panel A
//   Fila 10: SEP GRIS  — "Panel B — Diferencias en Diferencias (t=0 y t=1)"
//   Fila 11: BID HDR   — | (7) ITT-DiD (cs3) | (8) ITT-DiD (cs3)
//   Filas 12-16        — datos Panel B (cells fusionadas cs3 en cols 2-4 y 5-7)
//   Fila 17: SEP GRIS  — "Panel C — Descriptivos de Variable Resultado"
//   Fila 18: BID HDR   — | t = 0 (cs2) | t = 1 (cs2) | Δ (t=1−t=0) (cs2)
//   Filas 19-20        — datos Panel C (cells fusionadas cs2 en cols 2-3, 4-5, 6-7)
//   Fila 21: NOTAS     — Notas al pie embedded como colspan 7, halign(justify)
//
// Contrato: el programa NO carga ni transforma data. Asume que el caller ya
// dejó en memoria el panel balanceado con todas las variables construidas
// (incl. D_c y P_i si se usan definiciones recodificadas). Su única
// responsabilidad: dado ese insumo, estimar las 4 specs, almacenar y desplegar
// la tabla. La carga/merge/restricción a panel balanceado va en el caller
// (ver _helpers/prg_load_panel.do).
//
// Sintaxis:
//   prg_table_3panels, ///
//       outcome(varname) outcome_phrase("string") ///
//       table_num("string") out("filepath") ///
//       z_var(varname) dc_var(varname) pi_var(varname) post_var(varname) ///
//       controls("string") absorb(varname) cluster(varname) ///
//       [ outcome_qualifier("string") robustez ]
//
// Argumentos requeridos:
//   outcome        Variable resultado a estimar (debe existir en memoria)
//   outcome_phrase Frase nominal en español que completa "Efecto del programa
//                  de ECAs sobre <outcome_phrase>" en el título y en la
//                  oración 1 de la nota. El caller la redacta a propósito —
//                  no se hereda del label de variable (los labels siguen
//                  sirviendo como encabezados de columna). Ej.: "la adopción
//                  de prácticas adecuadas de riego".
//   table_num      Numeración de la tabla (ej. "8.2-8")
//   out            Path absoluto del archivo .docx output
//   z_var          Instrumento / variable de asignación aleatoria (ej. asig_ccpp).
//                  Se usa como factor en ITT-OLS, como IV en LATE y como un
//                  término de la interacción en DiD.
//   dc_var         Variable de implementación a nivel cluster, ya construida
//                  (binaria). Endógena instrumentada por z_var en LATE-cluster.
//   pi_var         Variable de participación individual, ya construida (binaria).
//                  Endógena instrumentada por z_var en LATE-individual.
//   post_var       Indicador de periodo (0=LB, 1=LS). Define la restricción
//                  cross-section (post_var==1) y el término temporal del DiD.
//   controls       Set de controles (puede incluir factors como i.mes_enc).
//                  El caller lo pasa explícito (sin default).
//   absorb         Variable de efectos fijos a absorber (ej. cod_rgn_PE).
//   cluster        Variable de clusterización de errores estándar (ej. cod_cpb).
//
// Argumentos opcionales:
//   outcome_qualifier  Texto que se renderiza entre paréntesis al final del
//                  título y al final de la oración 1 de la nota. Sirve para
//                  aclarar submuestra, desglose del outcome o definición
//                  resumida. Ej.: "submuestra: productores con riego
//                  tecnificado" o "indicador compuesto: al menos 2 de los 3
//                  pilares ENA". Default vacío (sin paréntesis).
//   robustez       Modifier. Cuando se pasa, antepone "Robustez. " al
//                  prefijo "Efecto del programa..." del título. Usar solo
//                  cuando la tabla es (a) una versión alternativa del outcome
//                  respecto al cuerpo principal, o (b) sobre una subpoblación
//                  distinta a la usada en el cuerpo principal.
//
// Dependencias:
//   - Global ${ruta_helpers} (definido por A_master.do) para el post-process.
//   - Helper PowerShell ${ruta_helpers}/fix_table_borders.ps1
//   - Data ya cargada en memoria por el caller (ver prg_load_panel.do).
//
// Notas técnicas (peculiaridades de Stata putdocx que motivaron el diseño):
//   - putdocx no expone w:sz para borders → helper inyecta vía XML.
//   - putdocx no admite halign(justify) en cell content → helper inyecta jc.
//   - putdocx renumera columnas tras colspan → merges en reverse order.
//   - putdocx auto-propaga borders en row siblings → no se pueden quitar
//     con border(side, nil/none) — Stata los ignora.
//   - putdocx font(name, size, color) — el color va dentro de font(), no
//     como opción separada.
//   - di %W.Df padea con espacios → trim() obligatorio antes de centrar.
//------------------------------------------------------------------------------

//==============================================================================
// Helper programs (definidos al top level del archivo — no se pueden anidar
// dentro de otro program en Stata, así que viven aquí y prg_table_3panels los
// invoca. Quedan disponibles globalmente tras `do prg_table_3panels.do`).
//==============================================================================
// _fmt_b: convierte coef + pval a string formateado con stars de significancia.
// OJO: `di %W.Df` padea con espacios a la izq. hasta W chars. Sin `trim()`,
// el string almacenado lleva esos espacios → halign(center) los centra junto
// con los dígitos, desplazando el valor a la derecha. Aplicamos trim() en
// todos los helpers para que solo los dígitos sean centrados en la celda.
cap program drop _fmt_b
program define _fmt_b, rclass
	args b p
	local s : di %9.3f `b'
	local s = trim("`s'")
	local stars = ""
	if `p' < 0.01      local stars = "***"
	else if `p' < 0.05 local stars = "**"
	else if `p' < 0.10 local stars = "*"
	return local out = "`s'`stars'"
end

cap program drop _fmt_se
program define _fmt_se, rclass
	args se
	local s : di %5.3f `se'
	local s = trim("`s'")
	return local out = "(`s')"
end

cap program drop _fmt_N
program define _fmt_N, rclass
	args n
	local s : di %9.0fc `n'
	local s = trim("`s'")
	return local out = "`s'"
end

cap program drop _fmt_F
program define _fmt_F, rclass
	args f
	local s : di %9.2f `f'
	local s = trim("`s'")
	return local out = "`s'"
end

//==============================================================================
// Programa principal: prg_table_3panels
//==============================================================================
cap program drop prg_table_3panels
program define prg_table_3panels
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
		[ outcome_qualifier(string) note_extra(string) ROBustez ]

	// Construcción del prefijo "Robustez. " y del paréntesis aclaratorio.
	local prefix_str = cond("`robustez'" != "", "Robustez. ", "")
	local qual_str   = cond(`"`outcome_qualifier'"' != "", " (`outcome_qualifier')", "")
	local extra_str  = cond(`"`note_extra'"' != "", " `note_extra'", "")

	// Estilos visuales (constantes de identidad BID, no son insumos analíticos
	// del usuario — sí van fijos dentro del programa).
	local font_main "Roboto"
	local size_m    9.5
	local size_n    8

	// El programa NO carga ni transforma data: asume que el caller ya dejó en
	// memoria el panel balanceado con `outcome', `z_var', `dc_var', `pi_var',
	// `post_var', `controls', `absorb' y `cluster' construidos. Su única
	// responsabilidad: dado ese insumo, estimar, almacenar y desplegar la tabla.
	// El check de ${ruta_helpers} se mantiene porque el post-process del XML
	// (Step 6) sí necesita el path del helper PowerShell.
	if "${ruta_helpers}" == "" {
		di as error "Global \${ruta_helpers} no está definido. El caller debe"
		di as error "haber hecho `qui include \"\${CONSULT}\\BID\\HRC0052956\\2_Scripts\\A_master.do\"`."
		exit 198
	}

	//==========================================================================
	// Step 1: Estimaciones — almacenadas en locales
	//==========================================================================
	// Convención de macros: `<param>_<estimador>_<spec>` donde:
	//   <param>     ∈ {b, se, p, F, N, Nc}
	//   <estimador> ∈ {itt, lc, li, did}
	//   <spec>      ∈ {1, 2}  (1 = sin controles; 2 = con controles)
	tempname fs_lc fs_li
	forvalues s = 1/2 {
		if `s' == 1 local ctrls ""
		if `s' == 2 local ctrls "`controls'"

		// Panel A.1 — ITT-OLS (cross-section follow-up, post_var==1)
		qui areg `outcome' i.`z_var' `ctrls' if `post_var'==1, ///
			a(`absorb') cl(`cluster')
		local b_itt_`s'  = _b[1.`z_var']
		local se_itt_`s' = _se[1.`z_var']
		local p_itt_`s'  = 2*ttail(e(df_r), abs(`b_itt_`s'' / `se_itt_`s''))
		local N_itt_`s'  = e(N)
		local Nc_itt_`s' = e(N_clust)

		// Panel A.2 — LATE-cluster (cross-section follow-up, post_var==1)
		// ivregress 2sls no almacena e(widstat) (eso es de ivreg2/ivreghdfe).
		// El F de primera etapa cluster-robusto se obtiene vía `estat firststage`,
		// matriz r(singleresults) columna 4 (F-stat).
		qui ivregress 2sls `outcome' (`dc_var' = i.`z_var') `ctrls' ///
			if `post_var'==1, absorb(`absorb') cluster(`cluster')
		local b_lc_`s'  = _b[`dc_var']
		local se_lc_`s' = _se[`dc_var']
		local p_lc_`s'  = 2*ttail(e(N_clust)-1, abs(`b_lc_`s'' / `se_lc_`s''))
		local N_lc_`s'  = e(N)
		local Nc_lc_`s' = e(N_clust)
		qui estat firststage
		mat `fs_lc' = r(singleresults)
		local F_lc_`s' = `fs_lc'[1, 4]

		// Panel A.3 — LATE-individual (cross-section follow-up, post_var==1)
		qui ivregress 2sls `outcome' (`pi_var' = i.`z_var') `ctrls' ///
			if `post_var'==1, absorb(`absorb') cluster(`cluster')
		local b_li_`s'  = _b[`pi_var']
		local se_li_`s' = _se[`pi_var']
		local p_li_`s'  = 2*ttail(e(N_clust)-1, abs(`b_li_`s'' / `se_li_`s''))
		local N_li_`s'  = e(N)
		local Nc_li_`s' = e(N_clust)
		qui estat firststage
		mat `fs_li' = r(singleresults)
		local F_li_`s' = `fs_li'[1, 4]

		// Panel B — ITT-DiD (panel balanceado LB + LS)
		qui areg `outcome' i.`z_var'##i.`post_var' `ctrls', ///
			a(`absorb') cl(`cluster')
		local b_did_`s'  = _b[1.`z_var'#1.`post_var']
		local se_did_`s' = _se[1.`z_var'#1.`post_var']
		local p_did_`s'  = 2*ttail(e(df_r), abs(`b_did_`s'' / `se_did_`s''))
		local N_did_`s'  = e(N)
		local Nc_did_`s' = e(N_clust)
	}

	// Panel C — Descriptivos del outcome por grupo × periodo
	qui summ `outcome' if `z_var'==0 & `post_var'==0
	local m_c0 = r(mean)
	qui summ `outcome' if `z_var'==0 & `post_var'==1
	local m_c1 = r(mean)
	qui summ `outcome' if `z_var'==1 & `post_var'==0
	local m_t0 = r(mean)
	qui summ `outcome' if `z_var'==1 & `post_var'==1
	local m_t1 = r(mean)
	local d_c = `m_c1' - `m_c0'
	local d_t = `m_t1' - `m_t0'

	//==========================================================================
	// Step 2: Pre-formatear strings (con stars y trim())
	//==========================================================================
	// Los helpers de formato (_fmt_b, _fmt_se, _fmt_N, _fmt_F) están definidos
	// al top level de este archivo. Quedan disponibles tras `do prg_table_3panels.do`.

	// Panel A (6 cols × 2 specs)
	forvalues s = 1/2 {
		_fmt_b `b_itt_`s'' `p_itt_`s''
		local s_b_itt_`s'  = r(out)
		_fmt_b `b_lc_`s''  `p_lc_`s''
		local s_b_lc_`s'   = r(out)
		_fmt_b `b_li_`s''  `p_li_`s''
		local s_b_li_`s'   = r(out)
		_fmt_se `se_itt_`s''
		local s_se_itt_`s' = r(out)
		_fmt_se `se_lc_`s''
		local s_se_lc_`s'  = r(out)
		_fmt_se `se_li_`s''
		local s_se_li_`s'  = r(out)
		_fmt_F  `F_lc_`s''
		local s_F_lc_`s'   = r(out)
		_fmt_F  `F_li_`s''
		local s_F_li_`s'   = r(out)
		_fmt_N  `N_itt_`s''
		local s_N_itt_`s'  = r(out)
		_fmt_N  `N_lc_`s''
		local s_N_lc_`s'   = r(out)
		_fmt_N  `N_li_`s''
		local s_N_li_`s'   = r(out)
		_fmt_N  `Nc_itt_`s''
		local s_Nc_itt_`s' = r(out)
		_fmt_N  `Nc_lc_`s''
		local s_Nc_lc_`s'  = r(out)
		_fmt_N  `Nc_li_`s''
		local s_Nc_li_`s'  = r(out)
	}

	// Panel B (2 cols)
	forvalues s = 1/2 {
		_fmt_b `b_did_`s'' `p_did_`s''
		local s_b_did_`s'  = r(out)
		_fmt_se `se_did_`s''
		local s_se_did_`s' = r(out)
		_fmt_N  `N_did_`s''
		local s_N_did_`s'  = r(out)
		_fmt_N  `Nc_did_`s''
		local s_Nc_did_`s' = r(out)
	}

	// Panel C (medias y deltas)
	local s_m_c0 : di %9.3f `m_c0'
	local s_m_c0 = trim("`s_m_c0'")
	local s_m_c1 : di %9.3f `m_c1'
	local s_m_c1 = trim("`s_m_c1'")
	local s_m_t0 : di %9.3f `m_t0'
	local s_m_t0 = trim("`s_m_t0'")
	local s_m_t1 : di %9.3f `m_t1'
	local s_m_t1 = trim("`s_m_t1'")
	local s_d_c  : di %9.3f `d_c'
	local s_d_c  = trim("`s_d_c'")
	local s_d_t  : di %9.3f `d_t'
	local s_d_t  = trim("`s_d_t'")

	//==========================================================================
	// Step 3: Construir el .docx con UNA sola tabla manual (estilo D4)
	//==========================================================================
	// Crear la carpeta de output si no existe
	local outdir = substr("`out'", 1, strrpos("`out'", "/") - 1)
	if "`outdir'" == "" {
		local outdir = substr("`out'", 1, strrpos("`out'", "\") - 1)
	}
	cap mkdir "`outdir'"

	putdocx clear
	putdocx begin, pagesize(A4) ///
		margin(left, 1.0) margin(right, 1.0) ///
		margin(top, 0.8)  margin(bottom, 0.8)

	// --- Título principal ---
	putdocx paragraph, halign(left) spacing(after, 0)
	putdocx text ("Tabla `table_num' — `prefix_str'Efecto del programa de ECAs sobre `outcome_phrase'`qual_str'"), bold ///
		font("`font_main'", `size_m')

	// --- Crear tabla 21x7 sin bordes default ---
	// Matriz de anchos como % del ancho de página. Suma = EXACTAMENTE 100.
	// Label col 28% + 6 cols × 12% = 28 + 72 = 100.
	tempname T_widths
	mat `T_widths' = (28, 12, 12, 12, 12, 12, 12)
	putdocx table T = (21, 7), border(all, nil) layout(autofitwindow) ///
		width(`T_widths')

	// =============================================================
	// PANEL A — Cross-section (filas 1-9)
	// =============================================================
	// Fila 1: Separator gris (colspan 7). Doble línea arriba = inicio de tabla.
	putdocx table T(1, 1), colspan(7) shading(211 210 209) ///
		border(top, double, "black", 1.5)
	putdocx table T(1, 1) = ("Panel A — Sección Cruzada — Línea de Seguimiento"), ///
		italic bold font("`font_main'", `size_m') halign(left)

	// Fila 2: Super-header BID — | ITT-OLS (cs2) | LATE-cluster (cs2) | LATE-individual (cs2)
	// Stata putdocx renumera columnas tras cada colspan; merges en reverse order.
	putdocx table T(2, 6) = ("LATE-individual"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(2, 6), colspan(2) shading(0 78 112)
	putdocx table T(2, 4) = ("LATE-clúster"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(2, 4), colspan(2) shading(0 78 112)
	putdocx table T(2, 2) = ("ITT-OLS"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(2, 2), colspan(2) shading(0 78 112)
	putdocx table T(2, 1), shading(0 78 112)

	// Fila 3: Sub-header BID — | (1) | (2) | (3) | (4) | (5) | (6)
	putdocx table T(3, 1), shading(0 78 112) border(bottom, single)
	forvalues i = 1/6 {
		local c = `i' + 1
		putdocx table T(3, `c'), shading(0 78 112) border(bottom, single)
		putdocx table T(3, `c') = ("(`i')"), bold font("`font_main'", `size_m', "white") halign(center)
	}

	// Fila 4: Coef.
	putdocx table T(4, 1) = ("Coef."), font("`font_main'", `size_m') halign(left)
	putdocx table T(4, 2) = ("`s_b_itt_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 3) = ("`s_b_itt_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 4) = ("`s_b_lc_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 5) = ("`s_b_lc_2'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 6) = ("`s_b_li_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 7) = ("`s_b_li_2'"),  font("`font_main'", `size_m') halign(center)

	// Fila 5: Err. Est.
	putdocx table T(5, 1) = ("Err. Est."), font("`font_main'", `size_m') halign(left)
	putdocx table T(5, 2) = ("`s_se_itt_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 3) = ("`s_se_itt_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 4) = ("`s_se_lc_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 5) = ("`s_se_lc_2'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 6) = ("`s_se_li_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 7) = ("`s_se_li_2'"),  font("`font_main'", `size_m') halign(center)

	// Fila 6: F primera etapa (solo LATE). Línea fina arriba separa Coef/SE de los stats.
	putdocx table T(6, 1) = ("F primera etapa"), font("`font_main'", `size_m') halign(left) border(top, single)
	putdocx table T(6, 2), border(top, single)
	putdocx table T(6, 3), border(top, single)
	putdocx table T(6, 4) = ("`s_F_lc_1'"), font("`font_main'", `size_m') halign(center) border(top, single)
	putdocx table T(6, 5) = ("`s_F_lc_2'"), font("`font_main'", `size_m') halign(center) border(top, single)
	putdocx table T(6, 6) = ("`s_F_li_1'"), font("`font_main'", `size_m') halign(center) border(top, single)
	putdocx table T(6, 7) = ("`s_F_li_2'"), font("`font_main'", `size_m') halign(center) border(top, single)

	// Fila 7: Observaciones (sección cruzada de línea de seguimiento)
	putdocx table T(7, 1) = ("Observaciones"), font("`font_main'", `size_m') halign(left)
	putdocx table T(7, 2) = ("`s_N_itt_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 3) = ("`s_N_itt_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 4) = ("`s_N_lc_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 5) = ("`s_N_lc_2'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 6) = ("`s_N_li_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 7) = ("`s_N_li_2'"),  font("`font_main'", `size_m') halign(center)

	// Fila 8: # Clusters
	putdocx table T(8, 1) = ("# Clústeres"), font("`font_main'", `size_m') halign(left)
	putdocx table T(8, 2) = ("`s_Nc_itt_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 3) = ("`s_Nc_itt_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 4) = ("`s_Nc_lc_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 5) = ("`s_Nc_lc_2'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 6) = ("`s_Nc_li_1'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 7) = ("`s_Nc_li_2'"),  font("`font_main'", `size_m') halign(center)

	// Fila 9: Controles
	putdocx table T(9, 1) = ("Controles"), font("`font_main'", `size_m') halign(left)
	putdocx table T(9, 2) = ("No"), font("`font_main'", `size_m') halign(center)
	putdocx table T(9, 3) = ("Sí"), font("`font_main'", `size_m') halign(center)
	putdocx table T(9, 4) = ("No"), font("`font_main'", `size_m') halign(center)
	putdocx table T(9, 5) = ("Sí"), font("`font_main'", `size_m') halign(center)
	putdocx table T(9, 6) = ("No"), font("`font_main'", `size_m') halign(center)
	putdocx table T(9, 7) = ("Sí"), font("`font_main'", `size_m') halign(center)

	// =============================================================
	// PANEL B — Diferencias en Diferencias (filas 10-16)
	// =============================================================
	// Fila 10: Separator gris. Doble línea SOLO arriba.
	putdocx table T(10, 1), colspan(7) shading(211 210 209) ///
		border(top, double, "black", 1.5)
	putdocx table T(10, 1) = ("Panel B — Datos de Panel Balanceado"), ///
		italic bold font("`font_main'", `size_m') halign(left)

	// Fila 11: Super-header BID — | (7) ITT-DiD (cs3) | (8) ITT-DiD (cs3)
	putdocx table T(11, 5) = ("(8)  ITT-DiD"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(11, 5), colspan(3) shading(0 78 112) border(bottom, single)
	putdocx table T(11, 2) = ("(7)  ITT-DiD"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(11, 2), colspan(3) shading(0 78 112) border(bottom, single)
	putdocx table T(11, 1), shading(0 78 112) border(bottom, single)

	// Fila 12: Coef.
	putdocx table T(12, 5) = ("`s_b_did_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(12, 5), colspan(3)
	putdocx table T(12, 2) = ("`s_b_did_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(12, 2), colspan(3)
	putdocx table T(12, 1) = ("Coef."), font("`font_main'", `size_m') halign(left)

	// Fila 13: Err. Est.
	putdocx table T(13, 5) = ("`s_se_did_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(13, 5), colspan(3)
	putdocx table T(13, 2) = ("`s_se_did_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(13, 2), colspan(3)
	putdocx table T(13, 1) = ("Err. Est."), font("`font_main'", `size_m') halign(left)

	// Fila 14: Observaciones (panel balanceado). Línea fina arriba.
	putdocx table T(14, 5) = ("`s_N_did_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(14, 5), colspan(3)
	putdocx table T(14, 2) = ("`s_N_did_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(14, 2), colspan(3)
	putdocx table T(14, 1) = ("Observaciones"), font("`font_main'", `size_m') halign(left)
	// border(top, single) post-merge en los índices renumerados
	putdocx table T(14, 1), border(top, single)
	putdocx table T(14, 2), border(top, single)
	putdocx table T(14, 3), border(top, single)

	// Fila 15: # Clusters
	putdocx table T(15, 5) = ("`s_Nc_did_2'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(15, 5), colspan(3)
	putdocx table T(15, 2) = ("`s_Nc_did_1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(15, 2), colspan(3)
	putdocx table T(15, 1) = ("# Clústeres"), font("`font_main'", `size_m') halign(left)

	// Fila 16: Controles
	putdocx table T(16, 5) = ("Sí"), font("`font_main'", `size_m') halign(center)
	putdocx table T(16, 5), colspan(3)
	putdocx table T(16, 2) = ("No"), font("`font_main'", `size_m') halign(center)
	putdocx table T(16, 2), colspan(3)
	putdocx table T(16, 1) = ("Controles"), font("`font_main'", `size_m') halign(left)

	// =============================================================
	// PANEL C — Descriptivos (filas 17-20)
	// =============================================================
	// Fila 17: Separator gris. Doble línea SOLO arriba.
	putdocx table T(17, 1), colspan(7) shading(211 210 209) ///
		border(top, double, "black", 1.5)
	putdocx table T(17, 1) = ("Descriptivos de Variable Resultado"), ///
		italic bold font("`font_main'", `size_m') halign(left)

	// Fila 18: Super-header BID — | t = 0 (cs2) | t = 1 (cs2) | Δ (t=1−t=0) (cs2)
	putdocx table T(18, 6) = ("Δ (t=1 − t=0)"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(18, 6), colspan(2) shading(0 78 112) border(bottom, single)
	putdocx table T(18, 4) = ("t = 1"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(18, 4), colspan(2) shading(0 78 112) border(bottom, single)
	putdocx table T(18, 2) = ("t = 0"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(18, 2), colspan(2) shading(0 78 112) border(bottom, single)
	putdocx table T(18, 1), shading(0 78 112) border(bottom, single)

	// Fila 19: Media | Control
	putdocx table T(19, 6) = ("`s_d_c'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(19, 6), colspan(2)
	putdocx table T(19, 4) = ("`s_m_c1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(19, 4), colspan(2)
	putdocx table T(19, 2) = ("`s_m_c0'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(19, 2), colspan(2)
	putdocx table T(19, 1) = ("Media | Control"), font("`font_main'", `size_m') halign(left)

	// Fila 20: Media | Tratado. Doble línea abajo = fin del data block.
	putdocx table T(20, 6) = ("`s_d_t'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(20, 6), colspan(2) border(bottom, double, "black", 1.5)
	putdocx table T(20, 4) = ("`s_m_t1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(20, 4), colspan(2) border(bottom, double, "black", 1.5)
	putdocx table T(20, 2) = ("`s_m_t0'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(20, 2), colspan(2) border(bottom, double, "black", 1.5)
	putdocx table T(20, 1) = ("Media | Tratado"), font("`font_main'", `size_m') halign(left)

	// =============================================================
	// FILA 21: Notas al pie (embedded como colspan 7)
	// =============================================================
	// border(top, double) refuerza la línea de cierre desde el lado de las notas.
	// halign(justify) NO se puede aplicar en cell content (Stata putdocx no lo
	// admite); se inyecta vía XML post-process en fix_table_borders.ps1.
	// Plantilla canónica de notas (5 oraciones). Oraciones 1, 4 y 5 son comunes
	// a los tres helpers; oraciones 2 y 3 son específicas de prg_table_3panels.
	local n1 "Esta tabla reporta el efecto del programa de Escuelas de Campo Agrícolas (ECAs) sobre `outcome_phrase'`qual_str'.`extra_str'"
	local n2 "Las columnas (1)-(2) estiman la intención de tratamiento (ITT) por OLS en la línea de seguimiento; las columnas (3)-(4), la misma ITT por diferencias en diferencias (DiD) sobre el panel balanceado; las columnas (5)-(6) y (7)-(8), el efecto promedio local del tratamiento (LATE) por 2SLS, usando la asignación aleatoria del centro poblado como instrumento de, respectivamente, la implementación efectiva de la ECA en el centro poblado y la participación individual del productor. En cada par, la columna impar omite controles y la par los incluye."
	local n3 "El bloque al pie (Descriptivos) reporta las medias de la variable de resultado por grupo y periodo sobre el panel balanceado."
	local n4 "Todas las especificaciones incluyen efectos fijos de diseño (estrato región-cultivo principal) y mes de encuesta; los controles son las covariables de línea base del productor, su hogar y su predio."
	local n5 "Los errores estándar, agrupados a nivel de centro poblado, se reportan entre paréntesis. * p<0.10, ** p<0.05, *** p<0.01."
	local nota_text "Notas. `n1' `n2' `n3' `n4' `n5'"

	putdocx table T(21, 1) = ("`nota_text'"), colspan(7) ///
		border(top, double, "black", 1.5) ///
		italic font("`font_main'", `size_n')

	// =============================================================
	// Alineación final
	// =============================================================
	// Col 1 (labels de fila)        → halign(left)   + valign(center)
	// Cols 2-7 (headers y valores)  → halign(center) + valign(center)
	// Excluye filas 1, 10, 17 (separators) y 21 (notas) que mantienen su
	// alineación original.
	forvalues r = 1/21 {
		if !inlist(`r', 1, 10, 17, 21) {
			cap putdocx table T(`r', 1), halign(left) valign(center)
			forvalues c = 2/7 {
				cap putdocx table T(`r', `c'), halign(center) valign(center)
			}
		}
	}

	//==========================================================================
	// Step 4: Guardar y post-procesar
	//==========================================================================
	putdocx save "`out'", replace

	// Post-process del XML para engrosar las dobles líneas (w:sz="6" = 0.75pt)
	// e inyectar halign(justify) en la cell de notas.
	shell powershell -NoProfile -ExecutionPolicy Bypass ///
		-File "${ruta_helpers}/fix_table_borders.ps1" "`out'"

	di as text "Archivo guardado: " as result "`out'"
	// El programa no carga ni modifica el dataset (solo areg/ivregress/summarize,
	// que no alteran la data), así que no hace falta preserve/restore.
end
