//------------------------------------------------------------------------------
// File           : _helpers/prg_table_4panels.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Description    : Programa reusable que genera una tabla docx de 4 paneles
//                  (uno por grupo de cultivo: Combinado / Cítricos / Papa /
//                  Plátano u otro corte definido por el caller) para DOS
//                  variables resultado (filas) estimadas con TRES estimadores
//                  × DOS specs (sin/con controles) = 6 columnas. Cada panel
//                  contiene además un sub-bloque compacto de descriptivos en
//                  escala original de la variable resultado (media y DE para
//                  asignados y no asignados). Invocable desde G1 del pipeline.
//                  Estilo visual: estilo D4 (separators grises con label de
//                  panel en italic-bold, header BID azul, línea fina entre
//                  Coef-SE y stats, doble línea en inicio/fin/antes-de-panel).
//
// Estructura de la tabla (57 filas × 7 columnas):
//   Por cada panel p ∈ {1, 2, 3, 4} (14 filas):
//     Fila base = (p-1)*14
//     Fila +1 : SEP GRIS  — "Panel <X> — <panel_lbl>" (colspan 7)
//     Fila +2 : BID HDR   — | ITT-OLS (cs2) | LATE-cluster (cs2) | LATE-individual (cs2)
//     Fila +3 : BID HDR   — | (1) | (2) | (3) | (4) | (5) | (6)
//     Fila +4 : Coef. (out1)         — 6 cells
//     Fila +5 : E.E.  (out1)         — 6 cells
//     Fila +6 : Coef. (out2)         — 6 cells
//     Fila +7 : E.E.  (out2)         — 6 cells
//     Fila +8 : F primera etapa      — . . F F F F (top single)
//     Fila +9 : N (productores)      — 6 N's
//     Fila +10: # Clusters           — 6 C's
//     Fila +11: Controles            — No Sí No Sí No Sí
//     Fila +12: SUB-HDR descriptivos — "Descriptivos — Escala Original" (cs7, top single, italic)
//     Fila +13: Asign.               — cadena compacta cs7 con M (DE) de los 2 outcomes
//     Fila +14: No asign.            — cadena compacta cs7 con M (DE) de los 2 outcomes
//   Fila 57: NOTAS — colspan 7, halign(justify) post-process
//
// Contrato: idéntico a prg_table_3panels y prg_table_2panels. El programa NO
// carga ni transforma data. Asume que el caller ya dejó en memoria la base
// con TODAS las variables construidas (outcomes std + raw + D_c + P_i + FE +
// controles) y ya pre-filtrada al universo de análisis (ej. post==1).
// Cada panel se estima sobre la sub-muestra definida por su `panel_cond`.
//
// Sintaxis:
//   prg_table_4panels, ///
//       out1(varname) raw1(varname) ///
//       out2(varname) raw2(varname) ///
//       title_phrase("string") ///
//       panel1_lbl("string") panel1_cond("string") ///
//       panel2_lbl("string") panel2_cond("string") ///
//       panel3_lbl("string") panel3_cond("string") ///
//       panel4_lbl("string") panel4_cond("string") ///
//       table_num("string") out("filepath") ///
//       z_var(varname) dc_var(varname) pi_var(varname) ///
//       controls("string") absorb(varname) cluster(varname) ///
//       [ title_qualifier("string") robustez ]
//
// Argumentos requeridos:
//   out1 / out2            Outcomes (típicamente estandarizados) — uno por fila.
//                          Las etiquetas internas (filas Coef. — <var>, sub-bloque
//                          de descriptivos) se leen del `: variable label' de cada
//                          uno; el caller debe declarar esos labels con `lab var'.
//   raw1 / raw2            Outcomes en escala ORIGINAL (para descriptivos).
//   title_phrase           Frase nominal en español que completa "Efecto del
//                          programa de ECAs sobre <title_phrase>" en el título y
//                          en la oración 1 de la nota. Combina ambos outcomes
//                          en una sola frase. Ej.: "los puntajes del test de
//                          conocimientos agronómicos".
//   panelK_lbl             Label del panel K ∈ {1..4} (ej. "Pooled", "Cítricos").
//   panelK_cond            Condición Stata que define la sub-muestra del panel K
//                          (ej. "1" para Pooled, "prod_ECA_eval==26" para Cítricos).
//                          Se aplica como `if `cond'` en cada regresión.
//   table_num              Numeración de la tabla (ej. "8.1-1").
//   out                    Path absoluto del archivo .docx output.
//   z_var                  Instrumento / variable de asignación aleatoria.
//   dc_var                 Variable de implementación a nivel cluster (binaria).
//                          Endógena instrumentada por z_var en LATE-cluster.
//   pi_var                 Variable de participación individual (binaria).
//                          Endógena instrumentada por z_var en LATE-individual.
//   controls               Set de controles (puede incluir factors como i.mes_enc).
//   absorb                 Variable de efectos fijos a absorber (ej. cod_rgn_PE).
//   cluster                Variable de clusterización (ej. cod_cpb).
//
// Argumentos opcionales:
//   title_qualifier        Texto que se renderiza entre paréntesis al final del
//                          título y al final de la oración 1 de la nota. Útil
//                          para desglose del outcome o submuestra. Ej.:
//                          "puntaje total y sección BPA".
//   robustez               Modifier. Antepone "Robustez. " al prefijo del título.
//                          Usar solo cuando la tabla sea (a) una versión
//                          alternativa del outcome respecto al cuerpo principal,
//                          o (b) sobre una subpoblación distinta a la del cuerpo.
//
// Dependencias:
//   - Global ${ruta_helpers} (definido por A_master.do) para el post-process.
//   - Helper PowerShell ${ruta_helpers}/fix_table_borders.ps1
//   - Data ya cargada en memoria por el caller.
//   - Helpers _fmt_b, _fmt_se, _fmt_N, _fmt_F: definidos en prg_table_3panels.do.
//     Este archivo los redefine como fallback para uso independiente.
//------------------------------------------------------------------------------

//==============================================================================
// Helper programs — replicados como fallback (idem prg_table_2panels)
//==============================================================================
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
// Programa principal: prg_table_4panels
//==============================================================================
cap program drop prg_table_4panels
program define prg_table_4panels
	syntax , ///
		out1(varname)      raw1(varname)                       ///
		out2(varname)      raw2(varname)                       ///
		title_phrase(string)                                   ///
		panel1_lbl(string) panel1_cond(string)                 ///
		panel2_lbl(string) panel2_cond(string)                 ///
		panel3_lbl(string) panel3_cond(string)                 ///
		panel4_lbl(string) panel4_cond(string)                 ///
		table_num(string)  out(string)                         ///
		z_var(varname)     dc_var(varname)    pi_var(varname)  ///
		controls(string)   absorb(varname)    cluster(varname) ///
		[ title_qualifier(string) note_extra(string) ROBustez ]

	// Construcción del prefijo "Robustez. ", del paréntesis aclaratorio y de
	// la oración extra de nota.
	local prefix_str = cond("`robustez'" != "", "Robustez. ", "")
	local qual_str   = cond(`"`title_qualifier'"' != "", " (`title_qualifier')", "")
	local extra_str  = cond(`"`note_extra'"' != "", " `note_extra'", "")

	// Etiquetas internas para filas Coef. — <var> y sub-bloque de descriptivos.
	// Se leen del `: variable label' de cada outcome (el caller los declara
	// con `lab var' antes de invocar el helper).
	local out1_lbl : variable label `out1'
	local out2_lbl : variable label `out2'

	// Estilos visuales (constantes BID — mismas que prg_table_3panels).
	local font_main "Roboto"
	local size_m    9.5
	local size_n    8

	if "${ruta_helpers}" == "" {
		di as error "Global \${ruta_helpers} no está definido. El caller debe"
		di as error "haber hecho `qui include \"\${CONSULT}\\BID\\HRC0052956\\2_Scripts\\A_master.do\"`."
		exit 198
	}

	//==========================================================================
	// Step 1: Estimaciones — loop sobre 4 paneles × 2 specs × {ITT, LC, LI} × 2 outcomes
	//==========================================================================
	// Convención de macros: `<param>_<estim>_<outcome>_p<P>_s<S>` donde:
	//   <param>   ∈ {b, se, p, N, Nc, F}
	//   <estim>   ∈ {itt, lc, li}
	//   <outcome> ∈ {o1, o2}
	//   <P>       ∈ {1..4}    (panel)
	//   <S>       ∈ {1, 2}    (1 = sin controles; 2 = con controles)
	// F primera etapa se almacena sin <outcome> (idéntico al primer outcome) y sin <estim>=itt.
	tempname fs_lc fs_li
	forvalues p = 1/4 {
		local cond `panel`p'_cond'
		forvalues s = 1/2 {
			if `s' == 1 local ctrls ""
			if `s' == 2 local ctrls "`controls'"

			// --- ITT-OLS — outcome 1 ---
			qui areg `out1' i.`z_var' `ctrls' if `cond', ///
				a(`absorb') cl(`cluster')
			local b_itt_o1_p`p'_s`s'  = _b[1.`z_var']
			local se_itt_o1_p`p'_s`s' = _se[1.`z_var']
			local p_itt_o1_p`p'_s`s'  = 2*ttail(e(df_r), abs(`b_itt_o1_p`p'_s`s'' / `se_itt_o1_p`p'_s`s''))
			local N_itt_p`p'_s`s'     = e(N)
			local Nc_itt_p`p'_s`s'    = e(N_clust)

			// --- ITT-OLS — outcome 2 ---
			qui areg `out2' i.`z_var' `ctrls' if `cond', ///
				a(`absorb') cl(`cluster')
			local b_itt_o2_p`p'_s`s'  = _b[1.`z_var']
			local se_itt_o2_p`p'_s`s' = _se[1.`z_var']
			local p_itt_o2_p`p'_s`s'  = 2*ttail(e(df_r), abs(`b_itt_o2_p`p'_s`s'' / `se_itt_o2_p`p'_s`s''))

			// --- LATE-cluster — outcome 1 (también captura FS-F del panel) ---
			qui ivregress 2sls `out1' (`dc_var' = i.`z_var') `ctrls' ///
				if `cond', absorb(`absorb') cluster(`cluster')
			local b_lc_o1_p`p'_s`s'  = _b[`dc_var']
			local se_lc_o1_p`p'_s`s' = _se[`dc_var']
			local p_lc_o1_p`p'_s`s'  = 2*ttail(e(N_clust)-1, abs(`b_lc_o1_p`p'_s`s'' / `se_lc_o1_p`p'_s`s''))
			local N_lc_p`p'_s`s'     = e(N)
			local Nc_lc_p`p'_s`s'    = e(N_clust)
			qui estat firststage
			mat `fs_lc' = r(singleresults)
			local F_lc_p`p'_s`s' = `fs_lc'[1, 4]

			// --- LATE-cluster — outcome 2 ---
			qui ivregress 2sls `out2' (`dc_var' = i.`z_var') `ctrls' ///
				if `cond', absorb(`absorb') cluster(`cluster')
			local b_lc_o2_p`p'_s`s'  = _b[`dc_var']
			local se_lc_o2_p`p'_s`s' = _se[`dc_var']
			local p_lc_o2_p`p'_s`s'  = 2*ttail(e(N_clust)-1, abs(`b_lc_o2_p`p'_s`s'' / `se_lc_o2_p`p'_s`s''))

			// --- LATE-individual — outcome 1 (también captura FS-F del panel) ---
			qui ivregress 2sls `out1' (`pi_var' = i.`z_var') `ctrls' ///
				if `cond', absorb(`absorb') cluster(`cluster')
			local b_li_o1_p`p'_s`s'  = _b[`pi_var']
			local se_li_o1_p`p'_s`s' = _se[`pi_var']
			local p_li_o1_p`p'_s`s'  = 2*ttail(e(N_clust)-1, abs(`b_li_o1_p`p'_s`s'' / `se_li_o1_p`p'_s`s''))
			local N_li_p`p'_s`s'     = e(N)
			local Nc_li_p`p'_s`s'    = e(N_clust)
			qui estat firststage
			mat `fs_li' = r(singleresults)
			local F_li_p`p'_s`s' = `fs_li'[1, 4]

			// --- LATE-individual — outcome 2 ---
			qui ivregress 2sls `out2' (`pi_var' = i.`z_var') `ctrls' ///
				if `cond', absorb(`absorb') cluster(`cluster')
			local b_li_o2_p`p'_s`s'  = _b[`pi_var']
			local se_li_o2_p`p'_s`s' = _se[`pi_var']
			local p_li_o2_p`p'_s`s'  = 2*ttail(e(N_clust)-1, abs(`b_li_o2_p`p'_s`s'' / `se_li_o2_p`p'_s`s''))
		}

		// Descriptivos del outcome por panel (escala ORIGINAL: usa raw1/raw2)
		qui summ `raw1' if `z_var'==1 & `cond'
		local m_t_o1_p`p'  = r(mean)
		local sd_t_o1_p`p' = r(sd)
		qui summ `raw1' if `z_var'==0 & `cond'
		local m_c_o1_p`p'  = r(mean)
		local sd_c_o1_p`p' = r(sd)
		qui summ `raw2' if `z_var'==1 & `cond'
		local m_t_o2_p`p'  = r(mean)
		local sd_t_o2_p`p' = r(sd)
		qui summ `raw2' if `z_var'==0 & `cond'
		local m_c_o2_p`p'  = r(mean)
		local sd_c_o2_p`p' = r(sd)
	}

	//==========================================================================
	// Step 2: Pre-formatear strings (stars + trim)
	//==========================================================================
	forvalues p = 1/4 {
		forvalues s = 1/2 {
			foreach o in 1 2 {
				foreach est in itt lc li {
					_fmt_b `b_`est'_o`o'_p`p'_s`s'' `p_`est'_o`o'_p`p'_s`s''
					local s_b_`est'_o`o'_p`p'_s`s'  = r(out)
					_fmt_se `se_`est'_o`o'_p`p'_s`s''
					local s_se_`est'_o`o'_p`p'_s`s' = r(out)
				}
			}
			foreach est in itt lc li {
				_fmt_N  `N_`est'_p`p'_s`s''
				local s_N_`est'_p`p'_s`s'  = r(out)
				_fmt_N  `Nc_`est'_p`p'_s`s''
				local s_Nc_`est'_p`p'_s`s' = r(out)
			}
			foreach est in lc li {
				_fmt_F `F_`est'_p`p'_s`s''
				local s_F_`est'_p`p'_s`s' = r(out)
			}
		}
		foreach o in 1 2 {
			local s_m_t_o`o'_p`p'  : di %9.3f `m_t_o`o'_p`p''
			local s_m_t_o`o'_p`p'  = trim("`s_m_t_o`o'_p`p''")
			local s_m_c_o`o'_p`p'  : di %9.3f `m_c_o`o'_p`p''
			local s_m_c_o`o'_p`p'  = trim("`s_m_c_o`o'_p`p''")
			local s_sd_t_o`o'_p`p' : di %9.3f `sd_t_o`o'_p`p''
			local s_sd_t_o`o'_p`p' = trim("`s_sd_t_o`o'_p`p''")
			local s_sd_c_o`o'_p`p' : di %9.3f `sd_c_o`o'_p`p''
			local s_sd_c_o`o'_p`p' = trim("`s_sd_c_o`o'_p`p''")
		}
	}

	//==========================================================================
	// Step 3: Construir el .docx con UNA sola tabla manual (estilo D4)
	//==========================================================================
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
	putdocx text ("Tabla `table_num' — `prefix_str'Efecto del programa de ECAs sobre `title_phrase'`qual_str'"), bold ///
		font("`font_main'", `size_m')

	// --- Crear tabla 57x7 sin bordes default ---
	// Label col 28% + 6 cols × 12% = 100%. Mismos anchos que prg_table_3panels.
	tempname T_widths
	mat `T_widths' = (28, 12, 12, 12, 12, 12, 12)
	putdocx table T = (57, 7), border(all, nil) layout(autofitwindow) ///
		width(`T_widths')

	// =========================================================================
	// Loop sobre los 4 paneles. Cada panel ocupa 14 filas.
	// =========================================================================
	local panel_letters A B C D
	forvalues p = 1/4 {
		local base = (`p' - 1) * 14
		local L : word `p' of `panel_letters'
		local plbl `panel`p'_lbl'

		local r1  = `base' +  1
		local r2  = `base' +  2
		local r3  = `base' +  3
		local r4  = `base' +  4
		local r5  = `base' +  5
		local r6  = `base' +  6
		local r7  = `base' +  7
		local r8  = `base' +  8
		local r9  = `base' +  9
		local r10 = `base' + 10
		local r11 = `base' + 11
		local r12 = `base' + 12
		local r13 = `base' + 13
		local r14 = `base' + 14

		// --- Fila +1: Separator gris (colspan 7) con doble línea arriba.
		//     En panel 1 cierra el borde superior de la tabla; en paneles 2-4
		//     separa visualmente del bloque anterior. Mismo patrón que
		//     prg_table_3panels (filas 1, 10, 17).
		putdocx table T(`r1', 1), colspan(7) shading(211 210 209) ///
			border(top, double, "black", 1.5)
		putdocx table T(`r1', 1) = ("Panel `L' — `plbl'"), ///
			italic bold font("`font_main'", `size_m') halign(left)

		// --- Fila +2: Super-header BID — | ITT-OLS (cs2) | LATE-cluster (cs2) | LATE-individual (cs2)
		// Stata putdocx renumera columnas tras cada colspan; merges en reverse order.
		putdocx table T(`r2', 6) = ("LATE-individual"), bold font("`font_main'", `size_m', "white") halign(center)
		putdocx table T(`r2', 6), colspan(2) shading(0 78 112)
		putdocx table T(`r2', 4) = ("LATE-clúster"), bold font("`font_main'", `size_m', "white") halign(center)
		putdocx table T(`r2', 4), colspan(2) shading(0 78 112)
		putdocx table T(`r2', 2) = ("ITT-OLS"), bold font("`font_main'", `size_m', "white") halign(center)
		putdocx table T(`r2', 2), colspan(2) shading(0 78 112)
		putdocx table T(`r2', 1), shading(0 78 112)

		// --- Fila +3: Sub-header BID — | (1) | (2) | (3) | (4) | (5) | (6)
		putdocx table T(`r3', 1), shading(0 78 112) border(bottom, single)
		forvalues i = 1/6 {
			local c = `i' + 1
			putdocx table T(`r3', `c'), shading(0 78 112) border(bottom, single)
			putdocx table T(`r3', `c') = ("(`i')"), bold font("`font_main'", `size_m', "white") halign(center)
		}

		// --- Fila +4: Coef. (outcome 1)
		putdocx table T(`r4', 1) = ("Coef. — `out1_lbl'"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r4', 2) = ("`s_b_itt_o1_p`p'_s1'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r4', 3) = ("`s_b_itt_o1_p`p'_s2'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r4', 4) = ("`s_b_lc_o1_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r4', 5) = ("`s_b_lc_o1_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r4', 6) = ("`s_b_li_o1_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r4', 7) = ("`s_b_li_o1_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)

		// --- Fila +5: E.E. (outcome 1)
		putdocx table T(`r5', 1) = ("E.E."), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r5', 2) = ("`s_se_itt_o1_p`p'_s1'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r5', 3) = ("`s_se_itt_o1_p`p'_s2'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r5', 4) = ("`s_se_lc_o1_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r5', 5) = ("`s_se_lc_o1_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r5', 6) = ("`s_se_li_o1_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r5', 7) = ("`s_se_li_o1_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)

		// --- Fila +6: Coef. (outcome 2)
		putdocx table T(`r6', 1) = ("Coef. — `out2_lbl'"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r6', 2) = ("`s_b_itt_o2_p`p'_s1'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r6', 3) = ("`s_b_itt_o2_p`p'_s2'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r6', 4) = ("`s_b_lc_o2_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r6', 5) = ("`s_b_lc_o2_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r6', 6) = ("`s_b_li_o2_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r6', 7) = ("`s_b_li_o2_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)

		// --- Fila +7: E.E. (outcome 2)
		putdocx table T(`r7', 1) = ("E.E."), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r7', 2) = ("`s_se_itt_o2_p`p'_s1'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r7', 3) = ("`s_se_itt_o2_p`p'_s2'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r7', 4) = ("`s_se_lc_o2_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r7', 5) = ("`s_se_lc_o2_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r7', 6) = ("`s_se_li_o2_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r7', 7) = ("`s_se_li_o2_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)

		// --- Fila +8: F primera etapa (solo cols LATE). Línea fina arriba separa estimates/stats.
		putdocx table T(`r8', 1) = ("F primera etapa"), font("`font_main'", `size_m') halign(left) border(top, single)
		putdocx table T(`r8', 2), border(top, single)
		putdocx table T(`r8', 3), border(top, single)
		putdocx table T(`r8', 4) = ("`s_F_lc_p`p'_s1'"), font("`font_main'", `size_m') halign(center) border(top, single)
		putdocx table T(`r8', 5) = ("`s_F_lc_p`p'_s2'"), font("`font_main'", `size_m') halign(center) border(top, single)
		putdocx table T(`r8', 6) = ("`s_F_li_p`p'_s1'"), font("`font_main'", `size_m') halign(center) border(top, single)
		putdocx table T(`r8', 7) = ("`s_F_li_p`p'_s2'"), font("`font_main'", `size_m') halign(center) border(top, single)

		// --- Fila +9: Observaciones — varía por estimador (OLS vs IV pueden diferir)
		putdocx table T(`r9', 1) = ("Observaciones"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r9', 2) = ("`s_N_itt_p`p'_s1'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r9', 3) = ("`s_N_itt_p`p'_s2'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r9', 4) = ("`s_N_lc_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r9', 5) = ("`s_N_lc_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r9', 6) = ("`s_N_li_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r9', 7) = ("`s_N_li_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)

		// --- Fila +10: # Clusters
		putdocx table T(`r10', 1) = ("# Clústeres"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r10', 2) = ("`s_Nc_itt_p`p'_s1'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r10', 3) = ("`s_Nc_itt_p`p'_s2'"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r10', 4) = ("`s_Nc_lc_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r10', 5) = ("`s_Nc_lc_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r10', 6) = ("`s_Nc_li_p`p'_s1'"),  font("`font_main'", `size_m') halign(center)
		putdocx table T(`r10', 7) = ("`s_Nc_li_p`p'_s2'"),  font("`font_main'", `size_m') halign(center)

		// --- Fila +11: Controles
		putdocx table T(`r11', 1) = ("Controles"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r11', 2) = ("No"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r11', 3) = ("Sí"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r11', 4) = ("No"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r11', 5) = ("Sí"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r11', 6) = ("No"), font("`font_main'", `size_m') halign(center)
		putdocx table T(`r11', 7) = ("Sí"), font("`font_main'", `size_m') halign(center)

		// --- Fila +12: Título del sub-bloque de descriptivos.
		// Layout compacto cs7 (sin grid de cs3): el sub-bloque sale del
		// alineamiento de columnas estimadas y se renderiza como dos líneas
		// de texto con M (DE) de los dos outcomes separados por '|'.
		// Línea fina arriba separa stats/descriptivos.
		putdocx table T(`r12', 1), colspan(7) border(top, single)
		putdocx table T(`r12', 1) = ("Descriptivos — Escala Original"), ///
			italic font("`font_main'", `size_m') halign(left)

		// --- Fila +13: línea compacta de productores TRATADOS.
		// Se divide en dos celdas (col 1 + cs6 sobre cols 2-7) para alinear
		// la etiqueta "Tratado"/"Control" en una columna fija — Roboto es
		// proporcional y "Tratado"/"Control" con misma cantidad de chars
		// renderizan anchos visuales distintos, lo que desalinearía un
		// em-dash si todo estuviera en colspan(7).
		local desc_t = "`out1_lbl': `s_m_t_o1_p`p'' (`s_sd_t_o1_p`p'')   |   `out2_lbl': `s_m_t_o2_p`p'' (`s_sd_t_o2_p`p'')"
		putdocx table T(`r13', 2), colspan(6)
		putdocx table T(`r13', 1) = ("  Tratado"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r13', 2) = ("`desc_t'"), font("`font_main'", `size_m') halign(left)

		// --- Fila +14: línea compacta de productores CONTROL.
		//     En el ÚLTIMO panel cierra con doble línea abajo (post-merge, ambas cells).
		local desc_c = "`out1_lbl': `s_m_c_o1_p`p'' (`s_sd_c_o1_p`p'')   |   `out2_lbl': `s_m_c_o2_p`p'' (`s_sd_c_o2_p`p'')"
		putdocx table T(`r14', 2), colspan(6)
		putdocx table T(`r14', 1) = ("  Control"), font("`font_main'", `size_m') halign(left)
		putdocx table T(`r14', 2) = ("`desc_c'"), font("`font_main'", `size_m') halign(left)
		if `p' == 4 {
			putdocx table T(`r14', 1), border(bottom, double, "black", 1.5)
			putdocx table T(`r14', 2), border(bottom, double, "black", 1.5)
		}
	}

	// =========================================================================
	// FILA 57: Notas al pie (embedded como colspan 7)
	// =========================================================================
	// border(top, double) refuerza la línea de cierre desde el lado de las notas.
	// halign(justify) se inyecta vía XML post-process en fix_table_borders.ps1.
	// Plantilla canónica de notas (5 oraciones). 1, 4 y 5 son comunes a los tres
	// helpers; 2 y 3 son específicas de prg_table_4panels (paneles por cultivo
	// + descriptivos en escala original + estandarización dentro de cultivo).
	local n1 "Esta tabla reporta el efecto del programa de Escuelas de Campo Agrícolas (ECAs) sobre `title_phrase'`qual_str'.`extra_str'"
	local n2 "El Panel A combina los tres cultivos en una sola regresión; los Paneles B, C y D restringen la estimación a las submuestras de Cítricos, Papa y Plátano. Dentro de cada panel, las columnas (1)-(2) estiman la intención de tratamiento (ITT) por OLS y las columnas (3)-(4) y (5)-(6) el efecto promedio local del tratamiento (LATE) por 2SLS, usando la asignación aleatoria del centro poblado como instrumento de, respectivamente, la implementación efectiva de la ECA en el centro poblado y la participación individual del productor; en cada par, la columna impar omite controles y la par los incluye."
	local n3 "Todas las estimaciones se corren sobre la línea de seguimiento. Los puntajes se estandarizan dentro de cada cultivo —cada observación se divide por el desvío estándar del grupo de control de su propio cultivo—, de modo que los coeficientes se leen en desvíos estándar; el bloque 'Descriptivos — Escala Original' al pie reporta la media y el desvío estándar sin estandarizar, por grupo."
	local n4 "Todas las especificaciones incluyen efectos fijos de diseño (estrato región), mes de encuesta y las covariables de línea base del productor, su hogar y su predio."
	local n5 "Los errores estándar, agrupados a nivel de centro poblado, se reportan entre paréntesis. * p<0.10, ** p<0.05, *** p<0.01."
	local nota_text "Notas. `n1' `n2' `n3' `n4' `n5'"

	putdocx table T(57, 1) = ("`nota_text'"), colspan(7) ///
		border(top, double, "black", 1.5) ///
		italic font("`font_main'", `size_n')

	// =========================================================================
	// Alineación final
	// =========================================================================
	// Col 1 (labels)    → halign(left)   + valign(center)
	// Cols 2-7 (datos)  → halign(center) + valign(center)
	// Excluye: filas de separator (1, 15, 29, 43), filas del sub-bloque
	// compacto de descriptivos cs7 (12-14, 26-28, 40-42, 54-56) y la fila
	// de notas (57), que mantienen su alineación original.
	forvalues r = 1/57 {
		if !inlist(`r', 1, 15, 29, 43, 12, 13, 14, 26, 27, 28, 40, 41, 42, 54, 55, 56, 57) {
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

	// Post-process del XML (engrosa dobles líneas + inyecta halign(justify)
	// en la cell de notas). Mismo helper que prg_table_3panels/2panels.
	shell powershell -NoProfile -ExecutionPolicy Bypass ///
		-File "${ruta_helpers}/fix_table_borders.ps1" "`out'"

	di as text "Archivo guardado: " as result "`out'"
end
