//------------------------------------------------------------------------------
// File           : E9_build_food_safety.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Genera variables de inocuidad alimentaria: gestion de
//                  residuos (cultivos y animales), almacenamiento, etiquetado
//                  y certificacion de productos.
// Input          : Out/4_.../Panel_Inicio.dta
// Output         : Out/5_.../Inocuidad_LByLS.dta
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local GenVars_Resid		  = 1	// Gestión de Residuos (Cultivos y Animales)
	local GenVars_Manejo	  = 1	// Almacenamiento, Etiquetado y Certificación
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local SaveData			  = 1
	local vars_inocuidad preg501* preg502* preg504 preg506* preg507 preg508
}

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create inocuidad
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
cap erase "${ruta_scripts}\E9_build_food_safety.log"
log using "${ruta_logs}\E9_build_food_safety.log", replace text

	
	frame change inocuidad
	use Codprod22 post `vars_inocuidad' using "`outc4'\\Panel_Inicio.dta", clear
	
	// Etiqueta general
	cap lab drop sino
	lab def sino 1 "Sí" 0 "No"
}

//==============================================================================
// Step 2: Residual Management (Cultivos y Animales)
//==============================================================================
if `GenVars_Resid'{
	//--------------------------------------------------------------------------
	// Residuos de Cultivos — 3 versiones
	//   Buenas prácticas: compostan (5012), entierran (5014)
	//   Malas prácticas:  queman (5011), botan (5013), dejan en campo (5015)
	//--------------------------------------------------------------------------
	// v1 (flexible): solo exige al menos 1 buena práctica
	gen ino_resid_cult_v1:sino = (preg5012==1 | preg5014==1) if !mi(preg5011) 
	lab var ino_resid_cult_v1 "Residuos cultivos - Flexible (solo alguna buena)"

	// v2 (intermedia/original): al menos 1 buena práctica + no queman ni botan 
	//    (dejar en campo NO se filtra; se permite como good practice)
	gen ino_resid_cult_v2:sino = (preg5012==1 | preg5014==1) & (preg5011==0 & preg5013==0) ///
		if !mi(preg5011)
	lab var ino_resid_cult_v2 "Residuos cultivos - Intermedia (no quema/bota + alguna buena)"

	// v3 (estricta): al menos una buena + no queman, no botan, no dejan en campo
	gen ino_resid_cult_v3:sino = (preg5012==1 | preg5014==1) & (preg5011==0 & preg5013==0 & preg5015==0) ///
		if !mi(preg5011)
	lab var ino_resid_cult_v3 "Residuos cultivos - Estricta (no quema/bota/deja + alguna buena)"

	//--------------------------------------------------------------------------
	// Residuos de Animales de Crianza — 3 versiones
	//   Buenas prácticas: compost/abono (502b4), entierran (502b5)
	//   Malas prácticas:  queman (502b1), botan (502b2), dejan en campo (502b3)
	//--------------------------------------------------------------------------
	// v1 (flexible): solo exige al menos 1 buena práctica
	gen ino_resid_anim_v1:sino = (preg502b4==1 | preg502b5==1) if !mi(preg502b4)
	lab var ino_resid_anim_v1 "Residuos animales - Flexible (solo alguna buena)"

	// v2 (intermedia): no queman ni botan + buenas prácticas
	//    (dejar en campo no se filtra, análogo a cultivos)
	gen ino_resid_anim_v2:sino = (preg502b4==1 | preg502b5==1) & (preg502b1==0 & preg502b2==0) ///
		if !mi(preg502b1)
	lab var ino_resid_anim_v2 "Residuos animales - Intermedia (no quema/entierra + alguna buena)"

	// v3 (estricta): no queman, no botan, no dejan en campo + buenas prácticas
	gen ino_resid_anim_v3:sino = (preg502b4==1 | preg502b5==1) & ///
		(preg502b1==0 & preg502b2==0 & preg502b3==0) if !mi(preg502b1)
	lab var ino_resid_anim_v3 "Residuos animales - Estricta (no quema/bota/entierra + alguna buena)"

	// Alguna entidad del estado le informó sobre contaminacion de alimentos
	gen ino_info_conta_alim:sino = preg504==1 if !mi(preg504)
	lab var ino_info_conta_alim "Inocuidad - Entidad del estado ha informado sobre contaminación de alimentos"
}

//==============================================================================
// Step 3: Produced Food Handling (Storage and Quality)
//==============================================================================
if `GenVars_Manejo'{
	//--------------------------------------------------------------------------
	// Almacenamiento Correcto — 3 versiones
	//   Buenas: lugar refrigerado (5061), cuarto seguro/ventilado (5063),
	//   Malas:  a la intemperie (5062), en el suelo (5064), sin protección (5066)
	//--------------------------------------------------------------------------
	// v1 (flexible): solo exige al menos 1 buena práctica
	gen ino_alim_prod_v1:sino = (preg5061==1 | preg5063==1) if !mi(preg5061)
	lab var ino_alim_prod_v1 "Almacenamiento - Flexible (solo alguna buena)"

	// v2 (intermedia/original): buenas (al menos una) + evita alguna mala
	gen ino_alim_prod_v2:sino = (preg5061==1 | preg5063==1) & (preg5062==0 | preg5064==0) ///
		if !mi(preg5061)
	lab var ino_alim_prod_v2 "Almacenamiento - Intermedia (alguna buena + evita alguna mala)"

	// v3 (estricta): buenas (al menos una) + evita malas (ambas)
	gen ino_alim_prod_v3:sino = (preg5061==1 | preg5063==1) & (preg5062==0 & preg5064==0) ///
		if !mi(preg5061)
	lab var ino_alim_prod_v3 "Almacenamiento - Estricta (alguna buena + evita malas)"

	// Identificación / Etiquetado
	gen ino_etiq_alim:sino = preg507==1 if !mi(preg507) 
	lab var ino_etiq_alim "Inocuidad - Alimentos producidos identificados/etiquetados para consumo"
 
	// Certificación de Calidad
	gen ino_cert_cal:sino = preg508==1 if !mi(preg508)
	lab var ino_cert_cal "Inocuidad - Alimentos producidos con certificación de calidad"
}

//==============================================================================
// Step 4: Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	keep Codprod22 post ino_*

	order ///
	/* B1. Identificadores                                            */ ///
	Codprod22 post ///
	/* B2. Residuos de cultivos (3 versiones de rigurosidad)          */ ///
	ino_resid_cult_v1 ino_resid_cult_v2 ino_resid_cult_v3 ///
	/* B3. Residuos de animales de crianza (3 versiones)              */ ///
	ino_resid_anim_v1 ino_resid_anim_v2 ino_resid_anim_v3 ///
	/* B4. Información sobre contaminación (entidad del estado)       */ ///
	ino_info_conta_alim ///
	/* B5. Almacenamiento de alimentos producidos (3 versiones)       */ ///
	ino_alim_prod_v1 ino_alim_prod_v2 ino_alim_prod_v3 ///
	/* B6. Etiquetado y certificación de calidad                      */ ///
	ino_etiq_alim ino_cert_cal

	label data "Inocuidad alimentaria: residuos, almacenamiento, etiquetado y certificación (LB y LS) | 6 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 6 bloques. Flujo: identidad -> residuos cultivos -> residuos animales -> información estatal -> almacenamiento alimentos -> etiquetado/certificación.
	note: UNIDAD DE ANÁLISIS: productor × periodo (post 0/1). Identificador único = Codprod22.
	note: SUFIJOS DE VERSIONES — _v1 (Flexible: solo exige alguna buena práctica) | _v2 (Original/Intermedia: alguna buena + no quema/bota; en almacenamiento, alguna buena + evita alguna mala) | _v3 (Estricta: alguna buena + filtros completos). Estas versiones son consumidas por E10_build_composite_bpas.do.

	note: B1 — IDENTIFICADORES (Codprod22, post).
	note: B2 — RESIDUOS DE CULTIVOS: dummies vF/vO/vE para "compostan o entierran" filtrando malas prácticas (queman/botan/dejan).
	note: B3 — RESIDUOS DE ANIMALES: mismo patrón vF/vO/vE para residuos de animales de crianza.
	note: B4 — INFORMACIÓN ESTATAL: alguna entidad del estado les ha informado sobre contaminación de alimentos.
	note: B5 — ALMACENAMIENTO DE ALIMENTOS: dummies vF/vO/vE para almacenar en lugar refrigerado o cuarto seguro/ventilado, evitando intemperie/suelo.
	note: B6 — ETIQUETADO Y CERTIFICACIÓN: alimentos identificados/etiquetados y con certificación de calidad.

	note ino_resid_cult_v1 : ">>> INICIO B2: Residuos de cultivos"
	note ino_resid_anim_v1 : ">>> INICIO B3: Residuos de animales"
	// B4 (1 var) sin nota ancla por punto I
	note ino_alim_prod_v1  : ">>> INICIO B5: Almacenamiento de alimentos"
	note ino_etiq_alim     : ">>> INICIO B6: Etiquetado y certificación"
}

//==============================================================================
// Step 5: Save Final Data
//==============================================================================
if `SaveData'{
	sort Codprod22 post
	compress
	save "`outc5'\\Inocuidad_LByLS", replace
}

log close
