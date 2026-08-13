//------------------------------------------------------------------------------
// File           : I5_balance_covariates.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Genera tres tablas de balance en línea base:
//                  D4. Balance en covariables (sociodemográficas, hogar y
//                      vivienda, predio) + F-test conjunto de ortogonalidad.
//                  D5. Balance en variables resultado (outcomes ENA vO).
//                  D6. Balance en recolección (días desde inicio del trabajo
//                      de campo, % encuestado antes de la fecha mediana global,
//                      fecha mediana de encuesta).
//                  Especificación principal:
//                    reg X treat i.cod_rgn_PE i.mes_enc, cluster(cod_cpb)
//                  Reporta media y DE por brazo, diferencia, SMD pooled y
//                  p-valor. Las binarias se reportan en escala 0-100 (%).
//                  Adicionalmente exporta hojas xlsx con las versiones cruda
//                  y robustez (sem_enc).
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
//                  Out/5_BDs por grupos de vars/Sociodem_Prod_JH_LB.dta
//                  Out/5_BDs por grupos de vars/Viv_Act_SEA_LB.dta
//                  Out/5_BDs por grupos de vars/Demog_Ing_Hog_LB.dta
//                  Out/5_BDs por grupos de vars/Productor_Predio_LB.dta
//                  Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/Anexo/B-5-1_Tabla_Balance_Covariables.docx
//                  (datos: Tablas/0_Diseño_y_Diagnóstico/Cuerpo/*.xlsx)
//                  Tablas/0_Diseño_y_Diagnóstico/Anexo/B-5-2_Tabla_Balance_Vars_Resultado.docx (+ xlsx)
//                  Tablas/0_Diseño_y_Diagnóstico/Anexo/B-5-3_Tabla_Balance_Timing.docx (+ xlsx)
//------------------------------------------------------------------------------

cls
version 19.0
clear all

//==============================================================================
// Step 1: Load environment
//==============================================================================
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
if "${ruta_data}" == "" {
	capture qui include "${ECAS}/2_Scripts/A_setup/A_master.do"
	if _rc capture qui include "2_Scripts/A_setup/A_master.do"
	if "${ruta_data}" == "" {
		di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
		di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
		exit 601
	}
}

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\\I5_balance_covariates.log"
log using "${ruta_logs}\\I5_balance_covariates.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Cuerpo"
local outanx "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Anexo"

local size_m 10pt
local size_n 9pt

local sociodem  edad sexo educ castell
local hogar     ilogsact icondvid tot_miem_1564 tot_miem_depen
local predio    tot_has_prod años_tenen_prod riego_tec_prod
local outc_vO   bpa_ena_riego_vO bpa_ena_suelo_vO bpa_ena_fert_abo_vO ///
                bpa_ena_plag_vO bpa_ena_biocontrol_vO bpa_ena_mip_vO ///
                bpa_ena_inoc_vO ena_pilar_agro_vO ena_pilar_insumos_vO ///
                ena_pilar_inoc_vO implementa_bpa_ena_vO

local binarias  sexo castell riego_tec_prod ///
                bpa_ena_riego_vO bpa_ena_suelo_vO bpa_ena_fert_abo_vO ///
                bpa_ena_plag_vO bpa_ena_biocontrol_vO bpa_ena_mip_vO ///
                bpa_ena_inoc_vO ena_pilar_agro_vO ena_pilar_insumos_vO ///
                ena_pilar_inoc_vO implementa_bpa_ena_vO

//==============================================================================
// Step 2: Construir base maestra
//==============================================================================
use Codprod22 post asig_ccpp cod_cpb cod_rgn_PE mes_enc sem_enc ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
keep if post == 0
duplicates drop Codprod22, force

// fch_enc no está preservada en Caract_Obs_Trat_ECA.dta (E1_build_obs_chars.do la
// usa para derivar sem_enc/mes_enc/año_enc pero no la mantiene en el output).
// La traemos directamente desde Panel_Inicio.dta.
merge 1:1 Codprod22 post using "`outc4'\\Panel_Inicio.dta", ///
	keepus(fch_enc) keep(1 3) nogen

merge 1:1 Codprod22 using "`outc5'\\Sociodem_Prod_JH_LB.dta", ///
	keepus(`sociodem') keep(1 3) nogen
merge 1:1 Codprod22 using "`outc5'\\Viv_Act_SEA_LB.dta", ///
	keepus(ilogsact icondvid) keep(1 3) nogen
merge 1:1 Codprod22 using "`outc5'\\Demog_Ing_Hog_LB.dta", ///
	keepus(tot_miem_1564 tot_miem_depen) keep(1 3) nogen

preserve
	use Codprod22 post `predio' using "`outc5'\\Productor_Predio_LB.dta", clear
	keep if post == 0
	// Guardar los labels antes del collapse, ya que (mean) los sustituye por
	// "(mean) <varname>" en cada variable colapsada.
	foreach v of local predio {
		local _lbl_`v' : variable label `v'
	}
	collapse (mean) `predio', by(Codprod22)
	// Restaurar los labels originales del do-file de construcción.
	foreach v of local predio {
		lab var `v' "`_lbl_`v''"
	}
	tempfile pre
	save `pre'
restore
merge 1:1 Codprod22 using `pre', keep(1 3) nogen

// Refinamiento de labels para tablas (versiones cortas, estilo paper).
// Las redundancias "del productor o JH" y "del hogar" se omiten porque se
// sobreentienden por el panel correspondiente y por el contexto del estudio.

// Bloque sociodemográficas (productor o jefe de hogar)
lab var edad     "Edad"
lab var sexo     "Sexo (Hombre)"
lab var educ     "Años de educación"
lab var castell  "Lengua materna castellano"

// Bloque hogar y vivienda
lab var ilogsact       "Índice log. de sofisticación de activos agrícolas"
lab var icondvid       "Índice de condiciones de vida"
lab var tot_miem_1564  "Miembros en edad activa (15-64)"
lab var tot_miem_depen "Miembros en edad dependiente (<15 o ≥65)"

// Bloque predio
lab var tot_has_prod    "Hectáreas totales que maneja"
lab var años_tenen_prod "Años de tenencia (predio más antiguo)"
lab var riego_tec_prod  "Predio con riego tecnificado"

preserve
	use Codprod22 post `outc_vO' using "`outc5'\\BPAs_Compuestos_LByLS.dta", clear
	keep if post == 0
	tempfile vo
	save `vo'
restore
merge 1:1 Codprod22 using `vo', keep(1 3) nogen

// Variables de timing
qui summ fch_enc
local fch_min = r(min)
gen dias_iniTC = fch_enc - `fch_min'
lab var dias_iniTC "Días desde inicio del trabajo de campo"

qui summ fch_enc, detail
local fch_med = r(p50)
gen byte enc_pre_med = (fch_enc <= `fch_med')
lab var enc_pre_med "% encuestado antes de la fecha mediana global"

// Reescalar binarias a porcentaje (0-100) para reportar como %
foreach v in `binarias' enc_pre_med {
	cap replace `v' = `v' * 100
}

tempfile master_bal
save `master_bal'

//==============================================================================
// Step 3: Programa para correr balance y cargar a collect
//==============================================================================
cap program drop _bal_var
program define _bal_var
	syntax varname, panel(string) idx(integer) tag(string) ///
		[adj(integer 1)] [fe_time(string)]
	local v `varlist'
	if "`fe_time'" == "" local fe_time mes_enc

	qui summ `v' if asig_ccpp == 0
	local m_C  = r(mean)
	local sd_C = r(sd)
	qui summ `v' if asig_ccpp == 1
	local m_T  = r(mean)
	local sd_T = r(sd)

	local sd_pool = sqrt((`sd_C'^2 + `sd_T'^2) / 2)
	if `adj' == 1 {
		qui reg `v' asig_ccpp i.cod_rgn_PE i.`fe_time', cluster(cod_cpb)
	}
	else {
		qui reg `v' asig_ccpp i.cod_rgn_PE, cluster(cod_cpb)
	}
	local diff = _b[asig_ccpp]
	local pv   = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))
	local smd  = cond(`sd_pool' > 0, `diff' / `sd_pool', .)

	qui collect get m =`m_C',  tags(panel[`panel'] cmdset[`idx'] arm[C])    name(`tag')
	qui collect get sd=`sd_C', tags(panel[`panel'] cmdset[`idx'] arm[C])    name(`tag')
	qui collect get m =`m_T',  tags(panel[`panel'] cmdset[`idx'] arm[T])    name(`tag')
	qui collect get sd=`sd_T', tags(panel[`panel'] cmdset[`idx'] arm[T])    name(`tag')
	qui collect get diff=`diff', tags(panel[`panel'] cmdset[`idx'] arm[bal]) name(`tag')
	qui collect get smd =`smd',  tags(panel[`panel'] cmdset[`idx'] arm[bal]) name(`tag')
	qui collect get pv  =`pv',   tags(panel[`panel'] cmdset[`idx'] arm[bal]) name(`tag')

	local lbl : variable label `v'
	if "`lbl'" == "" local lbl "`v'"
	collect label levels cmdset `idx' "`lbl'", modify
end

//==============================================================================
// Step 4: Programa para aplicar estilos BID y exportar
//
// La opción hdr_panel(numlist) recibe los índices de cmdset que actúan como
// "headers de panel" — filas vacías cuyo label se muestra a lo ancho con
// shading gris BID. Si está vacía, no se aplican estilos especiales.
//==============================================================================
cap program drop _format_export
program define _format_export
	syntax , tag(string) titulo(string) outfile(string) outdir(string) ///
		[hdr_panel(numlist)]

	collect set `tag'

	collect label levels arm ///
		C   "Control"     ///
		T   "Tratamiento" ///
		bal "Balance",    modify

	collect label levels result ///
		m    "Media"   ///
		sd   "DE"      ///
		diff "Dif."    ///
		smd  "SMD"     ///
		pv   "p-valor", modify

	// Estrellas en pv
	collect stars pv 0.01 "***" 0.05 "**" 0.10 "*", attach(pv)

	// Tamaños: regla del proyecto = notas son (datos − 1) pt.
	// Re-derivamos aquí porque el programa _format_export tiene su propio scope
	// y no ve las locales del script principal.
	local _pt_dat 10
	local size_m  "`_pt_dat'pt"
	local size_n  "`=`_pt_dat' - 1'pt"

	// Estilos BID
	collect style cell, border(right, pattern(nil)) margin(all, width(0pt))
	collect style cell cmdset, font(Roboto, size(`size_m') nobold noitalic) halign(left) valign(center)
	collect style cell arm,    font(Roboto, size(`size_m') nobold noitalic) halign(center)
	collect style cell result, font(Roboto, size(`size_m') nobold noitalic) halign(center)

	collect style cell result[m sd diff], nformat(%9.2f)
	collect style cell result[smd],       nformat(%9.3f)
	collect style cell result[pv],        nformat(%9.3f)
	collect style cell result[sd],        sformat("(%s)")

	// Datos (items): regular sin negrita ni cursiva.
	collect style cell cell_type[item], font(Roboto, size(`size_m') nobold noitalic)

	// Headers de columna AL FINAL: azul BID + blanco bold.
	collect style cell cell_type[corner column-header], ///
		shading(background(0 78 112)) font(Roboto, size(`size_m') color(white) bold noitalic)

	// Headers de panel: shading gris BID + label en italic bold.
	// El shading via cmdset captura la fila ENTERA porque todas las celdas de
	// la fila tienen tag cmdset[idx_hdr]. Para ocultar los puntos de los
	// valores missing que insertamos como placeholders en las columnas de
	// datos, pintamos el color del texto de esas celdas-item con el mismo
	// RGB del shading (211 210 209 = #d3d2d1) → quedan invisibles.
	// El label en cell_type[row-header] mantiene su color por defecto.
	if "`hdr_panel'" != "" {
		collect style cell cmdset[`hdr_panel'], ///
			shading(background(211 210 209)) ///
			font(Roboto, size(`size_m') italic bold) halign(left)
		collect style cell cmdset[`hdr_panel']#cell_type[item], ///
			font(Roboto, size(`size_m') color(211 210 209))
	}

	collect style column, dups(center)
	collect style header cmdset, level(label)
	collect style header arm,    level(label)
	collect style header result, level(label)
	collect style row stack, nobinder

	collect title "`titulo'"
	// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
	// notas en italic, tamaño = (cuerpo − 1) pt.
	collect style title, font(Roboto, size(`size_m') bold)
	collect style notes, font(Roboto, size(`size_n') italic)

	// Sangría en los nombres de variable (row-headers de cmdset). Va AL FINAL,
	// después de todos los estilos generales y específicos, para asegurar que
	// no la sobreescriba el `margin(all, width(0pt))` global ni los styles de
	// los headers de panel. Se aplica a TODAS las row-headers de cmdset y
	// luego se anula explícitamente solo en los headers de panel.
	collect style cell cmdset#cell_type[row-header], margin(left, width(25pt))
	if "`hdr_panel'" != "" {
		collect style cell cmdset[`hdr_panel']#cell_type[row-header], ///
			margin(left, width(0pt))
	}

	// Layout: filas = cmdset (incluye headers de panel + variables);
	// columnas = arm × stat (media, DE) y arm[bal] × resultado (Dif., SMD, p).
	collect layout (cmdset) (arm[C T]#result[m sd] arm[bal]#result[diff smd pv])

	mat widths = (38, 12, 6, 12, 6, 8, 8, 10)
	collect style putdocx, name(`tag') width(widths)
	collect export "`outanx'\\`outfile'.docx", as(docx) name(`tag') replace
end

//==============================================================================
// Step 5: Tabla B.5-1 — Balance en covariables (3 paneles, ajustada)
//==============================================================================
local tag4 Tabla_Balance_Cov
collect clear
collect create `tag4', replace

// Construimos las filas como cmdset secuenciales. Antes de cada bloque de
// variables, insertamos una fila "header de panel" con celdas missing en
// cada combinación arm × result del layout (m, sd para C/T y diff/smd/pv
// para bal). Eso fuerza a que la fila aparezca, todas sus celdas heredan
// el tag cmdset[idx] (clave para que el shading se extienda), y los missing
// se mostrarán como vacío gracias al missing("") aplicado en los estilos.
cap program drop _hdr_row
program define _hdr_row
	args tag idx
	qui collect get m =., tags(cmdset[`idx'] arm[C])    name(`tag')
	qui collect get sd=., tags(cmdset[`idx'] arm[C])    name(`tag')
	qui collect get m =., tags(cmdset[`idx'] arm[T])    name(`tag')
	qui collect get sd=., tags(cmdset[`idx'] arm[T])    name(`tag')
	qui collect get diff=., tags(cmdset[`idx'] arm[bal]) name(`tag')
	qui collect get smd =., tags(cmdset[`idx'] arm[bal]) name(`tag')
	qui collect get pv  =., tags(cmdset[`idx'] arm[bal]) name(`tag')
end

local idx = 1

// Bloque A: Sociodemográficas
local idx_hdrA = `idx'
_hdr_row `tag4' `idx'
local ++idx
foreach v of local sociodem {
	use `master_bal', clear
	_bal_var `v', panel(A) idx(`idx') tag(`tag4') adj(1)
	local ++idx
}

// Bloque B: Hogar y Vivienda del Productor
local idx_hdrB = `idx'
_hdr_row `tag4' `idx'
local ++idx
foreach v of local hogar {
	use `master_bal', clear
	_bal_var `v', panel(B) idx(`idx') tag(`tag4') adj(1)
	local ++idx
}

// Bloque C: Predio que maneja el productor
local idx_hdrC = `idx'
_hdr_row `tag4' `idx'
local ++idx
foreach v of local predio {
	use `master_bal', clear
	_bal_var `v', panel(C) idx(`idx') tag(`tag4') adj(1)
	local ++idx
}

collect set `tag4'

// Etiquetas de los headers de panel (filas con sólo label).
collect label levels cmdset ///
	`idx_hdrA' "Sociodemográficas"               ///
	`idx_hdrB' "Hogar y Vivienda del Productor"   ///
	`idx_hdrC' "Predio que maneja el productor", modify

local nota1 "Notas: La tabla reporta la media y desviación estándar de cada covariable basal por brazo, sobre la muestra analítica en línea base (definida en la Figura 4.2-1). Las variables binarias se reportan en escala 0-100 (porcentaje)."
local nota2 "La diferencia, la diferencia estandarizada de medias (SMD) y el p-valor provienen de una regresión de la covariable sobre el indicador de tratamiento, con efectos fijos del estrato de aleatorización y del mes de encuesta, y errores estándar agrupados a nivel de centro poblado. La SMD es la diferencia entre brazos dividida entre la desviación estándar combinada de ambos brazos."
local nota3 "Significancia: *** p<0.01, ** p<0.05, * p<0.10."

// F-test conjunto
use `master_bal', clear
qui reg asig_ccpp `sociodem' `hogar' `predio' i.cod_rgn_PE i.mes_enc, cluster(cod_cpb)
testparm `sociodem' `hogar' `predio'
local F   = r(F)
local pF  = r(p)
local df1 = r(df)
local df2 = r(df_r)
local F_f  : di %6.3f `F'
local pF_f : di %5.3f `pF'

local nota4 "F-test conjunto de ortogonalidad: F(`df1', `df2') = `F_f', p = `pF_f'."

collect notes "`nota1' `nota2' `nota3' `nota4'"

_format_export, tag(`tag4') ///
	titulo("Tabla B.5-1 — Balance en covariables en línea base (especificación ajustada)") ///
	outfile("B-5-1_Tabla_Balance_Covariables") outdir("`outdir'") ///
	hdr_panel(`idx_hdrA' `idx_hdrB' `idx_hdrC')

//==============================================================================
// Step 6: Robustez xlsx — versiones cruda y sem_enc
//==============================================================================
preserve
	tempfile rcruda rsem
	// Tras clear, gen crea las variables sin agregar obs; el dataset queda
	// con 0 obs y la estructura definida — no hace falta keep/drop.
	clear
	gen str40 variable = ""
	gen double m_C  = .
	gen double m_T  = .
	gen double diff = .
	gen double smd  = .
	gen double pval = .
	save `rcruda', emptyok
	save `rsem',   emptyok
restore

foreach v of varlist `sociodem' `hogar' `predio' {
	use `master_bal', clear
	qui summ `v' if asig_ccpp == 0
	local sd_C = r(sd)
	qui summ `v' if asig_ccpp == 1
	local sd_T = r(sd)
	local sd_pool = sqrt((`sd_C'^2 + `sd_T'^2) / 2)

	qui summ `v' if asig_ccpp == 0
	local m_C0 = r(mean)
	qui summ `v' if asig_ccpp == 1
	local m_T0 = r(mean)

	// Cruda
	qui reg `v' asig_ccpp i.cod_rgn_PE, cluster(cod_cpb)
	local d0 = _b[asig_ccpp]
	local p0 = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))
	local s0 = cond(`sd_pool' > 0, `d0' / `sd_pool', .)
	preserve
		clear
		set obs 1
		gen str40 variable = "`v'"
		gen double m_C  = `m_C0'
		gen double m_T  = `m_T0'
		gen double diff = `d0'
		gen double smd  = `s0'
		gen double pval = `p0'
		append using `rcruda'
		save `rcruda', replace
	restore

	// Robustez sem_enc
	use `master_bal', clear
	qui reg `v' asig_ccpp i.cod_rgn_PE i.sem_enc, cluster(cod_cpb)
	local d1 = _b[asig_ccpp]
	local p1 = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))
	local s1 = cond(`sd_pool' > 0, `d1' / `sd_pool', .)
	preserve
		clear
		set obs 1
		gen str40 variable = "`v'"
		gen double m_C  = `m_C0'
		gen double m_T  = `m_T0'
		gen double diff = `d1'
		gen double smd  = `s1'
		gen double pval = `p1'
		append using `rsem'
		save `rsem', replace
	restore
}

use `rcruda', clear
export excel using "`outdir'\\B-5-1_Tabla_Balance_Covariables.xlsx", ///
	firstrow(variables) sheet("Cruda") sheetreplace

use `rsem', clear
export excel using "`outdir'\\B-5-1_Tabla_Balance_Covariables.xlsx", ///
	firstrow(variables) sheet("Robustez_sem_enc") sheetreplace

//==============================================================================
// Step 7: Tabla B.5-2 — Balance en variables resultado vO
//==============================================================================
local tag5 Tabla_Balance_VarsResultado
collect clear
collect create `tag5', replace

// Etiquetas más amigables para outcomes
use `master_bal', clear
lab var bpa_ena_riego_vO       "BPA Riego"
lab var bpa_ena_suelo_vO       "BPA Suelo"
lab var bpa_ena_fert_abo_vO    "BPA Fertilizantes/Abonos"
lab var bpa_ena_plag_vO        "BPA Plaguicidas"
lab var bpa_ena_biocontrol_vO  "BPA Control biológico"
lab var bpa_ena_mip_vO         "BPA Manejo integrado"
lab var bpa_ena_inoc_vO        "BPA Inocuidad"
lab var ena_pilar_agro_vO      "Pilar Agro"
lab var ena_pilar_insumos_vO   "Pilar Insumos"
lab var ena_pilar_inoc_vO      "Pilar Inocuidad"
lab var implementa_bpa_ena_vO  "Compuesto final"
save `master_bal', replace

local idx = 1
foreach v of local outc_vO {
	use `master_bal', clear
	_bal_var `v', panel(A) idx(`idx') tag(`tag5') adj(1)
	local ++idx
}

collect set `tag5'

// D5 sólo tiene un grupo de variables (outcomes vO), redundante con el título;
// no se inserta header de panel.

local nota1 "Notas: La tabla reporta el balance preintervención de las variables de resultado principales medidas sobre la muestra analítica en línea base (definida en la Figura 4.2-1) en su versión ENA. Todas las variables de resultado son binarias y se reportan en escala 0-100 (porcentaje)."
local nota2 "La diferencia, la diferencia estandarizada de medias (SMD) y el p-valor provienen de la misma especificación que la Tabla B.5-1 (regresión sobre el indicador de tratamiento con efectos fijos del estrato de aleatorización y del mes de encuesta, y errores estándar agrupados a nivel de centro poblado). La SMD es la diferencia entre brazos dividida entre la desviación estándar combinada de ambos brazos."
local nota3 "Significancia: *** p<0.01, ** p<0.05, * p<0.10."
collect notes "`nota1' `nota2' `nota3'"

_format_export, tag(`tag5') ///
	titulo("Tabla B.5-2 — Balance en variables resultado en línea base (versión ENA)") ///
	outfile("B-5-2_Tabla_Balance_Vars_Resultado") outdir("`outdir'")

//==============================================================================
// Step 8: Tabla B.5-3 — Balance en recolección (timing)
//==============================================================================
local tag6 Tabla_Balance_Timing
collect clear
collect create `tag6', replace

local idx = 1
foreach v in dias_iniTC enc_pre_med {
	use `master_bal', clear
	_bal_var `v', panel(A) idx(`idx') tag(`tag6') adj(1)
	local ++idx
}

collect set `tag6'

// D6 sólo tiene un grupo (Recolección), redundante con el título; no se
// inserta header de panel.

// Fecha mediana de encuesta por brazo (informativo)
use `master_bal', clear
qui summ fch_enc if asig_ccpp == 0, detail
local fmed_C = r(p50)
qui summ fch_enc if asig_ccpp == 1, detail
local fmed_T = r(p50)
local fmed_C_f : di %tdDD_Mon_CCYY `fmed_C'
local fmed_T_f : di %tdDD_Mon_CCYY `fmed_T'

local nota1 "Notas: La tabla reporta indicadores del momento de recolección de cada encuesta basal, sobre la muestra analítica en línea base (definida en la Figura 4.2-1). La variable 'Días desde inicio del trabajo de campo' es continua y la variable '% encuestado antes de la fecha mediana global' es binaria reportada en escala 0-100."
local nota2 "La diferencia, la diferencia estandarizada de medias (SMD) y el p-valor provienen de la misma especificación que la Tabla B.5-1 (regresión sobre el indicador de tratamiento con efectos fijos del estrato de aleatorización y del mes de encuesta, y errores estándar agrupados a nivel de centro poblado). La SMD es la diferencia entre brazos dividida entre la desviación estándar combinada de ambos brazos."
local nota3 "Fecha mediana de encuesta — Control: `fmed_C_f' · Tratamiento: `fmed_T_f'."
local nota4 "Significancia: *** p<0.01, ** p<0.05, * p<0.10."
collect notes "`nota1' `nota2' `nota3' `nota4'"

_format_export, tag(`tag6') ///
	titulo("Tabla B.5-3 — Balance en el momento de recolección") ///
	outfile("B-5-3_Tabla_Balance_Timing") outdir("`outdir'")

di as text ""
di as text "Listo: D4 (covariables), D5 (resultado vO) y D6 (timing) exportadas en `outdir'."

log close
