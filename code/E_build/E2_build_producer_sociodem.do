//------------------------------------------------------------------------------
// File           : E2_build_producer_sociodem.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Genera variables sociodemograficas del productor o jefe de hogar
//                  (edad, sexo, educacion, lengua materna, autoidentificacion etnica)
//                  a partir de Panel_Inicio y Panel_Personas. Usa reclink2 para
//                  vincular productores con miembros del hogar.
// Depends        : (ninguno)
// Input          : Out/4_.../Panel_Inicio.dta
//                  Out/4_.../Panel_Personas.dta
// Output         : Out/5_.../Sociodem_Prod_JH_LB.dta
//------------------------------------------------------------------------------
version 19.0
clear all

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

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames 	  = 1
	local LoadData 			  = 1	// Carga, link y consolida marcos sociodem
	local GenVars  			  = 1	// Genera variables sociodemográficas
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local SaveAndClean		  = 1
	local varltoimport1 _idI Codprod22 nomb_prod apell_prod post
	local varltoimport2 Codprod22 post preg001c preg002-opreg008 preg803_1
}

//==============================================================================
// Frames
//==============================================================================
if `ResetDoFrames'{
	frames reset 
	frame create personas_LB_JH
	frame create farm_HH_scdm
}

//==============================================================================
// Load Data: Keep sociodem data from HH or Farm Producer and save in a frame
//==============================================================================
if `LoadData'{
	// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
	cap log close
	cap erase "${ruta_scripts}\E2_build_producer_sociodem.log"
	log using "${ruta_logs}\E2_build_producer_sociodem.log", replace text

	use `varltoimport1' if post==0 using "`outc4'\\Panel_Inicio.dta", clear
	drop post
	
	// Rename some variables
	ren nomb_prod 	preg001b
	ren apell_prod 	preg001a

	// String Merge 
	reclink2 Codprod22 preg001b preg001a using "`outc4'\\Panel_Personas.dta", ///
		idm(_idI) idu(_idM) gen(score) wm(20 7.5 15) req(Codprod22) _m(_m) np(1)
	gsort Codprod preg001c preg003_1
	duplicates drop Codprod22, force
	
	// Records with exact matching
	frame copy default exa_match_LB
	frame exa_match_LB{
		qui count if score >= 0.8249 & !mi(score)
		qui levelsof Codprod22 if score >= 0.8249 & !mi(score)
		dis "Casos con score >= 0.8249 son `r(N)'. Registros únicos son `r(r)'."
		keep if score >=0.8249 & !mi(score) // desde obs de ECA082-0-9-17
		duplicates drop Codprod22, force
		sort Codprod22
		keep Codprod22 preg001b preg001a preg0* opreg0* preg803_1
	}
	
	// Records with no exact matching
	frame copy default nexa_match_LB
	frame nexa_match_LB{
		qui count if score < 0.8249 | mi(score)
		qui levelsof Codprod22 if score < 0.8249 | mi(score)
		dis "Casos con score < 0.8249 son `r(N)'. Registros únicos son `r(r)'."
		keep if score<0.8249 | mi(score)
		duplicates drop Codprod22, force
		sort Codprod22
		keep Codprod22 preg001b preg001a
	}
	
	// Impute info from HH to records (IDs) with no exact matching
	frame change personas_LB_JH
	use `varltoimport2' if post==0 /* LB */ & preg001c==1 /* HH */ using ///
		"`outc4'\\Panel_Personas.dta", clear
	
	// Link frames (nexa_match_LB <-> personas_LB_JH)
	frame change nexa_match_LB
	frlink 1:1 Codprod22, frame(personas_LB_JH)
	frget _all, from(personas_LB_JH)
	drop personas_LB_JH post
	
	// Final Frame
	frame farm_HH_scdm: xframeappend exa_match_LB nexa_match_LB, gen(origen)
}

//==============================================================================
// Gen Vars: sociodem data from final frame
//==============================================================================
if `GenVars'{
	frame change farm_HH_scdm
	sort Codprod22 
	
	// Edad y Edad^2
	{
		gen edad	= preg003_1
		gen edadsq  = edad*edad
		lab var edad 	"Edad (del productor o JH)"
		lab var edadsq  "Ëdad al cuadrado (del productor o JH)"
	}
	
	// Sexo
	{
		recode preg002 (2=0 "Femenino") (1=1 "Masculino"), gen(sexo) lab(labsex)
		lab var sexo 	"Sexo (del productor o JH)"
	}
	
	// Max nivel de educacion completado
	{
		gen nivedmax = .
		replace preg005_1 = 2 if preg005_2==7 & preg005_1>=4
		replace preg005_1 = 3 if preg005_2==8 & preg005_1==5 & preg803_1==""
		replace preg005_1 = 3 if preg005_2==8 & preg005_1==9 & preg803_1==""
		replace preg005_1 = 3 if preg005_2==8 & preg005_1==6
		replace preg005_1 = 4 if preg005_2==8 & regexm(preg803_1,"DOCENTE|PROFESOR|MANTENIMIENTO")
		replace preg005_1 = 4 if preg005_2==10 & preg005_1==1
		replace preg005_1 = 4 if preg005_2==10 & preg005_1==7
		replace preg005_1 = 4 if preg005_2==10 & preg005_1==9
		replace nivedmax = 0 if (preg005_1==0 & preg005_2==1) 
		replace nivedmax = 1 if (preg005_1==0 & preg005_2==2) | (preg005_2==3) 
		replace nivedmax = 2 if (preg005_1==6 & preg005_2==4) | (preg005_2==5) 
		replace nivedmax = 3 if (preg005_1==5 & preg005_2==6) | (preg005_2==7) | (preg005_2==9)
		replace nivedmax = 4 if preg005_2==8
		replace nivedmax = 5 if preg005_2==10
		lab def nivedmax 0 "No estudió" 1 "Inicial" 2 "Primaria" 3 "Secundaria" ///
							4 "Sup. No Univ." 5 "Sup. Univ."
		lab val nivedmax nivedmax
		lab var nivedmax "Máximo nivel de educación completado (del productor o JH)"
	}
	
	// Años de educación (del productor o JH)
	{	
		gen educ = .
		replace educ = 0 if (preg005_2==1|preg005_2==2)
		replace educ = preg005_1 	  if inlist(preg005_2,3,4)
		replace educ = 6  + preg005_1 if inlist(preg005_2,5,6)
		replace educ = 11 + preg005_1 if inlist(preg005_2,7,8)
		replace educ = 11 + 1 if preg005_2==9 & inrange(preg005_1,1,2)
		replace educ = 11 + 2 if preg005_2==9 & inrange(preg005_1,3,4)
		replace educ = 11 + 3 if preg005_2==9 & inrange(preg005_1,5,6)
		replace educ = 11 + 4 if preg005_2==9 & inrange(preg005_1,7,8)
		replace educ = 11 + preg005_1 if preg005_2==10
		lab var educ "Años de educación (del productor o JH)"
	}
	
	// Lengua Materna: Castellano (del productor o JH)
	{
		gen castell = (preg007==10) if !mi(preg007)
		lab def castell 0 "Otra" 1 "Castellano"
		lab val castell castell
		lab var castell "Lengua materna: Castellano (del productor o JH)"
	}
	
	// Autoidenticación Étnica (del productor o JH)
	{
		gen iden_etn = 1 if preg008==6
		replace iden_etn = 2 if preg008==1
		replace iden_etn = 3 if preg008==2|preg008==3|preg008==7
		replace iden_etn = 4 if preg008==4|preg008==5
		replace iden_etn = 5 if preg008==8
		lab def iden_etn 1 "Mestizo" 2 "Quechua" 3 "Otro Indígena/Originario" ///
						 4 "Otro Grupo Étnico (Afrodesc./Blanco)" 5 "NS/NC"
		lab val iden_etn iden_etn
		lab var iden_etn "Autoidenticación étnica (productor o JH)"
	}
}

//==============================================================================
// Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	// Quedar con un subconjunto de variables (lista explícita; preserva comportamiento original)
	keep Codprod22 edad edadsq sexo educ castell iden_etn

	//--------------------------------------------------------------------------
	// Order Masivo por Bloques Temáticos
	//--------------------------------------------------------------------------
	order ///
	/* B1. Identificador             */ ///
	Codprod22 ///
	/* B2. Edad                      */ ///
	edad edadsq ///
	/* B3. Sexo                      */ ///
	sexo ///
	/* B4. Educación                 */ ///
	educ ///
	/* B5. Lengua materna            */ ///
	castell ///
	/* B6. Autoidentificación étnica */ ///
	iden_etn

	//--------------------------------------------------------------------------
	// Label Data y Notas (estructura, unidad de análisis, bloques)
	//--------------------------------------------------------------------------
	label data "Sociodemografía del productor o JH (línea base): edad, sexo, educación, lengua, etnia | 6 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 6 bloques. Flujo: identidad -> edad -> sexo -> educación -> lengua -> autoidentificación étnica.
	note: UNIDAD DE ANÁLISIS: productor (LB únicamente). Identificador único = Codprod22.
	note: ALCANCE: variables del productor del predio o, si éste no fue encuestado directamente como miembro del hogar, del JH (vía reclink2 sobre Panel_Personas).

	note: B1 — IDENTIFICADOR (Codprod22).
	note: B2 — EDAD: edad y edad².
	note: B3 — SEXO: 0 Femenino / 1 Masculino.
	note: B4 — EDUCACIÓN: años de escolaridad del productor o JH (categoría intermedia nivedmax se descarta).
	note: B5 — LENGUA MATERNA: 1 Castellano / 0 Otra.
	note: B6 — AUTOIDENTIFICACIÓN ÉTNICA: Mestizo / Quechua / Otro Indígena / Otro / NS-NC.

	// Notas de variable ancla (solo bloques con > 1 variable)
	note edad : ">>> INICIO B2: Edad"
}

//==============================================================================
// Save Final Data and Clean Frames
//==============================================================================
if `SaveAndClean'{
	sort Codprod22
	compress
	save "`outc5'\\Sociodem_Prod_JH_LB", replace
	frame drop default personas_LB_JH exa_match_LB nexa_match_LB
}

log close