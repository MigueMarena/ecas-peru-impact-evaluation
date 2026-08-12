//------------------------------------------------------------------------------
// File           : D_merge_panels.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Estandariza y fusiona las bases de linea base y seguimiento
//                  generadas por B2_clean_survey_modules.do. Filtra productores
//                  que manejaron predios con el cultivo de interes, corrige DNIs
//                  y nombres, asigna estatus de tratamiento a nivel de CCPP y
//                  productor, y genera cuatro paneles: Inicio, Personas, Parcelas
//                  y Cultivos.
// Depends        : _utils/fix_dni_names.do
//                  _utils/merge_ccpp_status.do
//                  _utils/merge_producer_eca.do
//                  _utils/relab_yesno.do
//                  _utils/fix_producer_names.do
//                  _utils/map_crop_names.do
// Input          : Out/1_.../pcl_Inicio_LB.dta
//                  Out/2_.../pcl_Inicio_LS.dta
//                  Out/1_.../pcl_Personas_LB.dta
//                  Out/2_.../pcl_NuevosIntegrantes_LS.dta
//                  Out/1_.../pcl_Parcela_LB.dta
//                  Out/2_.../pcl_Parcela_LS.dta
//                  Out/1_.../pcl_Cultivo_LB.dta
//                  Out/2_.../pcl_Cultivo_LS.dta
// Output         : Out/4_.../Panel_Inicio.dta
//                  Out/4_.../Panel_Personas.dta
//                  Out/4_.../Panel_Parcelas.dta
//                  Out/4_.../Panel_Cultivos.dta
//------------------------------------------------------------------------------

version 19.0

// NOTA: Previo a este merge, hice un merge basado en strings entre la BASE LINEA
// BASE y la de PRODUCTORES EN ECAs 2021, usando como llaves los nombres, apellidos
// y DNIs de los productores. A partir de ello, analicé uno a uno los casos donde
// el score producido era menor a 1 y el DNI entre el productor de la base master
// y la base using eran casi iguales. Seguido, corregí caso por caso comparando los
// DNIs de ambos y determinando cuál era el verídico. La fuente que me permitió
// determinar cuál DNI era el válido fue la CONSULTA EN LINEA DEL SIS. A partir de
// ello, si el DNI correcto era el de la base using (PRODUCTORES_2021_CCPPs_ALEATOR
// IZADOS), procedí a cambiar el DNI de la otra base. Esto se documentó en el script
// 05-1_do_corregir_DNIs_y_Nombres. En cambio, cuando el DNI correcto era el de la
// base master (pcl_Inicio_LB) procedí a hacer los cambios manuales en los archivos
// excel originales de Consolidado BID y de ECAS 2019-2023. Lamentablemente estos
// cambios manuales en los archivos brutos no se han documentado.

cls
clear all 

//  Llamar do-file con rutas 
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
cap erase "${ruta_scripts}\D_merge_panels.log"
log using "${ruta_logs}\D_merge_panels.log", replace text


//=====================================================================
// Step 1: Prepare baseline and follow-up: Inicio module
//=====================================================================
{ //	FASE PREPARACIÓN PRECRUCE: Inicio_LB e Inicio_LS		//
local j = 1
foreach base in `basesInicio'{
	use "`base'", clear
 
// Productores que manejaron predios solo con cultivo de interés en camp previa
	cap keep if ProdEnc==1  & cult_obj==1 & preg100a1==1 
	cap keep if continua==1 & cult_obj==1 & preg100a1==1
	
// Ordenar y quedan únicos
	sort ___index 
	duplicates drop dni_prod, force 

// Quedan variables relevantes
	cap drop ProdEnc 			// productor fue encuestado
	cap drop continua			// continuaron la encuesta (de inicio a fin)
	cap drop preg100a1 			// informante ha manejado/conducido predio en camp agr pasada 
	cap drop note001 			// no sé a qué refiere
	cap drop Nombres-email  	// datos personales del encuestador
	cap drop producto2 			// info en producto
	cap drop codprod_22			// info en Codprod22 
	cap drop sector-telf_prod 	// sector, direccion, referencia de la vivienda, información
								// escrita del informante y telef. del productor
	cap drop sector-telm_prod 	// sector, direccion, referencia de la vivienda, información
								// escrita del informante y telef. mov. del productor
	cap drop infor_ape-infor_telef // datos del informante
	cap drop cult_obj           // eliminar variable de cultivo objetivo presente en predio
	cap drop texmot-observa001 	// motivos por no respuesta, supervisor y otras obs.
	cap drop preg101c preg101d 	// ubicaciones que ya están en otras variables
	cap drop preg400R8_f* 		// fotos del lugar de almacenamiento de agroq
	cap drop georefere 			// ubicaciones que ya están en otras variables
	cap drop fotoencuest 		// foto de la encuesta
	cap drop pcroquis 			// croquis del predio
	cap drop ___status ___uuid	___submission_time ___submitted_by	 ____version ___index // otras 
	cap drop  
	drop preg401 preg421 preg422 preg424 preg400R preg400R8_1 preg501 preg502b ///
		 preg505 preg506 preg510 preg602 // vars. con respuestas en otras vars. 
	cap drop preg200 preg701 preg800bx preg907 preg909 preg913 preg914  	 // vars. con respuestas en otras vars.
	cap drop CQ3 CQ8 CQ11 CQ13 CQ14 CQ15 CQ16 CQ17 // vars. con respuestas en otras vars.
	cap drop PLQ8 PLQ11 PLQ13 PLQ14 PLQ15 PLQ16 PLQ17 // vars. con respuestas en otras vars.
	cap drop PAQ3 PAQ8 PAQ11 PAQ13 PAQ14 PAQ15 PAQ16 PAQ17 // vars. con respuestas en otras vars.
	forval i=1/10{
		drop preg603_`i' 
	}
	forval i=11/17{
		drop preg603_`i'_A
	}
	forval i=18/20{
		drop preg603_`i'
	}
	forval i=21/25{
		drop preg603_`i'_A
	}
	cap drop obsdup
	
// Estandarizar variables 
	ren (depart provinc distri ccpp) (nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp)
	ren nom_prod nomb_prod
	cap ren ___georefere_* georefere_*
	
// Id master
	gen   idm=_n
	order idm 

// Correcciones
// Generar una variable para comparación
	gen prodencod = ., a(producto)
	replace prodencod = 19 if producto=="PLATANOS"
	replace prodencod = 16 if producto=="PAPAS"
	replace prodencod = 26 if producto=="CITRICOS"
	
// A números y nombres de DNIs
	do "${ruta_utils}\fix_dni_names.do"

// Asignar estatus de asignación y otros a nivel de CCPP
	do "${ruta_utils}\merge_ccpp_status.do"

// Sanity check
	assert prodencod == prod_ECA_eval
 	if _rc==0{ // verifica que no hayan inconsistencias 
		drop producto
	}
	drop prodencod
	
// Asignar estatus de tratamiento a nivel de productor (participa/no participa de ECA):
// 	1) 2 TIPOS DE TRATAMIENTO A NIVEL DE PRODUCTOR
// 		1.1 ASISTIÓ PERO NO SE GRADUÓ
// 		1.2 ASISTIÓ Y SE GRADUÓ
// 	2) FECHA DE INICIO Y FIN DE LA ECA (SOLO PARA LOS QUE ASISTEN A UNA)
// 	3) PROMEDIO FINAL Y ESTATUS DE GRADUACIÓN DEL PRODUCTOR (SOLO PARA LOS QUE ASISTEN A UNA)
	do "${ruta_utils}\merge_producer_eca.do"

// Ordenar la data y reetiquetar 	
	sort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp ordenprod
	qui do "${ruta_utils}\relab_yesno.do"
	
// Reconversión de variables
	destring preg603_27,	replace // ult cap en técnicas de labranza de suelos
	tostring preg400R1_3, 	replace 
	tostring preg400R2_3, 	replace
	tostring preg400R6_3,	replace 
	tostring preg400R7_f,	replace
	tostring obspre400_7, 	replace
	tostring preg603o_12,   replace
	tostring preg603o_17, 	replace
	tostring preg603o_18, 	replace
	replace  preg400R1_3 = "" if preg400R1_3=="."
	replace  preg400R2_3 = "" if preg400R2_3=="."
	replace  preg400R6_3 = "" if preg400R6_3=="."
	replace  preg400R7_f = "" if preg400R7_f=="."
	replace  obspre400_7 = "" if obspre400_7=="."
	replace  preg603o_12 = "" if preg603o_12=="."
	replace  preg603o_17 = "" if preg603o_17=="."
	replace  preg603o_18 = "" if preg603o_18=="."
	
// Generar variable pre-post
	if `j'==1{
		gen post = 0, a(Codprod22)
		local w "LB"
	}
	else{
		gen post = 1, a(Codprod22)
		local w "LS"
	}
	lab var post "Periodo (Post=1 => campaña 2021-2022)"
	compress
	
// Guardar las bases en carpeta 1 
	save "`outc`j''\\Inicio_`w'", replace
	local ++j
	}
}

//=====================================================================
// Step 2: Merge panels: Inicio
//=====================================================================
{ //	JUNTAR: Inicio_LB - Inicio_LS		//
	use "`outc1'\\Inicio_LB", clear
	append using "`outc2'\\Inicio_LS"

// Identificadora para cruce 
	egen _idI = group(Codprod22 post)
	
// Ordenar data y guardar 
	sort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp Codprod22 post ordenprod
	compress 
	save "`outc4'\\Panel_Inicio.dta", replace
}

//=====================================================================
// Step 3: Prepare baseline and follow-up: Personas module
//=====================================================================
{ //	FASE PREPARACIÓN PRECRUCE: Personas_LB y NuevosIntegrantes_LS		// 
local j = 1
foreach base in `basesPersonas'{
	use "`base'", clear
	
//  Quedan variables relevantes 
	cap drop preg805_1 preg805_2 preg805_3
	cap drop preg805_3-preg809b_3 	// ningun miembro responde a estas preguntas
	cap drop preg812_3-___index 	// ningún miembro responde a estas preguntas
	cap drop ___index-_sub___version // variables solo en linea seguimiento
	
//  Reconversión de variables 
	cap destring preg805_21-preg805_299, replace
	cap destring HORD01 HORD01b, replace // solo en linea seguimiento

//  Corregir nombres de miembros que presumiblemente son productores 
	do "${ruta_utils}\fix_producer_names.do"
	
//  Reetiquetar 
	qui do "${ruta_utils}\relab_yesno.do"

//  Generar variable pre-post 
	if `j'==1{
		gen post = 0, a(HORD01)
		local w "LB"
	}
	else{
		gen post = 1, a(HORD01)
		local w "LS"
	}
	lab var post "Periodo (Post=1 => campaña 2021-2022)"
	compress
	
//  Guardar las bases en carpeta temporal, luego borrar 
	save "`outc`j''\\Personas_`w'", replace
	local ++j
	}
}

//=====================================================================
// Step 4: Merge panels: Personas
//=====================================================================
{ //	JUNTAR: Personas_LB - NuevosIntegrantes_LS		//
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
	use "`outc1'\\Personas_LB", clear
	append using "`outc2'\\Personas_LS"
	order HORD01b, a(HORD01)
	sort codprod post

//  Homogenizar Codprod22 para un mismo código de productor 
	by codprod: carryforward Codprod22, replace

//  Identificadora para cruce 
	egen _idM = group(Codprod22 post HORD01)
	
//  Ordenar data y guardar 
	sort Codprod22 post HORD01
	compress
	save "`outc4'\\Panel_Personas.dta", replace
}

//=====================================================================
// Step 5: Prepare baseline and follow-up: Parcela module
//=====================================================================
{ //	FASE PREPARACION PRERUCE: Parcela_LB y Parcela_LS		//
local j = 1
foreach base in `basesParcela'{
	use "`base'", clear

//  Quedan variables relevantes 
	drop preg115e preg115f1_5-preg115f5_7
	drop pagagua
	drop preg116a1 preg116a2 preg116b1 preg116b2 preg116c preg116d preg116e preg116f preg117
	cap drop ___index-___indexParcela
	cap drop ___index-_sub___version	

//  Reetiquetar 
	qui do "${ruta_utils}\relab_yesno.do"

//  Reconversión de variables 
	destring pagagua1-pagagua88, replace
	tostring preg116e*4b, replace
	foreach v of varlist preg116e*4b{
		replace `v' = "" if `v'=="."
	}

//  Generar variable pre-post 
	if `j'==1{
		gen post = 0, a(preg101a)
		local w "LB"
	}
	else{
		gen post = 1, a(preg101a)
		local w "LS"
	}
	lab var post "Periodo (Post=1 => campaña 2021-2022)"
	compress
	
//  Guardar las bases en carpeta temporal, luego borrar 
	save "`outc`j''\\Parcelas_`w'", replace
	local ++j
	}
}

//=====================================================================
// Step 6: Merge panels: Parcelas
//=====================================================================
{ //	JUNTAR: Parcelas_LB - Parcelas_LS		//
	use "`outc1'\\Parcelas_LB", clear
	append using "`outc2'\\Parcelas_LS"
	sort codprod post preg101a
	
//  Homogenizar Codprod22 para un mismo código de productor 
	by codprod: carryforward Codprod22, replace

//  Identificadora para cruce 
	egen _idP = group(Codprod22 post preg101a)	
	
//  Ordenar data y guardar 
	sort Codprod22 post preg101a
	compress 
	save "`outc4'\\Panel_Parcelas.dta", replace
}

//=====================================================================
// Step 7: Prepare baseline and follow-up: Cultivo module
//=====================================================================
{ //	FASE PREPARACION PRECRUCE: Cultivo_LB y Cultivo_LS		//
local j = 1
foreach base in `basesCultivo'{
	use "`base'", clear
	
//  Quedan variables relevantes 
	drop preg114o preg114p preg114t
	cap drop ___indexParcela
	cap drop ___index-_sub__tags
	
//  Reetiquetar 
	qui do "${ruta_utils}\relab_yesno.do"

//  Asociar código de cultivo con su resp. nombre 
	qui do "${ruta_utils}\map_crop_names.do"

//  Reconversión de variables 
	tostring preg114x2c_*, replace 
	foreach v of varlist preg114x2c_*{
		replace `v' = "" if `v'=="."
	}
	
//  Generar variable pre-post 
	if `j'==1{
		gen post = 0, a(ordp114)
		local w "LB"
	}
	else{
		gen post = 1, a(ordp114)
		local w "LS"
	}
	lab var post "Periodo (Post=1 => campaña 2021-2022)"
	compress
	
//  Guardar las bases en carpeta temporal, luego borrar 
	save "`outc`j''\\Cultivos_`w'", replace
	local ++j
	}
}

//=====================================================================
// Step 8: Merge panels: Cultivos
//=====================================================================
{ //	JUNTAR: Cultivos_LB - Cultivos_LS		//
	use "`outc1'\\Cultivos_LB", clear
	append using "`outc2'\\\Cultivos_LS"
	sort codprod post preg101a ordp114
	
//  Homogenizar Codprod22 para un mismo código de productor 
	by codprod: carryforward Codprod22, replace

//  Identificadora para cruce 
	egen _idC = group(Codprod22 post preg101a ordp114)
	
//  Ordenar data y guardar
	sort Codprod22 post preg101a ordp114
	compress 
	save "`outc4'\\Panel_Cultivos.dta", replace
}

// Ojo: En panel cultivos hay 5 productores (10 obs) donde un mismo cultivo 
// se cosecha en distintos predios.

log close
