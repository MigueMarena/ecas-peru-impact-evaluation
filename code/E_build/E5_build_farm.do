//------------------------------------------------------------------------------
// File           : E5_build_farm.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Procesamiento del panel a nivel de predio. Genera variables
//                  estructurales (responsable, tenencia, titulo, riego),
//					costos operativos (mano de obra, insumos, servicios) y
//					márgenes sobre ingreso. El gasto de alquiler agrega tres
//					componentes: dinero (preg107a), bienes (preg107c2) y
//					valorización del pago como % de producción (preg107b ×
//					valor cosecha del predio, traído de E4_build_crops.do).
// Input          : Out/4_.../Panel_Parcelas.dta
//                  Out/5_.../Valor_Produccion_Predio_LByLS.dta
// Output         : Out/5_.../Predio_LByLS.dta (+ LB y LS)
//                  Out/5_.../Productor_Predio_LByLS.dta (+ LB y LS)
//------------------------------------------------------------------------------
version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local GenVarsPred		  = 1
	local GenVarsPredAgr	  = 1
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar (Predios y Productores)
	local SaveData			  = 1
}

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create predios
	frame create productores
}

//==============================================================================
// Step 1:Load Data into Frame
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
cap erase "${ruta_scripts}\E5_build_farm.log"
log using "${ruta_logs}\E5_build_farm.log", replace text


	frame change predios
	use "`outc4'\\Panel_Parcelas.dta", clear
	// 3979 predios (2079 en LB y 1900 en LS)
	compress

	// Traer valor de la producción cosechada del predio (insumo para valorizar
	// el componente de alquiler pagado como % de producción; preg107b)
	merge 1:1 Codprod22 preg101a post using "`outc5'\\Valor_Produccion_Predio_LByLS.dta", ///
		keepusing(vtot_cose_pp) keep(1 3) nogen

	// Identificador único de predio
	sort Codprod22 preg101a post
	egen pp_id = group(Codprod22 preg101a)
	sort pp_id post
	lab var pp_id "Identificador Predio"
}

//==============================================================================
// Step 2: Data Generation and Check Consistency
//==============================================================================
if `GenVarsPred'{
	frame change predios
	
	//--------------------------------------------------------------------------
	// Características Generales del Predio
	//--------------------------------------------------------------------------
	// Características del responsable del predio
	{
		// Miembro del hogar responsable de actividad agrícola en predio
		gen cmh_resp_aagr_pp = preg102 if !mi(preg102)
		lab var cmh_resp_aagr_pp "Código de miembro del hogar responsable de act. agr. en predio/parcela"
		
		// Propietario
		lab def propiet 1 "Propietario" 0 "Otro"
		gen prop_pp:propiet = (preg104==1) if !mi(preg104)
		lab var prop_pp "Propietario del predio/parcela"
		
		// Arrendatario
		lab def arrenda 1 "Arrendatario" 0 "Otro"
		gen arren_pp:arrenda = (preg104==3) if !mi(preg104)
		lab var arren_pp "Arrendatario del predio/parcela"
	}
	
	// Tenencia y Propiedad
	{	
		// Años de tenencia
		gen años_tenen_pp = 2021 - preg105 if post==0
		replace años_tenen_pp = 2022 - preg105 if post==1
		lab var años_tenen_pp "Años de propiedad/tenencia del predio/parcela"

		// Predio con Título Formal
		lab def sino 1 "Sí" 0 "No"	
		gen titu_frml_pp:sino = inrange(preg106, 2, 8) if !mi(preg106)
		lab var titu_frml_pp "Predio/parcela con título registral o equivalente legal formal"
		
		// Gasto alquiler - componentes y total
		// (a) Pagos en dinero (preg107a) + en bienes (preg107c2)
		egen gtot_alq_a_pp = rowtotal(preg107a preg107c2)
		replace gtot_alq_a_pp = . if preg104==3 & preg107a==0 & preg107c2==.
		lab var gtot_alq_a_pp "Gasto Total (S/.) alquiler predio/parcela (dinero + bienes)"

		// (b) Valorización del pago como % de producción (preg107b × valor cosecha
		//     del predio). vtot_cose_pp proviene del script E4_build_crops.do.
		gen double gtot_alq_b_pp = vtot_cose_pp * preg107b / 100 ///
			if !mi(preg107b) & !mi(vtot_cose_pp)
		replace gtot_alq_b_pp = 0 if mi(gtot_alq_b_pp)
		lab var gtot_alq_b_pp "Gasto Total (S/.) alquiler predio/parcela (valor del % de producción)"

		// (c) Total = (a) + (b); missing si arrendatario no reportó ningún monto
		egen double gtot_alq_pp = rowtotal(gtot_alq_a_pp gtot_alq_b_pp)
		replace gtot_alq_pp = . if preg104==3 & preg107a==0 & preg107c2==. & (mi(preg107b) | preg107b==0)
		lab var gtot_alq_pp "Gasto Total (S/.) alquiler predio/parcela (dinero + bienes + % producción)"
	}
	
	// Tipo de Riego
	{
		gen tipo_riego_pp = .
		
		// Secano / Dependencia Exclusiva de la Lluvia
		replace tipo_riego_pp = 0 if ///
			preg108o == "LLUVIA" | preg108o == "LLUVIAS" | preg108o == "LLUVIAS." | ///
			preg108o == "RIEGO POR LA LLUVIA" | preg108o == "RIEGO POR LLUVIA" | ///
			preg108o == "SE RIEGA CON LA LLUVIA" | preg108o == "SOLO CON LLUVIA" | ///
			preg108o == "SOLO LLUVIA" | preg108o == "SU RIEGO SE DA POR MEDIO DE LA LLUVIA" | ///
			preg108o == "LLEGA EL CANAL DE RIEGO PERO NO LO USA" | ///
			preg108o == "AGUA DE LLUVIA Y RIO" | ///
			preg108o == "SI TIENE AGUA, PERO COMO HUBO LLUVIA YA NO REGO LA PARCELA" | ///
			preg108==98

		// Fuentes Naturales Superficiales
		replace tipo_riego_pp = 0 if ///
			preg108o == "MANANTIAL" | preg108o == "RIO" | preg108o == "PUQUIO" | ///
			preg108o == "SEQUIA" | preg108o == "TRAE AGUA DE MANANTIAL CON BALDES" | ///
			preg108o == "RIACHUELO TEORIA Y PEQUEÑOS RIACHUELOS DENTRO DEL FUNDO"

		// Pozos Artesanales / Excavados
		replace tipo_riego_pp = 0 if inlist(preg108o, "POZA", "POZAS", "POZO", "POZOS")
			
		// Riego con Manguera
		replace tipo_riego_pp = 1 if ///
			regexm(preg108o, "MANGUERA") | ///
			preg108o == "INSTALACION DE TUBOS Y MANGUERA S" 
			
		// Riego por Gravedad/Canales
		replace tipo_riego_pp = 2 if inrange(preg108,1,2) | ///
			regexm(preg108o, "CANAL|GRAVEDAD|INUNDACION|EXTENDIDO|TENDIDO")

		// Riego por Bombeo/Motorizado
		replace tipo_riego_pp = 3 if ///
			regexm(preg108o, "BOMBEO|MOTOR|BOMBA|ELECTROBOMBA|TUBULARES")

		// Riego por Aspersión
		replace tipo_riego_pp = 4 if preg108==4 | inlist(preg108o, "SISTEMA DE TUBOS", "TUBERIAS")					
		// Riego por por Goteo
		replace tipo_riego_pp = 5 if preg108==3
		
		lab def trielbl 0 "NT/Fuentes Naturales" 1 "Manguera/Manual" 2 "Gravedad/Canales" ///
						3 "Bombeo" 4 "Aspersión" 5 "Goteo"

		lab val tipo_riego_pp trielbl
		lab var tipo_riego_pp "Tipo de riego del predio/parcela"
	}

	// Riego Tecnificado
	{
		gen riego_tec_pp:sino = (tipo_riego_pp==3 | tipo_riego_pp==4 | tipo_riego_pp==5)
		lab var riego_tec_pp "Riego tecnificado (bombeo, aspersión o goteo) en el predio/parcela"
	}

	// Extensión y uso del Suelo (Hectáreas y Porcentajes)
	{
		// Total Hectáreas
		gen tot_has_pp 	 = preg109a 						if preg109a1==1
		replace tot_has_pp = preg109a/10000 				if preg109a1==2
		replace tot_has_pp = (preg109a * preg109a2e)/10000 	if preg109a1==3
		lab var tot_has_pp "Total de has. del predio/parcela"
		
		// Sembradas
		gen tot_has_semb_pp 	 = preg110a 		if preg109a1==1
		replace tot_has_semb_pp	 = preg110a/10000 	if preg109a1==2
		replace tot_has_semb_pp	 = (preg110a * preg109a2e)/10000 if preg109a1==3
		lab var tot_has_semb_pp	 "Total de has. sembradas/instaladas con cultivo del predio/parcela"
		
		// Barbecho
		gen tot_has_barbe_pp 	 = preg111a 	  if preg109a1==1
		replace tot_has_barbe_pp = preg111a/10000 if preg109a1==2
		replace tot_has_barbe_pp = (preg111a * preg109a2e)/10000 if preg109a1==3
		lab var tot_has_barbe_pp "Total de has. en barbecho/descanso del predio/parcela"

		// % Sembradas
		gen float pct_has_semb_pp = .
		replace pct_has_semb_pp = 0 if tot_has_pp==0 & tot_has_semb_pp==0
		replace pct_has_semb_pp = (tot_has_semb_pp/tot_has_pp)*100 if tot_has_pp>0
		replace pct_has_semb_pp = 100 if pct_has_semb_pp>100
		lab var pct_has_semb_pp "Porcentaje de has. sembradas/instaladas del predio/parcela"

		// % Barbecho
		gen float pct_has_barbe_pp = .
		replace pct_has_barbe_pp = 0 if tot_has_pp==0 & tot_has_barbe_pp==0
		replace pct_has_barbe_pp = (tot_has_barbe_pp/tot_has_pp)*100 if tot_has_pp>0
		replace pct_has_barbe_pp = 100 if pct_has_barbe_pp>100
		lab var pct_has_barbe_pp "Porcentaje de has. en barbecho/descanso del predio/parcela"
	}

	//--------------------------------------------------------------------------
	// Servicios de Asesoría y Plantones
	//--------------------------------------------------------------------------

	// Asesoría Agrícola (General y Plagas)
	{
		// Asesoría General (Abonos, Fert, Riego)
		gen contr_ases_pp_1:sino = preg115a==1
		lab var contr_ases_pp_1 "Contrataron asesoría: abonos, fert., riego o manejo cultivos" 

		gen gtot_ases_pp_1 = 0 
		replace gtot_ases_pp_1 = preg115b if contr_ases_pp_1==1
		lab var gtot_ases_pp_1 "Gasto Total (S/.) asesoría: abono, fert., riego o manejo cultivos"

		// Asesoría Plagas
		gen contr_ases_pp_2:sino = preg115c==1
		lab var contr_ases_pp_2  "Contrataron asesoría(s) en: Combate de plagas"

		gen gtot_ases_pp_2 = 0
		replace gtot_ases_pp_2 = preg115d if contr_ases_pp_2==1
		lab var gtot_ases_pp_2 "Gasto Total (S/.) asesoría combate de plagas"

		// Total de asesorías recibidas (Plagas)
		order preg115e90, a(preg115eo)
		egen tot_ases_pp_2 = rowtotal(preg115e1-preg115e61)
		lab var tot_ases_pp_2 "Total de asesorías combate de plagas"

		// Asesoría Técnica Agrícola y Combate/Control Plagas
		gen ases_tecn_pp = contr_ases_pp_1==1 | contr_ases_pp_2==1
		lab var ases_tecn_pp "Contrataron asesoría técnica agrícola y combate/control plagas"
		
		egen gtot_ases_tecn = rowtotal(gtot_ases_pp_1 gtot_ases_pp_2)
		lab var gtot_ases_tecn "Gasto Total (S/.) asesoría técnica agrícola y combate/control plagas"
		
		drop gtot_ases_pp_*
	}
	
	// Plantones
	{
		gen plantones_pp:sino = (preg115f1_1==1|preg115f1_2==1|preg115f1_3==1|preg115f1_4==1)
		lab var plantones_pp "Predio con plantones"

		egen tot_plantones_pp = rowtotal(preg115f3_*)
		lab var tot_plantones_pp "Total de plantones comprados"

		egen gtot_plantones_pp = rowtotal(preg115f5_*)
		lab var gtot_plantones_pp "Gasto Total (S/.) compra de plantones"
	}

	//--------------------------------------------------------------------------
	// Costos de Mano de Obra (Act. Agrícolas y Control de Plagas)
	//--------------------------------------------------------------------------

	// Corrección de Inconsistencias (Data Cleaning)
	{
		// Actividades Agrícolas General
		replace preg116a1a = 0 if preg116a2a==0
		replace preg116a2a = . if preg116a1a==0
		replace preg116a3a = . if preg116a2a==.

		// Corrección Horas/Jornal vs Pago/Jornal
		gen preg116a2a_cop = . , a(preg116a2a) 
		gen preg116a3a_cop = . , a(preg116a3a)
		replace preg116a2a_cop = preg116a3a if preg116a3a > 15 
		replace preg116a3a_cop = preg116a2a if preg116a3a > 15 & preg116a2a < 15
		replace preg116a2a_cop = . if mi(preg116a3a_cop)
		replace preg116a2a_cop = preg116a2a if preg116a3a <= 15
		replace preg116a3a_cop = preg116a3a if preg116a3a <= 15
		drop preg116a2a preg116a3a 
		rena (preg116a2a_cop preg116a3a_cop) (preg116a2a preg116a3a)
		
		// Topes lógicos horas
		replace preg116a3a = .  if preg116a3a<0
		replace preg116a3a = 12 if preg116a3a>12 & !mi(preg116a3a)
		
		// Tareas
		replace preg116a1b = 0 if preg116a2b==0
		replace preg116a2b = . if preg116a1b==0
		replace preg116a3b = . if preg116a2b==.
		replace preg116a3b = .  if preg116a3b<0
		replace preg116a3b = 12 if preg116a3b>12 & !mi(preg116a3b)
		
		// Actividades Prevención/Control Plagas
		replace preg116b1a = 0 if preg116b2a==0
		replace preg116b2a = . if preg116b1a==0
		replace preg116b3a = . if preg116b2a==.
		replace preg116b3a = .  if preg116b3a<0
		replace preg116b3a = 12 if preg116b3a>12 & !mi(preg116b3a) 
		
		replace preg116b1b = 0 if preg116b2b==0
		replace preg116b2b = . if preg116b1b==0
		replace preg116b3b = . if preg116b2b==.
		replace preg116b3b = .  if preg116b3b<0
		replace preg116b3b = 12 if preg116b3b>12 & !mi(preg116b3b)
	}

	// Variables de Costo MO - Actividades Agrícolas (Tipo A)
	{
		gen jorn_a_pp:sino 	= (preg116a1a>0)
		lab var jorn_a_pp 	"Contrataron jornales para actividad agrícola"

		gen gtot_jorn_a_pp 	= 0
		replace gtot_jorn_a_pp 	= preg116a1a * preg116a2a if jorn_a_pp==1 
		lab var gtot_jorn_a_pp 	"Gasto Total (S/.) jornales actividades agrícolas"

		gen tare_a_pp:sino 	= (preg116a1b>0)
		lab var tare_a_pp 	"Contrataron tareas para actividad agrícola"

		gen gtot_tare_a_pp 	= 0
		replace gtot_tare_a_pp 	= preg116a1b * preg116a2b if tare_a_pp==1
		lab var gtot_tare_a_pp 	"Gasto Total (S/.) tareas actividades agrícolas"

		egen gtot_mo_act_agr 	= rowtotal(gtot_jorn_a_pp gtot_tare_a_pp)
		lab var gtot_mo_act_agr	"Gasto Total (S/.) mano de obra actividades agrícolas"
	}

	// Variables de Costo MO - Prevención Plagas (Tipo B)
	{
		gen jorn_b_pp:sino 	= (preg116b1a>0)
		lab var jorn_b_pp 	"Contrataron jornales para prevención/control plagas"

		gen gtot_jorn_b_pp 	= 0  
		replace gtot_jorn_b_pp 	= preg116b1a * preg116b2a if jorn_b_pp==1
		lab var gtot_jorn_b_pp 	"Gasto Total (S/.) jornales prevención/control plagas"

		gen tare_b_pp:sino 	= (preg116b1b>0)
		lab var tare_b_pp 	"Contrataron tareas para prevención/control plagas"

		gen gtot_tare_b_pp 	= 0
		replace gtot_tare_b_pp 	= preg116b1b * preg116b2b if tare_b_pp==1 
		lab var gtot_tare_b_pp 	"Gasto Total (S/.) tareas prevención/control plagas"
			
		// Sanity Check
		assert preg116a1a * preg116a2a == gtot_jorn_a_pp if !mi(preg116a2a)
		assert preg116a1b * preg116a2b == gtot_tare_a_pp if !mi(preg116a2b)
		assert preg116b1a * preg116b2a == gtot_jorn_b_pp if !mi(preg116b2a)
		assert preg116b1b * preg116b2b == gtot_tare_b_pp if !mi(preg116b2b)

		egen gtot_mo_ctrl_pla 	= rowtotal(gtot_jorn_b_pp gtot_tare_b_pp)
		lab var gtot_mo_ctrl_pla "Gasto Total (S/.) mano de obra control de plagas"
		
		drop gtot_jorn_*_pp gtot_tare_*_pp
	}

	//--------------------------------------------------------------------------
	// Maquinaria y Fuerza Animal
	//--------------------------------------------------------------------------
	
	// Maquinaria
	{
		replace preg116c1 = 0 if preg116c2==0
		replace preg116c2 = . if preg116c1==0
		
		gen byte maq_pp = (preg116c1>0 | preg116c3>0)
		lab var maq_pp "Emplearon maquinaria (propia o alq.)"

		gen gtot_maq_pp = 0
		replace gtot_maq_pp = preg116c1 * preg116c2 if maq_pp==1
		replace gtot_maq_pp = 0 if mi(gtot_maq_pp)	
		lab var gtot_maq_pp "Gasto Total (S/.) alquiler de maquinaria"
	}

	// Fuerza Animal
	{
		replace preg116d1 = 0 	if preg116d2==0
		replace preg116d2 = . 	if preg116d1==0
		
		gen fanim_pp:sino = (preg116d1>0 | preg116d3>0)
		lab var fanim_pp "Emplearon fuerza animal (propia o alq.)"

		gen gtot_fanim_pp = 0 
		replace gtot_fanim_pp = preg116d1 * preg116d2 if fanim_pp==1
		replace gtot_fanim_pp = 0 if mi(gtot_fanim_pp)
		lab var gtot_fanim_pp "Gasto Total (S/.) alquiler de fuerza animal"
	}
	
	//--------------------------------------------------------------------------
	// Costos de Agua y Labor de Riego
	//--------------------------------------------------------------------------

	// Costo Directo de Agua
	{
		egen gtot_agua_riego_pp = rowtotal(preg116ea5c preg116eb5c preg116ec5c)
		lab var gtot_agua_riego_pp "Gasto Total (S/.) agua para riego"
	}

	// Mano de Obra en Labores de Riego
	{
		// Cleaning
		replace preg116f3a = 0 if preg116f3c==0
		replace preg116f3c = . if preg116f3a==0
		replace preg116f4a = 0 if preg116f4c==0
		replace preg116f4c = . if preg116f4a==0

		// Gasto Total
		egen gtot_mo_riego_pp = rowtotal(preg116f1 preg116f2 preg116f3c preg116f4c preg116f5 preg116f6)
		lab var gtot_mo_riego_pp "Gasto Total (S/.) Mano de Obra labores de riego"

		// Desglose por tarea
		gen mo_limp_aceq_pp:sino = (preg116f1>0 & !mi(preg116f1))
		lab var mo_limp_aceq_pp "Emplearon mano de obra para limpieza de acequia regadora"
		
		gen mo_niv_terr_pp:sino = (preg116f2>0 & !mi(preg116f2)) 
		lab var mo_niv_terr_pp 	"Emplearon mano de obra para nivelación de terreno"
		
		gen mo_rega_pp:sino 	= (preg116f3c>0 & !mi(preg116f3c))
		lab var mo_rega_pp 		"Emplearon mano de obra como regadores"
		
		gen mo_reco_pp:sino 	= (preg116f4c>0 & !mi(preg116f4c))
		lab var mo_reco_pp 		"Emplearon mano de obra como recorredores"
		
		gen mo_guard_pp:sino 	= (preg116f5>0 & !mi(preg116f5))
		lab var mo_guard_pp  	"Emplearon mano de obra como guardianes"
		
		gen mo_otr_pp:sino 		= (preg116f6>0 & !mi(preg116f6))
		lab var mo_otr_pp 		"Emplearon mano de obra en otros conceptos"
	}

	//--------------------------------------------------------------------------
	// Insumos y Otros Gastos Agrícolas
	//--------------------------------------------------------------------------
	{
		// Manejo Integrado de Plagas (MIP)
		gen met_mip_pp:sino = ((preg117a>0 & !mi(preg117a)) | (preg117b>0 & !mi(preg117b)))
		lab var met_mip_pp "Emplearon métodos para el manejo integrado de plagas en el predio"

		egen gtot_met_mip_pp = rowtotal(preg117a preg117b)
		lab var gtot_met_mip_pp "Gasto Total (S/.) en métodos de manejo integrado de plagas"
		
		// Transporte
		gen tpte_prod_pp:sino = (preg117c>0 & !mi(preg117c))
		lab var tpte_prod_pp  "Emplearon transporte de insumos/producción en el predio"

		gen gtot_tpte_prod_pp = preg117c if !mi(preg117c)
		lab var gtot_tpte_prod_pp "Gasto Total (S/.) en transporte de insumos/producción"
			
		// Insumos Químicos
		// ==== PLAGUICIDAS ====
		gen plagui_q_pp:sino = ((preg117e>0 & !mi(preg117e)))
		lab var plagui_q_pp "Emplearon plaguicidas (herb., insect., fung.) en el predio"

		gen gtot_plagui_q_pp = preg117e if !mi(preg117e)
		lab var gtot_plagui_q_pp "Gasto Total (S/.) en plaguicidas (herb., insect., fung.) en el predio"
		
		// ==== ABONOS/FERTILIZANTES QUÍMICOS ====
		gen abo_fert_q_pp:sino = (preg117g>0 & !mi(preg117g))
		lab var abo_fert_q_pp "Emplearon abonos/fertilizantes químicos en el predio"

		gen gtot_abo_fert_q_pp = preg117g if !mi(preg117g)
		lab var gtot_abo_fert_q_pp "Gasto Total (S/.) en abonos/fertilizantes químicos en el predio"

		// Insumos Orgánicos
		// ==== ABONOS ORGÁNICOS/NATURALES ====
		gen abo_org_pp:sino = (preg117f>0 & !mi(preg117f))
		lab var abo_org_pp "Emplearon abono orgánico/natural en el predio"

		gen gtot_abo_org_pp = preg117f if !mi(preg117f)
		lab var gtot_abo_org_pp "Gasto Total (S/.) en abono orgánico/natural en el predio"

		// Otros Gastos
		gen gtot_otr_pp:sino = preg117d
		lab var gtot_otr_pp "Gasto Total (S/.) otros conceptos de producción agrícola"
	}

	//--------------------------------------------------------------------------
	// Suma de Costos Finales
	//--------------------------------------------------------------------------
	{
		egen gtot_oper_1_pp = rowtotal(gtot_alq_pp gtot_ases_tecn gtot_plantones_pp ///
									   gtot_mo_act_agr gtot_mo_ctrl_pla gtot_maq_pp ///
									   gtot_fanim_pp gtot_agua_riego_pp gtot_mo_riego_pp ///
									   gtot_met_mip_pp gtot_tpte_prod_pp gtot_plagui_q_pp ///
									   gtot_abo_fert_q_pp gtot_abo_org_pp gtot_otr_pp) , m 
		lab var gtot_oper_1_pp "Gasto Total (S/.) costos operativos predio"							   
		
		egen gtot_oper_2_pp = rowtotal(gtot_alq_pp gtot_ases_tecn gtot_plantones_pp ///
									   	gtot_mo_act_agr gtot_mo_ctrl_pla gtot_maq_pp ///
										gtot_fanim_pp gtot_agua_riego_pp gtot_mo_riego_pp ///
										gtot_met_mip_pp gtot_tpte_prod_pp gtot_otr_pp) , m

		lab var gtot_oper_2_pp "Gasto Total (S/.) costos operativos (excl. insumos)"
	}
}

//==============================================================================
// Step 3: Aggregation: Plot → Producer × Period
//==============================================================================
if `GenVarsPredAgr'{
	// Copiar datos de predios al frame productores
	frame copy predios productores, replace
	frame change productores

	//--------------------------------------------------------------------------
	// Extensión total del productor
	//--------------------------------------------------------------------------
	{
		bys Codprod22 post: egen tot_has_prod = total(tot_has_pp), m 
		lab var tot_has_prod "Total de has. del productor (suma de predios)"

		bys Codprod22 post: egen tot_has_semb_prod = total(tot_has_semb_pp), m 
		lab var tot_has_semb_prod "Total de has. sembradas del productor (suma de predios)"

		bys Codprod22 post: egen tot_has_barbe_prod = total(tot_has_barbe_pp), m
		lab var tot_has_barbe_prod "Total de has. en barbecho del productor (suma de predios)"

		// Número de predios por productor-periodo
		bys Codprod22 post: egen n_predios_prod = count(pp_id)
		lab var n_predios_prod "Número de predios del productor"
	}

	//--------------------------------------------------------------------------
	// Gastos agregados por productor (suma de predios)
	//--------------------------------------------------------------------------
	{
		// Alquiler (total)
		bys Codprod22 post: egen gtot_alq_prod = total(gtot_alq_pp), m
		lab var gtot_alq_prod "Gasto Total (S/.) alquiler predios del productor"
		
		// Alquiler - componente: pago en dinero y bienes 
		bys Codprod22 post: egen gtot_alq_a_prod = total(gtot_alq_a_pp), m
		lab var gtot_alq_a_prod "Gasto Total (S/.) alquiler (dinero + bienes) del productor"
		
		// Alquiler - componente: valorización del pago como % de producción
		bys Codprod22 post: egen gtot_alq_b_prod = total(gtot_alq_b_pp), m
		lab var gtot_alq_b_prod "Gasto Total (S/.) alquiler (valor del % producción) del productor"

		// Asesoría técnica
		bys Codprod22 post: egen gtot_ases_tecn_prod = total(gtot_ases_tecn), m
		lab var gtot_ases_tecn_prod "Gasto Total (S/.) asesoría técnica del productor"

		// Plantones
		bys Codprod22 post: egen gtot_plantones_prod = total(gtot_plantones_pp), m
		lab var gtot_plantones_prod "Gasto Total (S/.) plantones del productor"

		// MO actividades agrícolas
		bys Codprod22 post: egen gtot_mo_act_agr_prod = total(gtot_mo_act_agr), m
		lab var gtot_mo_act_agr_prod "Gasto Total (S/.) MO actividades agrícolas del productor"

		// MO control de plagas
		bys Codprod22 post: egen gtot_mo_ctrl_pla_prod = total(gtot_mo_ctrl_pla), m
		lab var gtot_mo_ctrl_pla_prod "Gasto Total (S/.) MO control de plagas del productor"

		// Maquinaria
		bys Codprod22 post: egen gtot_maq_prod = total(gtot_maq_pp), m
		lab var gtot_maq_prod "Gasto Total (S/.) maquinaria del productor"

		// Fuerza animal
		bys Codprod22 post: egen gtot_fanim_prod = total(gtot_fanim_pp), m
		lab var gtot_fanim_prod "Gasto Total (S/.) fuerza animal del productor"

		// Agua de riego
		bys Codprod22 post: egen gtot_agua_riego_prod = total(gtot_agua_riego_pp), m
		lab var gtot_agua_riego_prod "Gasto Total (S/.) agua para riego del productor"

		// MO labores de riego
		bys Codprod22 post: egen gtot_mo_riego_prod = total(gtot_mo_riego_pp), m
		lab var gtot_mo_riego_prod "Gasto Total (S/.) MO labores de riego del productor"

		// MIP
		bys Codprod22 post: egen gtot_met_mip_prod = total(gtot_met_mip_pp), m
		lab var gtot_met_mip_prod "Gasto Total (S/.) MIP del productor"

		// Transporte
		bys Codprod22 post: egen gtot_tpte_prod_prod = total(gtot_tpte_prod_pp), m
		lab var gtot_tpte_prod_prod "Gasto Total (S/.) transporte del productor"

		// Insumos químicos (plaguicidas)
		bys Codprod22 post: egen gtot_plagui_q_prod = total(gtot_plagui_q_pp), m
		lab var gtot_plagui_q_prod "Gasto Total (S/.) en plaguicidas (herb., insect., fung.) del productor"

		// Insumos químicos (abonos/fertilizantes)
		bys Codprod22 post: egen gtot_abo_fert_q_prod = total(gtot_abo_fert_q_pp), m
		lab var gtot_abo_fert_q_prod "Gasto Total (S/.) en abonos/fertilizantes químicos del productor"

		// Insumos orgánicos/naturales (abono orgánico/natural)
		bys Codprod22 post: egen gtot_abo_org_prod = total(gtot_abo_org_pp), m
		lab var gtot_abo_org_prod "Gasto Total (S/.) abonos orgánicos/naturales del productor"

		// Otros gastos
		bys Codprod22 post: egen gtot_otr_prod = total(gtot_otr_pp), m
		lab var gtot_otr_prod "Gasto Total (S/.) otros gastos del productor"
	}

	//--------------------------------------------------------------------------
	// Variables del predio principal (preg101a == 1)
	//--------------------------------------------------------------------------
	{
		// Riego en parcela principal
		gen tiene_riego_ppal = (tipo_riego_pp!=0 & !mi(tipo_riego_pp)) if preg101a==1
		bys Codprod22 post: egen tiene_riego_prod = max(tiene_riego_ppal)
		lab var tiene_riego_prod "Parcela principal tiene algún tipo de riego (no NT/fuentes naturales)"
		lab val tiene_riego_prod sino
		drop tiene_riego_ppal

		// Riego tecnificado en parcela principal
		gen riego_tec_ppal = (riego_tec_pp==1) if preg101a==1
		bys Codprod22 post: egen riego_tec_prod = max(riego_tec_ppal)
		lab var riego_tec_prod "Parcela principal tiene riego tecnificado"
		lab val riego_tec_prod sino
		drop riego_tec_ppal

		// Tipo de riego de la parcela principal
		gen tipo_riego_ppal = tipo_riego_pp if preg101a==1
		bys Codprod22 post: egen tipo_riego_prod = max(tipo_riego_ppal)
		lab var tipo_riego_prod "Tipo de riego de la parcela principal"
		lab val tipo_riego_prod trielbl
		drop tipo_riego_ppal

		// Propiedad de la parcela principal
		gen prop_ppal = prop_pp if preg101a==1
		bys Codprod22 post: egen prop_prod = max(prop_ppal)
		lab var prop_prod "Propietario de la parcela principal"
		lab val prop_prod prop
		drop prop_ppal

		// Título formal de la parcela principal
		gen titu_frml_ppal = titu_frml_pp if preg101a==1
		bys Codprod22 post: egen titu_frml_prod = max(titu_frml_ppal)
		lab var titu_frml_prod "Título formal de la parcela principal"
		lab val titu_frml_prod sino
		drop titu_frml_ppal

		// Contrataron asesoría general (parcela principal)
		gen contr_ases_ppal_1 = contr_ases_pp_1 if preg101a==1
		bys Codprod22 post: egen contr_ases_prod_1 = max(contr_ases_ppal_1)
		lab var contr_ases_prod_1 "Contrataron asesoría agrícola en la parcela principal"
		lab val contr_ases_prod_1 sino
		drop contr_ases_ppal_1

		// Contrataron asesoría plagas (parcela principal)
		gen contr_ases_ppal_2 = contr_ases_pp_2 if preg101a==1
		bys Codprod22 post: egen contr_ases_prod_2 = max(contr_ases_ppal_2)
		lab var contr_ases_prod_2 "Contrataron asesoría plagas en la parcela principal"
		lab val contr_ases_prod_2 sino
		drop contr_ases_ppal_2

		// Compraron plantones (parcela principal)
		gen plantones_ppal = plantones_pp if preg101a==1
		bys Codprod22 post: egen plantones_prod = max(plantones_ppal)
		lab var plantones_prod "Compraron plantones en la parcela principal"
		lab val plantones_prod sino
		drop plantones_ppal

		// Maquinaria (parcela principal)
		gen maq_ppal = maq_pp if preg101a==1
		bys Codprod22 post: egen maq_prod = max(maq_ppal)
		lab var maq_prod "Emplearon maquinaria en la parcela principal"
		lab val maq_prod sino
		drop maq_ppal

		// Fuerza animal (parcela principal)
		gen fanim_ppal = fanim_pp if preg101a==1
		bys Codprod22 post: egen fanim_prod = max(fanim_ppal)
		lab var fanim_prod "Emplearon fuerza animal en la parcela principal"
		lab val fanim_prod sino
		drop fanim_ppal

		// MIP (parcela principal)
		gen met_mip_ppal = met_mip_pp if preg101a==1
		bys Codprod22 post: egen met_mip_prod = max(met_mip_ppal)
		lab var met_mip_prod "Emplearon MIP en la parcela principal"
		lab val met_mip_prod sino
		drop met_mip_ppal

		// Plaguicidas químicos (parcela principal)
		gen plagui_q_ppal = plagui_q_pp if preg101a==1
		bys Codprod22 post: egen plagui_q_prod = max(plagui_q_ppal)
		lab var plagui_q_prod "Emplearon plaguicidas (herb., insect., fung.) en la parcela principal"
		lab val plagui_q_prod sino
		drop plagui_q_ppal

		// Abonos/fertilizantes químicos (parcela principal)
		gen abo_fert_q_ppal = abo_fert_q_pp if preg101a==1
		bys Codprod22 post: egen abo_fert_q_prod = max(abo_fert_q_ppal)
		lab var abo_fert_q_prod "Emplearon abonos/fertilizantes químicos en la parcela principal"
		lab val abo_fert_q_prod sino
		drop abo_fert_q_ppal

		// Abono orgánico/natural (parcela principal)
		gen abo_org_ppal = abo_org_pp if preg101a==1
		bys Codprod22 post: egen abo_org_prod = max(abo_org_ppal)
		lab var abo_org_prod "Emplearon abono orgánico/natural en la parcela principal"
		lab val abo_org_prod sino
		drop abo_org_ppal
	}

	//--------------------------------------------------------------------------
	// Experiencia: años del predio más antiguo del productor
	//--------------------------------------------------------------------------
	{
		bys Codprod22 post: egen años_tenen_prod = max(años_tenen_pp)
		lab var años_tenen_prod "Años de tenencia del predio más antiguo (proxy experiencia)"
	}

	//--------------------------------------------------------------------------
	// Colapsar a nivel productor × periodo
	//--------------------------------------------------------------------------
	{
		// Quedarse con una obs por productor-periodo
		bys Codprod22 post: keep if _n==1

		// Recalcular porcentajes y costos operativos post-colapso
		gen float pct_has_semb_prod = .
		replace pct_has_semb_prod = 0 if tot_has_prod==0 & tot_has_semb_prod==0
		replace pct_has_semb_prod = (tot_has_semb_prod/tot_has_prod)*100 if tot_has_prod>0
		replace pct_has_semb_prod = 100 if pct_has_semb_prod>100
		lab var pct_has_semb_prod "Porcentaje de has. sembradas del productor"

		gen float pct_has_barbe_prod = .
		replace pct_has_barbe_prod = 0 if tot_has_prod==0 & tot_has_barbe_prod==0
		replace pct_has_barbe_prod = (tot_has_barbe_prod/tot_has_prod)*100 if tot_has_prod>0
		replace pct_has_barbe_prod = 100 if pct_has_barbe_prod>100
		lab var pct_has_barbe_prod "Porcentaje de has. en barbecho del productor"

		// Costos operativos totales (recalculados desde componentes agregados)
		egen gtot_oper_1_prod = rowtotal(gtot_alq_prod gtot_ases_tecn_prod ///
			gtot_plantones_prod gtot_mo_act_agr_prod gtot_mo_ctrl_pla_prod ///
			gtot_maq_prod gtot_fanim_prod gtot_agua_riego_prod ///
			gtot_mo_riego_prod gtot_met_mip_prod gtot_tpte_prod_prod ///
			gtot_plagui_q_prod gtot_abo_fert_q_prod gtot_abo_org_prod ///
			gtot_otr_prod)
		lab var gtot_oper_1_prod "Gasto Total (S/.) costos operativos del productor"

		egen gtot_oper_2_prod = rowtotal(gtot_alq_prod gtot_ases_tecn_prod ///
			gtot_plantones_prod gtot_mo_act_agr_prod gtot_mo_ctrl_pla_prod ///
			gtot_maq_prod gtot_fanim_prod gtot_agua_riego_prod ///
			gtot_mo_riego_prod gtot_met_mip_prod gtot_tpte_prod_prod ///
			gtot_otr_prod)
		lab var gtot_oper_2_prod "Gasto Total (S/.) costos operativos (excl. insumos) del productor"
	}
}

//==============================================================================
// Step 4: Order, Notes & Label Data (un sub-bloque por base de salida)
//==============================================================================
if `OrderNotesLabelData'{
	//--------------------------------------------------------------------------
	// Base 1: Predio_LByLS (frame "predios", panel pp_id × periodo)
	//--------------------------------------------------------------------------
	frame change predios
	keep pp_id post Codprod22 preg101a prop_pp-gtot_oper_2_pp

	order ///
	/* B1. Identificadores                                       */ ///
	pp_id post Codprod22 preg101a ///
	/* B2. Estructura y tenencia                                 */ ///
	prop_pp arren_pp años_tenen_pp titu_frml_pp ///
	/* B3. Alquiler (componentes y total)                        */ ///
	gtot_alq_a_pp gtot_alq_b_pp gtot_alq_pp ///
	/* B4. Riego (tipo y tecnificado)                            */ ///
	tipo_riego_pp riego_tec_pp ///
	/* B5. Extensión y uso del suelo                             */ ///
	tot_has_pp tot_has_semb_pp tot_has_barbe_pp pct_has_semb_pp pct_has_barbe_pp ///
	/* B6. Asesoría y plantones                                  */ ///
	contr_ases_pp_1 contr_ases_pp_2 tot_ases_pp_2 ases_tecn_pp gtot_ases_tecn ///
	plantones_pp tot_plantones_pp gtot_plantones_pp ///
	/* B7. Mano de obra (act. agrícolas y control de plagas)     */ ///
	jorn_a_pp tare_a_pp gtot_mo_act_agr ///
	jorn_b_pp tare_b_pp gtot_mo_ctrl_pla ///
	/* B8. Maquinaria y fuerza animal                            */ ///
	maq_pp gtot_maq_pp fanim_pp gtot_fanim_pp ///
	/* B9. Agua, MO y labores de riego                           */ ///
	gtot_agua_riego_pp gtot_mo_riego_pp ///
	mo_limp_aceq_pp mo_niv_terr_pp mo_rega_pp mo_reco_pp mo_guard_pp mo_otr_pp ///
	/* B10. Insumos y otros gastos                               */ ///
	met_mip_pp gtot_met_mip_pp tpte_prod_pp gtot_tpte_prod_pp ///
	plagui_q_pp gtot_plagui_q_pp abo_fert_q_pp gtot_abo_fert_q_pp ///
	abo_org_pp gtot_abo_org_pp gtot_otr_pp ///
	/* B11. Costos operativos totales                            */ ///
	gtot_oper_1_pp gtot_oper_2_pp

	label data "Predio: estructura, tenencia, riego, MO, insumos, costos operativos | 11 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 11 bloques. Flujo: identidad -> estructura/tenencia -> alquiler -> riego -> tierras -> asesoría/plantones -> MO -> maquinaria -> riego (operación) -> insumos -> costos totales.
	note: UNIDAD DE ANÁLISIS: predio × periodo (post 0/1). Identificador único = pp_id; predio dentro del productor = preg101a (1 = parcela principal).
	note: SUFIJO _pp en todas las variables denota que están a nivel predio/parcela.
	note: ALQUILER — gtot_alq_pp = gtot_alq_a_pp (dinero+bienes) + gtot_alq_b_pp (% producción × valor cosecha del predio, este último heredado de E4_build_crops.do).
	note: COSTOS OPERATIVOS — gtot_oper_1_pp incluye TODOS los costos (incl. insumos químicos/orgánicos); gtot_oper_2_pp EXCLUYE insumos (para análisis sin contabilizar costos de químicos).

	note: B1 — IDENTIFICADORES (pp_id, post, Codprod22, preg101a).
	note: B2 — ESTRUCTURA Y TENENCIA: propietario/arrendatario, años de tenencia, título formal.
	note: B3 — ALQUILER: dinero + bienes (a), valor del % producción (b), total (a+b).
	note: B4 — RIEGO: tipo (NT/canal/bombeo/aspersión/goteo) y dummy de riego tecnificado.
	note: B5 — EXTENSIÓN Y USO DEL SUELO: hectáreas totales, sembradas y en barbecho (totales y porcentajes).
	note: B6 — ASESORÍA Y PLANTONES: dummies de contratación, totales y gastos.
	note: B7 — MANO DE OBRA: jornales y tareas, en actividades agrícolas y en control de plagas.
	note: B8 — MAQUINARIA Y FUERZA ANIMAL: dummies de uso y gastos.
	note: B9 — AGUA, MO Y LABORES DE RIEGO: gasto en agua, MO total y desglose por tipo de tarea.
	note: B10 — INSUMOS Y OTROS GASTOS: MIP, transporte, plaguicidas químicos, fertilizantes químicos, abono orgánico, otros.
	note: B11 — COSTOS OPERATIVOS TOTALES: total con y sin insumos químicos.

	note pp_id            : ">>> INICIO B1: Identificadores"
	note prop_pp          : ">>> INICIO B2: Estructura y tenencia"
	note gtot_alq_a_pp    : ">>> INICIO B3: Alquiler"
	note tipo_riego_pp    : ">>> INICIO B4: Riego"
	note tot_has_pp       : ">>> INICIO B5: Extensión y uso del suelo"
	note contr_ases_pp_1  : ">>> INICIO B6: Asesoría y plantones"
	note jorn_a_pp        : ">>> INICIO B7: Mano de obra"
	note maq_pp           : ">>> INICIO B8: Maquinaria y fuerza animal"
	note gtot_agua_riego_pp: ">>> INICIO B9: Agua, MO y labores de riego"
	note met_mip_pp       : ">>> INICIO B10: Insumos y otros gastos"
	note gtot_oper_1_pp   : ">>> INICIO B11: Costos operativos totales"

	//--------------------------------------------------------------------------
	// Base 2: Productor_Predio_LByLS (frame "productores", panel productor × periodo)
	//--------------------------------------------------------------------------
	frame change productores
	keep ///
		Codprod22 post n_predios_prod ///
		tot_has_prod tot_has_semb_prod tot_has_barbe_prod ///
		pct_has_semb_prod pct_has_barbe_prod ///
		gtot_alq_prod gtot_alq_a_prod gtot_alq_b_prod gtot_ases_tecn_prod ///
		gtot_plantones_prod gtot_mo_act_agr_prod gtot_mo_ctrl_pla_prod ///
		gtot_maq_prod gtot_fanim_prod gtot_agua_riego_prod gtot_mo_riego_prod ///
		gtot_met_mip_prod gtot_tpte_prod_prod gtot_plagui_q_prod ///
		gtot_abo_fert_q_prod gtot_abo_org_prod gtot_otr_prod ///
		gtot_oper_1_prod gtot_oper_2_prod ///
		tiene_riego_prod riego_tec_prod tipo_riego_prod ///
		prop_prod titu_frml_prod ///
		contr_ases_prod_1 contr_ases_prod_2 plantones_prod ///
		maq_prod fanim_prod met_mip_prod plagui_q_prod abo_fert_q_prod ///
		abo_org_prod años_tenen_prod

	order ///
	/* B1. Identificadores                                       */ ///
	Codprod22 post n_predios_prod ///
	/* B2. Extensión y uso del suelo (agregado)                  */ ///
	tot_has_prod tot_has_semb_prod tot_has_barbe_prod ///
	pct_has_semb_prod pct_has_barbe_prod ///
	/* B3. Gastos por concepto (agregados a nivel productor)     */ ///
	gtot_alq_prod gtot_alq_a_prod gtot_alq_b_prod ///
	gtot_ases_tecn_prod gtot_plantones_prod ///
	gtot_mo_act_agr_prod gtot_mo_ctrl_pla_prod ///
	gtot_maq_prod gtot_fanim_prod ///
	gtot_agua_riego_prod gtot_mo_riego_prod ///
	gtot_met_mip_prod gtot_tpte_prod_prod ///
	gtot_plagui_q_prod gtot_abo_fert_q_prod gtot_abo_org_prod ///
	gtot_otr_prod ///
	/* B4. Costos operativos totales (agregados)                 */ ///
	gtot_oper_1_prod gtot_oper_2_prod ///
	/* B5. Riego de la parcela principal                         */ ///
	tiene_riego_prod riego_tec_prod tipo_riego_prod ///
	/* B6. Propiedad de la parcela principal                     */ ///
	prop_prod titu_frml_prod ///
	/* B7. Prácticas en la parcela principal                     */ ///
	contr_ases_prod_1 contr_ases_prod_2 plantones_prod ///
	maq_prod fanim_prod met_mip_prod ///
	plagui_q_prod abo_fert_q_prod abo_org_prod ///
	/* B8. Experiencia (años del predio más antiguo)             */ ///
	años_tenen_prod

	label data "Productor (suma de predios) y características de parcela principal | 8 bloques temáticos | últ. ord.: $S_DATE"
	capture notes drop _dta

	note: ESTRUCTURA: 8 bloques. Flujo: identidad -> tierras (suma) -> gastos por concepto (suma) -> costos totales (suma) -> riego/propiedad/prácticas en parcela principal -> experiencia.
	note: UNIDAD DE ANÁLISIS: productor × periodo (post 0/1). Identificador único = Codprod22.
	note: SUFIJO _prod denota agregación a nivel productor: variables de tierras y gastos son SUMAS sobre los predios; variables de prácticas son las del predio principal (preg101a==1) propagadas al productor.

	note: B1 — IDENTIFICADORES Y NÚMERO DE PREDIOS (Codprod22, post, n_predios_prod).
	note: B2 — TIERRAS (SUMA): hectáreas totales, sembradas, en barbecho y porcentajes recalculados sobre los totales sumados.
	note: B3 — GASTOS POR CONCEPTO (SUMA): alquiler (a/b/total), asesoría, plantones, MO, maquinaria, fuerza animal, agua/riego, MIP, transporte, insumos químicos/orgánicos, otros.
	note: B4 — COSTOS OPERATIVOS TOTALES (SUMA): con y sin insumos químicos.
	note: B5 — RIEGO PARCELA PRINCIPAL: dummy de tener riego, dummy de riego tecnificado y tipo de riego.
	note: B6 — PROPIEDAD PARCELA PRINCIPAL: dummies de propietario y de título formal.
	note: B7 — PRÁCTICAS PARCELA PRINCIPAL: dummies de asesoría, plantones, maquinaria, fuerza animal, MIP, plaguicidas y abonos químicos/orgánicos.
	note: B8 — EXPERIENCIA: años de tenencia del predio más antiguo del productor (proxy).

	note Codprod22         : ">>> INICIO B1: Identificadores y número de predios"
	note tot_has_prod      : ">>> INICIO B2: Tierras (suma)"
	note gtot_alq_prod     : ">>> INICIO B3: Gastos por concepto (suma)"
	note gtot_oper_1_prod  : ">>> INICIO B4: Costos operativos totales (suma)"
	note tiene_riego_prod  : ">>> INICIO B5: Riego parcela principal"
	note prop_prod         : ">>> INICIO B6: Propiedad parcela principal"
	note contr_ases_prod_1 : ">>> INICIO B7: Prácticas parcela principal"
	// B8 (1 var) sin nota ancla por punto I de la spec
}

//==============================================================================
// Step 5: Save Final Data
//==============================================================================
if `SaveData'{
	// Base a nivel de predio (panel)
	frame change predios
	sort  pp_id post
	compress
	save "`outc5'\\Predio_LByLS", replace

	// Base a nivel de predio (solo linea base)
	preserve
		keep if post==0
		save "`outc5'\\Predio_LB", replace
	restore

	// Base a nivel de predio (solo linea de seguimiento)
	preserve
		keep if post==1
		save "`outc5'\\Predio_LS", replace
	restore

	// Base agregada a nivel de productor × periodo (panel)
	frame change productores
	sort Codprod22 post
	compress
	save "`outc5'\\Productor_Predio_LByLS", replace

	// Base agregada a nivel de productor × periodo (solo linea base)
	preserve
		keep if post==0
		save "`outc5'\\Productor_Predio_LB", replace
	restore

	// Base agregada a nivel de productor × periodo (solo linea de seguimiento)
	preserve
		keep if post==1
		save "`outc5'\\Productor_Predio_LS", replace
	restore
}

log close
