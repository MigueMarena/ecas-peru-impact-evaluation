//------------------------------------------------------------------------------
// File           : C2_make_ccpp_assignment.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Crea la base a nivel de centro poblado con su estatus de asignacion
//                  al tratamiento y el estado final de tratamiento. Procesa cada base
//                  anual de CCPPs-ECAs (2020-2022), selecciona la primera ECA
//                  implementada en el CCPP, fusiona con la lista de centros aleatorizados
//                  y genera variables de cumplimiento (a nivel de centro), periodo
//					de implementacion, exclusión y otros.
// Depends        : _helpers/prg_procesa_eca.do
// Input          : Out/3_.../Productor/BD_REPORTE_BID_PRODUCTORES_2020.dta
//                  Out/3_.../Productor/PRODUCTORES_2021_CCPPs_ALEA.dta
//                  Out/3_.../Productor/SENASA_PRODUCTORES_ECA_2022-CCPP_ALEA.dta
//                  Out/3_.../CCPP/CCPP-ECAs-2020.dta
//                  Out/3_.../CCPP/CCPP-ECAs-2021.dta
//                  Out/3_.../CCPP/CCPP-ECAs-2022.dta
//                  Raw/3_.../CCPPs_ALEATORIZADOS_Y_REEMPLAZOS.dta
// Output         : Out/3_.../CCPP/CCPPsALEAy1aECA.dta
//                  Out/3_.../CCPP/CCPPALEAy1AECA_ESTAT_CUMPL.dta
//------------------------------------------------------------------------------

version 19.0

//==============================================================================
// Step 1: Set up environment and load programs
//==============================================================================
cls 
clear 

// Correr programa que procesa cada base por separado
do "${ruta_helpers}\\prg_procesa_eca"

// Llamar do-file con rutas
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
if "${ruta_data}" == "" {
	capture qui include "${ECAS}/2_Scripts/A_master.do"
	if _rc capture qui include "2_Scripts/A_master.do"
	if "${ruta_data}" == "" {
		di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
		di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
		exit 601
	}
}

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\C2_make_ccpp_assignment.log"
log using "${ruta_logs}\C2_make_ccpp_assignment.log", replace text


//==============================================================================
// Step 2: Process ECA bases by year
//==============================================================================
procesaECA 2020 "`outc3prod'\\BD_REPORTE_BID_PRODUCTORES_2020" 	"`outc3ccpp'"
procesaECA 2021 "`outc3prod'\\PRODUCTORES_2021_CCPPs_ALEA" 		"`outc3ccpp'"
procesaECA 2022 "`outc3prod'\\SENASA_PRODUCTORES_ECA_2022-CCPP_ALEA" "`outc3ccpp'"

//==============================================================================
// Step 3: Append annual bases and select first ECA per CCPP
//==============================================================================
use "`outc3ccpp'\\CCPP-ECAs-2020", clear
append using "`outc3ccpp'\\CCPP-ECAs-2021"
append using "`outc3ccpp'\\CCPP-ECAs-2022"
lab val prod_ECA prodECA
gsort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp año_ini_ECA fch_ini_ECA -astn_ECA -grad_ECA

// Quedarme con la primera ECA implementada en el CCPP (la de fecha más antigua)
// Si hay empate, me quedo con la ECA con mayor cantidad de asistentes o graduados.

by nomb_rgn-nomb_ccpp: keep if _n==1
ren *_ECA *_1aECA_ccpp
foreach l of varlist *_1aECA_ccpp{
	local lbl : var lab `l'
	local new_lbl =regexr("`lbl'", "(de la ECA)|(de ECA)|(ECA)", "de 1era ECA en el Centro Poblado")
	lab var `l' "`new_lbl'"
}
lab var prod_1aECA_ccpp "Producto en que capacitó la 1aECA en el Centro Poblado"

// Guardo la data de centros aleatorizados y la primera ECA implementada en ellos	
save "`outc3ccpp'\\CCPPsALEAy1aECA", replace

//==============================================================================
// Step 4: Merge with randomization list and build analysis variables
//==============================================================================
// Cargar data de los CCPPs Aleatorizados
use "`rawc3'\CCPPs_ALEATORIZADOS_Y_REEMPLAZOS", clear

// Merge con bases a nivel CCPP-ECA
merge 1:1 nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp using "`outc3ccpp'\\CCPPsALEAy1aECA", nogen
keep nomb_rgn-asig_ccpp prod_* año_ini_* fch_ini_* tiempo astn_1aECA
sort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp año_ini_1aECA
lab val prod_ECA_eval prodECA

// Implementaron 1ra ECA en Producto a Evaluar (solo en centros donde implementan ECA)
lab def sino 0 "No" 1 "Sí"
gen i1aECA_PE_ccpp:sino = (prod_ECA_eval==prod_1aECA) | ///
					  (prod_ECA_eval==26 & inlist(prod_1aECA,11,12,15)) if prod_1aECA!=.
lab var i1aECA_PE_ccpp  "Impl. 1era ECA en Producto a Evaluar en el Centro Poblado (. si no implementa ECA)"

// Implementaron 1ra ECA en cualquier Producto a Evaluar (solo en centros donde implementan ECA)
gen i1aECA_algPE_ccpp:sino = inlist(prod_1aECA,11,12,15,16,19) if prod_1aECA!=.
lab var i1aECA_algPE_ccpp  "Impl. 1era ECA en cualquier Producto a Evaluar en el Centro Poblado (. si no implementa ECA)"

// Periodo de implementación de 1a ECA en Centro Pobado (en PE determinado para
// ese centro o si es en cualquier PE) ---
// 0 = Antes de 2021-II (i.e 2021-I o 2020).
// 1 = En algún semestre en 2021.
// 2 = Entre 2021-II y 2022-I.
// 3 = En 2022-II.
//	   ECAs implementadas en 2022 sin fecha exacta se asumen implementadas en 2022-II.
local r2020 		(año_ini_1aECA==2020)
local r2021I       	((año_ini_1aECA==2021 & month(fch_ini_1aECA)<6)  | (año_ini_1aECA==2021 & mi(fch_ini_1aECA)))   
local r2021II_2022I ((año_ini_1aECA==2021 & month(fch_ini_1aECA)>=6) | (año_ini_1aECA==2022 & month(fch_ini_1aECA)<6))
local r2022IIomas  	((año_ini_1aECA==2022 & month(fch_ini_1aECA)>=6) | (año_ini_1aECA==2022 & mi(fch_ini_1aECA)) | (año_ini_1aECA>2022))
lab def perimECA 	0 "2020"			///
					1 "2021I"			/// 
					2 "2021II-2022I"	/// 
					3 "2022II" 			///
					99 "No implementaron" 

foreach tipo in 1aECA_PE 1aECA_algPE{
	gen per_`tipo'_ccpp:perimECA = .
	replace per_`tipo' = 0 if i`tipo'==1 & `r2020'
	replace per_`tipo' = 1 if i`tipo'==1 & `r2021I'		
	replace per_`tipo' = 2 if i`tipo'==1 & `r2021II_2022I' & !mi(fch_ini_1aECA)
	replace per_`tipo' = 3 if i`tipo'==1 & `r2022IIomas'   & !mi(año_ini_1aECA)
	replace per_`tipo' = 99 if mi(per_`tipo')
	lab val per_`tipo' perimECA
}

lab var per_1aECA_PE	"Periodo 1era ECA en el Centro Poblado (en Producto a Evaluar determinado por SENASA)"
lab var per_1aECA_algPE "Periodo 1era ECA en el Centro Poblado (en cualquiera de los Productos a Evaluar)"

// Nombre del CCPP donde exactamente se llevó a cabo la ECA en 2021 
// Criterio: Si en ambas fuentes se registra un ccpp distinto entonces concluyo 
// en que la ECA fue implementada en un ccpp distinto al de la lista. Es el caso
// de los centros que se registran a continuación. Los tres centros poblados de
// "QUIRACAS", "POQUES" y "SANTA ROSA" no fueron excluidos en el script fix_ccpp_names
// ya que no se consideran una correción, fueron los centros donde efectivamente 
// se llevó a cabo la ECA.
gen nomb_ccpp_ECA = "" , a(nomb_ccpp_ori)
replace nomb_ccpp_ECA = "QUIRACAS" 		if nomb_dstrt=="SAN IGNACIO" & nomb_ccpp=="FLOR DE LA FRONTERA"
replace nomb_ccpp_ECA = "POQUES"   		if nomb_dstrt=="LAMAY" 		 & nomb_ccpp=="ZAPACTO"
replace nomb_ccpp_ECA = "SANTA ROSA" 	if nomb_dstrt=="SANTA ANA"   & nomb_ccpp=="SANTA ANA"

// Centro Poblado aleatorizado (con datos de asignación al tratamiento, etc.)
gen es_ccpp_ale:sino = !mi(asig_ccpp)
qui count if es_ccpp_ale==1
assert `r(N)' == 135 
lab var es_ccpp_ale "Centro Poblado es parte de la lista de aleatorizados (135)"

// Centro Poblado presente en línea base 
gen pste_ccpp_lb:sino = 1 if es_ccpp_ale
replace pste_ccpp_lb  = 0 if nomb_dstrt=="LLOCHEGUA" 	& nomb_ccpp=="BUENOS AIRES"
replace pste_ccpp_lb  = 0 if nomb_dstrt=="SIVIA" 	 	& nomb_ccpp=="NARANJAL"
replace pste_ccpp_lb  = 0 if nomb_dstrt=="SIVIA" 	 	& nomb_ccpp=="PALMAPAMPA"
replace pste_ccpp_lb  = 0 if nomb_dstrt=="SIVIA" 	 	& nomb_ccpp=="RAMOS PAMPA"
replace pste_ccpp_lb  = 0 if nomb_dstrt=="PICHIGUA"  	& nomb_ccpp=="NUEVA ESPERANZA"
replace pste_ccpp_lb  = 0 if nomb_dstrt=="CHONTABAMBA" 	& nomb_ccpp=="PALMERAS"
replace pste_ccpp_lb  = 0 if nomb_dstrt=="CAMPANILLA"  	& nomb_ccpp=="BELLAVISTA"
lab var pste_ccpp_lb "Centro Poblado presente en línea base (solo aleatorizados)"

// Centro Poblado no excluido (Exclusión por: Instalación de equipos, empezar antes, etc.)
lab def excl 0 "No excluido" 1 "Excluido"
gen excl_ccpp:sino = ((nomb_dstrt=="SIVIA" & nomb_ccpp=="NARANJAL") | ///
				   (nomb_dstrt=="SIVIA" & nomb_ccpp=="PALMAPAMPA")  | /// 
				   (nomb_dstrt=="SIVIA" & nomb_ccpp=="RAMOS PAMPA") | ///
				   (nomb_dstrt=="SIVIA" & nomb_ccpp=="VILLA RICA")  | ///
				   (nomb_dstrt=="SIVIA" & nomb_ccpp=="VISTA ALEGRE")) if es_ccpp_ale==1 
lab var excl_ccpp "Centro Poblado excluido del estudio (solo aleatorizados)"

// Estatus cumplimiento de centro poblado cumple asignación 
lab def cump 0 "Incumplidor" 1 "Cumplidor"
gen cumpl_est_ccpp:cump = (asig_ccpp==1 & (inlist(per_1aECA_PE,1,2))) 	| ///
						(asig_ccpp==0 & per_1aECA_PE==3) 				| ///
						(asig_ccpp==0 & per_1aECA_algPE==99) if es_ccpp_ale==1
						
gen cumpl_flx_ccpp:cump = (asig_ccpp==1 & (inlist(per_1aECA_PE,1,2))) 	| ///	
						(asig_ccpp==0 & per_1aECA_PE==3)				| ///
						(asig_ccpp==0 & per_1aECA_PE==99) if es_ccpp_ale==1
						
// Centro Poblado es cumplidor si:
//	Siendo asignado a tratamiento implementa la 1a ECA en PE en 2021
// 	Siendo asignado a control implementa la 1a ECA en el PE en 2022-II o no la 
// 	implementa nunca.
lab var cumpl_est_ccpp "Cumplimiento: T->ECA PE 2021II, C->No ECA alg PE 2021|ECA PE 2022-II"
lab var cumpl_flx_ccpp "Cumplimiento: T->ECA PE 2021II, C->No ECA PE 2021|ECA PE 2022-II"

// Generar variable para cruce
egen idu = group(nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp)
order idu

// Quedan solo centros aleatorizados
keep if es_ccpp_ale
drop es_ccpp_ale
compress

save "`outc3ccpp'\\CCPPALEAy1AECA_ESTAT_CUMPL", replace

log close
