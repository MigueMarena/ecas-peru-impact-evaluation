//------------------------------------------------------------------------------
// File           : E3_build_household.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Genera variables agregadas del hogar en linea base: indice de
//                  sofisticacion de activos agricolas, caracteristicas de vivienda,
//                  servicios basicos, activos del hogar, indice de condiciones de
//                  vida, servicios de extension agraria (SEA), composicion
//                  demografica, e ingresos laborales (dependiente, independiente,
//                  otros) a nivel de hogar y per capita.
// Input          : Out/4_.../Panel_Inicio.dta
//                  Out/4_.../Panel_Personas.dta
// Output         : Out/5_.../Viv_Act_SEA_LB.dta
//                  Out/5_.../Demog_Ing_Hog_LB.dta
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadDataViv		  = 1	// Carga Panel_Inicio (Vivienda/Activos/Extensión)
	local GenVarsViv		  = 1	// Genera vars de vivienda y activos
	local GenVarsSEA		  = 1	// Genera vars de servicios de extensión (SEA)
	local LoadDataPers		  = 1	// Carga Panel_Personas (Demografía/Ingresos)
	local GenVarsDemog		  = 1	// Genera vars demográficas
	local GenVarsIngr		  = 1	// Genera vars de mercado laboral e ingresos
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar (Viv y Pers)
	local SaveAndClean		  = 1	// Guarda Viv_Act_SEA_LB y Demog_Ing_Hog_LB
}

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create vivienda
	frame create personas_hog
}

//==============================================================================
// Step 1: Procesamiento de Vivienda, Activos y SS de Extensión (Panel_Inicio)
//==============================================================================
if `LoadDataViv'{
	frame change vivienda
	
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
cap erase "${ruta_scripts}\E3_build_household.log"
log using "${ruta_logs}\E3_build_household.log", replace text

	use "`outc4'\\Panel_Inicio.dta", clear
	
	// Filtro Linea Base
	keep if post==0 
	drop post
	
	// Etiquetas
	cap lab drop sino
	lab def sino 0 "No" 1 "Sí"
}

if `GenVarsViv'{
	//--------------------------------------------------------------------------
	// Índice de Sofisticación de Activos Agrícolas
	//--------------------------------------------------------------------------
	{
		qui ds preg201a_*, has(type numeric)
		egen tot_act_agr    = rowtotal(`r(varlist)')
		egen tot_act_agr_n1 = rowtotal(preg201a_01 preg201a_02 preg201a_03 preg201a_04 preg201a_05 preg201a_07 preg201a_11)
		egen tot_act_agr_n2 = rowtotal(preg201a_06 preg201a_08 preg201a_09 preg201a_16 preg201a_18)
		egen tot_act_agr_n3 = rowtotal(preg201a_12 preg201a_14)
		egen tot_act_agr_n4 = rowtotal(preg201a_10 preg201a_13 preg201a_15 preg201a_17)
		egen tot_act_agr_n5 = rowtotal(preg201a_19 preg201a_20)
		
		gen  float ilogsact = 1*ln(1+tot_act_agr_n1) + 2*ln(1+tot_act_agr_n2) + ///
				      3*ln(1+tot_act_agr_n3) + 4*ln(1+tot_act_agr_n4) + ///
				      5*ln(1+tot_act_agr_n5) // verificar esto mañana
		format ilogsact %6.2f
		lab var ilogsact "Índice log. de sofisticación de activos agrícolas del hogar"
		drop tot_act_*
	}
	
	//--------------------------------------------------------------------------
	// Características de la Vivienda
	//--------------------------------------------------------------------------
	{
		// Materiales Adecuados
		gen mat_par_ade:sino = preg901==2 | preg901==6 | (preg901o!="BARRO CON PIEDRA" ///
			& preg901o!="CALAMINA" & preg901o!="CARRIZO" & preg901o!="PAJA DE ARROZ CAÑA BRAVA Y BARRO" ///
			& preg901o!="PIEDRA CON BARRO" & preg901o!="PIEDRA Y ADOBE" & preg901o!="PLASTICO" ///
			& preg901o!="TAPIA" & preg901o!="TAPIAL" & preg901o!="TAPIAR" & preg901o!="TRIPLAY" ///
			& preg901o!="TRIPLEY CASA PRE FABRICADA" ///
			& preg901o!="TRIPLEY EN LA PARTE DELANTE Y LADRILLO EN LA PARTE DE ATRAS" ///
			& preg901o!="")
			
		gen mat_tec_ade:sino = inlist(preg902,1,2,3,4) | (preg902o!="CHAPAJA" & preg902o!="HICHO" ///
			& preg902o!="HOJAS DE CAÑA BRAVA CON PALO ACHAHUASCAR" & preg902o!="HUMIRO" ///
			& preg902o!="HUMIRO." & preg902o!="OJA DE OMIRO" ///
			& preg902o!="PAJA" & preg902o!="PAJA (ICHU)" & preg902o!="PAJA O HICH'U" ///
			& preg902o!="QUILLO" & preg902o!="TECHALE" & preg902o!="UMIRO" & preg902o!="")
			
		gen mat_pis_ade:sino = inlist(preg903,2,3,4) | (preg903o!="")
		
		lab var mat_par_ade "Material de paredes de vivienda adecuado"
		lab var mat_tec_ade "Material de techos de vivienda adecuado"
		lab var mat_pis_ade "Material de pisos de vivienda adecuado"

		// Ambientes y Hacinamiento
		gen tot_amb_viv 		= preg904a 
		gen tot_amb_dor_viv 	= preg904b 
		gen float hab_ratio 	= tot_amb_dor_viv/nper if nper!=.
		gen float hab_score 	= min(1,hab_ratio/0.5)
		
		qui summ tot_amb_viv
		gen amb_norm = (tot_amb_viv-r(min))/(r(max)-r(min))

		lab var tot_amb_viv		"Total de ambientes en la vivienda del productor"
		lab var tot_amb_dor_viv	"Total de ambientes usados para dormir en la vivienda del productor"
		lab var hab_ratio 		"Ratio de habitación para dormir por miembro"
		lab var hab_score 		"Fracción de haci. (ratio de hab. para dormir x miembro, normalizado)"
		lab var amb_norm 		"Total de ambientes normalizado"
		
		// Servicios Básicos
		gen acc_agua_viv:sino	  = preg905==1
		gen acc_agua_pot_viv:sino = preg906==1
		gen elec_viv:sino 	  	  = preg908==1
		gen coc_gas_hog:sino 	  = preg910==1
		gen acc_intnet_hog:sino   = (preg9131==1 | preg9132==1) & preg9136==0
		
		gen san_mej_viv:sino 	  = (preg9091==1|preg9092==1|preg9093==1) | (preg909o!="AL AIRE LIBRE" ///
			& preg909o!="CAMPO" & preg909o!="CAMPO LIBRE" & preg909o!="DESAGUE" ///
			& preg909o!="EN CAMPO" & preg909o!="EN EL MONTE" & preg909o!="NO TIENE NINGUNO" ///
			& preg909o!="USAN EL CAMPO ABIERTO")

		lab var acc_agua_viv	  "Vivienda de productor con acceso a agua"
		lab var acc_agua_pot_viv  "Vivienda de productor con acceso a agua potable"
		lab var elec_viv	  	  "Vivienda de productor con acceso a electricidad"
		lab var san_mej_viv	  	  "Vivienda de productor con saneamiento adecuado/mejorado"
		lab var coc_gas_hog	  	  "Hogar de productor cocinan principalmente con gas"
		lab var acc_intnet_hog	  "Hogar de productor con acceso a internet permanente"
	}
	
	//--------------------------------------------------------------------------
	// Activos del Hogar y Riqueza (DAP)
	//--------------------------------------------------------------------------
	{
		// Activos Específicos
		gen tie_radio:sino   = preg9141==1
		gen q_radios	     = preg914b_1
		gen tie_tv:sino	     = (preg9142==1|preg9143==1)
		egen q_tvs 	     	 = rowtotal(preg914b_2 preg914b_3)
		gen tie_lap_tab:sino = (preg9144==1|preg9145==1) 
		egen q_lap_tab	     = rowtotal(preg914b_4 preg914b_5)
		gen tie_dvd:sino     = preg9146==1
		gen tie_maq_coc:sino = preg9147==1
		gen tie_eq_son:sino  = preg9148==1
		gen tie_refr:sino    = preg9149==1
		gen q_refr	     	 = preg914b_9
		gen tie_plan:sino    = (preg91410==1|preg91411==1)
		gen tie_bici:sino    = preg91412==1
		gen q_bici	     	 = preg914b_12
		gen tie_moto:sino    = (preg91413==1|preg91414==1) 
		gen tie_veh_mov:sino = (preg91415==1|preg91416==1)
		gen tie_cel_telf:sino= preg911==1 | preg91417==1
		gen q_cels	     	 = preg914b_17
		gen tie_coc_gas:sino = preg91418==1
		gen q_coc_gas 	     = preg914b_18
		gen veh_mov 	     = tie_moto==1 | tie_veh_mov==1

		// Activos Básicos Normalizados
		egen tot_act_bsc = rowtotal(q_radios q_tvs q_lap_tab q_refr q_bici q_cels q_coc_gas)
		qui summ tot_act_bsc
		gen tot_act_bsc_norm = (tot_act_bsc - r(min)) / (r(max) - r(min))
		lab var tot_act_bsc_norm "Total de activos básicos en el hogar (normalizado)"	
		lab var veh_mov "Poseen vehículo(s) móvil(es) en el hogar"
		
		// Índice Condiciones de Vida
		gen icondvid = mat_par_ade+mat_pis_ade+mat_tec_ade+hab_score+amb_norm+	///
			acc_agua_pot_viv+elec_viv+coc_gas_hog+acc_intnet_hog+san_mej_viv+ 	///
			tot_act_bsc_norm+veh_mov
		lab var icondvid "Índice de condiciones de vida del hogar"
		
		// Riqueza Estimada (DAP)							
		egen riq_act_est_DAP = rowtotal(preg914c*_*)
		lab var riq_act_est_DAP	"Valor de riqueza (en S/.) de activos estimada (DAP)"
		
		xtile dcl_riq_act = riq_act_est_DAP, nq(10)
		lab var dcl_riq_act "Decil de riqueza de activos (DAP)"
		
		xtile qtl_riq_act = riq_act_est_DAP, nq(5)
		lab var qtl_riq_act "Quintil de riqueza de activos (DAP)"
	}

	//--------------------------------------------------------------------------
	// Ingreso por Otros Conceptos
	//--------------------------------------------------------------------------
	{
		egen ianu_otr_hog = rowtotal(preg818a preg818b preg819b preg819c preg821a ///
						preg821b preg822a preg822b preg823a)
		gen  imen_otr_hog = ianu_otr_hog*(1/12)
		drop ianu_otr_hog
		lab var imen_otr_hog "Ingreso prom. mensual del hogar por otros conceptos (transf., alqu., etc.)"
	}
}

if `GenVarsSEA'{
	//--------------------------------------------------------------------------
	// Servicios de Extensión Agraria (SEA 1 - 23)
	//--------------------------------------------------------------------------
	// Automatización de etiquetas para evitar 60 líneas de código repetitivo
	# delimit ;
	local sea_lbls `" "ANÁLISIS DE SUELOS" "TÉCNICAS DE LABRANZA DE SUELOS" 
	"ROTACIÓN DE CULTIVOS" "TÉCNICAS DE MANEJO DE SEMILLAS" 
	"OPERACIÓN Y MANTENIMIENTO DE SISTEMAS DE RIEGO" "SISTEMAS DE RIEGO TECNIFICADO"
	"PRÁCTICAS ADECUADAS DE RIEGO" "USO DE ABONOS Y FERTILIZANTES" "USO DE PLAGUICIDAS"
	"USO DE CONTROL BIOLÓGICO" "MANEJO INTEGRADO DE PLAGAS" 
	"ESTÁNDARES DE CALIDAD DE AGUA PARA RIEGO" "BUENAS PRÁCTICAS AGRÍCOLAS" 
	"PRODUCCIÓN ORGÁNICA" "INSTALACIÓN Y MANEJO DE PASTOS" 
	"ALIMENTACIÓN DE ANIMALES DE CRIANZA" "MEJORAMIENTO GENÉTICO DE ANIMALES"
	"VACUNAS Y MEDICAMENTOS VETERINARIOS" "PRÁCTICAS DE BIOSEGURIDAD" 
	"BUENAS PRÁCTICAS PECUARIAS" "MANIPULACIÓN E HIGIENE DE ALIMENTOS" 
	"ALMACENAMIENTO DE ALIMENTOS" "CONTAMINACIÓN DE ALIMENTOS" "';
	# delimit cr
	local i = 1
	foreach lbl of local sea_lbls {
		gen sea`i':sino = preg602`i' == 1 
		lab var sea`i' "Recibieron capacitación (ult. 3 años) en: `lbl'"
		local i = `i' + 1
	}

	// Dummies Agregadas
	gen cap_suelo = inlist(1, sea1, sea2, sea3, sea4)
	gen cap_riego = inlist(1, sea5, sea6, sea7, sea12)
	gen cap_insum = inlist(1, sea8, sea9, sea10, sea11)
	lab var cap_suelo "Recibió cap. en prct. para minimizar degradación del suelo"
	lab var cap_riego "Recibió cap. en prct. para mejorar el riego"
	lab var cap_insum "Recibió cap. en prct. para mejorar aplicación de insumos"
}

//==============================================================================
// Step 2: Procesamiento de Demografía e Ingresos Laborales (Panel_Personas)
//==============================================================================
if `LoadDataPers'{
	frame change personas_hog
	
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
	use "`outc4'\\Panel_Personas", clear
	
	keep if post==0
	drop post
	drop if Codprod22=="ECA112-AD-4" // Duplicado
}

if `GenVarsDemog'{
	//--------------------------------------------------------------------------
	// Composición del Hogar
	//--------------------------------------------------------------------------
	{
		// Totales y Porcentajes por grupo etario y género
		// Nota: Usamos 'by Codprod22' para generar stats a nivel hogar repetidos en los miembros
		// Miembros Totales
		by Codprod22: egen tot_miem = count(HORD01)
		lab var tot_miem "Total de miembros en el hogar del productor"
		
		// Participación Laboral en Predio
		by Codprod22: egen tot_miem_talp = max(sum(preg006==1))
		by Codprod22: egen float pct_miem_talp = max((tot_miem_talp/tot_miem)*100)
		lab var tot_miem_talp "Total de miembros que ayudaron en labores del predio"
		lab var pct_miem_talp "Porcentaje de miembros que ayudaron en labores del predio"

		// Grupos Etarios
		by Codprod22: egen tot_miem_inf = max(sum(preg003_1 < 6))
		by Codprod22: egen float pct_miem_inf = max((tot_miem_inf/tot_miem)*100)
		lab var tot_miem_inf "Total de miembros en edad infantil (<6 años)"
		lab var pct_miem_inf "Porcentaje de miembros en edad infantil (<6 años)"
		
		by Codprod22: egen tot_miem_niñ = max(sum(preg003_1>= 6 & preg003_1<13))
		by Codprod22: egen float pct_miem_niñ = max((tot_miem_niñ/tot_miem)*100)
		lab var tot_miem_niñ "Total de miembros en edad de niñez (6-12 años)"
		lab var pct_miem_niñ "Porcentaje de miembros en edad de niñez (6-12 años)"
		
		by Codprod22: egen tot_miem_pre = max(sum(preg003_1 >= 13 & preg003_1 < 15))
		by Codprod22: egen float pct_miem_pre = max((tot_miem_pre/tot_miem)*100)
		lab var tot_miem_pre "Total de miembros en edad de preadolescencia (13-14 años)"
		lab var pct_miem_pre "Porcentaje de miembros en edad de preadolescencia (13-14 años)"
		
		by Codprod22: egen tot_miem_ado = max(sum(preg003_1 >= 15 & preg003_1 < 18))
		by Codprod22: egen float pct_miem_ado = max((tot_miem_ado/tot_miem)*100)
		lab var tot_miem_ado "Total de miembros en edad adolescente (15-17 años)"
		lab var pct_miem_ado "Porcentaje de miembros en edad adolescente (15-17 años)"
		
		// Género
		by Codprod22: egen tot_miem_H = max(sum(preg002==1))
		by Codprod22: egen float pct_miem_H = max((tot_miem_H/tot_miem)*100)
		by Codprod22: egen tot_miem_M = max(sum(preg002==2))
		by Codprod22: egen float pct_miem_M = max((tot_miem_M/tot_miem)*100)
		lab var tot_miem_H "Total de miembros hombres"
		lab var pct_miem_H "Porcentaje de miembros hombres"
		lab var tot_miem_M "Total de miembros mujeres"
		lab var pct_miem_M "Porcentaje de miembros mujeres"
		
		// Edad Productiva (15-64) y Dependencia
		by Codprod22: egen tot_miem_H_1564 = max(sum((preg003_1 >= 15 & preg003_1 <= 64) & preg002==1))
		by Codprod22: egen float pct_miem_H_1564 = max((tot_miem_H_1564/tot_miem_H)*100)
		lab var tot_miem_H_1564 "Total de miembros hombres en edad de no dependencia (15-64 años)"
		lab var pct_miem_H_1564 "Porcentaje de miembros hombres en edad de no dependencia (15-64 años)"
		
		by Codprod22: egen tot_miem_M_1564 = max(sum((preg003_1>=15 & preg003_1<= 64) & preg002==2))
		by Codprod22: egen float pct_miem_M_1564 = max((tot_miem_M_1564/tot_miem_M)*100)
		lab var tot_miem_M_1564 "Total de miembros mujeres en edad de no dependencia (15-64 años)"
		lab var pct_miem_M_1564 "Porcentaje de miembros mujeres en edad de no dependencia (15-64 años)"
		
		egen tot_miem_1564 = rowtotal(tot_miem_H_1564 tot_miem_M_1564)
		gen no_miem_1564   = (tot_miem_1564==0)
		lab var tot_miem_1564 	"Total de miembros en edad de no dependencia (15-64 años)"
		lab var no_miem_1564 	"Hogar sin miembros en edad no dependencia"
		
		by Codprod22: egen tot_miem_depen = max(sum(preg003_1<15 | preg003_1>=65))
		gen float tasa_dep = tot_miem_depen/tot_miem_1564 * 100
		lab var tot_miem_depen 	"Total de miembros en edad de dependencia (<15 o >=65 años)"
		lab var tasa_dep "Tasa de dependencia del hogar"
	}
}

if `GenVarsIngr'{
	//--------------------------------------------------------------------------
	// Trabajo Dependiente (Agrícola y No Agrícola)
	//--------------------------------------------------------------------------
	{
		// Contadores de Miembros
		by Codprod22: egen tot_miem_dep_agr = max(sum((preg802_1==1 & preg804_1==1)| ///
								(preg802_2==1 & preg804_2==1)| ///
								(preg802_3==1 & preg804_3==1)))
		by Codprod22: egen float pct_miem_dep_agr = max((tot_miem_dep_agr/tot_miem)*100)
		by Codprod22: egen tot_miem_dep_no_agr = max(sum((preg802_1==1 & preg804_1==0)| ///
								(preg802_2==1 & preg804_2==0)| ///
								(preg802_3==1 & preg804_3==0))) 
		egen tot_miem_dep = rowtotal(tot_miem_dep_agr tot_miem_dep_no_agr)
		lab var tot_miem_dep_agr "Total de miembros con trabajo dependiente agrícola"
		lab var pct_miem_dep_agr "Porcentaje de miembros con trabajo dependiente agrícola"
		lab var tot_miem_dep_no_agr "Total de miembros con trabajo dependiente no agrícola"
		lab var tot_miem_dep "Total de miembros con trabajo dependiente (agrícola + no agrícola)"

		// Cálculo de Meses Trabajados (Imputación)
		forval i=1/3{
			// Agrícola
			egen nmes_dep_agr_`i' = rowtotal(preg805_`i'1-preg805_`i'12) if preg804_`i'==1
			replace nmes_dep_agr_`i' = 12 if nmes_dep_agr_`i'==0 & preg804_`i'==1 
			
			// No Agrícola
			egen nmes_dep_no_agr_`i' = rowtotal(preg805_`i'1-preg805_`i'12) if preg804_`i'==0
			replace nmes_dep_no_agr_`i' = 12 if nmes_dep_no_agr_`i'==0 & preg804_`i'==0
		}
		
		// Cálculo de Ingreso Mensual Anualizado (Dependiente)
		// Lógica: (Ingreso * Factor Frecuencia) * (Meses Trabajados / 12)
		foreach tipo in agr no_agr {
			local cond_tipo = cond("`tipo'"=="agr", "==1", "==0")
			
			forval i=1/3{
				gen imen_dep_`tipo'_`i' = .
				// Diario (1)
				replace imen_dep_`tipo'_`i' = (preg808a_`i'*preg806_`i'*preg805_`i'A)*(nmes_dep_`tipo'_`i'/12) if preg804_`i'`cond_tipo' & preg808b_`i'==1 & !mi(preg808a_`i')
				// Semanal (2)
				replace imen_dep_`tipo'_`i' = (preg808a_`i'*preg805_`i'A)*(nmes_dep_`tipo'_`i'/12) 	if preg804_`i'`cond_tipo' & preg808b_`i'==2 & !mi(preg808a_`i')
				// Quincenal (3)
				replace imen_dep_`tipo'_`i' = (preg808a_`i'*2)*(nmes_dep_`tipo'_`i'/12)	if preg804_`i'`cond_tipo' & preg808b_`i'==3 & !mi(preg808a_`i')
				// Mensual (4)
				replace imen_dep_`tipo'_`i' = (preg808a_`i')*(nmes_dep_`tipo'_`i'/12) if preg804_`i'`cond_tipo' & preg808b_`i'==4 & !mi(preg808a_`i')
				// Trimestral (5)
				replace imen_dep_`tipo'_`i' = (preg808a_`i')*(4/12)*(nmes_dep_`tipo'_`i'/12) if preg804_`i'`cond_tipo' & preg808b_`i'==5 & !mi(preg808a_`i')
				// Semestral (6)
				replace imen_dep_`tipo'_`i' = (preg808a_`i')*(2/12)*(nmes_dep_`tipo'_`i'/12) if preg804_`i'`cond_tipo' & preg808b_`i'==6 & !mi(preg808a_`i')
				// Anual (7)
				replace imen_dep_`tipo'_`i' = (preg808a_`i')*(1/12)*(nmes_dep_`tipo'_`i'/12) if preg804_`i'`cond_tipo' & preg808b_`i'==7 & !mi(preg808a_`i')
			}
			
			egen imen_dep_`tipo' = rowtotal(imen_dep_`tipo'_1-imen_dep_`tipo'_3), m
			drop imen_dep_`tipo'_* nmes_dep_`tipo'_*
			by Codprod22 : egen imen_dep_`tipo'_hog = total(imen_dep_`tipo'), m
		} 
		egen imen_dep_hog = rowtotal(imen_dep_agr_hog imen_dep_no_agr_hog)
		lab var imen_dep_hog "Ingreso prom. men. anualizado total del hogar en trabajo dependiente"
		drop imen_dep_agr_* imen_dep_no_agr_* imen_dep_agr imen_dep_no_agr
	}

	//--------------------------------------------------------------------------
	// Trabajo Independiente
	//--------------------------------------------------------------------------
	{
		// Contadores de Miembros
		by Codprod22: egen tot_miem_indep = max(sum(preg811_1==1|preg811_2==1)) 
		lab var tot_miem_indep "Número total de miembros con trabajo independiente"
		
		// Corrección metodológica: Si ingreso > 10000 se asume anual y se divide entre 12
		forval k=1/2 {
			gen imen_indep_`k' = .
			replace imen_indep_`k' = preg816_`k'*(preg813_`k'/12) if preg816_`k'<=10000
			replace imen_indep_`k' = preg816_`k'*(1/preg813_`k')*(preg813_`k'/12) if preg816_`k'>10000 
		}
		egen imen_indep = rowtotal(imen_indep_1 imen_indep_2)
		by Codprod22: egen imen_indep_hog = total(imen_indep)
		lab var imen_indep_hog  "Ingreso prom. men. anualizado total del hogar en trabajo independiente"
		drop imen_indep_1 imen_indep_2 imen_indep
	}
	
	//--------------------------------------------------------------------------
	// Ingreso Total del Hogar y Per Cápita
	//--------------------------------------------------------------------------
	{
		// Colapsar frame de personas a nivel Productor
		by Codprod22: keep if _n==1
		
		// Traer la variable ingreosos otros
		frlink 1:1 Codprod22, frame(vivienda)
		frget imen_otr_hog, from(vivienda)
		
		// Computar ingresos
		egen imen_hog 		= rowtotal(imen_dep_hog imen_indep_hog imen_otr_hog)
		gen imen_per_cap	= imen_hog/tot_miem
		gen log_imen_per_cap= ln(imen_per_cap)
	
		lab var imen_hog 	     "Ingreso monetario men. anualizado total del hogar"
		lab var imen_per_cap     "Ingreso monetario men. anualizado per cápita del hogar"
		lab var log_imen_per_cap "Logaritmo del ingreso monetario men. anualizado per cápita"
		
		// Quedar con un subconjunto de variables en el frame
		drop vivienda
	}
}

//==============================================================================
// Step 3: Order, Notes & Label Data (un sub-bloque por base de salida)
//==============================================================================
if `OrderNotesLabelData'{
	//--------------------------------------------------------------------------
	// Base 1: Viv_Act_SEA_LB (frame "vivienda")
	//--------------------------------------------------------------------------
	frame change vivienda
	keep Codprod22 ilogsact icondvid *_DAP *_riq_act imen_otr_hog sea* cap_*

	order ///
	/* B1. Identificador                                        */ ///
	Codprod22 ///
	/* B2. Sofisticación de activos agrícolas                   */ ///
	ilogsact ///
	/* B3. Índice de condiciones de vida del hogar              */ ///
	icondvid ///
	/* B4. Riqueza estimada (DAP)                               */ ///
	riq_act_est_DAP dcl_riq_act qtl_riq_act ///
	/* B5. Otros ingresos del hogar (transf., alquileres, etc.) */ ///
	imen_otr_hog ///
	/* B6. Servicios de Extensión Agraria (SEA 1..23)           */ ///
	sea* ///
	/* B7. Capacitaciones agregadas (cap_*)                     */ ///
	cap_*

	label data "Vivienda, activos, riqueza y servicios de extensión agraria (línea base) | 7 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 7 bloques. Flujo: identidad -> activos agrícolas -> condiciones de vida -> riqueza -> otros ingresos -> capacitaciones SEA -> capacitaciones agregadas.
	note: UNIDAD DE ANÁLISIS: hogar productor (LB únicamente). Identificador único = Codprod22.
	note: SUFIJOS / PREFIJOS — _DAP: valor en S/. de activos estimado por Direct Asset Pricing | sea<n>: capacitación recibida en última 3 años (1..23 según catálogo) | cap_<tema>: dummy agregada de haber recibido cap. en algún SEA del tema.

	note: B1 — IDENTIFICADOR (Codprod22).
	note: B2 — SOFISTICACIÓN DE ACTIVOS AGRÍCOLAS: índice log. ponderado por nivel de sofisticación.
	note: B3 — CONDICIONES DE VIDA: índice agregado de materiales, hacinamiento, servicios básicos, activos básicos y vehículos.
	note: B4 — RIQUEZA ESTIMADA (DAP): valor total y posiciones (decil, quintil) en la distribución.
	note: B5 — OTROS INGRESOS DEL HOGAR: transferencias, alquileres y otros (S/. mensuales anualizados).
	note: B6 — SERVICIOS DE EXTENSIÓN AGRARIA: 23 capacitaciones del catálogo (sea1..sea23).
	note: B7 — CAPACITACIONES AGREGADAS: dummies por tema (suelo, riego, insumos).

	note riq_act_est_DAP : ">>> INICIO B4: Riqueza estimada (DAP)"
	note sea1            : ">>> INICIO B6: Servicios de Extensión Agraria"
	note cap_suelo       : ">>> INICIO B7: Capacitaciones agregadas"

	//--------------------------------------------------------------------------
	// Base 2: Demog_Ing_Hog_LB (frame "personas_hog")
	//--------------------------------------------------------------------------
	frame change personas_hog
	// Lista explícita en lugar del rango frágil "tot_miem-log_imen_per_cap"
	keep ///
		Codprod22 ///
		tot_miem tot_miem_talp pct_miem_talp ///
		tot_miem_inf pct_miem_inf tot_miem_niñ pct_miem_niñ ///
		tot_miem_pre pct_miem_pre tot_miem_ado pct_miem_ado ///
		tot_miem_H pct_miem_H tot_miem_M pct_miem_M ///
		tot_miem_H_1564 pct_miem_H_1564 tot_miem_M_1564 pct_miem_M_1564 ///
		tot_miem_1564 no_miem_1564 tot_miem_depen tasa_dep ///
		tot_miem_dep_agr pct_miem_dep_agr tot_miem_dep_no_agr tot_miem_dep ///
		imen_dep_hog tot_miem_indep imen_indep_hog ///
		imen_otr_hog imen_hog imen_per_cap log_imen_per_cap

	order ///
	/* B1. Identificador                                              */ ///
	Codprod22 ///
	/* B2. Tamaño del hogar y participación en labores del predio     */ ///
	tot_miem tot_miem_talp pct_miem_talp ///
	/* B3. Composición etaria                                         */ ///
	tot_miem_inf pct_miem_inf tot_miem_niñ pct_miem_niñ ///
	tot_miem_pre pct_miem_pre tot_miem_ado pct_miem_ado ///
	/* B4. Composición por género                                     */ ///
	tot_miem_H pct_miem_H tot_miem_M pct_miem_M ///
	/* B5. Edad productiva y dependencia                              */ ///
	tot_miem_H_1564 pct_miem_H_1564 tot_miem_M_1564 pct_miem_M_1564 ///
	tot_miem_1564 no_miem_1564 tot_miem_depen tasa_dep ///
	/* B6. Trabajo dependiente (contadores e ingreso)                 */ ///
	tot_miem_dep_agr pct_miem_dep_agr tot_miem_dep_no_agr tot_miem_dep ///
	imen_dep_hog ///
	/* B7. Trabajo independiente (contador e ingreso)                 */ ///
	tot_miem_indep imen_indep_hog ///
	/* B8. Otros ingresos del hogar                                   */ ///
	imen_otr_hog ///
	/* B9. Ingreso total y per cápita                                 */ ///
	imen_hog imen_per_cap log_imen_per_cap

	label data "Demografía e ingresos laborales del hogar (línea base) | 9 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 9 bloques. Flujo: identidad -> tamaño -> composición etaria -> género -> edad productiva -> trabajo dep. -> trabajo indep. -> otros ingresos -> ingreso total y per cápita.
	note: UNIDAD DE ANÁLISIS: hogar productor (LB, una observación por Codprod22 tras colapso keep if _n==1).
	note: SUFIJOS — tot_miem_<grupo>: total de miembros del grupo | pct_miem_<grupo>: porcentaje del total | imen_<tipo>_hog: ingreso mensual anualizado del hogar por tipo (dep, indep, otr).
	note: METODOLOGÍA DE INGRESOS — Trabajo dep.: ingreso × frecuencia × (meses trabajados/12). Trabajo indep.: corrección si reportan >10000 (asumido anual). Otros: rowtotal de transf., alquileres, etc. tomados de Panel_Inicio.

	note: B1 — IDENTIFICADOR (Codprod22).
	note: B2 — TAMAÑO Y LABORES DEL PREDIO: total de miembros y participación en labores agrícolas.
	note: B3 — COMPOSICIÓN ETARIA: infancia (<6), niñez (6-12), preadolescencia (13-14), adolescencia (15-17).
	note: B4 — COMPOSICIÓN POR GÉNERO: hombres y mujeres (totales y porcentajes).
	note: B5 — EDAD PRODUCTIVA Y DEPENDENCIA: 15-64 por género, total productivo, sin productivos, dependientes y tasa de dependencia.
	note: B6 — TRABAJO DEPENDIENTE: contadores agrícola/no agrícola e ingreso mensual anualizado del hogar.
	note: B7 — TRABAJO INDEPENDIENTE: contador e ingreso mensual anualizado del hogar.
	note: B8 — OTROS INGRESOS DEL HOGAR: transferencias, alquileres, etc. (heredado de frame vivienda).
	note: B9 — INGRESO TOTAL Y PER CÁPITA: suma de los 3 tipos, divisible entre miembros, y log.

	note tot_miem        : ">>> INICIO B2: Tamaño y labores del predio"
	note tot_miem_inf    : ">>> INICIO B3: Composición etaria"
	note tot_miem_H      : ">>> INICIO B4: Composición por género"
	note tot_miem_H_1564 : ">>> INICIO B5: Edad productiva y dependencia"
	note tot_miem_dep_agr: ">>> INICIO B6: Trabajo dependiente"
	note tot_miem_indep  : ">>> INICIO B7: Trabajo independiente"
	note imen_hog        : ">>> INICIO B9: Ingreso total y per cápita"
}

//==============================================================================
// Step 4: Save Final Datasets
//==============================================================================
if `SaveAndClean'{
	frame change vivienda
	sort Codprod22
	compress
	save "`outc5'\\Viv_Act_SEA_LB", replace

	frame change personas_hog
	sort Codprod22
	compress
	save "`outc5'\\Demog_Ing_Hog_LB", replace
}

log close
