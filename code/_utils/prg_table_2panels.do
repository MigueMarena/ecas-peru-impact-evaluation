//------------------------------------------------------------------------------
// File           : _utils/prg_table_2panels.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Description    : Programa reusable que genera una tabla docx de 2 paneles
//                  (Estimaciones / Descriptivos) condensada para anexo. A
//                  diferencia de prg_table_3panels, las 4 especificaciones
//                  (ITT-OLS, ITT-DiD, LATE-cluster, LATE-individual) se
//                  reportan en un único panel horizontal y solo en su versión
//                  CON controles. Es la presentación canónica para tablas
//                  anexas de robustez (vF/vE, criterios alternativos).
//                  Estilo visual: estilo D4 (separators grises con label de
//                  panel en italic-bold, header BID azul, línea fina entre
//                  Coef-SE y stats, doble línea en inicio/fin/antes-de-panel).
//
// Estructura de la tabla (13 filas × 5 columnas):
//   Fila  1: SEP GRIS  — "Panel A — Estimaciones (con controles)" (colspan 5)
//   Fila  2: BID HDR   — | ITT-OLS | ITT-DiD | LATE-cluster | LATE-individual
//   Fila  3: BID HDR   — | (1) | (2) | (3) | (4)
//   Filas 4-8          — datos Panel A (Coef / SE / FS-F / N / Nc)
//   Fila  9: SEP GRIS  — "Panel B — Descriptivos de Variable Resultado"
//   Fila 10: BID HDR   — | t = 0 | t = 1 | Δ (t=1−t=0) (cs2 sobre cols 4-5)
//   Filas 11-12        — datos Panel B (Media|Control, Media|Tratado)
//   Fila 13: NOTAS     — colspan 5, halign(justify) post-process
//
// Contrato: idéntico a prg_table_3panels. El programa NO carga ni transforma
// data. Asume que el caller ya dejó en memoria el panel balanceado con todas
// las variables construidas (incl. D_c y P_i). Su única responsabilidad:
// estimar las 4 specs (con controles) y desplegar la tabla.
//
// Sintaxis:
//   prg_table_2panels, ///
//       outcome(varname) outcome_phrase("string") ///
//       table_num("string") out("filepath") ///
//       z_var(varname) dc_var(varname) pi_var(varname) post_var(varname) ///
//       controls("string") absorb(varname) cluster(varname) ///
//       [ outcome_qualifier("string") robustez ]
//
// Argumentos: idénticos a prg_table_3panels (ver ese archivo).
//   Único cambio semántico: el argumento `controls' es OBLIGATORIO no-vacío
//   porque esta tabla solo reporta la spec con controles (sin loop s=1/s=2).
//   `robustez' aplica para tablas anexas que sean (a) versión alternativa del
//   outcome del cuerpo principal (uso típico: G5Ab vF, G5Ac vF) o (b) sobre
//   subpoblación distinta. Las tablas anexas de G2/G3/G4 NO la usan.
//
// Dependencias:
//   - Global ${ruta_utils} (definido por A_master.do) para el post-process.
//   - Helper PowerShell ${ruta_utils}/fix_table_borders.ps1
//   - Data ya cargada en memoria por el caller (ver prg_load_panel.do).
//   - Helpers _fmt_b, _fmt_se, _fmt_N, _fmt_F: definidos en prg_table_3panels.do.
//     El caller debe haber hecho `qui do prg_table_3panels.do` antes (o este
//     archivo, que también los redefine como fallback para uso independiente).
//------------------------------------------------------------------------------

//==============================================================================
// Helper programs — replicados como fallback en caso de que el caller use
// prg_table_2panels sin haber cargado prg_table_3panels antes. Si ya están
// definidos, `cap program drop` + `program define` los re-instancia sin error.
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
// Programa principal: prg_table_2panels
//==============================================================================
cap program drop prg_table_2panels
program define prg_table_2panels
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

	// Estilos visuales (constantes BID — mismas que prg_table_3panels).
	local font_main "Roboto"
	local size_m    9.5
	local size_n    8

	if "${ruta_utils}" == "" {
		di as error "Global \${ruta_utils} no está definido. El caller debe"
		di as error "hecho el bootstrap del entorno (ver A_master.do)."
		exit 198
	}

	if `"`controls'"' == "" {
		di as error "prg_table_2panels requiere controls() no-vacío:"
		di as error "esta tabla solo reporta la spec con controles. Para"
		di as error "tablas sin/con controles use prg_table_3panels."
		exit 198
	}

	// Construcción del prefijo "Robustez. ", del paréntesis aclaratorio y de
	// la oración extra de nota (detalle que el caller quitó del título para
	// mantenerlo bajo 20 palabras).
	local prefix_str = cond("`robustez'" != "", "Robustez. ", "")
	local qual_str   = cond(`"`outcome_qualifier'"' != "", " (`outcome_qualifier')", "")
	local extra_str  = cond(`"`note_extra'"' != "", " `note_extra'", "")

	//==========================================================================
	// Step 1: Estimaciones — solo con controles (4 specs en paralelo)
	//==========================================================================
	// Convención de macros: `<param>_<estimador>` donde:
	//   <param>     ∈ {b, se, p, F, N, Nc}
	//   <estimador> ∈ {itt, did, lc, li}
	tempname fs_lc fs_li
	local ctrls "`controls'"

	// Col 1 — ITT-OLS (cross-section follow-up, post_var==1)
	qui areg `outcome' i.`z_var' `ctrls' if `post_var'==1, ///
		a(`absorb') cl(`cluster')
	local b_itt  = _b[1.`z_var']
	local se_itt = _se[1.`z_var']
	local p_itt  = 2*ttail(e(df_r), abs(`b_itt' / `se_itt'))
	local N_itt  = e(N)
	local Nc_itt = e(N_clust)

	// Col 2 — ITT-DiD (panel balanceado LB + LS)
	qui areg `outcome' i.`z_var'##i.`post_var' `ctrls', ///
		a(`absorb') cl(`cluster')
	local b_did  = _b[1.`z_var'#1.`post_var']
	local se_did = _se[1.`z_var'#1.`post_var']
	local p_did  = 2*ttail(e(df_r), abs(`b_did' / `se_did'))
	local N_did  = e(N)
	local Nc_did = e(N_clust)

	// Col 3 — LATE-cluster (cross-section follow-up, post_var==1)
	qui ivregress 2sls `outcome' (`dc_var' = i.`z_var') `ctrls' ///
		if `post_var'==1, absorb(`absorb') cluster(`cluster')
	local b_lc  = _b[`dc_var']
	local se_lc = _se[`dc_var']
	local p_lc  = 2*ttail(e(N_clust)-1, abs(`b_lc' / `se_lc'))
	local N_lc  = e(N)
	local Nc_lc = e(N_clust)
	qui estat firststage
	mat `fs_lc' = r(singleresults)
	local F_lc = `fs_lc'[1, 4]

	// Col 4 — LATE-individual (cross-section follow-up, post_var==1)
	qui ivregress 2sls `outcome' (`pi_var' = i.`z_var') `ctrls' ///
		if `post_var'==1, absorb(`absorb') cluster(`cluster')
	local b_li  = _b[`pi_var']
	local se_li = _se[`pi_var']
	local p_li  = 2*ttail(e(N_clust)-1, abs(`b_li' / `se_li'))
	local N_li  = e(N)
	local Nc_li = e(N_clust)
	qui estat firststage
	mat `fs_li' = r(singleresults)
	local F_li = `fs_li'[1, 4]

	// Panel B — Descriptivos del outcome por grupo × periodo
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
	foreach est in itt did lc li {
		_fmt_b  `b_`est''  `p_`est''
		local s_b_`est'  = r(out)
		_fmt_se `se_`est''
		local s_se_`est' = r(out)
		_fmt_N  `N_`est''
		local s_N_`est'  = r(out)
		_fmt_N  `Nc_`est''
		local s_Nc_`est' = r(out)
	}
	_fmt_F `F_lc'
	local s_F_lc = r(out)
	_fmt_F `F_li'
	local s_F_li = r(out)

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

	// --- Crear tabla 13x5 sin bordes default ---
	// Anchos en % del ancho de página. Suma = 100.
	// Label col 32% + 4 cols × 17% = 32 + 68 = 100.
	tempname T_widths
	mat `T_widths' = (32, 17, 17, 17, 17)
	putdocx table T = (13, 5), border(all, nil) layout(autofitwindow) ///
		width(`T_widths')

	// =============================================================
	// PANEL A — Estimaciones con controles (filas 1-8)
	// =============================================================
	// Fila 1: Separator gris (colspan 5). Doble línea arriba = inicio de tabla.
	putdocx table T(1, 1), colspan(5) shading(211 210 209) ///
		border(top, double, "black", 1.5)
	putdocx table T(1, 1) = ("Panel A — Estimaciones (con controles)"), ///
		italic bold font("`font_main'", `size_m') halign(left)

	// Fila 2: Super-header BID — | ITT-OLS | ITT-DiD | LATE-cluster | LATE-individual
	// Sin colspans: 4 cols sencillas, una por estimador.
	putdocx table T(2, 1), shading(0 78 112)
	putdocx table T(2, 2) = ("ITT-OLS"),         bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(2, 2), shading(0 78 112)
	putdocx table T(2, 3) = ("ITT-DiD"),         bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(2, 3), shading(0 78 112)
	putdocx table T(2, 4) = ("LATE-clúster"),    bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(2, 4), shading(0 78 112)
	putdocx table T(2, 5) = ("LATE-individual"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(2, 5), shading(0 78 112)

	// Fila 3: Sub-header BID — | (1) | (2) | (3) | (4)
	putdocx table T(3, 1), shading(0 78 112) border(bottom, single)
	forvalues i = 1/4 {
		local c = `i' + 1
		putdocx table T(3, `c'), shading(0 78 112) border(bottom, single)
		putdocx table T(3, `c') = ("(`i')"), bold font("`font_main'", `size_m', "white") halign(center)
	}

	// Fila 4: Coef.
	putdocx table T(4, 1) = ("Coef."),       font("`font_main'", `size_m') halign(left)
	putdocx table T(4, 2) = ("`s_b_itt'"),   font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 3) = ("`s_b_did'"),   font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 4) = ("`s_b_lc'"),    font("`font_main'", `size_m') halign(center)
	putdocx table T(4, 5) = ("`s_b_li'"),    font("`font_main'", `size_m') halign(center)

	// Fila 5: Err. Est.
	putdocx table T(5, 1) = ("Err. Est."),   font("`font_main'", `size_m') halign(left)
	putdocx table T(5, 2) = ("`s_se_itt'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 3) = ("`s_se_did'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 4) = ("`s_se_lc'"),   font("`font_main'", `size_m') halign(center)
	putdocx table T(5, 5) = ("`s_se_li'"),   font("`font_main'", `size_m') halign(center)

	// Fila 6: F primera etapa (solo LATE — cols 4 y 5). Línea fina arriba.
	putdocx table T(6, 1) = ("F primera etapa"), font("`font_main'", `size_m') halign(left) border(top, single)
	putdocx table T(6, 2), border(top, single)
	putdocx table T(6, 3), border(top, single)
	putdocx table T(6, 4) = ("`s_F_lc'"), font("`font_main'", `size_m') halign(center) border(top, single)
	putdocx table T(6, 5) = ("`s_F_li'"), font("`font_main'", `size_m') halign(center) border(top, single)

	// Fila 7: Observaciones — N propio de cada modelo (DiD usa panel)
	putdocx table T(7, 1) = ("Observaciones"), font("`font_main'", `size_m') halign(left)
	putdocx table T(7, 2) = ("`s_N_itt'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 3) = ("`s_N_did'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 4) = ("`s_N_lc'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(7, 5) = ("`s_N_li'"),  font("`font_main'", `size_m') halign(center)

	// Fila 8: # Clusters
	putdocx table T(8, 1) = ("# Clústeres"), font("`font_main'", `size_m') halign(left)
	putdocx table T(8, 2) = ("`s_Nc_itt'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 3) = ("`s_Nc_did'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 4) = ("`s_Nc_lc'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(8, 5) = ("`s_Nc_li'"),  font("`font_main'", `size_m') halign(center)

	// =============================================================
	// PANEL B — Descriptivos (filas 9-12)
	// =============================================================
	// Fila 9: Separator gris. Doble línea SOLO arriba.
	putdocx table T(9, 1), colspan(5) shading(211 210 209) ///
		border(top, double, "black", 1.5)
	putdocx table T(9, 1) = ("Descriptivos de Variable Resultado"), ///
		italic bold font("`font_main'", `size_m') halign(left)

	// Fila 10: Super-header BID — | t = 0 | t = 1 | Δ (t=1−t=0) (cs2 sobre cols 4-5)
	// Stata putdocx renumera columnas tras colspan; merges en reverse order.
	putdocx table T(10, 4) = ("Δ (t=1 − t=0)"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(10, 4), colspan(2) shading(0 78 112) border(bottom, single)
	putdocx table T(10, 3) = ("t = 1"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(10, 3), shading(0 78 112) border(bottom, single)
	putdocx table T(10, 2) = ("t = 0"), bold font("`font_main'", `size_m', "white") halign(center)
	putdocx table T(10, 2), shading(0 78 112) border(bottom, single)
	putdocx table T(10, 1), shading(0 78 112) border(bottom, single)

	// Fila 11: Media | Control. Δ ocupa cols 4-5 fusionadas (cs2).
	putdocx table T(11, 4) = ("`s_d_c'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(11, 4), colspan(2)
	putdocx table T(11, 3) = ("`s_m_c1'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(11, 2) = ("`s_m_c0'"), font("`font_main'", `size_m') halign(center)
	putdocx table T(11, 1) = ("Media | Control"), font("`font_main'", `size_m') halign(left)

	// Fila 12: Media | Tratado. Doble línea abajo = fin del data block.
	putdocx table T(12, 4) = ("`s_d_t'"),  font("`font_main'", `size_m') halign(center)
	putdocx table T(12, 4), colspan(2) border(bottom, double, "black", 1.5)
	putdocx table T(12, 3) = ("`s_m_t1'"), font("`font_main'", `size_m') halign(center) border(bottom, double, "black", 1.5)
	putdocx table T(12, 2) = ("`s_m_t0'"), font("`font_main'", `size_m') halign(center) border(bottom, double, "black", 1.5)
	putdocx table T(12, 1) = ("Media | Tratado"), font("`font_main'", `size_m') halign(left) border(bottom, double, "black", 1.5)

	// =============================================================
	// FILA 13: Notas al pie (embedded como colspan 5)
	// =============================================================
	// Plantilla canónica de notas (5 oraciones). 1, 4 y 5 son comunes a los tres
	// helpers; 2 y 3 son específicas de prg_table_2panels (4 specs en horizontal
	// con controles + descriptivos al pie).
	local n1 "Esta tabla reporta el efecto del programa de Escuelas de Campo Agrícolas (ECAs) sobre `outcome_phrase'`qual_str'.`extra_str'"
	local n2 "La columna (1) estima la intención de tratamiento (ITT) por OLS en la línea de seguimiento; la columna (2), la misma ITT por diferencias en diferencias (DiD) sobre el panel balanceado. Las columnas (3) y (4) estiman el efecto promedio local del tratamiento (LATE) por 2SLS, usando la asignación aleatoria del centro poblado como instrumento de, respectivamente, la implementación efectiva de la ECA en el centro poblado y la participación individual del productor."
	local n3 "El bloque al pie reporta las medias de la variable de resultado por grupo y periodo, y su variación entre periodos."
	local n4 "Todas las especificaciones incluyen efectos fijos de diseño (estrato región-cultivo principal), mes de encuesta y las covariables de línea base del productor, su hogar y su predio."
	local n5 "Los errores estándar, agrupados a nivel de centro poblado, se reportan entre paréntesis. * p<0.10, ** p<0.05, *** p<0.01."
	local nota_text "Notas. `n1' `n2' `n3' `n4' `n5'"

	putdocx table T(13, 1) = ("`nota_text'"), colspan(5) ///
		border(top, double, "black", 1.5) ///
		italic font("`font_main'", `size_n')

	// =============================================================
	// Alineación final
	// =============================================================
	// Col 1 (labels de fila)        → halign(left)   + valign(center)
	// Cols 2-5 (headers y valores)  → halign(center) + valign(center)
	// Excluye filas 1, 9 (separators) y 13 (notas) que mantienen su
	// alineación original.
	forvalues r = 1/13 {
		if !inlist(`r', 1, 9, 13) {
			cap putdocx table T(`r', 1), halign(left) valign(center)
			forvalues c = 2/5 {
				cap putdocx table T(`r', `c'), halign(center) valign(center)
			}
		}
	}

	//==========================================================================
	// Step 4: Guardar y post-procesar
	//==========================================================================
	putdocx save "`out'", replace

	// Post-process del XML (engrosa dobles líneas + inyecta halign(justify)
	// en la cell de notas). Mismo helper que prg_table_3panels.
	shell powershell -NoProfile -ExecutionPolicy Bypass ///
		-File "${ruta_utils}/fix_table_borders.ps1" "`out'"

	di as text "Archivo guardado: " as result "`out'"
end
