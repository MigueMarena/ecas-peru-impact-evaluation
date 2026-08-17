//------------------------------------------------------------------------------
// File           : I8_balance_attrition.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Genera dos tablas relativas a atrición a nivel productor
//                  (línea base → línea de seguimiento). Conceptualmente distintas de la
//                  atrición a nivel cluster reportada en la Tabla D1 (centros
//                  poblados aleatorizados sin línea base):
//                    D9.  Atrición a nivel productor (línea base → línea de seguimiento).
//                         Para cada brazo y total, reporta n_baseline,
//                         n_endline, % completitud y atrición diferencial
//                         (regresión de el_completado sobre tratamiento con
//                         FE de estrato y SE clusterizado a nivel cluster).
//                    D10. Balance a nivel productor de atritos vs no-atritos
//                         en covariables de línea base, con diferencias y p-valor
//                         (test individual, sin cluster).
//                  Bajo el acuerdo metodológico actual, NO se reporta Panel A
//                  (Cobertura del baseline) porque no se dispuso de un padrón
//                  pre-baseline censal.
// Depends        : (ninguno)
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
//                  Out/5_BDs por grupos de vars/Sociodem_Prod_JH_LB.dta
//                  Out/5_BDs por grupos de vars/Viv_Act_SEA_LB.dta
//                  Out/5_BDs por grupos de vars/Demog_Ing_Hog_LB.dta
//                  Out/5_BDs por grupos de vars/Productor_Predio_LB.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/Cuerpo/6.2-1_Tabla_Atricion_Productor.docx (+ xlsx)
//                  Tablas/0_Diseño_y_Diagnóstico/Cuerpo/6.2-2_Tabla_Balance_Atritos_Productor.docx (+ xlsx)
//------------------------------------------------------------------------------

cls
version 19.0
clear all

//==============================================================================
// Step 1: Load environment
//==============================================================================
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

// Parámetros del diseño: $fe_estrato (estrato de aleatorización) y
// $cl_ccpp (nivel de agrupamiento de los errores estándar). Vienen de
// spec.do para que diagnóstico y estimación no puedan divergir.
qui include "${ruta_setup}/spec.do"

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\\I8_balance_attrition.log"
log using "${ruta_logs}\\I8_balance_attrition.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Cuerpo"

// Convención del proyecto: el tamaño de las notas es siempre (datos − 1) pt.
local _pt_dat 10
local size_m  "`_pt_dat'pt"
local size_n  "`=`_pt_dat' - 1'pt"

local sociodem  edad sexo educ castell
local hogar     ilogsact icondvid tot_miem_1564 tot_miem_depen
local predio    tot_has_prod años_tenen_prod riego_tec_prod

//==============================================================================
// Step 2: Construir flags de completitud
//==============================================================================
// Caract_Obs_Trat_ECA.dta tiene cod_cpb (construido en E1_build_obs_chars.do).
// Panel_Inicio.dta NO tiene cod_cpb porque ese código se genera en el 06.
use Codprod22 post asig_ccpp cod_cpb cod_rgn_PE ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear

gen byte _bl = (post == 0)
gen byte _el = (post == 1)
bysort Codprod22 (post): egen has_bl = max(_bl)
bysort Codprod22 (post): egen has_el = max(_el)

duplicates drop Codprod22, force
keep Codprod22 asig_ccpp cod_cpb cod_rgn_PE has_bl has_el

tempfile flags
save `flags'

//==============================================================================
// Step 3: Tabla D9 — Atrición a nivel productor (línea base → línea de seguimiento)
//==============================================================================
use `flags', clear
keep if has_bl == 1

count if asig_ccpp == 0
local n_blC = r(N)
count if asig_ccpp == 1
local n_blT = r(N)
local n_blTot = `n_blC' + `n_blT'

count if asig_ccpp == 0 & has_el == 1
local n_elC = r(N)
count if asig_ccpp == 1 & has_el == 1
local n_elT = r(N)
local n_elTot = `n_elC' + `n_elT'

local pct_elC   = 100 * `n_elC'   / `n_blC'
local pct_elT   = 100 * `n_elT'   / `n_blT'
local pct_elTot = 100 * `n_elTot' / `n_blTot'

local atC   = 100 - `pct_elC'
local atT   = 100 - `pct_elT'
local atTot = 100 - `pct_elTot'

// Diferencial (en pp)
qui reg has_el asig_ccpp i.$fe_estrato, cluster($cl_ccpp)
local diff_el = _b[asig_ccpp] * 100
local p_el    = 2 * ttail(e(df_r), abs(_b[asig_ccpp] / _se[asig_ccpp]))

// xlsx export
preserve
	clear
	set obs 3
	gen str40 indicador = ""
	gen double control = .
	gen double trat    = .
	gen double total   = .
	gen double dif     = .
	gen double pval    = .

	replace indicador = "Productores con línea base (n)" in 1
	replace control = `n_blC'   in 1
	replace trat    = `n_blT'   in 1
	replace total   = `n_blTot' in 1

	replace indicador = "Línea de seguimiento completada (%)" in 2
	replace control = `pct_elC'   in 2
	replace trat    = `pct_elT'   in 2
	replace total   = `pct_elTot' in 2
	replace dif     = `diff_el'   in 2
	replace pval    = `p_el'      in 2

	replace indicador = "Atrición línea base → línea de seguimiento (%)" in 3
	replace control = `atC'    in 3
	replace trat    = `atT'    in 3
	replace total   = `atTot'  in 3
	replace dif     = `=-1*`diff_el'' in 3
	replace pval    = `p_el'   in 3

	export excel using "`outdir'\\6.2-1_Tabla_Atricion_Productor.xlsx", ///
		firstrow(variables) sheet("Atricion") sheetreplace
restore

local tag8 Tabla_Atricion_D9

collect clear
collect create `tag8', replace

// Fila 1: productores con baseline
qui collect get value=`n_blC',   tags(cmdset[1] arm[C])    name(`tag8')
qui collect get value=`n_blT',   tags(cmdset[1] arm[T])    name(`tag8')
qui collect get value=`n_blTot', tags(cmdset[1] arm[Tot])  name(`tag8')

// Fila 2: endline completado (%)
qui collect get value=`pct_elC',   tags(cmdset[2] arm[C])    name(`tag8')
qui collect get value=`pct_elT',   tags(cmdset[2] arm[T])    name(`tag8')
qui collect get value=`pct_elTot', tags(cmdset[2] arm[Tot])  name(`tag8')
qui collect get diff =`diff_el',   tags(cmdset[2] arm[bal])  name(`tag8')
qui collect get pv   =`p_el',      tags(cmdset[2] arm[bal])  name(`tag8')

// Fila 3: atrición (%)
qui collect get value=`atC',   tags(cmdset[3] arm[C])    name(`tag8')
qui collect get value=`atT',   tags(cmdset[3] arm[T])    name(`tag8')
qui collect get value=`atTot', tags(cmdset[3] arm[Tot])  name(`tag8')
local diff_atr = -1 * `diff_el'
qui collect get diff =`diff_atr', tags(cmdset[3] arm[bal]) name(`tag8')
qui collect get pv   =`p_el',     tags(cmdset[3] arm[bal]) name(`tag8')

collect set `tag8'

collect label levels cmdset ///
	1 "Productores con línea base (n)"                          ///
	2 "Línea de seguimiento completada (%)"                                ///
	3 "Atrición a nivel productor — línea base → línea de seguimiento (%)",  modify

collect label levels arm ///
	C   "Control"      ///
	T   "Tratamiento"  ///
	Tot "Total"        ///
	bal "Balance",     modify

collect label levels result ///
	value "Valor"          ///
	diff  "Dif. (pp)"      ///
	pv    "p-valor",       modify

collect stars pv 0.01 "***" 0.05 "**" 0.10 "*", attach(pv)

// Estilo de casa BID (Roboto, encabezado azul, bordes y tamaños).
// Lo que se declare DESPUÉS de esta línea se superpone.
do "${ruta_utils}\collect_style_bid.do" `_pt_dat'

collect style cell arm,    font(Roboto, size(`size_m')) halign(center)
collect style cell result[value]#cmdset[1], nformat(%9.0f)
collect style cell result[value]#cmdset[2 3], nformat(%9.1f)
collect style cell result[diff], nformat(%9.1f)
collect style cell result[pv],   nformat(%9.3f)

// Datos (items): regular

// Headers: negrita blanca sobre azul BID

// Ocultar la etiqueta "Valor" del sub-header solo para el nivel result[value]
// — vía level(hide). Los sub-headers de result[diff] y result[pv] conservan
// sus etiquetas ("Dif. (pp)" y "p-valor") porque el selector apunta al nivel
// específico, no a la dimensión completa.
collect style header result[value], level(hide)

collect style header arm,    level(label)

local titulo "Tabla 6.2-1 — Atrición a nivel productor (línea base a línea de seguimiento)"
local nota1 "Notas: La tabla reporta la atrición a nivel productor observada entre línea base y línea de seguimiento — productores con encuesta de línea base que no fueron alcanzados por la encuesta de línea de seguimiento. Esta atrición es conceptualmente distinta de la atrición a nivel clúster reportada en la Figura 4.2-1 (centros poblados aleatorizados sin línea base, excluidos antes del análisis)."
local nota2 "El denominador corresponde a los productores con encuesta de línea base completa (muestra analítica). El diferencial entre brazos se estima por regresión del indicador de línea de seguimiento completado sobre el indicador de tratamiento, con efectos fijos del estrato de aleatorización y errores estándar agrupados a nivel de centro poblado."
local nota3 "No se reporta Panel A (Cobertura de la línea base) porque no se dispuso de un padrón censal previo a la línea base."
local nota4 "Significancia: *** p<0.01, ** p<0.05, * p<0.10."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3' `nota4'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.

collect layout (cmdset) (arm[C T Tot]#result[value] arm[bal]#result[diff pv])

mat widths = (40, 12, 12, 12, 12, 12)
collect style putdocx, name(`tag8') width(widths)
collect export "`outdir'\\6.2-1_Tabla_Atricion_Productor.docx", as(docx) name(`tag8') replace

//==============================================================================
// Step 4: Tabla D10 — Balance a nivel productor: atritos vs no-atritos
//==============================================================================
use `flags', clear
keep if has_bl == 1
gen byte atrito = (has_el == 0)

merge 1:1 Codprod22 using "`outc5'\\Sociodem_Prod_JH_LB.dta", ///
	keepus(`sociodem') keep(1 3) nogen
merge 1:1 Codprod22 using "`outc5'\\Viv_Act_SEA_LB.dta", ///
	keepus(ilogsact icondvid) keep(1 3) nogen
merge 1:1 Codprod22 using "`outc5'\\Demog_Ing_Hog_LB.dta", ///
	keepus(tot_miem_1564 tot_miem_depen) keep(1 3) nogen

preserve
	use Codprod22 post `predio' using "`outc5'\\Productor_Predio_LB.dta", clear
	keep if post == 0
	// Guardar y restaurar labels para que (mean) no los sobrescriba.
	foreach v of local predio {
		local _lbl_`v' : variable label `v'
	}
	collapse (mean) `predio', by(Codprod22)
	foreach v of local predio {
		lab var `v' "`_lbl_`v''"
	}
	tempfile prv
	save `prv'
restore
merge 1:1 Codprod22 using `prv', keep(1 3) nogen

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

count if atrito == 0
local n_noatr = r(N)
count if atrito == 1
local n_atr   = r(N)

tempfile master_atr
save `master_atr'

local tag9 Tabla_Balance_Atritos_D10

collect clear
collect create `tag9', replace

// Construimos las filas como cmdset secuenciales. Antes de cada bloque
// insertamos una fila "header de panel" con celdas missing en cada
// combinación arm × result del layout (m, sd para NoAtr/Atr y diff/pv
// para bal). Eso fuerza a que la fila aparezca; todas sus celdas heredan
// el tag cmdset[idx], lo que permite que el shading se extienda. Los
// missing se ocultarán visualmente con missing("") más adelante.
cap program drop _hdr_row9
program define _hdr_row9
	args tag idx
	qui collect get m =., tags(cmdset[`idx'] arm[NoAtr]) name(`tag')
	qui collect get sd=., tags(cmdset[`idx'] arm[NoAtr]) name(`tag')
	qui collect get m =., tags(cmdset[`idx'] arm[Atr])   name(`tag')
	qui collect get sd=., tags(cmdset[`idx'] arm[Atr])   name(`tag')
	qui collect get diff=., tags(cmdset[`idx'] arm[bal]) name(`tag')
	qui collect get pv  =., tags(cmdset[`idx'] arm[bal]) name(`tag')
end

local idx = 1

// Bloque A: Sociodemográficas
local idx_hdrA = `idx'
_hdr_row9 `tag9' `idx'
local ++idx
foreach v of local sociodem {
	use `master_atr', clear
	qui summ `v' if atrito == 0
	local m0 = r(mean)
	local s0 = r(sd)
	qui summ `v' if atrito == 1
	local m1 = r(mean)
	local s1 = r(sd)
	qui reg `v' atrito, robust
	local d  = _b[atrito]
	local pv = 2 * ttail(e(df_r), abs(_b[atrito] / _se[atrito]))

	qui collect get m =`m0', tags(cmdset[`idx'] arm[NoAtr]) name(`tag9')
	qui collect get sd=`s0', tags(cmdset[`idx'] arm[NoAtr]) name(`tag9')
	qui collect get m =`m1', tags(cmdset[`idx'] arm[Atr])   name(`tag9')
	qui collect get sd=`s1', tags(cmdset[`idx'] arm[Atr])   name(`tag9')
	qui collect get diff=`d', tags(cmdset[`idx'] arm[bal])  name(`tag9')
	qui collect get pv  =`pv', tags(cmdset[`idx'] arm[bal]) name(`tag9')

	local lbl : variable label `v'
	if "`lbl'" == "" local lbl "`v'"
	collect label levels cmdset `idx' "`lbl'", modify
	local ++idx
}

// Bloque B: Hogar y Vivienda del Productor
local idx_hdrB = `idx'
_hdr_row9 `tag9' `idx'
local ++idx
foreach v of local hogar {
	use `master_atr', clear
	qui summ `v' if atrito == 0
	local m0 = r(mean)
	local s0 = r(sd)
	qui summ `v' if atrito == 1
	local m1 = r(mean)
	local s1 = r(sd)
	qui reg `v' atrito, robust
	local d  = _b[atrito]
	local pv = 2 * ttail(e(df_r), abs(_b[atrito] / _se[atrito]))

	qui collect get m =`m0', tags(cmdset[`idx'] arm[NoAtr]) name(`tag9')
	qui collect get sd=`s0', tags(cmdset[`idx'] arm[NoAtr]) name(`tag9')
	qui collect get m =`m1', tags(cmdset[`idx'] arm[Atr])   name(`tag9')
	qui collect get sd=`s1', tags(cmdset[`idx'] arm[Atr])   name(`tag9')
	qui collect get diff=`d', tags(cmdset[`idx'] arm[bal])  name(`tag9')
	qui collect get pv  =`pv', tags(cmdset[`idx'] arm[bal]) name(`tag9')

	local lbl : variable label `v'
	if "`lbl'" == "" local lbl "`v'"
	collect label levels cmdset `idx' "`lbl'", modify
	local ++idx
}

// Bloque C: Predio que maneja el productor
local idx_hdrC = `idx'
_hdr_row9 `tag9' `idx'
local ++idx
foreach v of local predio {
	use `master_atr', clear
	qui summ `v' if atrito == 0
	local m0 = r(mean)
	local s0 = r(sd)
	qui summ `v' if atrito == 1
	local m1 = r(mean)
	local s1 = r(sd)
	qui reg `v' atrito, robust
	local d  = _b[atrito]
	local pv = 2 * ttail(e(df_r), abs(_b[atrito] / _se[atrito]))

	qui collect get m =`m0', tags(cmdset[`idx'] arm[NoAtr]) name(`tag9')
	qui collect get sd=`s0', tags(cmdset[`idx'] arm[NoAtr]) name(`tag9')
	qui collect get m =`m1', tags(cmdset[`idx'] arm[Atr])   name(`tag9')
	qui collect get sd=`s1', tags(cmdset[`idx'] arm[Atr])   name(`tag9')
	qui collect get diff=`d', tags(cmdset[`idx'] arm[bal])  name(`tag9')
	qui collect get pv  =`pv', tags(cmdset[`idx'] arm[bal]) name(`tag9')

	local lbl : variable label `v'
	if "`lbl'" == "" local lbl "`v'"
	collect label levels cmdset `idx' "`lbl'", modify
	local ++idx
}

collect set `tag9'

// Etiquetas de los headers de panel (filas con sólo label).
collect label levels cmdset ///
	`idx_hdrA' "Sociodemográficas"               ///
	`idx_hdrB' "Hogar y Vivienda del Productor"   ///
	`idx_hdrC' "Predio que maneja el productor", modify

collect label levels arm ///
	NoAtr "Productores no-atritos (n=`n_noatr')" ///
	Atr   "Productores atritos (n=`n_atr')"      ///
	bal   "Diferencia",                          modify

collect label levels result ///
	m    "Media"   ///
	sd   "DE"      ///
	diff "Dif."    ///
	pv   "p-valor", modify

collect stars pv 0.01 "***" 0.05 "**" 0.10 "*", attach(pv)

// Estilo de casa BID (Roboto, encabezado azul, bordes y tamaños).
// Lo que se declare DESPUÉS de esta línea se superpone.
do "${ruta_utils}\collect_style_bid.do" `_pt_dat'

collect style cell arm,    font(Roboto, size(`size_m') nobold noitalic) halign(center)
collect style cell result[m diff], nformat(%9.2f)
collect style cell result[sd], nformat(%9.2f) sformat("(%s)")
collect style cell result[pv], nformat(%9.3f)

// Datos (items): regular sin negrita ni cursiva.

// Headers de columna AL FINAL: azul BID + blanco bold.

// Headers de panel: shading gris BID + label en italic bold.
// El shading via cmdset captura la fila ENTERA porque todas las celdas de
// la fila tienen tag cmdset[idx_hdr]. Para ocultar los puntos de los
// valores missing que insertamos como placeholders en las columnas de
// datos, pintamos el color del texto de esas celdas-item con el mismo
// RGB del shading (211 210 209 = #d3d2d1) → quedan invisibles.
collect style cell cmdset[`idx_hdrA' `idx_hdrB' `idx_hdrC'], ///
	shading(background(211 210 209)) ///
	font(Roboto, size(`size_m') italic bold) halign(left)
collect style cell cmdset[`idx_hdrA' `idx_hdrB' `idx_hdrC']#cell_type[item], ///
	font(Roboto, size(`size_m') color(211 210 209))

collect style header arm,    level(label)

local titulo "Tabla 6.2-2 — Balance a nivel productor — atritos y no-atritos en covariables de línea base"
local nota1 "Notas: La unidad de análisis es el productor. Un productor se considera atrito si tiene encuesta de línea base (pertenece a la muestra analítica definida en la Figura 4.2-1) pero no fue alcanzado por la encuesta de línea de seguimiento. La tabla compara la media y desviación estándar de cada covariable basal entre productores no-atritos y atritos."
local nota2 "Esta atrición a nivel productor es conceptualmente distinta de la atrición a nivel clúster reportada en la Figura 4.2-1 (centros poblados aleatorizados sin línea base, excluidos del análisis)."
local nota3 "La diferencia y el p-valor provienen de una regresión simple sin agrupamiento del error estándar, dado que el interés es descriptivo a nivel individual."
local nota4 "Significancia: *** p<0.01, ** p<0.05, * p<0.10."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3' `nota4'"
// Estilo APA-AEA: título en bold (sin italic), tamaño = cuerpo;
// notas en italic, tamaño = (cuerpo − 1) pt.

// Sangría en los nombres de variable (row-headers de cmdset). Va AL FINAL,
// después de todos los estilos generales y específicos, para asegurar que
// no la sobreescriba el `margin(all, width(0pt))` global ni los styles de
// los headers de panel.
collect style cell cmdset#cell_type[row-header], margin(left, width(25pt))
collect style cell cmdset[`idx_hdrA' `idx_hdrB' `idx_hdrC']#cell_type[row-header], ///
	margin(left, width(0pt))

collect layout (cmdset) (arm[NoAtr Atr]#result[m sd] arm[bal]#result[diff pv])

// 7 columnas: cmdset + arm[NoAtr]#result[m sd] + arm[Atr]#result[m sd] + arm[bal]#result[diff pv].
// Suma 100.
mat widths = (38, 14, 6, 14, 6, 10, 12)
collect style putdocx, name(`tag9') width(widths)
collect export "`outdir'\\6.2-2_Tabla_Balance_Atritos_Productor.docx", as(docx) name(`tag9') replace

di as text "Listo: D9 (atrición a nivel productor) y D10 (balance atritos a nivel productor) exportadas en `outdir'."

log close