//------------------------------------------------------------------------------
// File           : E6_build_bpa_knowledge.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Calcula puntajes de conocimiento en BPAs por cultivo (Citricos,
//                  Papa, Platano) a partir del test aplicado en linea de seguimiento.
//                  Pondera por dificultad, reescala a 0-17, estandariza por DE del
//                  grupo de control y genera variables pooled.
// Input          : Out/4_.../Panel_Inicio.dta
// Output         : Out/5_.../Ptjs_Test_BPAs_LS.dta
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local ProcessCitricos	  = 1	// Procesar sección Cítricos (CQ)
	local ProcessPapa		  = 1	// Procesar sección Papa (PAQ)
	local ProcessPlatano	  = 1	// Procesar sección Plátano (PLQ)
	local StandardizeScores	  = 1	// Estandarizar puntajes por DE del grupo de control (LS)
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local SaveData			  = 1

	// Variables a importar (Asumo que Codprod22 es necesario para ID)
	local vars_citricos CQ*
	local vars_papa     PAQ*
	local vars_platano  PLQ*
	local vars_id       Codprod22 post asig_ccpp
}

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
frames reset
frame create test_bpa
}

//==============================================================================
// Step 1: Load Data
//==============================================================================
if `LoadData'{
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
cap erase "${ruta_scripts}\E6_build_bpa_knowledge.log"
log using "${ruta_logs}\E6_build_bpa_knowledge.log", replace text


frame change test_bpa
use `vars_id' `vars_citricos' `vars_papa' `vars_platano' using "`outc4'\\Panel_Inicio.dta", clear
keep if post==1 // solo info en LS
drop post
compress
}

//==============================================================================
// Step 2: Generate Variables for CÍTRICOS (CQ) - BPA Knowledge Score
//==============================================================================
if `ProcessCitricos'{	
// Preguntas Generales y Nutrientes (P1-P3)
{
	gen rpt_corr_CQ1 = (CQ1==3) if !mi(CQ1)
	gen rpt_corr_CQ2 = (CQ2==2) if !mi(CQ2)
	
	egen rpt_corr_CQ3 = rowtotal(CQ31-CQ33) if !mi(CQ31)
	replace rpt_corr_CQ3 = rpt_corr_CQ3/3
}

// Identificación Visual: Nutrientes (P4)
{
	gen rpt_corr_CQ4_1 = (CQ4_1==1) if !mi(CQ4_1)
	replace rpt_corr_CQ4_1 = 0.5 if regexm(CQ4_1o, "NITROGENO")

	gen rpt_corr_CQ4_2 = (CQ4_2==3) if !mi(CQ4_2)
	replace rpt_corr_CQ4_2 = 0.5 if regexm(CQ4_2o, "FOSF")

	gen rpt_corr_CQ4_3 = (CQ4_3==2) if !mi(CQ4_3)
	replace rpt_corr_CQ4_3 = 0.5 if regexm(CQ4_3o, "POTASIO")

	egen rpt_corr_CQ4 = rowtotal(rpt_corr_CQ4_1-rpt_corr_CQ4_3), m
	replace rpt_corr_CQ4 = rpt_corr_CQ4/3 
	drop rpt_corr_CQ4_*
}

// Periodicidad Análisis (P5-P6)
{
	gen rpt_corr_CQ5 = (CQ5==5) if !mi(CQ5)
	gen rpt_corr_CQ6 = (CQ6==5) if !mi(CQ6)
}

// Identificación Visual: Plagas (P7)
{
	gen rpt_corr_CQ7_1 = (CQ7_1==4) if !mi(CQ7_1)
	
	gen rpt_corr_CQ7_2 = (CQ7_2==2) if !mi(CQ7_2)
	replace rpt_corr_CQ7_2 = 1 if !mi(CQ7_2) & regexm(CQ7_2o,"CHINCHE") 
	
	gen rpt_corr_CQ7_3 = (CQ7_3==3) if !mi(CQ7_3)

	egen rpt_corr_CQ7 = rowtotal(rpt_corr_CQ7_1-rpt_corr_CQ7_3), m
	replace rpt_corr_CQ7 = rpt_corr_CQ7/3 
	drop rpt_corr_CQ7_*
}

// Control de Plagas y Procesos (P8-P10)
{
	// P8: Medidas SENASA
	egen rpt_corr_CQ8 = rowtotal(CQ81-CQ84), m
	replace rpt_corr_CQ8 = rpt_corr_CQ8/3 if !mi(rpt_corr_CQ8)
	
	// P9: Ordenamiento (Loop automatizado)
	local ans_CQ9 C A E B F G D
	local i = 1
	foreach ans of local ans_CQ9 {
		gen enu_corr_CQ9_`i' = (CQ9_`i'=="`ans'") if CQ9_1!=""
		local i = `i' + 1
	}
	egen rpt_corr_CQ9 = rowtotal(enu_corr_CQ9_1-enu_corr_CQ9_7), m
	replace rpt_corr_CQ9 = rpt_corr_CQ9/7

	// P10: Controladores Biológicos (Loop automatizado)
	local ans_CQ10 2 1 1 2 2
	local i = 1
	foreach ans of local ans_CQ10 {
		gen enu_corr_CQ10_`i' = (CQ10_`i'==`ans') if !mi(CQ10_`i')
		local i = `i' + 1
	}
	egen rpt_corr_CQ10 = rowtotal(enu_corr_CQ10_1-enu_corr_CQ10_5), m
	replace rpt_corr_CQ10 = rpt_corr_CQ10/5
}

// Seguridad y Manejo (P11-P17)
{
	// P11: Equipo Protección
	egen rpt_corr_CQ11 = rowtotal(CQ111-CQ116), m 
	replace rpt_corr_CQ11 = rpt_corr_CQ11/6 

	// P12-P13: Periodo Carencia
	gen rpt_corr_CQ12 = (CQ12==2) if !mi(CQ12)
	gen rpt_corr_CQ13 = (CQ133==1 | CQ134==1 | CQ135==1) if !mi(CQ131)

	// P14: Triple Lavado (Loop automatizado)
	local ans_CQ14 2 5 1 4 3
	local i = 1
	foreach ans of local ans_CQ14 {
		gen enu_corr_CQ14_`i' = (CQ14_`i'==`ans') if !mi(CQ14`i')
		local i = `i' + 1
	}
	egen rpt_corr_CQ14 = rowtotal(enu_corr_CQ14_1-enu_corr_CQ14_5), m
	replace rpt_corr_CQ14 = rpt_corr_CQ14/5

	// P15: Derrame (Indices irregulares, manual)
	gen enu_corr_CQ15_1 = (CQ15_6==1) if !mi(CQ151)
	gen enu_corr_CQ15_2 = (CQ15_2==2) if !mi(CQ152)
	gen enu_corr_CQ15_3 = (CQ15_5==3) if !mi(CQ153)
	gen enu_corr_CQ15_4 = (CQ15_3==4) if !mi(CQ154)
	egen rpt_corr_CQ15  = rowtotal(enu_corr_CQ15_1-enu_corr_CQ15_4), m
	replace rpt_corr_CQ15 = rpt_corr_CQ15/4

	// P16: Agua de Riego
	egen rpt_corr_CQ16 = rowtotal(CQ161-CQ163), m 
	replace rpt_corr_CQ16 = rpt_corr_CQ16/3

	// P17: Higiene (Loop para items simples, manual para regex)
	forval i=1/8 {
		gen enu_corr_CQ17_`i' = (CQ17`i'==1) if !mi(CQ17`i')
	}
	replace enu_corr_CQ17_1 = 1 if regexm(CQ17_o1, "BAÑARSE|BAÑANDOSE|(CAMBI(ARSE|ANDOSE|AR|O|OS)?( DE|LA)? ROPA)")
	replace enu_corr_CQ17_4 = 1 if regexm(CQ17_o1, "LAVARSE LAS MANOS")
	
	egen rpt_corr_CQ17 = rowtotal(enu_corr_CQ17_1-enu_corr_CQ17_8), m
	replace rpt_corr_CQ17 = rpt_corr_CQ17/8
}

// Cálculo de Puntaje Ponderado
{
	drop enu_corr_*
	
	// Definición de Pesos
	local w_P1 1
	local w_P2 1
	foreach j in 3 4 7 {
		local w_P`j' 1.5
	}
	foreach j in 5 6 8 9 10 11 12 13 14 15 16 17 {
		local w_P`j' 2
	}

	// Suma de pesos y cálculo
	gen ptj_pond_CQ = 0
	local sum_wghs_CQ = 0
	forval j = 1/17 {
		replace ptj_pond_CQ = ptj_pond_CQ + (`w_P`j'' * rpt_corr_CQ`j')
		local sum_wghs_CQ = `sum_wghs_CQ' + `w_P`j''
	}

	gen ptj_CQre 	=  17 * (ptj_pond_CQ/`sum_wghs_CQ')
	egen ptj_BPA_CQ = rowtotal(rpt_corr_CQ5 rpt_corr_CQ6 rpt_corr_CQ8-rpt_corr_CQ17), m
	
	lab var ptj_CQre   "Puntaje en el test de cítricos (ponderado y reescalado)"
	lab var ptj_BPA_CQ "Puntaje en la sección de BPA del test de cítricos"
}
}

//==============================================================================
// Step 3: Generate Variables for PAPA (PAQ) - BPA Knowledge Score
//==============================================================================
if `ProcessPapa'{
// Preguntas Generales y Nutrientes (P1-P3)
{
	gen rpt_corr_PAQ1 = (PAQ1==3) if !mi(PAQ1)
	gen rpt_corr_PAQ2 = (PAQ2==2) if !mi(PAQ2)
	
	egen rpt_corr_PAQ3 = rowtotal(PAQ31-PAQ33), m 
	replace rpt_corr_PAQ3 = rpt_corr_PAQ3/3
}

// Identificación Visual: Nutrientes (P4)
{
	gen rpt_corr_PAQ4_1 = (PAQ4_1==1) if !mi(PAQ4_1)
	replace rpt_corr_PAQ4_1 = 0.5 if regexm(PAQ4_1o, "NITROGENO")

	gen rpt_corr_PAQ4_2 = (PAQ4_2==3) if !mi(PAQ4_2)
	replace rpt_corr_PAQ4_2 = 0.5 if regexm(PAQ4_2o, "FOSF")

	gen rpt_corr_PAQ4_3 = (PAQ4_3==2) if !mi(PAQ4_3)
	replace rpt_corr_PAQ4_3 = 0.5 if regexm(PAQ4_3o, "POTASIO")

	egen rpt_corr_PAQ4 = rowtotal(rpt_corr_PAQ4_1-rpt_corr_PAQ4_3), m
	replace rpt_corr_PAQ4 = rpt_corr_PAQ4/3 
	drop rpt_corr_PAQ4_*
}

// Periodicidad (P5-P6)
{
	gen rpt_corr_PAQ5 = (PAQ5==3) if !mi(PAQ5)
	gen rpt_corr_PAQ6 = (PAQ6==1) if !mi(PAQ6)
}

// Identificación Visual: Plagas (P7)
{
	gen rpt_corr_PAQ7_1 = (PAQ7_1==2) if !mi(PAQ7_1)
	
	gen rpt_corr_PAQ7_2 = (PAQ7_2==3) if !mi(PAQ7_2)
	replace rpt_corr_PAQ7_2 = 1 if !mi(PAQ7_2) & regexm(PAQ7_2o,"POLILLA")
	
	gen rpt_corr_PAQ7_3 = (PAQ7_3==2) if !mi(PAQ7_3)
	replace rpt_corr_PAQ7_3 = 1 if !mi(PAQ7_3) & regexm(PAQ7_3o,"MOSCA MINADORA")

	egen rpt_corr_PAQ7 = rowtotal(rpt_corr_PAQ7_1-rpt_corr_PAQ7_3), m
	replace rpt_corr_PAQ7 = rpt_corr_PAQ7/3 
	drop rpt_corr_PAQ7_*
}

// Control de Plagas y Procesos (P8-P10)
{
	egen rpt_corr_PAQ8 = rowtotal(PAQ81-PAQ83), m
	replace rpt_corr_PAQ8 = rpt_corr_PAQ8/3 if !mi(rpt_corr_PAQ8)

	// P9: Ordenamiento (Loop)
	local ans_PAQ9 C A E B F G D
	local i = 1
	foreach ans of local ans_PAQ9 {
		gen enu_corr_PAQ9_`i' = (PAQ9_`i'=="`ans'") if PAQ9_1!=""
		local i = `i' + 1
	}
	egen rpt_corr_PAQ9 = rowtotal(enu_corr_PAQ9_1-enu_corr_PAQ9_7), m
	replace rpt_corr_PAQ9 = rpt_corr_PAQ9/7

	// P10: Controladores Biológicos (Loop)
	local ans_PAQ10 2 1 1 2 2
	local i = 1
	foreach ans of local ans_PAQ10 {
		gen enu_corr_PAQ10_`i' = (PAQ10_`i'==`ans') if !mi(PAQ10_`i')
		local i = `i' + 1
	}
	egen rpt_corr_PAQ10 = rowtotal(enu_corr_PAQ10_1-enu_corr_PAQ10_5), m
	replace rpt_corr_PAQ10 = rpt_corr_PAQ10/5
}

// Seguridad y Manejo (P11-P17)
{
	// P11: Equipo (Regex manual)
	replace PAQ111 = 1 if regexm(PAQ11_o1, "IMPERMEABLES")
	replace PAQ113 = 1 if regexm(PAQ11_o1, "ZAPATOS ESPECIALES")
	egen rpt_corr_PAQ11 = rowtotal(PAQ111-PAQ116) , m 
	replace rpt_corr_PAQ11 = rpt_corr_PAQ11/6 

	gen rpt_corr_PAQ12 = (PAQ12==2) if !mi(PAQ12)
	gen rpt_corr_PAQ13 = (PAQ133==1 | PAQ134==1 | PAQ135==1) if !mi(PAQ131)

	// P14: Triple Lavado (Loop)
	local ans_PAQ14 2 5 1 4 3
	local i = 1
	foreach ans of local ans_PAQ14 {
		gen enu_corr_PAQ14_`i' = (PAQ14_`i'==`ans') if !mi(PAQ14`i')
		local i = `i' + 1
	}
	egen rpt_corr_PAQ14 = rowtotal(enu_corr_PAQ14_1-enu_corr_PAQ14_5), m
	replace rpt_corr_PAQ14 = rpt_corr_PAQ14/5

	// P15: Derrame (Indices irregulares, manual)
	gen enu_corr_PAQ15_1 = (PAQ15_6==1) if !mi(PAQ151)
	gen enu_corr_PAQ15_2 = (PAQ15_2==2) if !mi(PAQ152)
	gen enu_corr_PAQ15_3 = (PAQ15_5==3) if !mi(PAQ153)
	gen enu_corr_PAQ15_4 = (PAQ15_3==4) if !mi(PAQ154)
	egen rpt_corr_PAQ15  = rowtotal(enu_corr_PAQ15_1-enu_corr_PAQ15_4), m
	replace rpt_corr_PAQ15 = rpt_corr_PAQ15/4

	egen rpt_corr_PAQ16 = rowtotal(PAQ161-PAQ163), m 
	replace rpt_corr_PAQ16 = rpt_corr_PAQ16/3

	// P17: Higiene
	forval i=1/8 {
		gen enu_corr_PAQ17_`i' = (PAQ17`i'==1) if !mi(PAQ17`i')
	}
	replace enu_corr_PAQ17_1 = 1 if regexm(PAQ17_o1, "BAÑARSE|BAÑANDOSE|(CAMBI(ARSE|ANDOSE|AR|O|OS)?( DE|LA)? ROPA)|ROPA")
	replace enu_corr_PAQ17_4 = 1 if regexm(PAQ17_o1, "LAVA")
	egen rpt_corr_PAQ17 = rowtotal(enu_corr_PAQ17_1-enu_corr_PAQ17_8), m
	replace rpt_corr_PAQ17 = rpt_corr_PAQ17/8
}

// Cálculo de Puntaje Ponderado
{
	drop enu_corr_*
	local w_P1 1
	local w_P2 1
	foreach j in 3 4 7 {
		local w_P`j' 1.5
	}
	foreach j in 5 6 8 9 10 11 12 13 14 15 16 17 {
		local w_P`j' 2
	}

	gen ptj_pond_PAQ = 0
	local sum_wghs_PAQ = 0
	forval j = 1/17 {
		replace ptj_pond_PAQ = ptj_pond_PAQ + (`w_P`j'' * rpt_corr_PAQ`j')
		local sum_wghs_PAQ = `sum_wghs_PAQ' + `w_P`j''
	}

	gen ptj_PAQre   =  17 * (ptj_pond_PAQ/`sum_wghs_PAQ')
	egen ptj_BPA_PAQ = rowtotal(rpt_corr_PAQ5 rpt_corr_PAQ6 rpt_corr_PAQ8-rpt_corr_PAQ17), m
	
	lab var ptj_PAQre   "Puntaje en el test de papa (ponderado y reescalado)"
	lab var ptj_BPA_PAQ "Puntaje en la sección de BPA del test de papa"
}
}

//==============================================================================
// Step 4: Generate Variables for PLÁTANOS (PLQ) - BPA Knowledge Score
//==============================================================================
if `ProcessPlatano'{
// Preguntas Generales y Nutrientes (P1-P3)
{
	gen rpt_corr_PLQ1 = (PLQ1==3) if !mi(PLQ1)
	gen rpt_corr_PLQ2 = (PLQ2==2) if !mi(PLQ2)
	
	gen rpt_corr_PLQ3 = (PLQ3==3) if !mi(PLQ3)
	replace rpt_corr_PLQ3 = 0.5 if regexm(PLQ3_o1, "POTASIO")
}

// Identificación Visual: Nutrientes (P4)
{
	gen rpt_corr_PLQ4_1 = (PLQ4_1==1) if !mi(PLQ4_1)
	replace rpt_corr_PLQ4_1 = 0.5 if regexm(PLQ4_1o, "NITROGENO")

	gen rpt_corr_PLQ4_2 = (PLQ4_2==3) if !mi(PLQ4_2)
	replace rpt_corr_PLQ4_2 = 0.5 if regexm(PLQ4_2o, "FOSF")

	gen rpt_corr_PLQ4_3 = (PLQ4_3==2) if !mi(PLQ4_3)
	replace rpt_corr_PLQ4_3 = 0.5 if regexm(PLQ4_3o, "POTASIO")

	egen rpt_corr_PLQ4 = rowtotal(rpt_corr_PLQ4_1-rpt_corr_PLQ4_3), m
	replace rpt_corr_PLQ4 = rpt_corr_PLQ4/3 
	drop rpt_corr_PLQ4_*
}

// Periodicidad y Enfermedades (P5-P6)
{
	gen rpt_corr_PLQ5 = (PLQ5==5) if !mi(PLQ5)
	gen rpt_corr_PLQ6 = (PLQ6==2) if !mi(PLQ6)
}

// Identificación Visual: Plagas (P7)
{
	gen rpt_corr_PLQ7_1 = (PLQ7_1==1) if !mi(PLQ7_1)
	replace rpt_corr_PLQ7_1 = 1 if !mi(PLQ7_1) & regexm(PLQ7_1o, "PICUDO NEGRO")

	gen rpt_corr_PLQ7_2 = (PLQ7_2==1) if !mi(PLQ7_2)
	replace rpt_corr_PLQ7_2 = 1 if !mi(PLQ7_2) & regexm(PLQ7_2o,"SURI|SHURI|TORNILLO") 
	replace rpt_corr_PLQ7_2 = 0 if !mi(PLQ7_2) & PLQ7_2o=="GUSANO QUE NO ES SURI"

	gen rpt_corr_PLQ7_3 = (PLQ7_3==4) if !mi(PLQ7_3)
	replace rpt_corr_PLQ7_3 = 1 if !mi(PLQ7_3) & regexm(PLQ7_3o, "GORGOJO NEGRO|^GORGOJO$|GORGOJOS")

	egen rpt_corr_PLQ7 = rowtotal(rpt_corr_PLQ7_1-rpt_corr_PLQ7_3), m
	replace rpt_corr_PLQ7 = rpt_corr_PLQ7/3 
	drop rpt_corr_PLQ7_*
}

// Control de Plagas y Procesos (P8-P10)
{
	egen rpt_corr_PLQ8 = rowtotal(PLQ81-PLQ83) , m
	replace rpt_corr_PLQ8 = rpt_corr_PLQ8/3 if !mi(rpt_corr_PLQ8)

	// P9: Ordenamiento (Loop)
	local ans_PLQ9 C A E B F G D
	local i = 1
	foreach ans of local ans_PLQ9 {
		gen enu_corr_PLQ9_`i' = (PLQ9_`i'=="`ans'") if PLQ9_1!=""
		local i = `i' + 1
	}
	egen rpt_corr_PLQ9 = rowtotal(enu_corr_PLQ9_1-enu_corr_PLQ9_7), m
	replace rpt_corr_PLQ9 = rpt_corr_PLQ9/7

	// P10: Controladores Biológicos (Loop)
	local ans_PLQ10 2 1 1 2 2
	local i = 1
	foreach ans of local ans_PLQ10 {
		gen enu_corr_PLQ10_`i' = (PLQ10_`i'==`ans') if !mi(PLQ10_`i')
		local i = `i' + 1
	}
	egen rpt_corr_PLQ10 = rowtotal(enu_corr_PLQ10_1-enu_corr_PLQ10_5), m
	replace rpt_corr_PLQ10 = rpt_corr_PLQ10/5
}

// Seguridad y Manejo (P11-P17)
{
	egen rpt_corr_PLQ11 = rowtotal(PLQ111-PLQ116) , m 
	replace rpt_corr_PLQ11 = rpt_corr_PLQ11/6 

	gen rpt_corr_PLQ12 = (PLQ12==2) if !mi(PLQ12)
	gen rpt_corr_PLQ13 = (PLQ133==1 | PLQ134==1 | PLQ135==1) if !mi(PLQ131)

	// P14: Triple Lavado (Loop)
	local ans_PLQ14 2 5 1 4 3
	local i = 1
	foreach ans of local ans_PLQ14 {
		gen enu_corr_PLQ14_`i' = (PLQ14_`i'==`ans') if !mi(PLQ14`i')
		local i = `i' + 1
	}
	egen rpt_corr_PLQ14 = rowtotal(enu_corr_PLQ14_1-enu_corr_PLQ14_5), m
	replace rpt_corr_PLQ14 = rpt_corr_PLQ14/5

	// P15: Derrame (Indices irregulares, manual)
	gen enu_corr_PLQ15_1 = (PLQ15_6==1) if !mi(PLQ151)
	gen enu_corr_PLQ15_2 = (PLQ15_2==2) if !mi(PLQ152)
	gen enu_corr_PLQ15_3 = (PLQ15_5==3) if !mi(PLQ153)
	gen enu_corr_PLQ15_4 = (PLQ15_3==4) if !mi(PLQ154)
	egen rpt_corr_PLQ15  = rowtotal(enu_corr_PLQ15_1-enu_corr_PLQ15_4), m
	replace rpt_corr_PLQ15 = rpt_corr_PLQ15/4

	egen rpt_corr_PLQ16 = rowtotal(PLQ161-PLQ163), m 
	replace rpt_corr_PLQ16 = rpt_corr_PLQ16/3

	// P17: Higiene
	forval i=1/8 {
		gen enu_corr_PLQ17_`i' = (PLQ17`i'==1) if !mi(PLQ17`i')
	}
	replace enu_corr_PLQ17_1 = 1 if regexm(PLQ17_o1, "BAÑARSE|BAÑANDOSE|(CAMBI(ARSE|ANDOSE|AR|O|OS)?( DE)? ROPA)")
	egen rpt_corr_PLQ17 = rowtotal(enu_corr_PLQ17_1-enu_corr_PLQ17_8), m
	replace rpt_corr_PLQ17 = rpt_corr_PLQ17/8
}

// Cálculo de Puntaje Ponderado
{
	drop enu_corr_*
	local w_P1 1
	local w_P2 1
	foreach j in 3 4 6 7 {
		local w_P`j' 1.5
	}
	foreach j in 5 8 9 10 11 12 13 14 15 16 17 {
		local w_P`j' 2
	}

	gen ptj_pond_PLQ = 0
	local sum_wghs_PLQ = 0
	forval j = 1/17 {
		replace ptj_pond_PLQ = ptj_pond_PLQ + (`w_P`j'' * rpt_corr_PLQ`j')
		local sum_wghs_PLQ = `sum_wghs_PLQ' + `w_P`j''
	}

	gen ptj_PLQre 	=  17 * (ptj_pond_PLQ/`sum_wghs_PLQ')
	egen ptj_BPA_PLQ = rowtotal(rpt_corr_PLQ5 rpt_corr_PLQ8-rpt_corr_PLQ17), m
	
	lab var ptj_PLQre   "Puntaje en el test de plátano (ponderado y reescalado)"
	lab var ptj_BPA_PLQ "Puntaje en la sección de BPA del test de plátano"
	drop ptj_pond_*
}
}

//==============================================================================
// Step 5: Stadardize Scores: Divide by DE Control Group (LS)
//==============================================================================
// Cada puntaje se divide por el DE del grupo de control en línea de seguimiento.
// El coeficiente de tratamiento en la regresión se interpreta como el efecto
// en unidades de desviación estándar (DE).
if `StandardizeScores'{
foreach vraw in ptj_CQre ptj_BPA_CQ ptj_PAQre ptj_BPA_PAQ ptj_PLQre ptj_BPA_PLQ {
	qui summ `vraw' if asig_ccpp == 0
	gen `vraw'_std = `vraw' / r(sd)
}

lab var ptj_CQre_std    "Puntaje test cítricos (estandarizado: ÷ DE control LS)"
lab var ptj_BPA_CQ_std  "Puntaje BPA test cítricos (estandarizado: ÷ DE control LS)"
lab var ptj_PAQre_std   "Puntaje test papa (estandarizado: ÷ DE control LS)"
lab var ptj_BPA_PAQ_std "Puntaje BPA test papa (estandarizado: ÷ DE control LS)"
lab var ptj_PLQre_std   "Puntaje test plátano (estandarizado: ÷ DE control LS)"
lab var ptj_BPA_PLQ_std "Puntaje BPA test plátano (estandarizado: ÷ DE control LS)"
}

//==============================================================================
// Step 6: Generate Pool Variables
//==============================================================================
// Cada productor responde un solo test, así que cond() apila sin conflictos.
// - ptj_test:     puntaje total raw (escala 0-17, común a los 3 cultivos).
// - ptj_BPA:      puntaje BPA raw (rowtotal: 0-12 CQ/PAQ, 0-11 PLQ).
// - ptj_test_std: coalesce de los ya estandarizados within-crop (÷ DE del
//                 control del mismo cultivo en LS). Del bloque 4.
// - ptj_BPA_std:  ídem, coalesce directo de ptj_BPA_XX_std del bloque 4.
//                 La estandarización within-crop absorbe la diferencia de
//                 escalas (12 vs 11 ítems) porque cada SD es proporcional.
{
	// Puntaje total raw (ya en escala 0-17)
	gen ptj_test = cond(!mi(ptj_CQre), ptj_CQre, ///
	               cond(!mi(ptj_PAQre), ptj_PAQre, ptj_PLQre))
	lab var ptj_test "Puntaje total en el test (pooled, escala 0-17)"

	// Puntaje BPA raw (rowtotal, escala original por cultivo)
	gen ptj_BPA = cond(!mi(ptj_BPA_CQ), ptj_BPA_CQ, ///
	              cond(!mi(ptj_BPA_PAQ), ptj_BPA_PAQ, ptj_BPA_PLQ))
	lab var ptj_BPA "Puntaje sección BPA (pooled, rowtotal: 0-12 CQ/PAQ, 0-11 PLQ)"

	// Pooled estandarizados (coalesce de within-crop std del bloque 4)
	gen ptj_test_std = cond(!mi(ptj_CQre_std), ptj_CQre_std, ///
	                   cond(!mi(ptj_PAQre_std), ptj_PAQre_std, ptj_PLQre_std))
	lab var ptj_test_std "Puntaje total test (pooled, ÷ DE control within-crop)"

	gen ptj_BPA_std = cond(!mi(ptj_BPA_CQ_std), ptj_BPA_CQ_std, ///
	                  cond(!mi(ptj_BPA_PAQ_std), ptj_BPA_PAQ_std, ptj_BPA_PLQ_std))
	lab var ptj_BPA_std "Puntaje BPA (pooled, ÷ DE control within-crop)"
}

//==============================================================================
// Step 7: Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	keep Codprod22 ptj_*

	order ///
	/* B1. Identificador                                          */ ///
	Codprod22 ///
	/* B2. Cítricos (CQ): puntaje total y BPA, raw y estandar.    */ ///
	ptj_CQre ptj_CQre_std ptj_BPA_CQ ptj_BPA_CQ_std ///
	/* B3. Papa (PAQ): puntaje total y BPA, raw y estandar.       */ ///
	ptj_PAQre ptj_PAQre_std ptj_BPA_PAQ ptj_BPA_PAQ_std ///
	/* B4. Plátano (PLQ): puntaje total y BPA, raw y estandar.    */ ///
	ptj_PLQre ptj_PLQre_std ptj_BPA_PLQ ptj_BPA_PLQ_std ///
	/* B5. Pooled (apilado por cultivo): raw y estandarizados     */ ///
	ptj_test ptj_test_std ptj_BPA ptj_BPA_std

	label data "Puntajes test conocimiento BPAs (LS) por cultivo + pooled | 5 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 5 bloques. Flujo: identidad -> Cítricos -> Papa -> Plátano -> Pooled.
	note: UNIDAD DE ANÁLISIS: productor (LS únicamente). Identificador único = Codprod22.
	note: PREFIJOS / SUFIJOS — ptj_<cultivo>re: puntaje total reescalado a 0-17 | ptj_BPA_<cultivo>: rowtotal de la sección BPA (P5/P6 + P8-P17) | _std: estandarizado dividiendo por DE del grupo de control en LS.
	note: POOLED — ptj_test, ptj_BPA, *_std son coalesce within-crop: cada productor responde un solo test, así que cond() apila sin conflictos. La estandarización within-crop absorbe la diferencia de escalas.

	note: B1 — IDENTIFICADOR (Codprod22).
	note: B2 — CÍTRICOS (CQ): puntaje total reescalado y puntaje BPA, ambos en versión raw y estandarizada.
	note: B3 — PAPA (PAQ): mismo patrón que B2.
	note: B4 — PLÁTANO (PLQ): mismo patrón que B2.
	note: B5 — POOLED: coalesce de los puntajes anteriores apilando los 3 cultivos (un test por productor).

	note ptj_CQre  : ">>> INICIO B2: Cítricos (CQ)"
	note ptj_PAQre : ">>> INICIO B3: Papa (PAQ)"
	note ptj_PLQre : ">>> INICIO B4: Plátano (PLQ)"
	note ptj_test  : ">>> INICIO B5: Pooled"
}

//==============================================================================
// Step 8: Save Final Data
//==============================================================================
if `SaveData'{
	sort Codprod22
	compress
	save "`outc5'\\Ptjs_Test_BPAs_LS", replace
}

log close
