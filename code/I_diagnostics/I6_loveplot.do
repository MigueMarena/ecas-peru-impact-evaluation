//------------------------------------------------------------------------------
// File           : I6_loveplot.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Genera el love plot dual (Figura 2) con dos series por
//                  variable: SMD cruda (solo design FE = cod_rgn_PE) y SMD
//                  ajustada por timing (cod_rgn_PE + mes_enc). Las variables
//                  se agrupan en tres bloques visualmente separados:
//                    (1) nivel cluster (productores por cluster);
//                    (2) individuales tiempo-invariantes (sociodem + hogar
//                        + predio);
//                    (3) individuales tiempo-sensibles (outcomes ENA vO).
//                  Para tiempo-invariantes solo se grafica un punto (la SMD
//                  no se ve afectada por el ajuste de timing). Líneas de
//                  umbral en ±0.10. Exporta PNG (300 dpi) y PDF.
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
//                  Out/5_BDs por grupos de vars/Sociodem_Prod_JH_LB.dta
//                  Out/5_BDs por grupos de vars/Viv_Act_SEA_LB.dta
//                  Out/5_BDs por grupos de vars/Demog_Ing_Hog_LB.dta
//                  Out/5_BDs por grupos de vars/Productor_Predio_LB.dta
//                  Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta
// Output         : Imágenes/Gráfico_Loveplot/F2_Loveplot_SMD.png
//                  Imágenes/Gráfico_Loveplot/F2_Loveplot_SMD.pdf
//                  Imágenes/Gráfico_Loveplot/F2_Loveplot_SMD_data.dta
//------------------------------------------------------------------------------

cls
version 19.0
clear all

//==============================================================================
// Step 1: Load environment
//==============================================================================
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
// A_master.do se incluye SIEMPRE, sin guardarlo tras un `if' sobre alguna
// global: define locales (`outc1', `rawc1', …) y `do' abre un scope nuevo,
// así que los locales del llamador NO llegan hasta acá. Saltarse el include
// porque las globals ya existan deja al script sin rutas y falla con r(601).
// `include' es idempotente: solo redefine rutas y crea carpetas con `cap'.
capture qui include "${ECAS}/2_Scripts/A_setup/A_master.do"
if _rc capture qui include "2_Scripts/A_setup/A_master.do"
if "${ruta_data}" == "" {
	di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
	di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
	exit 601
}

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\\I6_loveplot.log"
log using "${ruta_logs}\\I6_loveplot.log", replace text

local outimg "${ruta_images}\\Gráfico_Loveplot"

local sociodem  edad sexo educ castell
local hogar     ilogsact icondvid tot_miem_1564 tot_miem_depen
local predio    tot_has_prod años_tenen_prod riego_tec_prod
local invariant `sociodem' `hogar' `predio'

local outc_vO   bpa_ena_riego_vO bpa_ena_suelo_vO bpa_ena_fert_abo_vO ///
                bpa_ena_plag_vO bpa_ena_biocontrol_vO bpa_ena_mip_vO ///
                bpa_ena_inoc_vO ena_pilar_agro_vO ena_pilar_insumos_vO ///
                ena_pilar_inoc_vO implementa_bpa_ena_vO

//==============================================================================
// Step 2: Construir base maestra (igual que en 34)
//==============================================================================
use Codprod22 post asig_ccpp cod_cpb cod_rgn_PE mes_enc ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
// Panel balanceado: los diagnósticos deben describir la MISMA muestra que
// estiman las tablas de resultados. prg_load_panel.do hace `keep if n_obs == 2';
// sin esta restricción el balance se reporta sobre los 1,445 encuestados en
// línea base mientras las estimaciones corren sobre los 1,282 del panel.
bys Codprod22: gen byte _en_panel = (_N == 2)
keep if post == 0 & _en_panel
drop _en_panel
duplicates drop Codprod22, force

merge 1:1 Codprod22 using "`outc5'\\Sociodem_Prod_JH_LB.dta", ///
	keepus(`sociodem') keep(1 3) nogen
merge 1:1 Codprod22 using "`outc5'\\Viv_Act_SEA_LB.dta", ///
	keepus(ilogsact icondvid) keep(1 3) nogen
merge 1:1 Codprod22 using "`outc5'\\Demog_Ing_Hog_LB.dta", ///
	keepus(tot_miem_1564 tot_miem_depen) keep(1 3) nogen

preserve
	use Codprod22 post `predio' using "`outc5'\\Productor_Predio_LB.dta", clear
	keep if post == 0
	// Preservar labels que (mean) sobrescribe con "(mean) varname".
	foreach v of local predio {
		local _lbl_`v' : variable label `v'
	}
	collapse (mean) `predio', by(Codprod22)
	foreach v of local predio {
		lab var `v' "`_lbl_`v''"
	}
	tempfile pre
	save `pre'
restore
merge 1:1 Codprod22 using `pre', keep(1 3) nogen

preserve
	use Codprod22 post `outc_vO' using "`outc5'\\BPAs_Compuestos_LByLS.dta", clear
	keep if post == 0
	tempfile vo
	save `vo'
restore
merge 1:1 Codprod22 using `vo', keep(1 3) nogen

// Conteo de productores por cluster (variable a nivel cluster, replicada al productor)
bysort cod_cpb: gen _n_prods_clu = _N

// Labels cortos para el love plot (mismo patrón que las tablas D4/D5).
// Las redundancias "del productor o JH", "del hogar" y los códigos ENA
// se omiten — quedan implícitos por el bloque o se aclaran en la nota.
lab var _n_prods_clu          "Productores por clúster"

// Sociodemográficas (productor o jefe de hogar)
lab var edad     "Edad"
lab var sexo     "Sexo (Hombre)"
lab var educ     "Años de educación"
lab var castell  "Lengua materna castellano"

// Hogar y vivienda — usamos saltos de línea (`"línea 1" "línea 2"') en las
// etiquetas largas para que se muestren completas en el eje Y sin truncarse.
lab var ilogsact       `""Índice log. de sofisticación" "de activos agrícolas""'
lab var icondvid       "Índice de condiciones de vida"
lab var tot_miem_1564  "Miembros en edad activa (15-64)"
lab var tot_miem_depen `""Miembros en edad dependiente" "(<15 o ≥65)""'

// Predio
lab var tot_has_prod    "Hectáreas totales que maneja"
lab var años_tenen_prod `""Años de tenencia" "(predio más antiguo)""'
lab var riego_tec_prod  "Predio con riego tecnificado"

// Outcomes ENA vO
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

tempfile master_bal
save `master_bal'

//==============================================================================
// Step 3: Programa para calcular SMD cruda y ajustada por variable
//==============================================================================
cap program drop _smd_one
program define _smd_one, rclass
	args var
	qui summ `var' if asig_ccpp == 0
	local sd_C = r(sd)
	qui summ `var' if asig_ccpp == 1
	local sd_T = r(sd)
	local sd_pool = sqrt((`sd_C'^2 + `sd_T'^2) / 2)
	if `sd_pool' == 0 | mi(`sd_pool') {
		return scalar smd_c = .
		return scalar smd_a = .
		return scalar p_c   = .
		return scalar p_a   = .
		exit
	}
	tempvar _z
	qui gen `_z' = `var' / `sd_pool'
	qui reg `_z' asig_ccpp i.cod_rgn_PE, cluster(cod_cpb)
	local smd_c = _b[asig_ccpp]
	local p_c   = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))
	qui reg `_z' asig_ccpp i.cod_rgn_PE i.mes_enc, cluster(cod_cpb)
	local smd_a = _b[asig_ccpp]
	local p_a   = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))
	return scalar smd_c = `smd_c'
	return scalar smd_a = `smd_a'
	return scalar p_c   = `p_c'
	return scalar p_a   = `p_a'
end

//==============================================================================
// Step 4: Iterar y construir dataset con SMDs por variable
//==============================================================================
tempfile resul
clear
gen str40   varname  = ""
// str200 para acomodar etiquetas multi-línea con comillas internas.
gen str200  etiqueta = ""
gen str30   bloque   = ""
gen byte    is_sens  = 0
gen double  smd_c    = .
gen double  smd_a    = .
gen double  p_c      = .
gen double  p_a      = .
gen int     orden    = .
save `resul', emptyok

local k = 0

// (1) Bloque cluster — usar nivel-cluster (collapse interno).
// Calculamos AMBAS especificaciones (cruda y ajustada por mes-encuesta) para
// que el love plot reporte ambos puntos en TODAS las filas, igual que para
// los demás bloques.
local k = `k' + 1
use `master_bal', clear
preserve
	collapse (firstnm) _n_prods_clu asig_ccpp cod_rgn_PE mes_enc, by(cod_cpb)
	rename _n_prods_clu n_prods_clu
	qui summ n_prods_clu if asig_ccpp == 0
	local sd_C = r(sd)
	qui summ n_prods_clu if asig_ccpp == 1
	local sd_T = r(sd)
	local sd_pool = sqrt((`sd_C'^2 + `sd_T'^2) / 2)
	tempvar _z
	qui gen `_z' = n_prods_clu / `sd_pool'
	// Cruda: solo estrato FE
	qui reg `_z' asig_ccpp i.cod_rgn_PE, robust
	local smd_c_v = _b[asig_ccpp]
	local p_c_v   = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))
	// Ajustada: estrato + mes-encuesta FE
	cap qui reg `_z' asig_ccpp i.cod_rgn_PE i.mes_enc, robust
	if _rc == 0 {
		local smd_a_v = _b[asig_ccpp]
		local p_a_v   = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))
	}
	else {
		// Si la regresión ajustada no converge (mes-encuesta colineal con
		// estrato a nivel cluster), reportar la cruda como ajustada.
		local smd_a_v = `smd_c_v'
		local p_a_v   = `p_c_v'
	}
restore

clear
set obs 1
gen str40   varname  = "n_prods_clu"
// str200 consistente con el resto de filas (para acomodar etiquetas multi-línea).
gen str200  etiqueta = "Productores por clúster"
gen str30   bloque   = "Nivel clúster"
gen byte    is_sens  = 0
gen double  smd_c    = `smd_c_v'
gen double  smd_a    = `smd_a_v'
gen double  p_c      = `p_c_v'
gen double  p_a      = `p_a_v'
gen int     orden    = `k'
append using `resul'
save `resul', replace

// (2) Bloque individuales tiempo-invariantes
foreach v of local invariant {
	local k = `k' + 1
	use `master_bal', clear
	_smd_one `v'
	local smd_c_v = r(smd_c)
	local smd_a_v = r(smd_a)
	local p_c_v   = r(p_c)
	local p_a_v   = r(p_a)
	local lab : variable label `v'
	// Comillas compuestas para que el if no se rompa si `lab' contiene
	// comillas dobles internas (etiquetas multi-línea como "L1" "L2").
	if `"`lab'"' == "" local lab "`v'"

	clear
	set obs 1
	gen str40   varname  = "`v'"
	// str200 + comillas compuestas para acomodar etiquetas multi-línea con
	// comillas internas (e.g., `"L1" "L2"').
	gen str200  etiqueta = `"`lab'"'
	gen str30   bloque   = "Individuales tiempo-invariantes"
	gen byte    is_sens  = 0
	gen double  smd_c    = `smd_c_v'
	gen double  smd_a    = `smd_a_v'
	gen double  p_c      = `p_c_v'
	gen double  p_a      = `p_a_v'
	gen int     orden    = `k'
	append using `resul'
	save `resul', replace
}

// (3) Bloque individuales tiempo-sensibles
foreach v of local outc_vO {
	local k = `k' + 1
	use `master_bal', clear
	_smd_one `v'
	local smd_c_v = r(smd_c)
	local smd_a_v = r(smd_a)
	local p_c_v   = r(p_c)
	local p_a_v   = r(p_a)
	local lab : variable label `v'
	if `"`lab'"' == "" local lab "`v'"

	clear
	set obs 1
	gen str40   varname  = "`v'"
	gen str200  etiqueta = `"`lab'"'
	gen str30   bloque   = "Individuales tiempo-sensibles"
	gen byte    is_sens  = 1
	gen double  smd_c    = `smd_c_v'
	gen double  smd_a    = `smd_a_v'
	gen double  p_c      = `p_c_v'
	gen double  p_a      = `p_a_v'
	gen int     orden    = `k'
	append using `resul'
	save `resul', replace
}

use `resul', clear
sort orden
save "`outimg'\\F2_Loveplot_SMD_data.dta", replace
export excel using "`outimg'\\F2_Loveplot_SMD_data.xlsx", ///
	firstrow(variables) sheet("SMDs") sheetreplace

//==============================================================================
// Step 5: Construir love plot con twoway scatter (dual + bloques separados)
//==============================================================================
gen y = -orden
qui levelsof orden, local(rngo)
local ymin : word 1 of `rngo'
local ymax = `: word `=wordcount("`rngo'")' of `rngo''
local n = _N

// Etiquetas para axis Y
labmask y, values(etiqueta)

// Identificar separadores entre bloques
gen byte _sep = 0
forval i = 2/`n' {
	local b1 = bloque[`i']
	local b0 = bloque[`=`i'-1']
	if "`b1'" != "`b0'" {
		replace _sep = 1 in `i'
	}
}
qui levelsof y if _sep == 1, local(yseps)

// Construir comandos de yline para los separadores (a mitad entre puntos)
local ylines ""
foreach yv of local yseps {
	local ymid = `yv' + 0.5
	local ylines `ylines' yline(`ymid', lpattern(solid) lcolor(gs10) lwidth(thin))
}

// Configuración del gráfico:
//   - xsize aumentado a 12 para acomodar etiquetas multi-línea del eje Y +
//     dar espacio horizontal a la leyenda dentro del plot.
//   - ysize 9 mantiene espacio vertical entre las 23 filas.
//   - Marcadores vsmall para no competir con los datos.
//   - Etiquetas en `vsmall' uniformes en ejes y leyenda — simetría
//     tipográfica con las tablas (notas a 9 pt).
//   - Leyenda DENTRO del gráfico en posición 11 (arriba-izquierda) donde
//     no hay datos cercanos: los SMD no superan |0.25|, así que la zona
//     extrema izquierda (≈ -0.4) está libre.
//   - SMD cruda y SMD ajustada se grafican para TODAS las variables.
//   - Líneas de umbral con lwidth(thin) — más finas que el default medium.
//   - Colores BID: azul #004e70 (cruda) y cian #009ade (ajustada).
twoway ///
	(scatter y smd_c, msymbol(Oh) msize(small) mcolor("0 78 112") mlwidth(thin)) ///
	(scatter y smd_a, msymbol(D) msize(small) mcolor("0 154 222") mlwidth(thin)), ///
	xline(-0.10, lpattern(dash) lcolor(red) lwidth(thin)) ///
	xline( 0.10, lpattern(dash) lcolor(red) lwidth(thin)) ///
	xline(0,     lpattern(solid) lcolor(gs8) lwidth(thin)) ///
	`ylines' ///
	xtitle("Diferencia estandarizada (tratamiento − control)", size(vsmall)) ///
	ytitle("") ///
	ylabel(`=-`n''(1)-1, valuelabel angle(0) labsize(vsmall) noticks) ///
	xlabel(-0.4(0.1)0.4, labsize(vsmall)) ///
	legend(order(1 "SMD cruda (sólo design FE)" 2 "SMD ajustada (design + mes-encuesta FE)") ///
		position(7) ring(0) col(1) size(vsmall) ///
		region(margin(small) lstyle(foreground) lpattern(solid) ///
			lcolor("166 166 168") lwidth(thin) fcolor(white)) ///
		bmargin(small)) ///
	title("") ///
	ysize(9) xsize(12) ///
	graphregion(color(white)) plotregion(color(white)) ///
	scheme(s1mono)

// Dimensiones del export: ~12×9 pulgadas a 300 dpi → 3600×2700 px.
// Aspect ratio horizontal que acomoda etiquetas multi-línea + leyenda.
graph export "`outimg'\\F2_Loveplot_SMD.png", replace width(3600) height(2700)
graph export "`outimg'\\F2_Loveplot_SMD.pdf", replace

di as text "Listo: F2_Loveplot_SMD (png + pdf + dta + xlsx) en `outimg'."

log close
