//------------------------------------------------------------------------------
// File             : B2_clean_survey_modules.do
// Author           : Carlos Marena
// Email            : carlosmarena1995@gmail.com
// Last Mod. Date   : 15/05/2025
// Description      : Estandariza y preprocesa los modulos de
// encuesta de Linea Base (Inicio, Personas, Parcela, Credito,
// Cultivo) y Linea de Seguimiento (Inicio, Nuevos Integrantes,
// Parcela, Cultivo). Para cada modulo: limpia strings, convierte
// categorias negativas a missing, verifica identificadores y
// guarda la base pre-limpia (prefijo pcl_) para tratamiento
// posterior.
//
// Depends          : _helpers/to_miss_neg_cat.do,
//                    _helpers/lab_cle.do,
//                    _helpers/std_strings.do
// Input            : BaseInicio.dta (Raw/1_Encu Linea Base/),
//                    Personas.dta (Raw/1_Encu Linea Base/),
//                    Parcela.dta (Raw/1_Encu Linea Base/),
//                    Credito.dta (Raw/1_Encu Linea Base/),
//                    Cultivo.dta (Raw/1_Encu Linea Base/),
//                    Inicio.dta (Raw/2_Encu Linea Segui/),
//                    NuevosIntegrantesHogar.dta (Raw/2_Encu Linea Segui/),
//                    Parcela.dta (Raw/2_Encu Linea Segui/),
//                    Cultivo.dta (Raw/2_Encu Linea Segui/)
// Output           : pcl_Inicio_LB.dta (Out/1_Encu Linea Base/),
//                    pcl_Personas_LB.dta (Out/1_Encu Linea Base/),
//                    pcl_Parcela_LB.dta (Out/1_Encu Linea Base/),
//                    pcl_Credito_LB.dta (Out/1_Encu Linea Base/),
//                    pcl_Cultivo_LB.dta (Out/1_Encu Linea Base/),
//                    pcl_Inicio_LS.dta (Out/2_Encu Linea Segui/),
//                    pcl_NuevosIntegrantes_LS.dta (Out/2_Encu Linea Segui/),
//                    pcl_Parcela_LS.dta (Out/2_Encu Linea Segui/),
//                    pcl_Cultivo_LS.dta (Out/2_Encu Linea Segui/)
//------------------------------------------------------------------------------

//==============================================================================
// Step 1: Load helper programs and set up environment
//==============================================================================
cls
version 19.0
clear all

// PRIMERO: CORRER DO-FILES QUE:
// 	1) CONVIERTEN A . VALORES (CATEGORÍAS) NEGATIVOS DE VARIABLES CON ETIQUETAS
// 	2) VERIFICAR SI TODAS LAS ETIQUETAS DE VALOR SON STRINGS QUE REPRESENTAN
//	NÚMEROS, Y SI ES ASÍ, ELIMINA LA DEFINICIÓN/ASOCIACIÓN DE ETIQUETAS DE VALOR
// 	DE ESAS VARIABLES.
qui do "${ruta_helpers}\to_miss_neg_cat.do"
qui do "${ruta_helpers}\lab_cle.do"

// --- Llamar do-file con rutas ---
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
cap erase "${ruta_scripts}\B2_clean_survey_modules.log"
log using "${ruta_logs}\B2_clean_survey_modules.log", replace text



//==============================================================================
// Step 2: Clean LB Inicio module
//==============================================================================
{
	use "`rawc1'\\BaseInicio.dta", clear // 2485 obs
	qui compress 

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES CON CATEGORÍAS <0 (OMISIÓN A RPTA)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// MODIFICAR MANUALMENTE CARACTERES INVÁLIDOS (MUY PUNTUALES)
	tab1 extra_*
	replace extra_invl_Nombres	= "ANDRES" 	if extra_invl_Nombres=="ANDR�S"
	replace extra_invl_Apellidos= "OCAÑA"	if extra_invl_Apellidos=="OCA�A"
	replace Nombres 	= regexr(Nombres, "\b\w*�\w*\b", "ANDRES") 	///
							if extra_invl_Nombres=="ANDRES"
	replace Apellidos 	= regexr(Apellidos, "\b\w*�\w*\b", "OCAÑA") ///
							if extra_invl_Apellidos=="OCAÑA"
	drop dum_* extra_*

// GENERAR VARIABLE DE INICIO Y FIN DE ENCUESTA
	gen double ini_enc = clock(INIC_ENC, "YMD#hm#"), a(INIC_ENC)
	gen double fin_enc = clock(FIN_ENC, "YMD#hm#") , a(ini_enc)
	gen fch_enc = mdy(real(substr(today,6,2)), ///
					  real(substr(today,9,2)), ///
					  real(substr(today,1,4))), a(today) 
	format ini_enc fin_enc %tc
	format fch_enc %tdDD-NN-CCYY
	lab var ini_enc  "Hora y día del inicio de la encuesta"
	lab var fin_enc  "Hora y día del fin de la encuesta"
	lab var fch_enc  "Fecha de la encuesta"
	drop start end INIC_ENC FIN_ENC today

// GENERAR LA VARIABLE CULTIVO OBJETIVO (O DE INTERÉS SI PREG4A==1 O PREG4B==1)
	lab def sino 0 "No" 1 "Si"
	gen cult_obj:sino = (preg4a==1|preg4b==1), a(preg4b)
	lab var cult_obj "1 Si el cultivo de interés estuvo en el predio en la campaña 20/21"

// DE STRING A NUMÉRICA PARA VARIABLE DE GEOREFERENCIA
	destring ___georefere_*, replace 

// ORDENAR LA DATA
	sort depart provinc distri ccpp ordenprod  

// GUARDAR CAMBIOS EN pcl_Inicio_LB
	qui compress 
	save "`outc1'\\pcl_Inicio_LB.dta", replace	
}


//==============================================================================
// Step 3: Clean LB Personas module
//==============================================================================
{
	use "`rawc1'\\Personas.dta", clear // 5094 obs
	qui compress 

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES (ETIQUETADAS) CON CATEGORÍAS <0 (OMISIÓN)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// CORROBORAR NIVEL DE IDENTIFICACIÓN (MIEMBRO DENTRO DEL HOGAR)
	isid codprod HORD01		// codprod es código del productor
	isid Codprod22 HORD01 	// Codprod 22 es código del productor en 2022
	sort Codprod22 HORD01

// GUARDAR CAMBIOS EN pcl_Personas_LB
	qui compress 
	save "`outc1'\\pcl_Personas_LB.dta", replace 
}


//==============================================================================
// Step 4: Clean LB Parcela module
//==============================================================================
{
	use "`rawc1'\\Parcela.dta", clear // obs
	qui compress 

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES (ETIQUETADAS) CON CATEGORÍAS <0 (OMISIÓN)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// CORROBORAR NIVEL DE IDENTIFICACIÓN (PREDIO/PARCELA)
	isid Codprod22 preg101a
	isid codprod preg101a

// ORDENAR LA DATA
	sort Codprod22 preg101a

// GUARDAR CAMBIOS EN pcl_Parcela_LB
	qui compress 
	save "`outc1'\\pcl_Parcela_LB.dta", replace 
}


//==============================================================================
// Step 5: Clean LB Credito module
//==============================================================================
{
	use "`rawc1'\\Credito.dta", clear // obs
	qui compress 

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES (ETIQUETADAS) CON CATEGORÍAS <0 (OMISIÓN)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// CORROBORAR NIVEL DE IDENTIFICACIÓN
	isid Codprod22 ord302
	isid codprod ord302

// ORDENAR DATA
	sort Codprod ord302

// GUARDAR CAMBIOS EN pcl_Credito_LB
	qui compress 
	save "`outc1'\\pcl_Credito_LB.dta", replace	
}


//==============================================================================
// Step 6: Clean LB Cultivo module
//==============================================================================
{
	use "`rawc1'\\Cultivo.dta", clear // obs
	qui compress 

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES (ETIQUETADAS) CON CATEGORÍAS <0 (OMISIÓN)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// CORROBORAR NIVEL DE IDENTIFICACIÓN (CULTIVO DENTRO DE PREDIO)
	isid Codprod22 preg101a ordp114
	isid codprod preg101a ordp114

// ORDENAR LA DATA
	sort Codprod preg101a ordp114

// GUARDAR CAMBIOS EN pcl_Cultivo_LB
	qui compress 
	save "`outc1'\\pcl_Cultivo_LB.dta", replace
}


//==============================================================================
// Step 7: Clean LS Inicio module
//==============================================================================
{
	use "`rawc2'\\Inicio.dta", clear 
	qui compress 

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1
	qui do "${ruta_helpers}\std_strings.do"

// MODIFICAR MANUALMENTE CARACTERES INVÁLIDOS (MUY PUNTUALES)
	tab1 extra_*
	replace extra_invl_Nombres	= "ANDRES" 	if extra_invl_Nombres=="ANDR�S"
	replace extra_invl_Apellidos= "OCAÑA"	if extra_invl_Apellidos=="OCA�A"
	replace extra_invl_Apellidos= "ORDOÑEZ"	if extra_invl_Apellidos=="ORDO�EZ"
	replace Nombres = regexr(Nombres, "\b\w*�\w*\b", "ANDRES") 		///
					if extra_invl_Nombres=="ANDRES"
	replace Apellidos = regexr(Apellidos, "\b\w*�\w*\b", "OCAÑA") 	///
					if extra_invl_Apellidos=="OCAÑA"
	replace Apellidos = regexr(Apellidos, "\b\w*�\w*\b", "ORDOÑEZ") ///
					if extra_invl_Apellidos=="ORDOÑEZ"
	drop dum_* extra_*

// GENERAR VARIABLE DE INICIO Y FIN DE ENCUESTA
	gen double ini_enc = round((INIC_ENC+td(30dec1899))*86400)*1000, a(INIC_ENC)
	gen double fin_enc = round((FIN_ENC+td(30dec1899))*86400)*1000 , a(FIN_ENC)
	gen double fch_enc = round(today+td(30dec1899))   			   , a(today)
	format ini_enc fin_enc %tc
	format fch_enc %tdDD-NN-CCYY
	lab var ini_enc "Hora y día del inicio de la encuesta"
	lab var fin_enc "Hora y día del fin de la encuesta"
	lab var fch_enc "Fecha de la encuesta"
	drop start end INIC_ENC FIN_ENC today 

// CREAR UN REPORTE DE MISSINGS POR PREGUNTA DE ACUERDO A SI ...
	count if continua==1 & (preg4a==1 | preg4b==1) // continuan y responden la enc
	count if continua==1 & (preg4a==2 & preg4b==2) // continuan pero no responden nada luego

// GENERAR LA VARIABLE CULTIVO OBJETIVO (O DE INTERÉS SI PREG4A==1 O PREG4B==1)
	lab def sino 0 "No" 1 "Si"
	gen cult_obj:sino = (preg4a==1|preg4b==1), a(preg4b)
	lab var cult_obj "1 Si el cultivo de interés estuvo en el predio en la campaña 21/22"
	
// ORDENAR LA DATA
	sort depart provinc distri ccpp ordenprod 

// GUARDAR CAMBIOS EN pcl_Inicio_LS
	qui compress 
	save "`outc2'\\pcl_Inicio_LS.dta", replace
}


//==============================================================================
// Step 8: Clean LS Nuevos Integrantes module
//==============================================================================
{
	use "`rawc2'\\NuevosIntegrantesHogar.dta", clear // 5094 obs
	qui compress 

// RENOMBRAR VARIABLE Y HACERLO CORTO (EVITA ERRORES LUEGO EN APPEND)
	ren ___submission_* _sub_*

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES CON CATEGORÍAS <0 (OMISIÓN A RPTA)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// CORROBORAR NIVEL DE IDENTIFICACIÓN (MIEMBRO DENTRO DEL HOGAR)
	isid codprod HORD01
	isid codprod HORD01b

// ORDENAR LA DATA
	sort codprod HORD01

// GUARDAR CAMBIOS EN pcl_NuevosIntegrantes_LS
	qui compress 
	save "`outc2'\\pcl_NuevosIntegrantes_LS.dta", replace 
}


//==============================================================================
// Step 9: Clean LS Parcela module
//==============================================================================
{
	use "`rawc2'\\Parcela.dta", clear // obs
	qui compress 

// RENOMBRAR VARIABLE Y HACERLO CORTO (EVITA ERRORES LUEGO EN APPEND)
	ren ___submission_* _sub_*

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES CON CATEGORÍAS <0 (OMISIÓN A RPTA)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// CORROBORAR NIVEL DE IDENTIFICACIÓN (PREDIO/PARCELA)
	isid codprod preg101a
	
// ORDENAR LA DATA
	sort codprod preg101a

// GUARDAR CAMBIOS EN pcl_Parcela_LS
	qui compress 
	save "`outc2'\\pcl_Parcela_LS.dta", replace 
}


//==============================================================================
// Step 10: Clean LS Cultivo module
//==============================================================================
{
	use "`rawc2'\\Cultivo.dta", clear // obs
	qui compress 

// RENOMBRAR VARIABLE Y HACERLO CORTO (EVITA ERRORES LUEGO EN APPEND)
	ren ___submission_* _sub_*

// ESTANDARIZAR STRINGS
	gl remspaces 	1
	gl remaccents	1
	gl remumlaut	1
	gl remcircum	1
	gl remother		1
	gl gen_extract_invl 1 
	qui do "${ruta_helpers}\std_strings.do"

// LISTAR Y CAMBIAR VALORES DE VARIABLES CON CATEGORÍAS <0 (OMISIÓN A RPTA)
	qui ds, has(vallab)
	foreach vl in `r(varlist)'{
		qui to_miss_neg_cat `vl'
		qui lab_cle 		`vl'
	}

// CORROBORAR NIVEL DE IDENTIFICACIÓN (CULTIVO DENTRO DE PREDIO)
	isid codprod preg101a ordp114

// ORDENAR LA DATA
	sort codprod preg101a ordp114

// GUARDAR CAMBIOS EN pcl_Cultivo_LS
	qui compress 
	save "`outc2'\\pcl_Cultivo_LS.dta", replace
}

log close
