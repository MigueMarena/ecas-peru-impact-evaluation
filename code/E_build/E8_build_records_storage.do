//------------------------------------------------------------------------------
// File           : E8_build_records_storage.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Genera variables sobre tenencia de registros agricolas
//                  (aplicacion de insumos, produccion, costos, ventas) y
//                  condiciones minimas de almacenamiento de agroquimicos.
// Input          : Out/4_.../Panel_Inicio.dta
// Output         : Out/5_.../Registros_Almacen_LByLS.dta
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local GenVars_Regis		  = 1	// Variables de Registros/Libretas (1-7)
	local GenVars_Almac		  = 1	// Condiciones de Almacenamiento
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local SaveData			  = 1

	// Variables necesarias
	local vars_regis preg400R*
}

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create registros
}

//==============================================================================
// Step 1: Load Data
//==============================================================================
if `LoadData'{
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
cap erase "${ruta_scripts}\E8_build_records_storage.log"
log using "${ruta_logs}\E8_build_records_storage.log", replace text

	
	frame change registros
	use Codprod22 post `vars_regis' using "`outc4'\\Panel_Inicio.dta", clear
	
	// Etiqueta general
	cap lab drop sino
	lab def sino 1 "Sí" 0 "No"
}

//==============================================================================
// Step 2: Generate Variables for Records and Field Notebooks (Automated)
//==============================================================================
if `GenVars_Regis'{
	// Lista de etiquetas para las 7 variables de registros
	# delimit ;
	local regis_lbls 
	`" "Tienen registro/libreta de aplicación de abonos y/o fertilizantes" 
	"Tienen registro/libreta de aplicación de plaguicidas" 
	"Tienen registro/libreta de liberac./aplicac. de control biológico" 
	"Tienen registro/libreta de aplicación de riego" 
	"Tienen registro de control de producto cosechado" 
	"Tienen registro kardex para control de almacén (ingreso/salida)" 
	"Tienen registro de rastreabilidad y trazabilidad" "';
	# delimit cr
	
	local i = 1
	foreach lbl of local regis_lbls {
		// Generar variable: regis_1, regis_2... hasta regis_7
		// Basado en: preg400R1, preg400R2... hasta preg400R7
		gen regis_`i':sino = preg400R`i' == 1 if !mi(preg400R`i')
		lab var regis_`i' "`lbl'"
		local i = `i' + 1
	}
}

//==============================================================================
// Step 3: Generate Variables for Storage Conditions of Agrochemicals
//==============================================================================
if `GenVars_Almac'{
	// Índice sumatorio de condiciones mínimas indispensables
	// Variables: preg400R8_11, 12, 13, 15, 111, 112
	egen tot_cond_min_alm = rowtotal(preg400R8_11 preg400R8_12 preg400R8_13 ///
					 preg400R8_15 preg400R8_111 preg400R8_112), m
	lab var tot_cond_min_alm "Total de condiciones de almacenaje mínimas indispensables para agroquímicos"
}

//==============================================================================
// Step 4: Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	keep Codprod22 post regis_* tot_cond_min_alm

	order ///
	/* B1. Identificadores                                            */ ///
	Codprod22 post ///
	/* B2. Registros y libretas de campo (7 tipos)                    */ ///
	regis_1 regis_2 regis_3 regis_4 regis_5 regis_6 regis_7 ///
	/* B3. Almacenamiento de agroquímicos (índice de condiciones)     */ ///
	tot_cond_min_alm

	label data "Registros, libretas de campo y almacenamiento de agroquímicos (LB y LS) | 3 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 3 bloques. Flujo: identidad -> tenencia de registros -> condiciones de almacenamiento.
	note: UNIDAD DE ANÁLISIS: productor × periodo (post 0/1). Identificador único = Codprod22.
	note: NOMENCLATURA — regis_<n> (n=1..7): tenencia de registro/libreta del concepto n (1 abonos/fertilizantes, 2 plaguicidas, 3 control biológico, 4 riego, 5 producto cosechado, 6 kardex almacén, 7 trazabilidad/rastreabilidad). | tot_cond_min_alm: rowtotal de 6 condiciones mínimas indispensables para almacenar agroquímicos.

	note: B1 — IDENTIFICADORES (Codprod22, post).
	note: B2 — REGISTROS Y LIBRETAS DE CAMPO: 7 dummies (sí/no) por concepto.
	note: B3 — CONDICIONES MÍNIMAS DE ALMACENAMIENTO: rowtotal de 6 condiciones (ventilación, separación, etc.).

	note regis_1 : ">>> INICIO B2: Registros y libretas de campo"
	// B3 (1 var) sin nota ancla por punto I de la spec
}

//==============================================================================
// Step 5: Save Final Data
//==============================================================================
if `SaveData'{
	sort Codprod22 post
	compress
	save "`outc5'\\Registros_Almacen_LByLS", replace
}

log close
