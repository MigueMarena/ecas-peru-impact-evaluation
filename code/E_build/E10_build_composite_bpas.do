//------------------------------------------------------------------------------
// File           : E10_build_composite_bpas.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Genera indicadores compuestos de Buenas Practicas Agricolas
//                  (BPAs) combinando variables construidas en los scripts
//                  12-14. Dos familias de indicadores:
//                    (1) Compuesto propio (implementa_bpa): un unico indicador
//                        final, AND estricto de 4 pilares (produccion,
//                        higiene, almacenamiento, distribucion). Higiene y
//                        almacenamiento se construyen en 3 sub-versiones
//                        intermedias (vF/vO/vE) segun la rigurosidad de la
//                        cadena de inocuidad; el indicador final usa la
//                        version intermedia vO.
//                    (2) Compuesto ENA: pilares agronomico, insumos e
//                        inocuidad, con 3 versiones de agregacion:
//                          vF = Flexible      (>=N de M)
//                          vO = Original ENA  (definiciones del catalogo ENA)
//                          vE = Estricta      (todos los criterios requeridos)
//                        El sub-indicador de inocuidad de cada version ENA
//                        consume su propia variante de la cadena (vF->_v1,
//                        vO->_v2, vE->_v3).
//                  Origen: portado y depurado de
//                  do_calculo_indicadores_PCR_v2.do (Apoyo/Pedidos_Luis).
//                  Correcciones aplicadas:
//                    - Universo OR en missings para pilares con logica OR.
//                    - Verificacion robusta via inlist() para detectar al
//                      menos una variable no-missing en cada grupo bpa_comp_.
//                    - Redefinicion conceptual del pilar de insumos en la
//                      version ENA (no trata "no usar plaguicidas" como BPA).
//                    - Sub-indicador ENA de riego (vF/vO/vE) restringido a la
//                      submuestra con riego tecnificado (riego_tec_prod==1);
//                      los no-tecnificados quedan missing, coherente con el
//                      analisis a nivel de pregunta (G2). El pilar agronomico
//                      se sostiene via suelo (OR tolerante a missings).
// Depends        : (ninguno — solo lee bases ya construidas)
// Input          : Out/4_BDs Fusionadas/Panel_Inicio.dta
//                  Out/5_BDs por grupos de vars/BPAs_CondyNoCond_LByLS.dta
//                  Out/5_BDs por grupos de vars/Inocuidad_LByLS.dta
//                  Out/5_BDs por grupos de vars/Registros_Almacen_LByLS.dta
// Output         : Out/5_BDs por grupos de vars/BPAs_Compuestos_LByLS.dta
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local GenCompPropio		  = 1	// Compuesto propio (prod, higiene, alm, distrib)
	local GenENA_vF			  = 1	// Compuesto ENA - Version Flexible
	local GenENA_vO			  = 1	// Compuesto ENA - Version Original (ENA)
	local GenENA_vE			  = 1	// Compuesto ENA - Version Estricta
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local SaveData			  = 1
}

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create composite
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
cap erase "${ruta_scripts}\E10_build_composite_bpas.log"
log using "${ruta_logs}\E10_build_composite_bpas.log", replace text


	frame change composite

	// Base de identificadores (usar Panel_Inicio solo para Codprod22 post)
	use Codprod22 post using "`outc4'\\Panel_Inicio.dta", clear

	merge 1:1 Codprod22 post using "`outc5'\\BPAs_CondyNoCond_LByLS.dta", ///
		keepus(bpa_*) keep(3) nogen

	merge 1:1 Codprod22 post using "`outc5'\\Inocuidad_LByLS.dta", ///
		keepus(ino_resid_cult* ino_info_conta_alim ino_alim_prod* ///
		       ino_etiq_alim ino_cert_cal) keep(3) nogen

	merge 1:1 Codprod22 post using "`outc5'\\Registros_Almacen_LByLS.dta", ///
		keepus(regis_1-regis_7 tot_cond_min_alm) keep(3) nogen

	// riego_tec_prod (basal, invariante por productor): se usa para restringir
	// los sub-indicadores ENA de riego a la submuestra con riego tecnificado,
	// coherente con el analisis a nivel de pregunta (G2). Los no-tecnificados
	// quedan missing en el sub-indicador de riego (no entran al denominador);
	// el pilar agronomico se sostiene via suelo (OR tolerante a missings).
	// merge m:1 (una fila por productor en la base de linea base); keep(1 3)
	// para no descartar obs sin match (quedarian con riego_tec_prod missing).
	merge m:1 Codprod22 using "`outc5'\\Productor_Predio_LB.dta", ///
		keepus(riego_tec_prod) keep(1 3) nogen

	// Etiqueta general
	cap lab drop sino
	lab def sino 1 "Sí" 0 "No"
}

//******************************************************************************
//******************************************************************************
//
//   PARTE A: COMPUESTO PROPIO
//
//   Estructura:
//     Pilar Produccion     = Suelo OR Riego OR Insumos
//     Pilar Higiene        = Residuos cultivos (v1/v2/v3)
//     Pilar Almacenamiento = Alimento producido OR kardex (v1/v2/v3)
//     Pilar Distribucion   = Trazabilidad OR etiquetado
//     Compuesto            = AND estricto de los 4 pilares
//
//******************************************************************************
//******************************************************************************

//==============================================================================
// Step 2: Compuesto Propio - Pilar Produccion
//==============================================================================
if `GenCompPropio'{

	// Suelo: al menos 1 de 4 practicas (bpa_1-4)
	gen bpa_comp_suelo:sino = (bpa_1==1 | bpa_2==1 | bpa_3==1 | bpa_4==1) ///
		if inlist(1,bpa_1,bpa_2,bpa_3,bpa_4) | inlist(0,bpa_1,bpa_2,bpa_3,bpa_4)
	lab var bpa_comp_suelo "Al menos 1 BPA de suelo (bpa_1-4)"

	// Riego: al menos 1 de 5 practicas (bpa_5-9)
	gen bpa_comp_riego:sino = (bpa_5==1 | bpa_6==1 | bpa_7==1 | bpa_8==1 | bpa_9==1) ///
		if inlist(1,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9) ///
		 | inlist(0,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9)
	lab var bpa_comp_riego "Al menos 1 BPA de riego (bpa_5-9)"

	// Insumos: no usa plaguicidas OR bio-control OR MIP
	// NOTA: la definicion intencionalmente trata "no usar plaguicidas" como
	//       favorable. La version ENA redefine insumos con criterio positivo.
	gen bpa_comp_insumos:sino = (bpa_12==0 | bpa_13==1 | bpa_14==1) ///
		if inlist(1,bpa_12,bpa_13,bpa_14) | inlist(0,bpa_12,bpa_13,bpa_14)
	lab var bpa_comp_insumos "BPA insumos: no plagui. O bio-ctrl O MIP"

	// Pilar agregado (al menos 1 sub-pilar)
	gen bpa_comp_prod:sino = (bpa_comp_suelo==1 | bpa_comp_riego==1 | ///
		bpa_comp_insumos==1) ///
		if inlist(1,bpa_comp_suelo,bpa_comp_riego,bpa_comp_insumos) ///
		 | inlist(0,bpa_comp_suelo,bpa_comp_riego,bpa_comp_insumos)
	lab var bpa_comp_prod "Al menos 1 BPA de produccion"
}

//==============================================================================
// Step 3: Compuesto Propio - Pilar Higiene (3 versiones)
//==============================================================================
if `GenCompPropio'{

	//----------------------------------------------------------------------
	// HIGIENE — 3 versiones intermedias (según definición de ino_resid_cult)
	//   vF: flexible  (solo buenas prácticas)
	//   vO: original  (no quema/bota + buenas prácticas, dejar en campo = ok)
	//   vE: estricta  (no quema/bota/deja + buenas)
	// El indicador final (Step 6) usa solo la versión vO.
	//----------------------------------------------------------------------
	gen bpa_comp_higiene_vF:sino = (ino_resid_cult_v1==1) if !mi(ino_resid_cult_v1)
	lab var bpa_comp_higiene_vF "Higiene - Flexible"

	gen bpa_comp_higiene_vO:sino = (ino_resid_cult_v2==1) if !mi(ino_resid_cult_v2)
	lab var bpa_comp_higiene_vO "Higiene - Original"

	gen bpa_comp_higiene_vE:sino = (ino_resid_cult_v3==1) if !mi(ino_resid_cult_v3)
	lab var bpa_comp_higiene_vE "Higiene - Estricta"
}

//==============================================================================
// Step 4: Compuesto Propio - Pilar Almacenamiento (3 versiones)
//==============================================================================
if `GenCompPropio'{
	
	//----------------------------------------------------------------------
	// ALMACENAMIENTO — 3 versiones intermedias (según definición de
	// ino_alim_prod). Cada versión se combina vía OR con regis_6 (kardex).
	//   vF: flexible  (solo buenas prácticas, sin filtrar malas)
	//   vO: original  (3 buenas + no malas)
	//   vE: estricta  (2 buenas + no malas)
	// El indicador final (Step 6) usa solo la versión vO.
	//----------------------------------------------------------------------
	// FIX: OR logico con universo tolerante a missings (una no-missing basta)
	gen bpa_comp_alm_vF:sino = (ino_alim_prod_v1==1 | regis_6==1) ///
		if inlist(1,ino_alim_prod_v1,regis_6) | inlist(0,ino_alim_prod_v1,regis_6)
	lab var bpa_comp_alm_vF "Almacenamiento - Flexible"

	gen bpa_comp_alm_vO:sino = (ino_alim_prod_v2==1 | regis_6==1) ///
		if inlist(1,ino_alim_prod_v2,regis_6) | inlist(0,ino_alim_prod_v2,regis_6)
	lab var bpa_comp_alm_vO "Almacenamiento - Original"

	gen bpa_comp_alm_vE:sino = (ino_alim_prod_v3==1 | regis_6==1) ///
		if inlist(1,ino_alim_prod_v3,regis_6) | inlist(0,ino_alim_prod_v3,regis_6)
	lab var bpa_comp_alm_vE "Almacenamiento - Estricta"
}

//==============================================================================
// Step 5: Compuesto Propio - Pilar Distribucion
//==============================================================================
if `GenCompPropio'{

	// FIX: OR logico con universo tolerante a missings
	gen bpa_comp_distrib:sino = (regis_7==1 | ino_etiq_alim==1) ///
		if inlist(1,regis_7,ino_etiq_alim) | inlist(0,regis_7,ino_etiq_alim)
	lab var bpa_comp_distrib "Trazabilidad o etiquetado"
}

//==============================================================================
// Step 6: Compuesto Propio - Indicador Compuesto Final
//==============================================================================
// AND estricto entre los 4 pilares. Missings en cualquier pilar -> missing.
// Usa la versión intermedia (vO) de higiene y almacenamiento.
//==============================================================================
if `GenCompPropio'{
	gen implementa_bpa:sino = (bpa_comp_prod==1 & bpa_comp_higiene_vO==1 & ///
		bpa_comp_alm_vO==1 & bpa_comp_distrib==1) ///
		if !mi(bpa_comp_prod, bpa_comp_higiene_vO, bpa_comp_alm_vO, bpa_comp_distrib)
	lab var implementa_bpa "BPAs completas propias"
}

//******************************************************************************
//******************************************************************************
//
//   PARTE B: COMPUESTO ENA - VERSION FLEXIBLE (vF)
//
//   Criterios relajados: "al menos N de M" prácticas; OR entre sub-practica
//   y registro para condicionales. Pilares con OR tolerante a missings.
//
//******************************************************************************
//******************************************************************************

//==============================================================================
// Step 7: Sub-indicadores ENA - VERSION FLEXIBLE (vF)
//==============================================================================
if `GenENA_vF'{

	// Riego: >=2 de 5 practicas (submuestra: riego tecnificado; ver nota Step 1)
	gen bpa_ena_riego_vF:sino = ((bpa_5==1) + (bpa_6==1) + (bpa_7==1) + ///
		(bpa_8==1) + (bpa_9==1)) >= 2 ///
		if (inlist(1,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9) ///
		 | inlist(0,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9)) & riego_tec_prod==1
	lab var bpa_ena_riego_vF "BPA riego (>=2 de 5) - Flexible (submuestra: riego tecnif.)"

	// Suelo: >=2 de 4 practicas
	gen bpa_ena_suelo_vF:sino = ((bpa_1==1) + (bpa_2==1) + (bpa_3==1) + ///
		(bpa_4==1)) >= 2 ///
		if inlist(1,bpa_1,bpa_2,bpa_3,bpa_4) | inlist(0,bpa_1,bpa_2,bpa_3,bpa_4)
	lab var bpa_ena_suelo_vF "BPA suelo (>=2 de 4 practicas) - Flexible"

	// Fert/abono: usa & (registra | recomendado por especialista)
	gen bpa_ena_fert_abo_vF:sino = ((bpa_10==1) | (bpa_11==1)) & ///
		(regis_1==1 | bpa_10_3==1 | bpa_11_3==1) ///
		if !mi(bpa_10) | !mi(bpa_11)
	lab var bpa_ena_fert_abo_vF "BPA fert/abono (usa & (registra|recomendado)) - Flexible"

	// Plaguicidas: usa & (registra | recom) &
	//   (no quimico | (quimico & >=1 practica de manejo))
	gen bpa_ena_plag_vF:sino = (bpa_12==1 & (regis_2==1 | bpa_12_3==1)) & ///
		((bpa_12_4==0) | (bpa_12_4==1 & ///
		((bpa_12_q_1==1) | (bpa_12_q_2==1) | (bpa_12_q_3==1) | ///
		 (bpa_12_q_4==1) | (bpa_12_q_5==1) | (bpa_12_q_6==1)))) ///
		if !mi(bpa_12)
	lab var bpa_ena_plag_vF "BPA plaguicidas (quimico relajado) - Flexible"

	// Control biologico: aplica & (evalua plagas | registra)
	gen bpa_ena_biocontrol_vF:sino = (bpa_13==1 & (bpa_13_1==1 | regis_3==1)) ///
		if !mi(bpa_13)
	lab var bpa_ena_biocontrol_vF "BPA control biologico - Flexible"

	// MIP: aplica & combina metodos
	gen bpa_ena_mip_vF:sino = (bpa_14==1 & bpa_14_1==1) if !mi(bpa_14)
	lab var bpa_ena_mip_vF "BPA MIP - Flexible"
 
	// Inocuidad (Indicador 1 de Producto 1957): AND de ambos grupos (prevención y control)
	// 		Nota: Misma estructura que la versión vO, pero alimentada con la
	// 		definición más flexible de la cadena de inocuidad
	// 		(ino_resid_cult_v1, ino_alim_prod_v1).
	gen bpa_ena_inoc_vF:sino = ((ino_resid_cult_v1==1) | (ino_info_conta_alim==1)) ///
		& ((ino_alim_prod_v1==1) | (ino_etiq_alim==1) | (regis_7==1)) ///
		if !mi(ino_resid_cult_v1, ino_info_conta_alim, ino_alim_prod_v1, ///
		       ino_etiq_alim, regis_7)
	lab var bpa_ena_inoc_vF "Inocuidad (Producto 1957) - Flexible"
}

//==============================================================================
// Step 8: Pilares ENA - VERSION FLEXIBLE (vF)
//==============================================================================
if `GenENA_vF'{

	// Pilar agronomico: riego | suelo
	gen ena_pilar_agro_vF:sino = (bpa_ena_riego_vF==1 | bpa_ena_suelo_vF==1) ///
		if inlist(1,bpa_ena_riego_vF,bpa_ena_suelo_vF) ///
		 | inlist(0,bpa_ena_riego_vF,bpa_ena_suelo_vF)
	lab var ena_pilar_agro_vF "Pilar ENA agronomico - Flexible"

	// Pilar insumos: fert | plag | biocontrol | mip
	gen ena_pilar_insumos_vF:sino = (bpa_ena_fert_abo_vF==1 | bpa_ena_plag_vF==1 | ///
		bpa_ena_biocontrol_vF==1 | bpa_ena_mip_vF==1) ///
		if inlist(1,bpa_ena_fert_abo_vF,bpa_ena_plag_vF,bpa_ena_biocontrol_vF,bpa_ena_mip_vF) ///
		 | inlist(0,bpa_ena_fert_abo_vF,bpa_ena_plag_vF,bpa_ena_biocontrol_vF,bpa_ena_mip_vF)
	lab var ena_pilar_insumos_vF "Pilar ENA insumos - Flexible"

	// Pilar inocuidad vF: pasa-through del sub-indicador (versión flexible)
	gen ena_pilar_inoc_vF:sino = (bpa_ena_inoc_vF==1) if !mi(bpa_ena_inoc_vF)
	lab var ena_pilar_inoc_vF "Pilar ENA inocuidad - Flexible"
}

//==============================================================================
// Step 9: Compuesto ENA - VERSION FLEXIBLE (vF)
//==============================================================================
if `GenENA_vF'{

	gen implementa_bpa_ena_vF:sino = ((ena_pilar_agro_vF==1) + ///
		(ena_pilar_insumos_vF==1) + (ena_pilar_inoc_vF==1)) >= 2 ///
		if !mi(ena_pilar_agro_vF, ena_pilar_insumos_vF, ena_pilar_inoc_vF)
	lab var implementa_bpa_ena_vF "Implementan BPAs ENA (>=2 pilares) - Flexible"
}

//******************************************************************************
//******************************************************************************
//
//   PARTE C: COMPUESTO ENA - VERSION ORIGINAL (vO)
//
//   Definiciones estrictas segun el catalogo ENA:
//     - Riego         (Indicador 2479)
//     - Suelo         (Producto 2486)
//     - Fert/Abono    (Producto 2743)
//     - Plaguicidas   (Producto 2744)
//     - Inocuidad     (5 condiciones divididas en 2 grupos)
//
//******************************************************************************
//******************************************************************************

//==============================================================================
// Step 10: Sub-indicadores ENA - VERSION ORIGINAL (vO)
//==============================================================================
if `GenENA_vO'{

	// Riego (ENA Ind. 2479; submuestra: riego tecnificado; ver nota Step 1):
	//   medir agua & mantenimiento riego & (det. agua necesaria | frec. | analisis)
	gen bpa_ena_riego_vO:sino = (bpa_7==1 & bpa_8==1 & (bpa_5==1 | bpa_6==1 | bpa_9==1)) ///
		if (inlist(1,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9) ///
		 | inlist(0,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9)) & riego_tec_prod==1
	lab var bpa_ena_riego_vO "BPA riego (ENA Ind. 2479) (submuestra: riego tecnif.)"

	// Suelo (ENA Prod. 2486):
	//   analisis suelo & (materia organica | asociar cultivos | surcos contorno)
	gen bpa_ena_suelo_vO:sino = (bpa_1==1 & (bpa_2==1 | bpa_3==1 | bpa_4==1)) ///
		if inlist(1,bpa_1,bpa_2,bpa_3,bpa_4) | inlist(0,bpa_1,bpa_2,bpa_3,bpa_4)
	lab var bpa_ena_suelo_vO "BPA suelo (ENA Prod. 2486)"

	// Fert/abono (ENA Prod. 2743):
	//   (usa abono & recomendado) | (usa fert & recomendado), & registra
	gen _abo_reco_vO 	= (bpa_10==1 & bpa_10_3==1)
	gen _fert_reco_vO 	= (bpa_11==1 & bpa_11_3==1)
	gen bpa_ena_fert_abo_vO:sino = (_abo_reco_vO==1 | _fert_reco_vO==1) & ///
		regis_1==1 if !mi(bpa_10) | !mi(bpa_11) | !mi(regis_1)
	drop _abo_reco_vO _fert_reco_vO
	lab var bpa_ena_fert_abo_vO "BPA fert/abono (ENA Prod. 2743)"

	// Plaguicidas (ENA Prod. 2744):
	//   usa & registra & recomendado &
	//   (no quimico | (quimico & etiqueta & >=2 de 5 practicas manejo))
	gen bpa_ena_plag_vO:sino = (bpa_12==1 & regis_2==1 & bpa_12_3==1) & ///
		((bpa_12_4==0) | (bpa_12_4==1 & bpa_12_q_1==1 & ///
		((bpa_12_q_2==1) + (bpa_12_q_3==1) + (bpa_12_q_4==1) + ///
		 (bpa_12_q_5==1) + (bpa_12_q_6==1)) >= 2)) ///
		if !mi(bpa_12)
	lab var bpa_ena_plag_vO "BPA plaguicidas (ENA Prod. 2744)"

	// Control biologico: aplica & evalua plagas & registra (Adaptado de ENA)
	gen bpa_ena_biocontrol_vO:sino = (bpa_13==1 & bpa_13_1==1 & regis_3==1) ///
		if !mi(bpa_13) & !mi(regis_3)
	lab var bpa_ena_biocontrol_vO "BPA control biologico - Adaptado ENA Original"

	// MIP: aplica & combina metodos (Adaptado de ENA)
	gen bpa_ena_mip_vO:sino = (bpa_14==1 & bpa_14_1==1) if !mi(bpa_14)
	lab var bpa_ena_mip_vO "BPA MIP - Adaptado ENA Original"

	// Inocuidad (Indicador 1 de Producto 1957): AND de ambos grupos (prevención y control)
	// 		Nota: Indicador en versión original con insumos originales 
	// 		(ino_resid_cult_v2, ino_alim_prod_v2)
	gen bpa_ena_inoc_vO:sino = ((ino_resid_cult_v2==1) | (ino_info_conta_alim==1)) ///
		& ((ino_alim_prod_v2==1) | (ino_etiq_alim==1) | (regis_7==1)) ///
		if !mi(ino_resid_cult_v2, ino_info_conta_alim, ino_alim_prod_v2, ///
		       ino_etiq_alim, regis_7)
	lab var bpa_ena_inoc_vO "Inocuidad (Producto 1957) - Adaptado ENA Original"
}

//==============================================================================
// Step 11: Pilares ENA - VERSION ORIGINAL (vO)
//==============================================================================
if `GenENA_vO'{

	// Pilar agronomico: riego | suelo
	gen ena_pilar_agro_vO:sino = (bpa_ena_riego_vO==1 | bpa_ena_suelo_vO==1) ///
		if inlist(1,bpa_ena_riego_vO,bpa_ena_suelo_vO) ///
		 | inlist(0,bpa_ena_riego_vO,bpa_ena_suelo_vO)
	lab var ena_pilar_agro_vO "Pilar ENA agronomico"

	// Pilar insumos: fert | plag | biocontrol | mip
	gen ena_pilar_insumos_vO:sino = (bpa_ena_fert_abo_vO==1 | bpa_ena_plag_vO==1 | ///
		bpa_ena_biocontrol_vO==1 | bpa_ena_mip_vO==1) ///
		if inlist(1,bpa_ena_fert_abo_vO,bpa_ena_plag_vO,bpa_ena_biocontrol_vO,bpa_ena_mip_vO) ///
		 | inlist(0,bpa_ena_fert_abo_vO,bpa_ena_plag_vO,bpa_ena_biocontrol_vO,bpa_ena_mip_vO)
	lab var ena_pilar_insumos_vO "Pilar ENA insumos"

	// Pilar inocuidad: inocuidad (Producto 1957)
	gen ena_pilar_inoc_vO:sino = (bpa_ena_inoc_vO==1) if !mi(bpa_ena_inoc_vO)
	lab var ena_pilar_inoc_vO "Pilar ENA inocuidad"
}

//==============================================================================
// Step 12: Compuesto ENA - VERSION ORIGINAL (vO)
//==============================================================================
if `GenENA_vO'{

	gen implementa_bpa_ena_vO:sino = ((ena_pilar_agro_vO==1) + ///
		(ena_pilar_insumos_vO==1) + (ena_pilar_inoc_vO==1)) >= 2 ///
		if !mi(ena_pilar_agro_vO, ena_pilar_insumos_vO, ena_pilar_inoc_vO)
	lab var implementa_bpa_ena_vO "Implementan BPAs ENA (>=2 pilares) - Original"
}

//******************************************************************************
//******************************************************************************
//
//   PARTE D: COMPUESTO ENA - VERSION ESTRICTA (vE)
//
//   Todos los criterios requeridos (AND) dentro de cada sub-indicador.
//   Mas exigente que vO: exige todas las sub-practicas de cada bateria.
//
//******************************************************************************
//******************************************************************************

//==============================================================================
// Step 13: Sub-indicadores ENA vE
//==============================================================================
if `GenENA_vE'{

	// Riego: TODAS las 5 practicas (submuestra: riego tecnificado; ver nota Step 1)
	gen bpa_ena_riego_vE:sino = (bpa_5==1 & bpa_6==1 & bpa_7==1 & bpa_8==1 & bpa_9==1) ///
		if (inlist(1,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9) ///
		 | inlist(0,bpa_5,bpa_6,bpa_7,bpa_8,bpa_9)) & riego_tec_prod==1
	lab var bpa_ena_riego_vE "BPA riego - Estricto (todas las 5) (submuestra: riego tecnif.)"

	// Suelo: TODAS las 4 practicas
	gen bpa_ena_suelo_vE:sino = (bpa_1==1 & bpa_2==1 & bpa_3==1 & bpa_4==1) ///
		if inlist(1,bpa_1,bpa_2,bpa_3,bpa_4) | inlist(0,bpa_1,bpa_2,bpa_3,bpa_4)
	lab var bpa_ena_suelo_vE "BPA suelo - Estricto (todas las 4 practicas)"

	// Fert/abono: usa (ambos) & recomendado & registra & dosis & almacen
	gen bpa_ena_fert_abo_vE:sino = (bpa_10==1 & bpa_10_1==1 & bpa_10_2==1 & ///
		bpa_10_3==1 & bpa_10_4==1 & bpa_10_5==1) & ///
		(bpa_11==1 & bpa_11_1==1 & bpa_11_2==1 & ///
		 bpa_11_3==1 & bpa_11_4==1 & bpa_11_5==1) & ///
		regis_1==1 ///
		if !mi(bpa_10) | !mi(bpa_11) | !mi(regis_1)
	lab var bpa_ena_fert_abo_vE "BPA fert/abono - Estricto (todas las practicas)"

	// Plaguicidas: usa & registra & recomendado &
	//   (no quimico | (quimico & etiqueta & TODAS las 5 practicas manejo))
	gen bpa_ena_plag_vE:sino = (bpa_12==1 & regis_2==1 & bpa_12_1==1 & ///
		bpa_12_2==1 & bpa_12_3==1) & ///
		((bpa_12_4==0) | (bpa_12_4==1 & bpa_12_q_1==1 & bpa_12_q_2==1 & ///
		 bpa_12_q_3==1 & bpa_12_q_4==1 & bpa_12_q_5==1 & bpa_12_q_6==1 & ///
		 bpa_12_q_7==1 & bpa_12_q_71==1)) ///
		if !mi(bpa_12)
	lab var bpa_ena_plag_vE "BPA plaguicidas - Estricto (todas las practicas)"

	// Control biologico: aplica & evalua & registra (AND estricto)
	gen bpa_ena_biocontrol_vE:sino = (bpa_13==1 & bpa_13_1==1 & regis_3==1) ///
		if !mi(bpa_13)
	lab var bpa_ena_biocontrol_vE "BPA control biologico - Estricto"

	// MIP: aplica & combina metodos (idem vO — no hay mas sub-practicas)
	gen bpa_ena_mip_vE:sino = (bpa_14==1 & bpa_14_1==1) if !mi(bpa_14)
	lab var bpa_ena_mip_vE "BPA MIP - Estricto"

	// Inocuidad (Indicador 1 de Producto 1957): AND de ambos grupos (prevención y control)
	// 		Nota: Mismo indicador que en versión original pero con requisito de 
	// 		insumos	más estrictos (ino_resid_cult_v3, ino_alim_prod_v3)
	gen bpa_ena_inoc_vE:sino = ((ino_resid_cult_v3==1) | (ino_info_conta_alim==1)) ///
		& ((ino_alim_prod_v3==1) | (ino_etiq_alim==1) | (regis_7==1)) ///
		if !mi(ino_resid_cult_v3, ino_info_conta_alim, ino_alim_prod_v3, ///
		       ino_etiq_alim, regis_7)
	lab var bpa_ena_inoc_vE "Inocuidad (Producto 1957) - Estricto"
}

//==============================================================================
// Step 14: Pilares ENA vE
//==============================================================================
if `GenENA_vE'{

	// Pilar agronomico vE: riego | suelo
	gen ena_pilar_agro_vE:sino = (bpa_ena_riego_vE==1 | bpa_ena_suelo_vE==1) ///
		if inlist(1,bpa_ena_riego_vE,bpa_ena_suelo_vE) ///
		 | inlist(0,bpa_ena_riego_vE,bpa_ena_suelo_vE)
	lab var ena_pilar_agro_vE "Pilar ENA agronomico - Estricto"

	// Pilar insumos vE: fert | plag | biocontrol | mip
	gen ena_pilar_insumos_vE:sino = (bpa_ena_fert_abo_vE==1 | bpa_ena_plag_vE==1 | ///
		bpa_ena_biocontrol_vE==1 | bpa_ena_mip_vE==1) ///
		if inlist(1,bpa_ena_fert_abo_vE,bpa_ena_plag_vE,bpa_ena_biocontrol_vE,bpa_ena_mip_vE) ///
		 | inlist(0,bpa_ena_fert_abo_vE,bpa_ena_plag_vE,bpa_ena_biocontrol_vE,bpa_ena_mip_vE)
	lab var ena_pilar_insumos_vE "Pilar ENA insumos - Estricto"

	// Pilar inocuidad vE: inocuidad (Producto 1957 v3)
	gen ena_pilar_inoc_vE:sino = (bpa_ena_inoc_vE==1) if !mi(bpa_ena_inoc_vE)
	lab var ena_pilar_inoc_vE "Pilar ENA inocuidad - Estricto"
}

//==============================================================================
// Step 15: Compuesto ENA vE
//==============================================================================
if `GenENA_vE'{

	gen implementa_bpa_ena_vE:sino = ((ena_pilar_agro_vE==1) + ///
		(ena_pilar_insumos_vE==1) + (ena_pilar_inoc_vE==1)) >= 2 ///
		if !mi(ena_pilar_agro_vE, ena_pilar_insumos_vE, ena_pilar_inoc_vE)
	lab var implementa_bpa_ena_vE "Implementan BPAs ENA (>=2 pilares) - Estricto"
}

//==============================================================================
// Step 16: Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	keep Codprod22 post bpa_comp_* implementa_bpa* ///
	     bpa_ena_* ena_pilar_*

	order ///
	/* B1. Identificadores                                              */ ///
	Codprod22 post ///
	/* B2. Compuesto Propio: pilares y agregado final                   */ ///
	bpa_comp_suelo bpa_comp_riego bpa_comp_insumos bpa_comp_prod ///
	bpa_comp_higiene_vF bpa_comp_higiene_vO bpa_comp_higiene_vE ///
	bpa_comp_alm_vF bpa_comp_alm_vO bpa_comp_alm_vE ///
	bpa_comp_distrib ///
	implementa_bpa ///
	/* B3. Compuesto ENA Flexible (vF): sub-indicadores, pilares, total */ ///
	bpa_ena_riego_vF bpa_ena_suelo_vF bpa_ena_fert_abo_vF bpa_ena_plag_vF ///
	bpa_ena_biocontrol_vF bpa_ena_mip_vF bpa_ena_inoc_vF ///
	ena_pilar_agro_vF ena_pilar_insumos_vF ena_pilar_inoc_vF ///
	implementa_bpa_ena_vF ///
	/* B4. Compuesto ENA Original (vO): sub-indicadores, pilares, total */ ///
	bpa_ena_riego_vO bpa_ena_suelo_vO bpa_ena_fert_abo_vO bpa_ena_plag_vO ///
	bpa_ena_biocontrol_vO bpa_ena_mip_vO bpa_ena_inoc_vO ///
	ena_pilar_agro_vO ena_pilar_insumos_vO ena_pilar_inoc_vO ///
	implementa_bpa_ena_vO ///
	/* B5. Compuesto ENA Estricta (vE): sub-indicadores, pilares, total */ ///
	bpa_ena_riego_vE bpa_ena_suelo_vE bpa_ena_fert_abo_vE bpa_ena_plag_vE ///
	bpa_ena_biocontrol_vE bpa_ena_mip_vE bpa_ena_inoc_vE ///
	ena_pilar_agro_vE ena_pilar_insumos_vE ena_pilar_inoc_vE ///
	implementa_bpa_ena_vE

	label data "Indicadores compuestos de BPAs (propio + ENA vF/vO/vE) | 5 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 5 bloques. Flujo: identidad -> compuesto propio (4 pilares + final) -> ENA Flexible -> ENA Original -> ENA Estricta. Cada bloque ENA contiene sub-indicadores -> pilares -> indicador final.
	note: UNIDAD DE ANÁLISIS: productor × periodo (post 0/1). Identificador único = Codprod22.
	note: PREFIJOS — bpa_comp_*: subindicadores y pilares del compuesto propio | implementa_bpa: indicador final del compuesto propio (AND estricto de 4 pilares; usa higiene_vO y alm_vO) | bpa_ena_*_v[FOE]: subindicadores ENA por versión | ena_pilar_*_v[FOE]: pilares ENA (agro, insumos, inocuidad) | implementa_bpa_ena_v[FOE]: indicador final ENA por versión (>=2 de 3 pilares).
	note: VERSIONES vF/vO/vE — Flexible (>=N de M y OR amplios) | Original (catálogo ENA: Ind. 2479 riego, Prod. 2486 suelo, 2743 fert/abono, 2744 plaguicidas; Ind. 1957 inocuidad) | Estricta (AND de todas las sub-prácticas). El sub-indicador de inocuidad de cada versión consume su propia variante de la cadena (vF→_v1, vO→_v2, vE→_v3).
	note: RIEGO (submuestra) — Los sub-indicadores bpa_ena_riego_v[FOE] se calculan SOLO sobre productores con riego tecnificado en la parcela principal (riego_tec_prod==1, basal); los no-tecnificados quedan missing (no entran al denominador), coherente con el análisis a nivel de pregunta (G2). El pilar agronómico (riego OR suelo) y el compuesto final (>=2 de 3 pilares) se sostienen vía suelo para los no-tecnificados gracias al OR tolerante a missings.
	note: ORIGEN — portado y depurado de do_calculo_indicadores_PCR_v2.do (Apoyo/Pedidos_Luis); ver encabezado del script para correcciones aplicadas.

	note: B1 — IDENTIFICADORES (Codprod22, post).
	note: B2 — COMPUESTO PROPIO: 4 pilares (Producción, Higiene, Almacenamiento, Distribución) y el indicador final implementa_bpa. Higiene y Almacenamiento se construyen en 3 sub-versiones intermedias (vF/vO/vE); el indicador final usa vO.
	note: B3 — COMPUESTO ENA FLEXIBLE (vF): 7 sub-indicadores -> 3 pilares -> indicador final (>=2 de 3 pilares). Inocuidad usa la cadena _v1.
	note: B4 — COMPUESTO ENA ORIGINAL (vO): mismo flujo que B3 pero con definiciones del catálogo ENA. Inocuidad usa la cadena _v2.
	note: B5 — COMPUESTO ENA ESTRICTA (vE): AND estricto de todas las sub-prácticas en cada sub-indicador. Inocuidad usa la cadena _v3.

	note bpa_comp_suelo    : ">>> INICIO B2: Compuesto Propio"
	note bpa_ena_riego_vF  : ">>> INICIO B3: Compuesto ENA Flexible (vF)"
	note bpa_ena_riego_vO  : ">>> INICIO B4: Compuesto ENA Original (vO)"
	note bpa_ena_riego_vE  : ">>> INICIO B5: Compuesto ENA Estricta (vE)"
}

//==============================================================================
// Step 17: Save Final Data
//==============================================================================
if `SaveData'{
	sort Codprod22 post
	compress
	save "`outc5'\\BPAs_Compuestos_LByLS", replace
}

log close
