//------------------------------------------------------------------------------
// File           : I3_summary_cluster.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 28/04/2026
// Description    : Genera la tabla de estadísticas descriptivas a nivel cluster:
//                  número de centros poblados por brazo, distribución por estrato
//                  (cítricos, papa, plátano), e ICC pooled de los outcomes
//                  principales en versión vO. Los ICC se estiman con
//                  modelos de varianza-componentes a nivel cluster, pooled sobre
//                  la muestra de baseline.
// Input          : Out/5_BDs por grupos de vars/Caract_Obs_Trat_ECA.dta
//                  Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta
// Output         : Tablas/0_Diseño_y_Diagnóstico/Cuerpo/D2_Tabla_Descrip_Clus.docx
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
cap erase "${ruta_scripts}\\I3_summary_cluster.log"
log using "${ruta_logs}\\I3_summary_cluster.log", replace text

local outdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\Cuerpo"

// Convenciones del proyecto (estilo APA-AEA híbrido):
//   - Cuerpo y título de la tabla al mismo tamaño base (datos).
//   - Título en bold, sin italic.
//   - Notas a (datos − 1) pt en italic.
// putdocx admite enteros directos en font(Roboto, N); mantenemos versiones
// numéricas puras para usarlas en title()/note() de putdocx_table.
local _pt_dat = 10
local _pt_tit = `_pt_dat'
local _pt_not = `_pt_dat' - 1
local size_m  "`_pt_dat'pt"
local size_n  "`_pt_not'pt"
mat widths = (60, 20, 20)

//==============================================================================
// Step 2: Conteo de CCPPs por brazo y por estrato
//==============================================================================
use Codprod22 post asig_ccpp cod_cpb cod_rgn_PE prod_ECA_eval ///
	using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
// Panel balanceado: los diagnósticos deben describir la MISMA muestra que
// estiman las tablas de resultados. prg_load_panel.do hace `keep if n_obs == 2';
// sin esta restricción el balance se reporta sobre los 1,445 encuestados en
// línea base mientras las estimaciones corren sobre los 1,282 del panel.
bys Codprod22: gen byte _en_panel = (_N == 2)
keep if post == 0 & _en_panel
drop _en_panel
duplicates drop cod_cpb, force

count if asig_ccpp == 0
local nccp_C = r(N)
count if asig_ccpp == 1
local nccp_T = r(N)

gen byte est_papa  = (prod_ECA_eval == 16)
gen byte est_plat  = (prod_ECA_eval == 19)
gen byte est_citri = (prod_ECA_eval == 26)

foreach b in 0 1 {
	foreach s in citri papa plat {
		count if asig_ccpp == `b' & est_`s' == 1
		local n_`s'_`b' = r(N)
	}
}

local strata_C "`n_citri_0', `n_papa_0', `n_plat_0'"
local strata_T "`n_citri_1', `n_papa_1', `n_plat_1'"

di as text "CCPPs Control:     `nccp_C' (Cítricos `n_citri_0', Papa `n_papa_0', Plátano `n_plat_0')"
di as text "CCPPs Tratamiento: `nccp_T' (Cítricos `n_citri_1', Papa `n_papa_1', Plátano `n_plat_1')"

//==============================================================================
// Step 3: ICC pooled de outcomes principales vO en línea base
//==============================================================================
local outcomes ///
	bpa_ena_riego_vO bpa_ena_suelo_vO bpa_ena_fert_abo_vO ///
	bpa_ena_plag_vO bpa_ena_biocontrol_vO bpa_ena_mip_vO bpa_ena_inoc_vO ///
	ena_pilar_agro_vO ena_pilar_insumos_vO ena_pilar_inoc_vO implementa_bpa_ena_vO

// Cargar Vars_Caract_Obs (tiene cod_cpb) y mergear los outcomes vO
use Codprod22 post cod_cpb using "`outc5'\\Caract_Obs_Trat_ECA.dta", clear
// Panel balanceado: los diagnósticos deben describir la MISMA muestra que
// estiman las tablas de resultados. prg_load_panel.do hace `keep if n_obs == 2';
// sin esta restricción el balance se reporta sobre los 1,445 encuestados en
// línea base mientras las estimaciones corren sobre los 1,282 del panel.
bys Codprod22: gen byte _en_panel = (_N == 2)
keep if post == 0 & _en_panel
drop _en_panel
merge 1:1 Codprod22 post using "`outc5'\\BPAs_Compuestos_LByLS.dta", ///
	keepus(`outcomes') keep(3) nogen

// Etiquetas para filas de ICC
lab var bpa_ena_riego_vO        "BPA Riego"
lab var bpa_ena_suelo_vO        "BPA Suelo"
lab var bpa_ena_fert_abo_vO     "BPA Fertilizantes/Abonos"
lab var bpa_ena_plag_vO         "BPA Plaguicidas"
lab var bpa_ena_biocontrol_vO   "BPA Control biológico"
lab var bpa_ena_mip_vO          "BPA Manejo integrado"
lab var bpa_ena_inoc_vO         "BPA Inocuidad"
lab var ena_pilar_agro_vO       "Pilar Agro"
lab var ena_pilar_insumos_vO    "Pilar Insumos"
lab var ena_pilar_inoc_vO       "Pilar Inocuidad"
lab var implementa_bpa_ena_vO   "Compuesto final"

tempname Micc
matrix `Micc' = J(`:word count `outcomes'', 1, .)

local i = 1
foreach v of local outcomes {
	cap noisily mixed `v' || cod_cpb:
	if _rc == 0 {
		cap noisily estat icc
		if _rc == 0 {
			matrix `Micc'[`i',1] = r(icc2)
		}
	}
	local ++i
}
matlist `Micc', title("ICC de las principales variables de resultado")

//==============================================================================
// Step 4: Construir tabla con putdocx (collect no soporta cell-merge directo)
//
// Estructura de la tabla:
//   - Header (fila 1): Variable | Control | Tratamiento  (3 cols)
//   - Sub-panel A (filas 2-6): tamaños y estratos en formato 2 columnas
//        Fila 2: Número de centros poblados | n_C | n_T
//        Fila 3: <sub-header> "Clústeres por estrato (cultivo a evaluar)" — colspan(3)
//        Filas 4-6: Cítricos / Papa / Plátano | n_C | n_T
//   - Sub-panel B (filas 7-18): ICC pooled — colspan(2) en columnas Control/Tratamiento
//        Fila 7: <sub-header> "ICC pooled (baseline) — outcomes principales vO"
//        Filas 8-18: 11 outcomes, valor centrado abarcando ambas columnas
//==============================================================================

local nrows = 18
// Convertir a string limpio (sin padding) para insertar como texto en putdocx
local nccp_C    = strtrim("`: di %4.0f `nccp_C''")
local nccp_T    = strtrim("`: di %4.0f `nccp_T''")
local n_citri_0 = strtrim("`: di %4.0f `n_citri_0''")
local n_citri_1 = strtrim("`: di %4.0f `n_citri_1''")
local n_papa_0  = strtrim("`: di %4.0f `n_papa_0''")
local n_papa_1  = strtrim("`: di %4.0f `n_papa_1''")
local n_plat_0  = strtrim("`: di %4.0f `n_plat_0''")
local n_plat_1  = strtrim("`: di %4.0f `n_plat_1''")

// Recolectar etiquetas para las 11 filas de ICC.
// Las comillas compuestas `" "..." "..." "' permiten que cada string con espacios
// sea un token único al usar `: word i of'.
local outc_lbls `" "BPA Riego" "BPA Suelo" "BPA Fertilizantes/Abonos" "BPA Plaguicidas" "BPA Control biológico" "BPA Manejo integrado" "BPA Inocuidad" "Pilar Agro" "Pilar Insumos" "Pilar Inocuidad" "Compuesto final" "'

putdocx clear
putdocx begin

// title() y note() son opciones de putdocx table que reservan una fila
// adicional en la tabla — title() al inicio (fila 1) y note() al final
// (fila `nrows'+2 cuando hay title). Las filas de datos quedan en 2..(nrows+1).
// Truco para evitar el parsing-error con comas anidadas: usar comillas
// compuestas `"..."' alrededor del string y NO meter coma dentro de font()
// (e.g. font(Roboto,11) sin espacio funciona; font(Roboto, 11) confunde al parser).
putdocx table tbl = (`nrows', 3), border(all, nil) ///
	border(top, single, "000000") border(bottom, single, "000000") ///
	title(`"Tabla D2 — Estadísticas descriptivas del clúster"', font(Roboto,`_pt_tit') bold) ///
	note(`"Notas: El panel superior reporta el número de centros poblados (clústeres) por brazo y por cultivo a evaluar. El panel inferior reporta el coeficiente de correlación intraclúster (ICC) estimado con un modelo lineal de efectos aleatorios a nivel de centro poblado sobre la panel balanceado en línea base (los productores con observación en ambas rondas; ver Figura 4.2-1). Las variables de resultado principales corresponden a la versión ENA."', font(Roboto,`_pt_not') italic)

//------------------------------------------------------------------------------
// Step 5: Llenar filas (asignación de texto antes de aplicar colspan)
//------------------------------------------------------------------------------

// Fila 2: header principal
putdocx table tbl(2, 1) = ("Variable"), halign(left)
putdocx table tbl(2, 2) = ("Control"), halign(center)
putdocx table tbl(2, 3) = ("Tratamiento"), halign(center)

// Fila 3: número de CCPPs
putdocx table tbl(3, 1) = ("Número de centros poblados"), halign(left)
putdocx table tbl(3, 2) = ("`nccp_C'"), halign(center)
putdocx table tbl(3, 3) = ("`nccp_T'"), halign(center)

// Fila 4: sub-panel header "Clústeres por estrato"
putdocx table tbl(4, 1) = ("Clústeres por cultivo a evaluar"), halign(left) italic

// Filas 5-7: estratos (con sangría en col 1)
putdocx table tbl(5, 1) = ("    Cítricos"),   halign(left)
putdocx table tbl(5, 2) = ("`n_citri_0'"),    halign(center)
putdocx table tbl(5, 3) = ("`n_citri_1'"),    halign(center)

putdocx table tbl(6, 1) = ("    Papa"),       halign(left)
putdocx table tbl(6, 2) = ("`n_papa_0'"),     halign(center)
putdocx table tbl(6, 3) = ("`n_papa_1'"),     halign(center)

putdocx table tbl(7, 1) = ("    Plátano"),    halign(left)
putdocx table tbl(7, 2) = ("`n_plat_0'"),     halign(center)
putdocx table tbl(7, 3) = ("`n_plat_1'"),     halign(center)

// Fila 7: sub-panel header "ICC pooled..."
putdocx table tbl(8, 1) = ("ICC de las principales variables de resultado"), halign(left) italic

// Filas 8-18: outcomes ICC (valor en col 2, col 3 vacía y se fusionará)
forval i = 1/11 {
	local row = `i' + 8
	local lbl : word `i' of `outc_lbls'
	local val = `Micc'[`i', 1]
	if mi(`val') {
		local val_f "."
	}
	else {
		local val_f = strtrim("`: di %5.3f `val''")
	}
	putdocx table tbl(`row', 1) = ("    `lbl'"), halign(left)
	putdocx table tbl(`row', 2) = ("`val_f'"),   halign(center)
	putdocx table tbl(`row', 3) = (""),          halign(center)
}

//------------------------------------------------------------------------------
// Step 6: Aplicar colspan después de las asignaciones
//------------------------------------------------------------------------------

// Sub-panel headers (filas 4 y 8) abarcan las 3 columnas
putdocx table tbl(4, 1), colspan(3)
putdocx table tbl(8, 1), colspan(3)

// Filas ICC (9-19): col 2 abarca cols 2-3 (cell merge entre Control y Tratamiento)
forval r = 9/19 {
	putdocx table tbl(`r', 2), colspan(2)
}

//------------------------------------------------------------------------------
// Step 7: Estilos BID
//
// Estrategia: aplicar el font(`_pt_dat') únicamente a las filas de datos,
// NO con tbl(.,.). Así respetamos los formatos definidos en title()/note()
// del Step 4 sin tener que sobreescribirlos al final.
// Filas: 1 = title, 2 = header, 3..(nrows+1) = datos, (nrows+2) = nota.
//------------------------------------------------------------------------------

// Header principal (fila 2): azul BID, texto blanco, negrita
putdocx table tbl(2,.), shading("004e70")
putdocx table tbl(2,.), font(Roboto, `_pt_dat', "ffffff") bold halign(center)
putdocx table tbl(2, 1), halign(left)
putdocx table tbl(2,.), border(bottom, single, "000000")

// Filas de datos del Sub-panel A: número CCPPs (3) y estratos (5-7).
// Saltamos la fila 4 (sub-header) — se estiliza después con sus propios atributos.
putdocx table tbl(3,.), font(Roboto, `_pt_dat')
forval r = 5/7 {
	putdocx table tbl(`r',.), font(Roboto, `_pt_dat')
}

// Filas de datos del Sub-panel B: outcomes ICC (9-19).
// Saltamos la fila 8 (sub-header).
forval r = 9/19 {
	putdocx table tbl(`r',.), font(Roboto, `_pt_dat')
}

// Sub-panel headers (filas 4 y 8): gris BID claro, italic + bold.
// Después de colspan, sólo (r,1) es accesible.
putdocx table tbl(4, 1), shading("d3d2d1")
putdocx table tbl(4, 1), font(Roboto, `_pt_dat') italic bold
putdocx table tbl(8, 1), shading("d3d2d1")
putdocx table tbl(8, 1), font(Roboto, `_pt_dat') italic bold

// Separador entre la última fila de datos (fila 19) y la nota (fila 20).
// Aplicamos el borde a la celda (19, 1); como la fila 19 ya tiene colspan(2)
// en la celda 2, el borde se ve a lo ancho de toda la tabla.
putdocx table tbl(19, 1), border(bottom, single, "000000")
putdocx table tbl(19, 2), border(bottom, single, "000000")

//------------------------------------------------------------------------------
// Step 8: Guardar
// (La nota ya quedó embebida en la tabla via la opción note() del Step 4.)
//------------------------------------------------------------------------------
putdocx save "`outdir'\\D2_Tabla_Descrip_Clus.docx", replace

di as text "Listo: D2_Tabla_Descrip_Clus exportada en `outdir'."

log close
