//------------------------------------------------------------------------------
// File           : E1_build_obs_chars.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Genera variables de caracteristicas de la observacion: efectos
//                  fijos (region, region-producto, centro poblado, mes/anio de
//                  encuesta) y dias de exposicion entre inicio de linea base e
//                  inicio de la ECA.
// Input          : Out/4_.../Panel_Inicio.dta
// Output         : Out/5_.../Caract_Obs_Trat_ECA.dta
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local GenVars			  = 1
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local SaveData			  = 1
	local VarsCaractObs fch_enc codenc nomb_rgn-nomb_ccpp asig_ccpp-ordenprod ///
		qprod

}

// Los comandos externos (acá: labutil) se instalan una vez por máquina con
// 2_Scripts/_utils/install_ado.do, no en medio de una corrida.

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create caract_obs
}

//==============================================================================
// Load Data
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
cap erase "${ruta_scripts}\E1_build_obs_chars.log"
log using "${ruta_logs}\E1_build_obs_chars.log", replace text

	
	frame change caract_obs
	use Codprod22 post `VarsCaractObs' using "`outc4'\\Panel_Inicio.dta", clear
	sort Codprod22 post
	
	// Etiqueta general
	cap lab drop sino
	lab def sino 1 "Sí" 0 "No"
}

//==============================================================================
// Create Variables
//==============================================================================
if `GenVars'{
	//--------------------------------------------------------------------------
	// Fixed Effects 
	//--------------------------------------------------------------------------
	sort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp
	// Región 
	{ 
		tempvar templab
		egen cod_rgn = group(nomb_rgn), label
		gen `templab'= ustrtitle(nomb_rgn)
		labmask cod_rgn, values(`templab')
		lab var cod_rgn "Región"
	}
	
	// Región y Producto a Evaluar (bloque de diseño)
	{
		tempvar templab
		tempvar decoded
		decode prod_ECA_eval, gen(`decoded')
		egen cod_rgn_PE = group(nomb_rgn prod_ECA_eval), label
		gen `templab' = "ECA de " + ustrtitle(`decoded') + " en " + ustrtitle(nomb_rgn)
		labmask cod_rgn_PE, values(`templab')
		lab var cod_rgn_PE "Estrato: Región y Producto a Evaluar"
	}
	
	// Centro Poblado
	{
		tempvar templab
		egen cod_cpb = group(nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp), label
		gen `templab'= ustrtitle(nomb_ccpp) + " en región " + ustrtitle(nomb_rgn)
		labmask cod_cpb , values(`templab')
		lab var cod_cpb "Centro Poblado"
	}

	// Order on-the-way: efectos fijos juntos (junto a post)
	order cod_rgn cod_rgn_PE cod_cpb, a(post)

	// Año de la encuesta
	{
		gen año_enc = year(fch_enc)
		lab var año_enc "Año en que se tomó la encuesta"
	}
	
	// Mes de la encuesta
	{
		tempvar templab 
		gen mes_enc = month(fch_enc) 
		gen `templab' = "Enero" if mes_enc == 1 
		replace `templab' = "Febrero"	if mes_enc == 2
		replace `templab' = "Marzo"	 	if mes_enc == 3
		replace `templab' = "Abril"		if mes_enc == 4 
		replace `templab' = "Mayo"		if mes_enc == 5
		replace `templab' = "Junio"		if mes_enc == 6 
		replace `templab' = "Julio"		if mes_enc == 7 
		replace `templab' = "Agosto"	if mes_enc == 8 
		replace `templab' = "Setiembre"	if mes_enc == 9
		replace `templab' = "Octubre"	if mes_enc == 10
		replace `templab' = "Noviembre"	if mes_enc == 11
		replace `templab' = "Diciembre"	if mes_enc == 12
		labmask mes_enc, values(`templab')
		lab var mes_enc "Mes en que se tomó la encuesta"
	}
	
	// Semana de la encuesta
	{
		gen sem_enc = week(fch_enc)
		lab var sem_enc "Semana en que se tomó la encuesta"
	}

	// Order on-the-way: temporales derivadas de fch_enc juntas (junto a fch_enc)
	order año_enc mes_enc sem_enc, a(fch_enc)

	//--------------------------------------------------------------------------
	// Exposición entre inicio de ECA y fecha de recojo de información
	//--------------------------------------------------------------------------
	// Días de exposición entre inicio de enc. de LB e inicio de la ECA
	{
		// Exposición a nivel de centro poblado
		gen dias_LB_ini_1aECA = fch_enc - fch_ini_1aECA if post==0
		replace dias_LB_ini_1aECA = 0 if (mi(fch_ini_1aECA) | ///
										!inlist(prod_1aECA_ccpp,11,12,15,16,19)) ///
										& post==0
		lab var dias_LB_ini_1aECA "Días entre linea base e inicio de 1a ECA en el Centro Poblado"
			
		// Exposición a nivel individual
		gen dias_LB_ini_ECA = fch_enc - fch_ini_ECA if post==0
		replace dias_LB_ini_ECA = 0 if (mi(fch_ini_ECA) | ///
										!inlist(prod_ECA,11,12,15,16,19)) ///
										& post==0
		lab var dias_LB_ini_ECA "Días entre linea base e inicio de ECA en la que participa el productor"
	}
}

//==============================================================================
// Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	// Drop columnas auxiliares antes de ordenar
	drop nomb_rgn-nomb_dstrt

	//--------------------------------------------------------------------------
	// Order Masivo por Bloques Temáticos
	//--------------------------------------------------------------------------
	order ///
	/* B1. Identificadores y periodo                            */ ///
	Codprod22 codenc post ///
	/* B2. Fecha y temporales (derivadas de fch_enc)            */ ///
	fch_enc año_enc mes_enc sem_enc ///
	/* B3. Estratos y efectos fijos                             */ ///
	cod_rgn cod_rgn_PE cod_cpb ///
	/* B4. Centro poblado y producto a evaluar                  */ ///
	nomb_ccpp asig_ccpp prod_ECA_eval pste_ccpp_lb excl_ccpp ///
	/* B5. Primera ECA del centro poblado                       */ ///
	i1aECA* prod_1aECA_ccpp-astn_1aECA_ccpp ///
	/* B6. Clasificación productor × ECA                        */ ///
	cumpl_* DentroLista grupo ordenprod qprod casoespec ///
	/* B7. ECA en la que participa el productor                 */ ///
	nomb_ccpp_ECA-grad_ECA_prod ///
	/* B8. Días de exposición                                   */ ///
	dias_LB_ini_1aECA dias_LB_ini_ECA

	//--------------------------------------------------------------------------
	// Label Data y Notas (estructura, unidad de análisis, sufijos, bloques)
	//--------------------------------------------------------------------------
	label data "Características de la observación: identificadores, efectos fijos, ECA y exposición | 8 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 8 bloques. Flujo: identidad -> temporal -> estratos -> tratamiento (CCPP, primera ECA, productor) -> exposición.
	note: UNIDAD DE ANÁLISIS: productor × periodo (post = 0 LB, post = 1 LS). Identificador único = Codprod22.
	note: SUFIJOS — _enc: derivadas de fch_enc | _ccpp: a nivel centro poblado | _ECA: a nivel ECA en la que participa el productor.

	note: B1 — IDENTIFICADORES Y PERIODO (Codprod22, codenc, post).
	note: B2 — FECHA Y TEMPORALES: fch_enc + año/mes/semana derivados.
	note: B3 — ESTRATOS Y EFECTOS FIJOS: región, región × producto evaluado, centro poblado.
	note: B4 — CENTRO POBLADO Y PRODUCTO A EVALUAR: asignación de tratamiento al CCPP y producto evaluado.
	note: B5 — PRIMERA ECA DEL CCPP: variables que describen la primera ECA implementada en el CCPP.
	note: B6 — CLASIFICACIÓN PRODUCTOR × ECA: cumplimiento, presencia en lista, grupo, orden de producto.
	note: B7 — ECA DEL PRODUCTOR: variables de la ECA en la que efectivamente participa el productor.
	note: B8 — DÍAS DE EXPOSICIÓN: ventana entre línea base e inicio de la ECA (a nivel CCPP y a nivel productor).

	// Notas de variable ancla (primera variable de cada bloque)
	note Codprod22         : ">>> INICIO B1: Identificadores y periodo"
	note fch_enc           : ">>> INICIO B2: Fecha y temporales"
	note cod_rgn           : ">>> INICIO B3: Estratos y efectos fijos"
	note nomb_ccpp         : ">>> INICIO B4: Centro poblado y producto a evaluar"
	note i1aECA_PE_ccpp    : ">>> INICIO B5: Implementación de primera ECA del centro poblado"
	// B6: la primera variable es cumpl_* (resuelta dinámicamente)
	qui ds cumpl_*
	local first_cumpl : word 1 of `r(varlist)'
	note `first_cumpl'     : ">>> INICIO B6: Clasificación productor × ECA"
	note nomb_ccpp_ECA     : ">>> INICIO B7: ECA del productor"
	note dias_LB_ini_1aECA : ">>> INICIO B8: Días de exposición"
}

//==============================================================================
// Save Final Data
//==============================================================================
if `SaveData'{
	sort Codprod22 post
	// Limpia tempvars residuales (__000NNN).
	cap drop __0*
	compress
	save "`outc5'\\Caract_Obs_Trat_ECA.dta", replace
}

log close
