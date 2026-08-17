//------------------------------------------------------------------------------
// File           : C1_make_treated_producers.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Crea la base final de productores tratados a partir de dos fuentes:
//                  (a) ECAS_2019_AL_2023.xlsx (datos SENASA) y (b) Consolidado de
//                  reporte de asistencia BID. Para cada fuente, estandariza strings,
//                  corrige nombres de CCPPs y DNIs, codifica productos, filtra centros
//                  poblados aleatorizados y elimina duplicados. Luego fusiona ambas
//                  fuentes para el año 2021, valida la consistencia geografica,
//                  completa valores faltantes, imputa sesiones asistidas y genera
//                  variables de participacion. Finalmente, limpia archivos intermedios.
//                  La imputacion de sesiones solo alcanza a quien tenga registrado
//                  el total de sesiones de su ECA; el resto queda sin dato, y la
//                  bandera ssns_imputado distingue los tres estados.
// Depends        : _utils/std_strings.do
//                  _utils/fix_ccpp_names.do
//                  _utils/fix_dni_names.do
//                  _utils/filter_randomized_ccpp.do
// Input          : Raw/3_.../Copia de Informacion ECAS_2019_AL_2023.xlsx
//                  Raw/3_.../2. A. Consolidado de reporte de asistencia BID - Editado.xlsx
// Output         : Out/3_.../Productor/SENASA_PRODUCTORES_ECA_{2019..2023}-CCPP_ALEA.dta
//                  Out/3_.../Productor/BD_REPORTE_BID_PRODUCTORES_{2020..2022}.dta
//                  Out/3_.../Productor/PRODUCTORES_2021_CCPPs_ALEA.dta
//------------------------------------------------------------------------------
cls
version 19.0
clear all

// Llamar do-file con rutas
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

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\C1_make_treated_producers.log"
log using "${ruta_logs}\C1_make_treated_producers.log", replace text

//==============================================================================
// Step 1: Process SENASA roster (ECAS 2019-2023)
//==============================================================================
{
// Cargar Data
	import excel "`rawc3'\\Copia de Informacion ECAS_2019_AL_2023.xlsx", ///
		clear sheet("REPORTE_ECAS") firstrow case(l)

// Renombrar variables 
	ren departamento 		nomb_rgn
	ren provincia			nomb_prvnc
	ren distrito			nomb_dstrt
	ren centro_poblado		nomb_ccpp
	ren nombre_de_la_eca 	nomb_ECA
	ren productos			prod_ECA
	ren bpabpp				tipo_ECA
	ren año					año_ini_ECA
	ren nombres 			nomb_prod
	ren apellidos			apell_prod
	ren dni 				dni_prod
	ren promedio_final		prom_fin
	
// Estandarizar Strings 
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1
	ds, has(type string)
	local list_of_strings `r(varlist)'
	gl varstoremaccent 	`list_of_strings'
	gl varstoremumlaut 	`list_of_strings'
	gl varstoremcircumf `list_of_strings'
	gl varstoremother 	`list_of_strings'
	qui do "${ruta_utils}\std_strings.do"

// Crear/modificar variables 
//  Nombres de CCPPs: Correr do que corrige nombre de CCPPs
	do "${ruta_utils}\fix_ccpp_names.do"
	replace nomb_dstrt="HUAYLLABAMBA" 	if nomb_ECA=="ASOCIACION DE PRODUCTORES LOS TRIUNFADORES DE PACHAVILCA"
	replace nomb_ccpp="PACHAVILCA"		if nomb_ECA=="ASOCIACION DE PRODUCTORES LOS TRIUNFADORES DE PACHAVILCA"
	
//  Producto de ECA: Generar variable codificada
	replace prod_ECA = ustrtitle(prod_ECA)
	replace prod_ECA = "Limón" 	 if prod_ECA=="Limon"
	replace prod_ECA = "Maíz"	 if prod_ECA=="Maiz"
	replace prod_ECA = "Plátano" if prod_ECA=="Platano"	
	encode  prod_ECA, gen(prodECA)
	lab define prodECA 26 "Cítrico", modify
	drop prod_ECA
	ren prodECA prod_ECA
	
//  Año de inicio de ECA: de string a numérica
	destring año_ini_ECA, replace 
	
//  DNI del Productor: Símbolos anómalos y completar con 0s para 8 dígitos
	replace dni_prod = substr("00000000" + dni_prod, -8, 8) if length(dni_prod) < 8
	replace dni_prod = subinstr(dni_prod, "*", "", .)
	replace dni_prod = subinstr(dni_prod, ".", "", .)
	replace dni_prod = subinstr(dni_prod, "_", "", .)
	replace dni_prod = subinstr(dni_prod, "|", "", .)

//  Nombres de lugares y ECA: Quitar comillas dobles, puntos al inicio/fin y otros caracteres
	foreach v in nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp nomb_ECA{
		replace `v' = trim(itrim(ustrregexra(`v', `"""', "")))
		replace `v' = trim(itrim(ustrregexra(`v', "^\.", "")))
		replace `v' = trim(itrim(ustrregexra(`v', "\.$", "")))
		replace `v' = regexr(`v', "´", "")
		replace `v' = regexr(`v', "'", "")
		replace `v' = regexs(1) if regexm(`v', "^(.*)\.$")
		replace `v' = regexs(1) +  "(" + regexs(2) + ")" if regexm(`v', "^(.*)\(\s+([A-Z]+)\s+\)")
	}
	
//  Graduado: Promedio mayor o igual a 11 se graduaron (supuesto)
	qui do "${ruta_utils}\lab_sino.do"
	gen graduado:sino = (prom_fin>=11) if !mi(prom_fin)	

// Hacer cambios manuales a números de DNIs y nombres de productores
	qui do "${ruta_utils}\fix_dni_names.do"	
	
// Trim data
// 	Regiones relevantes (que contienen solo centros poblados aleatorizados), y
// 	Variables relevantes
	keep if nomb_rgn=="AMAZONAS"|nomb_rgn=="ANCASH"	 |nomb_rgn=="APURIMAC" | ///
		nomb_rgn=="AREQUIPA"|nomb_rgn=="AYACUCHO"	 |nomb_rgn=="CAJAMARCA"| ///
		nomb_rgn=="CUSCO"	|nomb_rgn=="HUANCAVELICA"|nomb_rgn=="JUNIN"	   | ///
		nomb_rgn=="LIMA"	|nomb_rgn=="PASCO"		 |nomb_rgn=="SAN MARTIN"| ///
		nomb_rgn=="TUMBES"
	keep año_ini_ECA nomb_* *_ECA *_prod prom_fin graduado
	
// 	Centros Poblados aleatorizados (i.e parte del estudio o que incialmente lo eran)
	qui do "${ruta_utils}\filter_randomized_ccpp.do"
	
// Casos duplicados (base queda a nivel año-productor-eca)
//  Eliminar duplicados en todos los campos
	duplicates drop

// 	Ordenar: Productor con mayor nota primero (de una misma ECA)
	gsort año_ini_ECA nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA nomb_ECA dni_prod -prom_fin

// 	Eliminar duplicados a nivel año-producto-eca-productor
	duplicates drop año_ini_ECA nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA nomb_ECA dni_prod, force
	
// Ordenar variables y data
	order prod_ECA nomb_ECA, a(tipo_ECA)
	order año_ini_ECA, a(nomb_ECA)
	order dni_prod, b(nomb_prod)
	gsort año_ini_ECA nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA nomb_ECA -prom_fin

// Etiquetar y guardar la data (loop de base por año)
	lab var nomb_rgn 		"Nombre de Región"
	lab var nomb_prvnc 		"Nombre de Provincia"
	lab var nomb_dstrt		"Nombre de Distrito"
	lab var nomb_ccpp 		"Nombre de Centro Poblado"
	lab var prod_ECA 		"Producto que capacitó la ECA"
	lab var tipo_ECA		"Tipo de ECA (BBP o BPA)"
	lab var nomb_ECA 		"Nombre de la ECA"
	lab var año_ini_ECA		"Año de inicio de ECA"
	lab var dni_prod		"DNI del Productor"
	lab var nomb_prod		"Nombres del Productor"
	lab var apell_prod		"Apellidos del Productor"
	lab var prom_fin 		"Promedio Final del Productor"
	lab var graduado		"Estado Graduación del Productor"
	
	qui levelsof año_ini_ECA, local(lvly)
	foreach yy in `lvly'{
		preserve
		keep if año_ini_ECA==`yy'
		qui count 
		if `r(N)'==0{
			restore 
			continue
		}
		else{
			compress
			save "`outc3prod'\\SENASA_PRODUCTORES_ECA_`yy'-CCPP_ALEA.dta", replace
		}
		restore
	}
}

//==============================================================================
// Step 2: Process BID attendance report
//==============================================================================
{
// Cargar Data
	import excel "`rawc3'\2. A. Consolidado de reporte de asistencia BID - Editado", ///
	clear sheet("Base de datos de listas ECAs") cellra(B1:T1265) firstrow case(l) 

// NOTA: HICE ALGUNOS CAMBIOS MANUALES A LA BASE DE CONSOLIDADO EN EXCEL.
// DESTACAN EL  CAMBIO DE NOMBRE DE REGION DE CHAVIN A ANCASH, FECHAS, NÚMERO DE
// SESIONES DE UN  CENTO POBLADO DONDE DECÍA PAPA QUE INFERÍ ERAN 12, ENTRE OTROS.

// Renombrar variables 
	ren región 							nomb_rgn
	ren provincia						nomb_prvnc
	ren distrito						nomb_dstrt
	ren centropoblado					nomb_ccpp
	ren productoenelquesebasólaec		prod_ECA
	ren fechadeiniciodelaecadrp 		fch_ini_ECA
	ren fechadecierredelaecaclaus 		fch_fin_ECA
	ren númerototaldesesionesenlas		ssns_as_prod
	ren númerototaldesesionesdelae 		ssns_ECA
	ren nombresyapellidosdelresponsa	nomb_resp
	ren correoelectronicodelresponsab	corr_resp
	ren nombrescompletosenmayúscula 	nomb_prod
	ren apellidoscompletos 				apell_prod
	ren dni								dni_prod
	ren indicarsiestapersonasegradu 	graduado
	ren notafinalobtenidaporlaperso		prom_fin
		 
// Estandarizar Strings
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1
	ds, has(type string)
	local list_of_strings `r(varlist)'
	gl varstoremaccent 	`list_of_strings'
	gl varstoremumlaut 	`list_of_strings'
	gl varstoremcircumf `list_of_strings'
	gl varstoremother 	`list_of_strings'
	qui do "${ruta_utils}\std_strings.do"

// Crear/modificar variables 
//  Cambio manual a distrito de Santa Isabel de Siguas
	replace nomb_dstrt="SANTA ISABEL DE SIGUAS" if nomb_dstrt=="SANTA ISABEL" & nomb_prvnc=="AREQUIPA"
	
//  Producto de ECA: Cambiar de string a numérica con códigos de prodECA (mirar arriba)
	replace prod_ECA = ustrtitle(prod_ECA)
	replace prod_ECA = "15" if prod_ECA=="Naranja"
	replace prod_ECA = "16" if prod_ECA=="Papa"
	replace prod_ECA = "19" if prod_ECA=="Platano"
	destring prod_ECA, replace 	

//  Tipo de ECA: BPA para productos codificados
	gen tipo_ECA = "BPA" if inlist(prod_ECA,15,16,19), a(prod_ECA)

//  Nombres de ECAs y CCPPs: Adjudicar nombre de CCPPs (algunos cambios son manuales)
// === Nota: Cambios solo en nombres con 100% de certeza. Imputación del nombre de la base ECAS_2019_AL_2023.
	gen nomb_ECA = "", a(tipo_ECA)
	replace nomb_ECA = "ASOCIACIÓN DE PRODUCTORES LA JUVENTUD DE AHIJADERO" if nomb_ccpp=="AHIJADERO-ASOCIACION"
	replace nomb_ECA = "COMITE DE PRODUCTORES SAN ANTONIO DE AHIJADERO I"	if nomb_ccpp=="AHIJADERO-COMITE"
	replace nomb_ECA = "LOS EMPRENDEDORES DE MAREHUAIN - HUAMARIN" 	if nomb_ccpp=="HUAMARIN-EMPRENDEDORES"
	replace nomb_ECA = "SANTA ROSA DE MAREHUAIN - HUAMARIN" 		if nomb_ccpp=="HUAMARIN-SANTA ROSA"
	replace nomb_ECA = nomb_ccpp   if regexm(nomb_ccpp, "PARARIN")
	replace nomb_ECA = "PALLAHUASI" if nomb_ccpp=="VILCABAMBA -PALLAHUASI"
	replace nomb_ECA = "CHAUPIS"	if nomb_ccpp=="VILCABAMBA- CHAUPIS"
	
//  Nombres de CCPPs: Correr do que corrige nombre de CCPPs
	do "${ruta_utils}\fix_ccpp_names.do"	
	
//  DNI del Productor: Símbolos anómalos y completar con 0s para 8 dígitos
	replace dni_prod = substr("00000000" + dni_prod, -8, 8) if length(dni_prod) < 8
	replace dni_prod = subinstr(dni_prod, "*", "", .)
	replace dni_prod = subinstr(dni_prod, ".", "", .)
	replace dni_prod = subinstr(dni_prod, "_", "", .)
	replace dni_prod = subinstr(dni_prod, "|", "", .)

//  Nombres de lugares y ECA: Eliminar caracteres
	foreach v in nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp{
		replace `v' = trim(itrim(ustrregexra(`v', `"""', "")))
		replace `v' = trim(itrim(ustrregexra(`v', "^\.", "")))
		replace `v' = trim(itrim(ustrregexra(`v', "\.$", "")))
		replace `v' = regexr(`v', "´", "")
		replace `v' = regexr(`v', "'", "")
		replace `v' = regexs(1) if regexm(`v', "^(.*)\.$")
		replace `v' = regexs(1) +  "(" + regexs(2) + ")" if regexm(`v', "^(.*)\(\s+([A-Z]+)\s+\)")
	}

//  Año de Inicio de ECA
	gen año_ini_ECA = year(fch_ini_ECA), b(fch_ini_ECA)
	
//  Graduado y Promedio Final: De string a numéricas
	qui do "${ruta_utils}\lab_sino.do"
	replace  graduado="1" if graduado=="SI"
	replace  graduado="0" if graduado=="NO"
	destring graduado	,	replace
	destring prom_fin	, 	replace float
	lab val graduado sino
	
//  Fecha de inicio/fin de ECAs: Modificar formato a fecha
	foreach name in ini fin{ 
		format fch_`name'_ECA %tdDD-NN-CCYY
	}

//  Correr do-file con cambios manuales a DNIs y nombres de productores
	qui do "${ruta_utils}\fix_dni_names.do"	
	
// Trim data
//  Variables relevantes
	keep nomb_* *_ECA *_prod prom_fin graduado
	drop *_resp 

//  Centros poblados aleatorizados (i.e parte del estudio o que incialmente lo eran)
	qui do "${ruta_utils}\filter_randomized_ccpp.do"	
	
// Casos duplicados (base queda a nivel año-productor-eca)
//  Eliminar duplicados en todos los campos
	duplicates drop

//  Ordenar: Productor con mayor nota primero (de una misma ECA)
	gsort año_ini_ECA nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA nomb_ECA dni_prod -prom_fin

//  Eliminar duplicados a nivel año-producto-eca-productor
	duplicates drop año_ini_ECA nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA nomb_ECA dni_prod, force

// Ordenar variables y data
	order nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp
	order prod_ECA nomb_ECA, a(tipo_ECA)
	order año_ini_ECA, a(nomb_ECA)
	order dni_prod nomb_prod, b(apell_prod)
	order prom_fin, b(graduado)
	gsort año_ini_ECA nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA nomb_ECA -prom_fin	
	
// Etiquetar y guardar la data (loop de base por año)
	lab var nomb_rgn 		"Nombre de Región"
	lab var nomb_prvnc 		"Nombre de Provincia"
	lab var nomb_dstrt		"Nombre de Distrito"
	lab var nomb_ccpp 		"Nombre de Centro Poblado"
	lab var prod_ECA 		"Producto que capacitó la ECA"
	lab var tipo_ECA		"Tipo de ECA (BBP o BPA)"
	lab var nomb_ECA 		"Nombre de la ECA"
	lab var año_ini_ECA		"Año de inicio de ECA"
	lab var fch_ini_ECA 	"Fecha Inicio de ECA"
	lab var fch_fin_ECA 	"Fecha Fin de ECA"
	lab var ssns_ECA		"Sesiones ECA"
	lab var dni_prod		"DNI del Productor"
	lab var nomb_prod		"Nombres del Productor"
	lab var apell_prod		"Apellidos del Productor"
	lab var ssns_as_prod	"Sesiones que asistió el productor"
	lab var prom_fin 		"Promedio Final del Productor"
	lab var graduado		"Estado Graduación del Productor"

	qui levelsof año_ini_ECA, local(lvly)
	foreach yy in `lvly'{
		preserve
		keep if año_ini_ECA==`yy'
		if `yy'==2021{
			ren (nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prom_fin) ///
				(U_nomb_rgn U_nomb_prvnc U_nomb_dstrt U_nomb_ccpp U_prom_fin)
		}
		if `yy'!=2021{
			replace nomb_ECA = "ECA en " + nomb_ccpp if mi(nomb_ECA)
		}
		compress
		save "`outc3prod'\\BD_REPORTE_BID_PRODUCTORES_`yy'.dta", replace
		restore
	}
}

//==============================================================================
// Step 3: Merge SENASA and BID sources for 2021
//==============================================================================
{
// Cargar data de ambas fuentes para el año 2021
	use "`outc3prod'\\SENASA_PRODUCTORES_ECA_2021-CCPP_ALEA.dta", clear
// ==== Nota: Para evitar problemas con la ejecución de este bloque correr los bloques anteriores.
// Merge de ambas fuentes de información
	merge m:1 dni_prod using "`outc3prod'\\BD_REPORTE_BID_PRODUCTORES_2021.dta"

// Sanity check: Validar merge
	cap assert (nomb_rgn==U_nomb_rgn) & (nomb_prvnc==U_nomb_prvnc) & ///
			   (nomb_dstrt==U_nomb_dstrt) & (nomb_ccpp==U_nomb_ccpp) if _m==3
	if _rc {
		di as error "Error: Región o provincia o distrito o ccpp no coinciden entre bases"
		error 9 
	}

// Track: Fuente de donde proviene la observación
	lab def fte 1 "ECAS 2019-2023" 2 "Consolidado Asistencia BID" 3 "Ambas"
	gen fuente:fte = 1 if _m==1
	replace fuente = 2 if _m==2 
	replace fuente = 3 if _m==3
	drop _m
	lab var fuente "Fuente (¿De dónde proviene esta observación?)"

// Fill missing values
	replace nomb_rgn   	= U_nomb_rgn   	if mi(nomb_rgn)
	replace nomb_prvnc 	= U_nomb_prvnc 	if mi(nomb_prvnc)
	replace nomb_dstrt 	= U_nomb_dstrt 	if mi(nomb_dstrt) 
	replace nomb_ccpp  	= U_nomb_ccpp  	if mi(nomb_ccpp)		
	recast 	double U_prom_fin
	replace prom_fin 	= U_prom_fin 	if mi(prom_fin)
	replace graduado    = 0 if prom_fin<11
	drop U_*

// Sort Data
// 	Criterio 1: Dentro de un CCPP y ECA ordena primero obs con fecha de inicio no missing
	gsort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA -nomb_ECA fch_ini_ECA -fuente
	local blockccpp 	nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp
	local blockprodECA  `blockccpp' prod_ECA
	local blocknombECA	`blockccpp' nomb_ECA

//  Capturar el orden completo
	gen long _sortorder = _n

//  Forward-Fills (FF) and Fallback's (FBs) y Sanity Checks (SC)
// 		FF1: Arrastra nombre de ECA para un mismo producto en un ccpp
	bys `blockprodECA' (_sortorder): replace nomb_ECA = nomb_ECA[_n-1] if mi(nomb_ECA)

// 		FB1: Para missings residuales de nomb_ECA asignar "ECA en [nombre ccpp]"
	qui levelsof nomb_ccpp, local(nccpp)
	foreach n in `nccpp'{
		qui replace nomb_ECA="ECA en `n'" if mi(nomb_ECA) & nomb_ccpp=="`n'"
	}

// 		FB2: Arrastra valores de fechas y sesiones (n) para una misma ECA
	foreach v in fch_ini_ECA fch_fin_ECA ssns_ECA{
		bys `blocknombECA' (_sortorder): replace `v'=`v'[_n-1] if mi(`v')
	}
	
// 		SC 1: Mistake es 1 si para una misma ECA hay dos fechas distintas
	bys `blocknombECA' (_sortorder): gen mistake = fch_ini_ECA[1]!=fch_ini_ECA[_N]
	qui count if mistake!=0
	if `r(N)'>0{
		di as error "Alguna(s) ECA(s) tiene(n) fechas que no coinciden."
		error 9
	}
	else{
		drop mistake
	}
	drop _sortorder

// 		SC 2: Tabular ECAs sin fechas de inicio/fin
	tab nomb_ccpp if mi(fch_ini_ECA) | mi(fch_fin_ECA)

// 	Criterio 2: Ordenar en funcion de lo mismo + promedio final (de mayor a menor nota)
	gsort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp prod_ECA -nomb_ECA fch_ini_ECA -fuente -prom_fin

// Generar otras variables
//  Sesiones asistidas por productor
// 	El alcance de esta imputación es limitado a propósito. `predict' devuelve
// 	missing si falta cualquier regresor, y ssns_ECA (el total de sesiones de la
// 	ECA) no existe para las ECAs que solo aparecen en el padrón de SENASA, que
// 	no registra asistencia. Esos productores quedan SIN dato de asistencia y así
// 	se guardan: imputarles el total de sesiones exigiría inventar el denominador
// 	del porcentaje, y no hay base para hacerlo. La bandera ssns_imputado deja
// 	esto explícito en la base en vez de que haya que deducirlo del código.
	encode  nomb_rgn, gen(nomb_rgn_enc)
	encode  nomb_ccpp, gen(nomb_ccpp_enc)
	qui reg ssns_as_prod graduado prom_fin ssns_ECA i.prod_ECA i.nomb_rgn_enc i.nomb_ccpp_enc
	predict ssns_as_pro_hat, xb
	replace ssns_as_pro_hat = round(ssns_as_pro_hat,1)

// 	Acotar al rango factible. `predict, xb' extrapola linealmente y puede salirse
// 	de [0, ssns_ECA] cuando la nota del productor está lejos del soporte de su
// 	centro poblado: el caso observado es una nota de 0 en un CCPP cuyas demás
// 	notas promedian 17, que arrastra la predicción a -1 sesiones. El round()
// 	redondea pero no acota.
	replace ssns_as_pro_hat = 0 if ssns_as_pro_hat < 0 & !mi(ssns_as_pro_hat)
	replace ssns_as_pro_hat = ssns_ECA ///
		if ssns_as_pro_hat > ssns_ECA & !mi(ssns_as_pro_hat) & !mi(ssns_ECA)

// 	Bandera de procedencia del dato. Sin ella, una vez guardado el .dta la
// 	distinción entre asistencia observada e imputada es irrecuperable y no se
// 	puede correr la robustez de excluir imputados. Queda en missing para quien
// 	no tiene dato de asistencia por ninguna vía (ver nota de arriba), de modo
// 	que ssns_imputado es no-missing exactamente cuando ssns_as_prod lo es.
	lab def imput 0 "Observado" 1 "Imputado"
	gen byte ssns_imputado:imput = 0 if !mi(ssns_as_prod)
	replace  ssns_imputado = 1 if mi(ssns_as_prod) & !mi(ssns_as_pro_hat)
	lab var  ssns_imputado "Procedencia de ssns_as_prod (observado / imputado por regresión)"

	replace ssns_as_prod = ssns_as_pro_hat if mi(ssns_as_prod)
	drop 	ssns_as_pro_hat nomb_rgn_enc nomb_ccpp_enc
		
//  Porcentaje de sesiones asistidas
	lab def pctssns 1 "0%< S <=25%" 2 "25%< S <=50%" 3 "50%< S <=75%" 4 "75%< S <=100%"
	gen float pct_ssns_as = ssns_as_prod/ssns_ECA*100 
	gen byte cat_ssns_as:pctssns = 1 if pct_ssns_as <= 25
	replace cat_ssns_as   = 2 if pct_ssns_as > 25 & pct_ssns_as <= 50
	replace cat_ssns_as   = 3 if pct_ssns_as > 50 & pct_ssns_as <= 75
	replace cat_ssns_as   = 4 if pct_ssns_as > 75 & pct_ssns_as <= 100
	format %4.2f pct_ssns_as
	lab var pct_ssns_as "Porcentaje de sesiones a las que asistió"
	lab var cat_ssns_as "Categoría (<=25%<=50%<=75%<=100%) de sesiones a las que asistió"
	order pct_ssns_as cat_ssns_as, a(ssns_as_prod)
		
//  Variable para emparejar
	gen idu = _n
	
// Guardar data
	compress
	save "`outc3prod'\\PRODUCTORES_2021_CCPPs_ALEA", replace
}

//==============================================================================
// Step 4: Clean up intermediate files
//==============================================================================
// Eliminar archivos intermedios.
// La carpeta se crea con la ruta ABSOLUTA. Antes usaba el local `c3', que es
// solo el nombre de la subcarpeta ("3_Centros Poblados y su..."), así que el
// mkdir apuntaba a un destino relativo al directorio de trabajo. Funcionaba en
// la máquina del autor porque la carpeta ya existía de una corrida vieja; en un
// clon limpio el `copy' de abajo —que no está capturado— aborta el script.
cap mkdir "`outc3prod'\Temp_or_Trash"
local file1 "SENASA_PRODUCTORES_ECA_2021-CCPP_ALEA.dta"
local file2 "BD_REPORTE_BID_PRODUCTORES_2021.dta"
copy "`outc3prod'\\`file1'" "`outc3prod'\Temp_or_Trash\\`file1'", replace 
copy "`outc3prod'\\`file2'" "`outc3prod'\Temp_or_Trash\\`file2'", replace
erase "`outc3prod'\\`file1'"
erase "`outc3prod'\\`file2'"

log close