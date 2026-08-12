//------------------------------------------------------------------------------
// File           : E7_build_bpa_practices.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Genera variables de adopcion de Buenas Practicas Agricolas (BPA)
//                  generales (no condicionadas: suelo, riego, plagas) y
//                  condicionadas por tipo de insumo (abonos, fertilizantes,
//                  plaguicidas, control biologico, MIP).
// Input          : Out/4_.../Panel_Inicio.dta
// Output         : Out/5_.../BPAs_CondyNoCond_LByLS.dta
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local GenBPA_General	  = 1	// BPAs no condicionadas (1-14)
	local GenBPA_Abonos		  = 1	// BPAs condicionadas: Abonos
	local GenBPA_Fertil		  = 1	// BPAs condicionadas: Fertilizantes
	local GenBPA_Plagui		  = 1	// BPAs condicionadas: Plaguicidas
	local GenBPA_MIP		  = 1	// BPAs condicionadas: Bio y MIP
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local SaveData			  = 1

	// Variables necesarias
	local vars_bpa preg401* preg402-preg424o
}

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create bpas
}

//==============================================================================
// Step 1: Load Data
//==============================================================================
if `LoadData'{
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
cap erase "${ruta_scripts}\E7_build_bpa_practices.log"
log using "${ruta_logs}\E7_build_bpa_practices.log", replace text

	
	frame change bpas
	use Codprod22 post `vars_bpa' using "`outc4'\\Panel_Inicio.dta", clear
	
	// Etiqueta general
	cap lab drop sino
	lab def sino 1 "Sí" 0 "No"
}

//==============================================================================
// Step 2: Generate General BPAs (Not Conditioned)
//==============================================================================
if `GenBPA_General'{
	// Automatización de creación y etiquetas para BPA 1 - 14
	# delimit ;
	local bpa_lbls 
	`" "Realizaron Análisis de Suelos" "Mezclaron Tierra con Materia Orgánica" 
	"Asociaron Cultivos para Proteger Suelo" "Realizaron Surcos en Contornos" 
	"Determinaron Necesidad de Agua del Cultivo" "Determinaron Frecuencia de Riego"
	"Midieron Cantidad de Agua Aplicada" "Realizaron Mantenimiento Sistema Riego"
	"Analizaron Agua" "Usaron Abonos" "Usaron Fertilizantes" "Usaron Plaguicidas"
	"Aplicaron Control Biológico" "Aplicaron Manejo Integrado de Plagas (MIP)" "';
	# delimit cr
	
	local i = 1
	foreach lbl of local bpa_lbls {
		gen bpa_`i':sino = preg401`i'==1 if !mi(preg401`i')
		lab var bpa_`i' "`lbl'"
		local i = `i' + 1
	}
}

//==============================================================================
// Step 3.1: Generate Conditioned BPAs: Abonos y Fertilizantes
//==============================================================================
if `GenBPA_Abonos'{
	// 2.1 Abonos (Condicionado a bpa_10)
	//--------------------------------------------------------------------------
	gen bpa_10_1:sino = preg402==1 if bpa_10==1 
	lab var bpa_10_1 "Abono - Usaron cantidad necesaria"

	gen bpa_10_2:sino = preg403==1 if bpa_10==1
	lab var bpa_10_2 "Abono - Insumo de buena calidad"

	gen bpa_10_3:sino = preg404==1 if bpa_10==1
	lab var bpa_10_3 "Abono - Recomendado por especialista"

	gen bpa_10_4:sino = preg405==1 if bpa_10==1 & bpa_10_3==1
	lab var bpa_10_4 "Abono - Aplicaron dosis recomendada"

	gen bpa_10_5:sino = preg406==1 if bpa_10==1 & bpa_10_3==1
	lab var bpa_10_5 "Abono - Condiciones de almacenamiento recomendadas"
}

if `GenBPA_Fertil'{
	// 2.2 Fertilizantes (Condicionado a bpa_11)
	//--------------------------------------------------------------------------
	gen bpa_11_1:sino = preg407==1 if bpa_11==1
	lab var bpa_11_1 "Fertilizante - Usaron cantidad necesaria"

	gen bpa_11_2:sino = preg408==1 if bpa_11==1
	lab var bpa_11_2 "Fertilizante - Insumo de buena calidad"

	gen bpa_11_3:sino = preg409==1 if bpa_11==1
	lab var bpa_11_3 "Fertilizante - Recomendado por especialista"

	gen bpa_11_4:sino = preg410==1 if bpa_11==1 & bpa_11_3==1
	lab var bpa_11_4 "Fertilizante - Aplicaron dosis recomendada"

	gen bpa_11_5:sino = preg411==1 if bpa_11==1 & bpa_11_3==1
	lab var bpa_11_5 "Fertilizante - Condiciones de almacenamiento recomendadas"
}

//==============================================================================
// Step 3.2: Generate Conditioned BPAs: Plaguicidas (Conditioned on bpa_12)
//==============================================================================
if `GenBPA_Plagui'{
	gen bpa_12_1:sino = preg412==1 if bpa_12==1
	lab var bpa_12_1 "Plaguicida - Usaron cantidad necesaria"

	gen bpa_12_2:sino = preg413==1 if bpa_12==1
	lab var bpa_12_2 "Plaguicida - Insumo de buena calidad"

	gen bpa_12_3:sino = preg414==1 if bpa_12==1
	lab var bpa_12_3 "Plaguicida - Recomendado por especialista"

	gen bpa_12_4:sino = preg415==1 if bpa_12==1
	lab var bpa_12_4 "Plaguicida - Usaron plaguicida químico"
	
	// Con etiqueta en el envase (Cond. a químico)
	gen bpa_12_q_1:sino = preg415a==1 if bpa_12_4==1 
	lab var bpa_12_q_1 "Plaguicida Químico - Tiene etiqueta en envase"

	// Leyeron info en el envase (Cond. a químico)
	gen bpa_12_q_2:sino = preg416==1 if bpa_12_q_1==1 
	lab var bpa_12_q_2 "Plaguicida Químico - Leyeron info en envase" 
	
	// Dosis recomendada (Cond. a químico)
	gen bpa_12_q_3:sino = preg417==1 if bpa_12_q_1==1 
	lab var bpa_12_q_3 "Plaguicida Químico - Aplicaron dosis recomendada en el envase" 
	
	// Solo en cultivo indicado (Cond. a químico)
	gen bpa_12_q_4:sino = preg418==1 if bpa_12_q_1==1
	lab var bpa_12_q_4 "Plaguicida Químico - Aplicaron solo en cultivo indicado en el envase"

	// Periodo de carencia (Cond. a químico)
	gen bpa_12_q_5:sino = preg419==1 if bpa_12_4==1
	lab var bpa_12_q_5 "Plaguicida Químico - Cumplieron tiempo recomendado entre ultima aplicación y periodo de cosecha"

	// Almacenamiento (Cond. a químico)
	gen bpa_12_q_6:sino = preg420==1 if bpa_12_4==1 
	lab var bpa_12_q_6 "Plaguicida Químico - Condiciones de almacenamiento recomendadas"

	// Protección Personal (Cond. a químico)
	gen bpa_12_q_7:sino = (preg4211==1|preg4212==1|preg4213==1|preg4214==1|preg4215==1|preg4216==1) ///
			    if bpa_12_4==1
	lab var bpa_12_q_7 "Plaguicida Químico - Usaron alguna protección"
	
	// Gestión de Envases (Solo métodos adecuados vs inadecuados)
	gen bpa_12_q_71:sino = (preg4225==1 | preg4226==1) & ///
			    (preg4221==0 & preg4222==0 & preg4223==0 & preg4224==0) ///
			    if !mi(preg4221)
	lab var bpa_12_q_71 "Plaguicida - Implementaron buena gestión de envases vacíos"
}

//==============================================================================
// Step 3.3: Generate Conditioned BPAs: Control Biológico y MIP
//==============================================================================
if `GenBPA_MIP'{
	// Control Biológico (Condicionado a bpa_13)
	gen bpa_13_1:sino = preg423==1 if bpa_13==1
	lab var bpa_13_1 "Realizaron evaluación de plagas al aplicar control biológico"	

	// MIP (Condicionado a bpa_14)
	gen bpa_14_1:sino = (preg4241==1|preg4242==1|preg4243==1|preg4245==1) if bpa_14==1 
	lab var bpa_14_1 "MIP - Combinaron uso estratégico de diferentes tipos de control"
}

//==============================================================================
// Step 4: Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	keep Codprod22 post bpa_*

	order ///
	/* B1. Identificadores                                            */ ///
	Codprod22 post ///
	/* B2. BPAs generales no condicionadas (1-14)                     */ ///
	bpa_1 bpa_2 bpa_3 bpa_4 ///
	bpa_5 bpa_6 bpa_7 bpa_8 bpa_9 ///
	bpa_10 bpa_11 bpa_12 bpa_13 bpa_14 ///
	/* B3. Condicionadas — Abonos (sub-prácticas de bpa_10)           */ ///
	bpa_10_1 bpa_10_2 bpa_10_3 bpa_10_4 bpa_10_5 ///
	/* B4. Condicionadas — Fertilizantes (sub-prácticas de bpa_11)    */ ///
	bpa_11_1 bpa_11_2 bpa_11_3 bpa_11_4 bpa_11_5 ///
	/* B5. Condicionadas — Plaguicidas (sub-prácticas de bpa_12 + q*) */ ///
	bpa_12_1 bpa_12_2 bpa_12_3 bpa_12_4 ///
	bpa_12_q_1 bpa_12_q_2 bpa_12_q_3 bpa_12_q_4 ///
	bpa_12_q_5 bpa_12_q_6 bpa_12_q_7 bpa_12_q_71 ///
	/* B6. Condicionadas — Control biológico y MIP                    */ ///
	bpa_13_1 bpa_14_1

	label data "BPAs no condicionadas y condicionadas (LB y LS) | 6 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 6 bloques. Flujo: identidad -> generales (catálogo 1-14) -> sub-prácticas condicionadas por insumo (abonos, fertilizantes, plaguicidas) -> bio/MIP.
	note: UNIDAD DE ANÁLISIS: productor × periodo (post 0/1). Identificador único = Codprod22.
	note: NOMENCLATURA — bpa_<n>: práctica general n=1..14 | bpa_<n>_<k>: sub-práctica k condicionada al uso del insumo n (n=10 abonos, 11 fertilizantes, 12 plaguicidas) | bpa_12_q_<k>: sub-práctica condicionada a usar plaguicida químico (bpa_12_4==1) | bpa_12_q_71: gestión de envases (subset del 7).
	note: ESCALAS — 0 No / 1 Sí (etiqueta sino). Las condicionadas son missing si no aplica el filtro de uso.

	note: B1 — IDENTIFICADORES (Codprod22, post).
	note: B2 — BPAs GENERALES NO CONDICIONADAS: 14 prácticas (4 suelo, 5 riego, 5 insumos/plagas).
	note: B3 — ABONOS (cond. a bpa_10): cantidad necesaria, calidad, recomendación, dosis, almacenamiento.
	note: B4 — FERTILIZANTES (cond. a bpa_11): mismo patrón que B3 para fertilizantes.
	note: B5 — PLAGUICIDAS (cond. a bpa_12): cantidad/calidad/recom./uso químico + 7 sub-prácticas de manejo del químico (etiqueta, lectura info, dosis, cultivo indicado, carencia, almacenamiento, protección personal) + gestión de envases.
	note: B6 — BIO/MIP (cond. a bpa_13/bpa_14): evaluación de plagas para control biológico y combinación de métodos para MIP.

	note bpa_1     : ">>> INICIO B2: BPAs generales no condicionadas"
	note bpa_10_1  : ">>> INICIO B3: Abonos (cond. a bpa_10)"
	note bpa_11_1  : ">>> INICIO B4: Fertilizantes (cond. a bpa_11)"
	note bpa_12_1  : ">>> INICIO B5: Plaguicidas (cond. a bpa_12)"
	note bpa_13_1  : ">>> INICIO B6: Bio/MIP"
}

//==============================================================================
// Step 5: Save Final Data
//==============================================================================
if `SaveData'{
	sort Codprod22 post
	compress
	save "`outc5'\\BPAs_CondyNoCond_LByLS", replace
}

log close
