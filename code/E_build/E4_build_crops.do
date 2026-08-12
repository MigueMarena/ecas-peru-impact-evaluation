//------------------------------------------------------------------------------
// File           : E4_build_crops.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 09/05/2026
// Description    : Procesamiento del panel agricola en dos bases:
//                  (i)  Cultivos_LByLS.dta      (todos los cultivos, sufijo _ppc)
//                  (ii) Cultivo_Pcpal_LByLS.dta (solo cultivo principal, sufijo _culp)
//                  Genera variables de produccion, rendimientos, costos de
//                  insumos (plaguicidas, abonos, fertilizantes), margenes sobre
//                  ingreso y clasificacion de estrategias productivas (Stayers,
//                  Sustitutos, Diversificadores). Incluye winsorizacion de
//                  outliers y deflacion a precios constantes (S/. 2021), esta
//                  ultima integrada on-the-way en cada paso de creacion de var.
//                  monetaria. Tambien genera el valor total de la produccion
//                  cosechada agregada a nivel de predio (insumo para el gasto
//                  de alquiler como % de produccion en E5_build_farm.do).
// Depends        : _utils/outliers_crop_yields.do
//                  _utils/outliers_crop_prices.do
//                  _utils/outliers_pesticide_prices.do
//                  _utils/clean_pesticide_names.do
// Input          : Out/4_.../Panel_Cultivos.dta
//                  Out/6_.../Productor-Producto.dta
// Output         : Out/5_.../Cultivo_Pcpal_LByLS.dta
//                  Out/5_.../Cultivos_LByLS.dta
//                  Out/5_.../Valor_Produccion_Predio_LByLS.dta
//------------------------------------------------------------------------------

version 19.0
clear all

//==============================================================================
// Local Macros (Control Flow)
//==============================================================================
{
	local ResetDoFrames		  = 1
	local LoadData 			  = 1
	local GenVarsProd		  = 1	// Producción, Ventas y Rendimientos Físicos (ingresos deflactados on-the-way)
	local DropDuplicates	  = 1	// Eliminar Duplicados/Colapsar a nivel cultivo
	local Outliers_Rend		  = 1	// Winsorización de rendimientos e ingresos (deflactados on-the-way)
	local ClassifySamples	  = 1 	// Identificación de líneas Stayer y Estrategias
	local GenValorProd		  = 1	// Valor producción cosechada (insumo alquiler %prod)
	local GenVarsPlagas		  = 1	// Eventos adversos y Plagas
	local GenVarsInsm		  = 1	// Plaguicidas y Fertilizantes (gastos deflactados on-the-way)
	local GenMgnIns			  = 1	// Margenes sobre Ingreso (deflactados on-the-way)
	local OrderNotesLabelData = 1	// Ordenar, Crear Notas y Etiquetar Base
	local CleanMainCrops	  = 1	// main_crops: drop vars predio + rename _ppc→_culp
	local SaveAndClean		  = 1
	local varltoimport1 Codprod22 preg101a nomb_prod* preg114b1 nomb_tipo_cult post preg114*
}

//==============================================================================
// Parámetros de Deflación (IPC Peru, Fuente: INEI)
//==============================================================================
// LB: campaña 2020-2021, encuestado aprox. 2021 → IPC promedio Jul-Dic 2021
// LS: campaña 2021-2022, encuestado aprox. 2022 → IPC promedio Jul-Dic 2022
// Para expresar LS en precios de LB: dividir por factor_def (≈ 1.0847)
// Fuentes y valores idénticos a do_calculo_indicadores_PCR.do
scalar ipc_lb     = 98.5399356   // IPC promedio Jul-Dic 2021 (base)
scalar ipc_ls     = 106.8904127  // IPC promedio Jul-Dic 2022
scalar factor_def = ipc_ls / ipc_lb  // Factor inflación LS → precios LB (≈ 1.0847)

//==============================================================================
// Frames Setup
//==============================================================================
if `ResetDoFrames'{
	frames reset
	frame create all_crops
}
//==============================================================================
// Step 1: Load Data & Identify Crops
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
cap erase "${ruta_scripts}\E4_build_crops.log"
log using "${ruta_logs}\E4_build_crops.log", replace text


	frame change all_crops
	use `varltoimport1' using "`outc4'\\Panel_Cultivos.dta", clear
	compress

	// Merge de producto a evaluar
	// El helper GENERA Productor-Producto.dta. Antes no se invocaba desde acá:
	// el archivo existía en disco de una corrida vieja, así que el merge
	// funcionaba en la máquina del autor y fallaba en un clon limpio. Se invoca
	// igual que outliers_pesticide_prices.do más abajo (ver Step de plaguicidas).
	preserve
	qui do "${ruta_utils}\make_producer_product.do"
	restore
	merge m:1 Codprod22 post using "`outc6'\\Productor-Producto.dta", nogen
	order prod_ECA_eval, a(nomb_prod_obj)
	
	// Identificador Único de Línea de Cultivo
	egen ppc_id = group(Codprod22 preg101a preg114b1)
	lab var ppc_id "Identifcador de Linea de Cultivo-Predio"
	
	duplicates tag ppc_id post, gen(dup_ppc_id)
	sort ppc_id post
	order Codprod22 preg101a nomb_prod preg114b1 nomb_tipo_cult post dup_ppc_id
}

//==============================================================================
// Step 2: Generar Variables de Producción y Productividad (Nivel Variedad)
//==============================================================================
if `GenVarsProd'{
	//--------------------------------------------------------------------------
	// Totales de Producción (Siembra, Cosecha, Venta)
	//--------------------------------------------------------------------------
	
	// Superficie y Unidades Instaladas
	{
		// Hectáreas Sembradas
		gen double tot_has_semb_cult_d = preg114d 				 if preg114d1==1 
		replace tot_has_semb_cult_d = preg114d/10000 			 if preg114d1==2 // mt2 a has
		replace tot_has_semb_cult_d = (preg114d*preg114de)/10000 if preg114d1==3 
		bys ppc_id post: egen tot_has_semb_cult_ppc=total(tot_has_semb_cult_d), m
		lab var tot_has_semb_cult_ppc "Total de has. sembradas/instalados con el cultivo"
		
		// Plantas Instaladas (Permanentes)
		gen tot_ud_plnts_d = preg114e
		bys ppc_id post: egen tot_ud_plnts_ppc = total(tot_ud_plnts_d), m 
		lab var tot_ud_plnts_ppc "Total (en ud.) de plantas instaladas para el cultivo"

		// Plantas en Edad Productiva
		gen tot_ud_plnts_eprod_d = 0			if !mi(tot_ud_plnts_ppc)
		replace tot_ud_plnts_eprod_d = preg114f	if !mi(preg114f)
		by  ppc_id post: egen tot_ud_plnts_eprod_ppc = total(tot_ud_plnts_eprod_d), m 
		lab var tot_ud_plnts_eprod_ppc "Total (en ud.) de plantas en edad productiva"

		// Semilla (Transitorios)
		gen tot_kg_sem_d = 0 					if !mi(preg114e1)
		replace tot_kg_sem_d = preg114e1 		if preg114e2==1
		replace tot_kg_sem_d = preg114e1*1000 	if preg114e2==2 // ton a kg
		replace tot_kg_sem_d = preg114e4 		if preg114e2==3 
		by  ppc_id post: egen tot_kg_sem_ppc = total(tot_kg_sem_d), m
		lab var tot_kg_sem_ppc 	"Total (en kg.) de semilla utilizada para el cultivo"
	}

	// Estandarización de Unidades de Medida (Data Cleaning)
	{
		// Homogenizar nombres en preg114go
		replace preg114go = "ARROBAS" 		if regexm(preg114go,"ARROBA")
		replace preg114go = "ATADOS" 		if preg114go=="ATADO"
		replace preg114go = "BANDEJAS" 		if preg114go=="BANDEJA" | preg114go=="BANDEJQ"
		replace preg114go = "BATEAS" 		if preg114go=="BQAEAS"  | preg114go=="VATEAS"
		replace preg114go = "CABEZAS"		if inlist(preg114go,"CABAZA","CABESAS","CABEZA","CAVEZAS")
		replace preg114go = "CAJAS"  		if preg114go=="CAJA"
		replace preg114go = "CAMIONES" 		if preg114go=="CAMIONADA" | preg114go=="CAMIONADAS"
		replace preg114go = "CAMIONETAS" 	if preg114go=="CAMIONETA"
		replace preg114go = "CARGAS" 		if preg114go=="CARGA"
		replace preg114go = "CIENTOS" 		if inlist(preg114go,"CIENTAS","CIENTO")
		replace preg114go = "COSTALES"		if preg114go=="COSTAL"
		replace preg114go = "JABAS" 		if inlist(preg114go,"JAVA","JABA","JABAA","JAV","JAVAS")
		replace preg114go = "MANTAS" 		if preg114go=="MATAS"
		replace preg114go = "MILLARES" 		if preg114go=="MILLAR"
		replace preg114go = "PACAS" 		if preg114go=="PACA"
		replace preg114go = "PLASTIQUERAS" 	if preg114go=="PLASTIQUERA"
		replace preg114go = "QUINTALES" 	if inlist(preg114go,"KINTAL","KINTALES","QUINTAL")
		replace preg114go = "RACIMOS" 		if preg114go=="RACIMO" | preg114go=="RACINO"
		replace preg114go = "SACOS" 		if regexm(preg114go,"^SACO")
		replace preg114go = "TACHOS" 		if preg114go=="TACHO"
		replace preg114go = "TAPABOCAS" 	if preg114go=="TAPABOCA"
		replace preg114go = "TERCIOS" 		if preg114go=="TERCIO"
		replace preg114go = "UNIDADES" 		if preg114go=="UNIDAD" | preg114go=="UNIDADADES"
		
		// Generar moda por tipo de cultivo y unidad 
		bys nomb_tipo_cult preg114go: egen mpreg114ge = mode(preg114ge) if preg114go!="", max
		replace preg114ge = mpreg114ge if preg114ge<=0
		drop mpreg114ge
		
		// Reemplazos manuales
		replace preg114ge = 0.094 if nomb_tipo_cult=="Tangerina" & preg114go=="UNIDADES"
		replace preg114ge = 0.125 if nomb_tipo_cult=="Palto"	 & preg114go=="UNIDADES"
		replace preg114ge = 1     if preg114ge < 0
	}

	// Volúmenes de Cosecha/Venta/Autoconsumo
	{
		// Producción Cosechada
		gen tot_kg_prod_cose_d = preg114g					
		replace tot_kg_prod_cose_d = preg114g * 1000 		if preg114g1==2 
		replace tot_kg_prod_cose_d = preg114g * preg114ge 	if preg114g1==3
		replace tot_kg_prod_cose_d = 0 						if mi(tot_kg_prod_cose_d)
		sort ppc_id post
		by ppc_id post: egen long tot_kg_prod_cose_ppc = total(tot_kg_prod_cose_d) , m
		lab var tot_kg_prod_cose_ppc "Total (en kg.) de producción cosechada del cultivo"
		
		// Ventas Totales
		gen tot_kg_prod_vend_d = preg114h1 
		replace tot_kg_prod_vend_d = preg114h1 * 1000 		if preg114g1==2
		replace tot_kg_prod_vend_d = preg114h1 * preg114ge 	if preg114g1==3
		replace tot_kg_prod_vend_d = 0 						if mi(tot_kg_prod_vend_d)
		by  ppc_id post: egen long tot_kg_prod_vend_ppc = total(tot_kg_prod_vend_d), m
		lab var tot_kg_prod_vend_ppc "Total (en kg.) de producción cosechada vendida del cultivo"
		
		// Ventas: Mercado Nacional
		gen tot_kg_prod_vend_MN_d = preg114k
		replace tot_kg_prod_vend_MN_d = preg114k * 1000      if preg114g1==2 
		replace tot_kg_prod_vend_MN_d = preg114k * preg114ge if preg114g1==3
		replace tot_kg_prod_vend_MN_d = 0		             if mi(tot_kg_prod_vend_MN_d)
		by  ppc_id post: egen long tot_kg_prod_vend_MN_ppc = total(tot_kg_prod_vend_MN_d), m
		lab var tot_kg_prod_vend_MN_ppc "Total (en kg.) de producción cosechada vendida al mercado nacional"

		// Ventas: Mercado Local (dentro de MN)
		gen tot_kg_prod_vend_MN_ML_d 	 = preg114l4
		replace tot_kg_prod_vend_MN_ML_d = preg114l4 * 1000 	 if preg114g1==2
		replace tot_kg_prod_vend_MN_ML_d = preg114l4 * preg114ge if preg114g1==3
		replace tot_kg_prod_vend_MN_ML_d = 0					 if mi(tot_kg_prod_vend_MN_ML_d)
		by  ppc_id post: egen long tot_kg_prod_vend_MN_ML_ppc = total(tot_kg_prod_vend_MN_ML_d), m
		lab var tot_kg_prod_vend_MN_ML_ppc "Total (en kg.) vendida dentro del centro o ferias cercanas"

		// Ventas: Mercado Internacional
		gen tot_kg_prod_vend_MI_d = preg114k1
		replace tot_kg_prod_vend_MI_d = preg114k1 * 1000      	if preg114g1==2 
		replace tot_kg_prod_vend_MI_d = preg114k1 * preg114ge 	if preg114g1==3
		replace tot_kg_prod_vend_MI_d = 0		      			if mi(tot_kg_prod_vend_MI_d)
		by  ppc_id post: egen long tot_kg_prod_vend_MI_ppc = total(tot_kg_prod_vend_MI_d), m
		lab var tot_kg_prod_vend_MI_ppc "Total (en kg.) de producción cosechada vendida al mercado internacional"
		
		// Autoconsumo y otros usos 
		forval i =1/6{
			gen tot_kg_prod_uso_`i'_d = preg114m`i'
			replace tot_kg_prod_uso_`i'_d = preg114m`i' * 1000      	if preg114g1==2 
			replace tot_kg_prod_uso_`i'_d = preg114m`i' * preg114ge 	if preg114g1==3
			replace tot_kg_prod_uso_`i'_d = 0		      				if mi(tot_kg_prod_uso_`i'_d)
			by  ppc_id post: egen long tot_kg_prod_uso_`i'_ppc = total(tot_kg_prod_uso_`i'_d), m
		}
		egen long tot_kg_prod_autoc_ppc = rowtotal(tot_kg_prod_uso_*_ppc)
		lab var tot_kg_prod_autoc_ppc "Total (en kg.) de producción cosechada para autoconsumo u otros usos"
		
		drop *_d tot_kg_prod_uso_*_ppc
	}

	//--------------------------------------------------------------------------
	// Ratios de Productividad/Ventas/Autconsumo
	//--------------------------------------------------------------------------
	{
		// % Plantas Productivas
		gen float pct_plnts_eprod_ppc = (tot_ud_plnts_eprod_ppc/tot_ud_plnts_ppc)*100 if tot_ud_plnts_ppc>0
		replace pct_plnts_eprod_ppc = 100 if pct_plnts_eprod_ppc>100 & !mi(pct_plnts_eprod_ppc)
		lab var pct_plnts_eprod_ppc "Porcentaje de plantas en edad productiva del cultivo"
		
		// % Venta sobre Cosecha
		gen float pct_prod_cose_vend_ppc = (tot_kg_prod_vend_ppc/tot_kg_prod_cose_ppc)*100 if tot_kg_prod_cose_ppc>0
		replace pct_prod_cose_vend_ppc = 100 if tot_kg_prod_vend_ppc>tot_kg_prod_cose_ppc & !mi(pct_prod_cose_vend_ppc)
		lab var pct_prod_cose_vend_ppc "Porcentaje de la producción cosechada vendida del cultivo"

		// % Mercado Nacional
		gen float pct_prod_vend_MN_ppc 	= (tot_kg_prod_vend_MN_ppc/tot_kg_prod_vend_ppc) * 100 if tot_kg_prod_vend_ppc>0
		replace pct_prod_vend_MN_ppc = 100 if pct_prod_vend_MN_ppc>100 & !mi(pct_prod_vend_MN_ppc)
		lab var pct_prod_vend_MN_ppc "Porcentaje de la producción vendida al mercado nacional del cultivo"

		// % Mercado Local
		gen float pct_prod_vend_MN_ML_ppc = (tot_kg_prod_vend_MN_ML_ppc/tot_kg_prod_vend_MN_ppc) * 100 if tot_kg_prod_vend_MN_ppc>0
		replace pct_prod_vend_MN_ML_ppc = 100 if pct_prod_vend_MN_ML_ppc>100 & !mi(pct_prod_vend_MN_ML_ppc)
		lab var pct_prod_vend_MN_ML_ppc "Porcentaje de la producción nacional vendida localmente del cultivo"

		// % Mercado Internacional
		gen float pct_prod_vend_MI_ppc	= (tot_kg_prod_vend_MI_ppc/tot_kg_prod_vend_ppc) * 100 if tot_kg_prod_vend_ppc>0
		replace pct_prod_vend_MI_ppc = 100 if pct_prod_vend_MI_ppc>100 & !mi(pct_prod_vend_MI_ppc) 
		lab var pct_prod_vend_MI_ppc "Porcentaje de la producción vendida al mercado internacional del cultivo"
		
		// % Autoconsumo u otros usos sobre Cosecha
		gen float pct_prod_cose_autoc_ppc = (tot_kg_prod_autoc_ppc/tot_kg_prod_cose_ppc)*100 if tot_kg_prod_cose_ppc>0
		replace pct_prod_cose_autoc_ppc = 100 if tot_kg_prod_autoc_ppc>tot_kg_prod_cose_ppc & !mi(pct_prod_cose_autoc_ppc)
		lab var pct_prod_cose_autoc_ppc "Porcentaje de la producción cosechada para autoconsumo u otro uso del cultivo"
		
		// Rendimientos
		gen float kgxha_semb_ppc = tot_kg_prod_cose_ppc/tot_has_semb_cult_ppc if tot_has_semb_cult_ppc>0
		lab var kgxha_semb_ppc 	"Rendimiento del cultivo (kg. por ha. sembrada)"

		gen float kgx1p_eprod_ppc= tot_kg_prod_cose_ppc/tot_ud_plnts_eprod_ppc if tot_ud_plnts_eprod_ppc>0
		lab var kgx1p_eprod_ppc "Rendimiento de la planta en edad productiva (kg. de cultivo por planta)"

		gen float kgxkg_sem_ppc = tot_kg_prod_cose_ppc/tot_kg_sem_ppc if tot_kg_sem_ppc>0
		lab var kgxkg_sem_ppc 	"Rendimiento de la semilla (kg. de cultivo por kg. de semilla)"
	}
	
	//--------------------------------------------------------------------------
	// Ingresos por Venta (con versiones deflactadas a S/. constantes 2021)
	//--------------------------------------------------------------------------
	{
		by ppc_id post: egen double itot_cult_corr_ppc = total(preg114h2), m
		replace itot_cult_corr_ppc = 0 if tot_kg_prod_vend_ppc==0
		gen double ixkg_ppc = itot_cult_corr_ppc/tot_kg_prod_vend_ppc if ///
			(tot_kg_prod_vend_ppc>0 & !mi(tot_kg_prod_vend_ppc))
		drop itot_cult_corr_ppc
		lab var ixkg_ppc "Ingreso por kg. (en S/.) de venta del cultivo"

		gen itot_ppc	 = tot_kg_prod_vend_ppc * ixkg_ppc
		replace itot_ppc = 0 if tot_kg_prod_vend_ppc==0
		lab var itot_ppc "Ingreso Total (en S/.) de venta del cultivo"

		// Deflactado on-the-way (LB sin ajuste; LS dividido por factor_def)
		foreach var in ixkg_ppc itot_ppc {
			local lbl : var lab `var'
			gen double `var'_def = `var'                       if post == 0
			replace    `var'_def = `var' / scalar(factor_def)  if post == 1
			lab var `var'_def "`lbl' (S/. constantes 2021)"
			order `var'_def, a(`var')
		}
	}
}

//==============================================================================
// Step 3: Eliminar duplicados a nivel productor-predio-cultivo-periodo (colapsar)
//==============================================================================
if `DropDuplicates'{
	sor ppc_id post preg114o1
	by 	ppc_id post: keep if _n==1
	qui count 
	ass `r(N)'==6799
	sort ppc_id post
	drop dup_ppc_id
}

//==============================================================================
// Step 4: Identificación de Estrategias y Submuestras (Impact Evaluation)
//==============================================================================
// Ubicado entre DropDuplicates y Outliers_Rend para que las variables
// identificatorias/clasificatorias del browse final (stayer_line, pp_id,
// tipo_predio) se creen ANTES de las sustantivas y sus capeos/deflactados.
// No depende de las winsorizaciones (verificado: ningún helper de Outliers
// usa stayer_line, pp_id, tipo_predio ni vars intermedias). El sub-bloque
// "Liberar Espacio" original se mantiene al final del Step 5 (Outliers_Rend),
// porque dropea pregs que sí se usan dentro de Outliers.
//==============================================================================
if `ClassifySamples'{
	//--------------------------------------------------------------------------
	// Identificación de "Stayers" (Líneas Presentes en t0 y t1)
	//--------------------------------------------------------------------------
	{
		by ppc_id: gen n_obs_ppc  = _N
		by ppc_id: gen tiene_pre  = (post[1] == 0)
		by ppc_id: gen tiene_post = (post[_N] == 1)
		gen stayer_line = (n_obs_ppc == 2 & tiene_pre & tiene_post)
		label var stayer_line "S1: Línea Stayer (para Fase 2)"
	}

	//--------------------------------------------------------------------------
	// Contadores a Nivel Predio (Entries & Exits)
	//--------------------------------------------------------------------------
	{
		gen exit_only  = (n_obs_ppc == 1 & tiene_pre)  // Cultivo existe en pre, no en post
		gen entry_only = (n_obs_ppc == 1 & tiene_post) // Cultivo existe en post, no en pre

		// Identifcador de predio
		egen pp_id = group(Codprod22 preg101a)
		order pp_id, b(ppc_id)
		sort  pp_id

		// Contadores
		by pp_id: egen n_stayers_predio = total(stayer_line == 1 & post == 0) // Contar 1 vez
		by pp_id: egen n_exits_predio 	= total(exit_only  	== 1)
		by pp_id: egen n_entries_predio = total(entry_only 	== 1)
	}

	//--------------------------------------------------------------------------
	// Clasificación de Estrategia de Portafolio (Fase 3)
	//--------------------------------------------------------------------------
	{
		gen tipo_predio = 0
		label var tipo_predio "Clasificación del predio para Fase 3"

		// T1: Continuador Puro (A -> A)
		replace tipo_predio = 1 if n_stayers_predio > 0 & n_exits_predio == 0 & n_entries_predio == 0

		// T2: Sustituto Puro (A -> B)
		replace tipo_predio = 2 if n_stayers_predio==0 & n_exits_predio>0 & n_entries_predio>0

		// T3: Abandono (A -> 0)
		replace tipo_predio = 3 if n_stayers_predio==0 & n_exits_predio>0 & n_entries_predio==0

		// T4: Activador (0 -> A)
		replace tipo_predio = 4 if n_stayers_predio==0 & n_exits_predio==0 & n_entries_predio>0

		// T5: Diversificador (A -> A, B)
		replace tipo_predio = 5 if n_stayers_predio>0 & n_entries_predio>0 & n_exits_predio==0

		// T6: Consolidador (A, B -> A)
		replace tipo_predio = 6 if n_stayers_predio>0 & n_entries_predio==0 & n_exits_predio>0

		// T7: Rotación (A, B -> A, C)
		replace tipo_predio = 7 if n_stayers_predio>0 & n_exits_predio>0 & n_entries_predio>0

		label define tpredlbl 0 "Otro/No Clasif" ///
				      1 "S1: Continuador Puro (A->A)" ///
				      2 "S2: Sustituto Puro (A->B)" ///
				      3 "S3: Abandono de Cultivo  (A->0)" ///
				      4 "S4: Activador de Cultivo (0->A)" ///
				      5 "H1: Diversificador (A->A,B)" ///
				      6 "H2: Consolidador    (A,B->A)" ///
				      7 "H3: Continuador con rotación (A,B->A,C)"
		label values tipo_predio tpredlbl
		drop n_* tiene_pre tiene_post exit_only entry_only n_stayers_predio	n_exits_predio n_entries_predio
		lab var nomb_tipo_cult "Nombre del tipo de cultivo (asociado a su código)"
	}

	// Re-establecer sort canónico antes del Step 5 (los helpers de Outliers
	// y el resto del pipeline asumen ppc_id post).
	sort ppc_id post
}

//==============================================================================
// Step 5: Winsorización de Outliers (Rendimientos e Ingresos)
//==============================================================================
if `Outliers_Rend'{
	//--------------------------------------------------------------------------
	// Rendimientos (Cultivo, Planta en Edad Productiva y Semilla)
	//--------------------------------------------------------------------------
	{
		do "${ruta_utils}\outliers_crop_yields"
		// Kilogramo cosechado por hectárea sembradas/instalados
		lab var kgxha_semb_ppc_wz1 "Rendimiento del cultivo (kg/ha) - capeo 1 (logs)"
		lab var kgxha_semb_ppc_wz2 "Rendimiento del cultivo (kg/ha) - capeo 2 (nivs)"
		lab var kgxha_semb_ppc_mis "Rendimiento del cultivo (kg/ha) - outliers a missings"

		// Kilogramo cosechado por planta en edad productiva
		lab var kgx1p_eprod_ppc_wz1	"Rendimiento de la planta en eprod (kg. de cultivo por planta) - capeo 1 (var en logs)"
		lab var kgx1p_eprod_ppc_wz2	"Rendimiento de la planta en eprod (kg. de cultivo por planta) - capeo 2 (var en nivs)"
		lab var kgx1p_eprod_ppc_mis	"Rendimiento de la planta en eprod (kg. de cultivo por planta) - outliers a missings"

		// Kilogramo cosechado por kilogramo de semilla cultivada
		lab var kgxkg_sem_ppc_wz1	"Rendimiento de la semilla (kg. de cultivo por kg. de semilla) - capeo 1 (var en logs)"
		lab var kgxkg_sem_ppc_wz2	"Rendimiento de la semilla (kg. de cultivo por kg. de semilla) - capeo 2 (var en nivs)"
		lab var kgxkg_sem_ppc_mis	"Rendimiento de la semilla (kg. de cultivo por kg. de semilla) - outliers a missings"
		order kgxha_semb_ppc_wz1-kgxha_semb_ppc_mis, 	a(kgxha_semb_ppc)
		order kgx1p_eprod_ppc_wz1-kgx1p_eprod_ppc_mis,	a(kgx1p_eprod_ppc)
		order kgxkg_sem_ppc_wz1-kgxkg_sem_ppc_mis, 		a(kgxkg_sem_ppc)
	}
	//--------------------------------------------------------------------------
	// Ingresos por Venta en S/. (Totales, por Kg. de Cultivo, por Ha. de
	// Cultivo Sembrada)
	//--------------------------------------------------------------------------
	{
		do "${ruta_utils}\outliers_crop_prices"

		gen 	itot_ppc_wz1 = tot_kg_prod_vend_ppc * ixkg_ppc_wz1
		replace itot_ppc_wz1 = 0 if itot_ppc==0
		gen 	itot_ppc_wz2 = tot_kg_prod_vend_ppc * ixkg_ppc_wz2
		replace itot_ppc_wz2 = 0 if itot_ppc==0
		gen 	itot_ppc_mis = tot_kg_prod_vend_ppc * ixkg_ppc_mis
		replace itot_ppc_mis = 0 if itot_ppc==0
		gen 	ixha_ppc 	 = itot_ppc/tot_has_semb_cult_ppc
		gen 	ixha_ppc_wz1 = itot_ppc_wz1/tot_has_semb_cult_ppc
		gen 	ixha_ppc_wz2 = itot_ppc_wz2/tot_has_semb_cult_ppc
		gen 	ixha_ppc_mis = itot_ppc_mis/tot_has_semb_cult_ppc

		// Ingreso Total de Venta (winsorizado)
		lab var itot_ppc_wz1 "Ingreso Total (en S/.) de venta del cultivo - capeo 1 (var de ixkg en logs)"
		lab var itot_ppc_wz2 "Ingreso Total (en S/.) de venta del cultivo - capeo 2 (var de ixkg en nivs)"
		lab var itot_ppc_mis "Ingreso Total (en S/.) de venta del cultivo - outliers a missings"
		// Precio de Venta (winsorizado)
		lab var ixkg_ppc_wz1 "Ingreso por kg. (en S/.) de venta del cultivo - capeo 1 (logs)"
		lab var ixkg_ppc_wz2 "Ingreso por kg. (en S/.) de venta del cultivo - capeo 2 (var en nivs)"
		lab var ixkg_ppc_mis "Ingreso por kg. (en S/.) de venta del cultivo - outliers a missings"
		// Ingreso por Hectárea sembrada (winsorizado)
		lab var ixha_ppc	 "Ingreso Bruto por hectárea sembrada de cultivo (soles x ha.)"
		lab var ixha_ppc_wz1 "Ingreso Bruto por hectárea sembrada de cultivo (soles x ha.) - capeo 1 (var de ikg en logs)"
		lab var ixha_ppc_wz2 "Ingreso Bruto por hectárea sembrada de cultivo (soles x ha.) - capeo 2 (var de ixkg en nivs)"
		lab var ixha_ppc_mis "Ingreso Bruto por hectárea sembrada de cultivo (soles x ha.) - outliers a missings"

		order ixkg_ppc_wz1-ixkg_ppc_mis, 	a(ixkg_ppc)
		order itot_ppc_wz1-itot_ppc_mis, 	a(itot_ppc)
		order ixha_ppc-ixha_ppc_mis, 		a(itot_ppc_mis)

		// Deflactado on-the-way (precios e ingresos winsorizados + por hectárea)
		foreach var in ixkg_ppc_wz1 ixkg_ppc_wz2 ixkg_ppc_mis ///
		               itot_ppc_wz1 itot_ppc_wz2 itot_ppc_mis ///
		               ixha_ppc ixha_ppc_wz1 ixha_ppc_wz2 ixha_ppc_mis {
			local lbl : var lab `var'
			gen double `var'_def = `var'                      if post == 0
			replace    `var'_def = `var' / scalar(factor_def) if post == 1
			lab var `var'_def "`lbl' (S/. constantes 2021)"
			order `var'_def, a(`var')
		}
	}

	//--------------------------------------------------------------------------
	// Liberar Espacio (drop de pregs ya no usadas + compress)
	//--------------------------------------------------------------------------
	// Originalmente al final del Step 5 (ClassifySamples). Movido aquí porque
	// el drop preg114b-preg114l4 elimina variables que sí se usan dentro de
	// Outliers (los helpers leen preg114b1, preg114g1, preg114ge, etc.) y
	// porque ClassifySamples ya no las necesita (depende solo de ppc_id/post).
	//--------------------------------------------------------------------------
	{
		sort ppc_id post
		drop preg114b-preg114l4
		compress
	}
}

//==============================================================================
// Step 6: Valor de la Producción Cosechada (insumo para gasto alquiler %prod)
//==============================================================================
// Propósito: Cuantificar en S/. el valor total de la producción cosechada por
// cultivo y predio, para poder valorizar el pago de alquiler reportado como
// porcentaje de la producción (preg107b) en el script E5_build_farm.do.
//==============================================================================
if `GenValorProd'{
	frame change all_crops

	//--------------------------------------------------------------------------
	// Precio por kg. con imputación (mediana por tipo de cultivo × periodo si
	// no hubo venta del cultivo)
	//--------------------------------------------------------------------------
	bys nomb_tipo_cult post: egen double _p_med = median(ixkg_ppc)
	gen double ixkg_ppc_imp = cond(!mi(ixkg_ppc), ixkg_ppc, _p_med)
	drop _p_med
	lab var ixkg_ppc_imp "Ingreso por kg. (S/.) del cultivo imputado (mediana por tipo × periodo)"

	//--------------------------------------------------------------------------
	// Valor total de la producción cosechada del cultivo
	//--------------------------------------------------------------------------
	gen double vtot_cose_ppc = tot_kg_prod_cose_ppc * ixkg_ppc_imp
	replace vtot_cose_ppc = 0 if tot_kg_prod_cose_ppc==0
	lab var vtot_cose_ppc "Valor Total (S/.) de la producción cosechada del cultivo"

	//--------------------------------------------------------------------------
	// Agregación a nivel predio × periodo (suma sobre cultivos del predio)
	//--------------------------------------------------------------------------
	bys pp_id post: egen double vtot_cose_pp = total(vtot_cose_ppc), m
	lab var vtot_cose_pp "Valor Total (S/.) producción cosechada del predio (suma cultivos)"
	drop ixkg_ppc_imp
}

//==============================================================================
// Step 7 (Cultivo Principal): Plagas y Eventos)
//==============================================================================
if `GenVarsPlagas'{
	frame copy all_crops main_crops, replace
	frame change main_crops
	
	//--------------------------------------------------------------------------
	// Identificar Cultivo Principal y Colapsar Data
	//--------------------------------------------------------------------------
	{	
		lab de sino 1 "Sí" 0 "No" 
		gen culp_ppc:sino = (!mi(preg114o1) | !mi(preg114o2) | !mi(preg114o88)) 
		lab var culp_ppc "1 Si es cultivo principal"
		keep if culp_ppc==1
		drop culp_ppc
	}
	
	//--------------------------------------------------------------------------
	// Indicadores de Afectación del Cultivo Principal
	//--------------------------------------------------------------------------
	{
		gen afct_plga_culp_ppc:sino = preg114o1==1
		lab var afct_plga_culp_ppc "Alguna plaga afectó al cultivo principal"

		gen afct_evi_culp_ppc:sino = preg114o2==1
		lab var afct_evi_culp_ppc "Algún evento inesperado afectó al cultivo principal"
	}
	
	//--------------------------------------------------------------------------
	// Plagas y Eventos (Totales) del Cultivo Principal
	//--------------------------------------------------------------------------
	{
		egen tot_plgas_culp_ppc = rowtotal(preg114p1-preg114p61)
		lab var tot_plgas_culp_ppc "Total de plagas que afectaron al cultivo principal"

		egen tot_evi_culp_ppc = rowtotal(preg114t1-preg114t9)
		lab var tot_evi_culp_ppc "Total de eventos inesperados que afectaron al cultivo principal"
	}
}

//==============================================================================
// Step 8 (Cultivo Principal): Insumos Químicos y Orgánicos (Plaguicidas y
// Fertilizantes)
//==============================================================================
if `GenVarsInsm'{
	
	//--------------------------------------------------------------------------
	// Limpieza y Cálculo de Gasto en Plaguicidas (Lógica Externa)
	//--------------------------------------------------------------------------
	{		
		// Corregir nombres de Plaguicidas
		qui do "${ruta_utils}\clean_pesticide_names.do"
		frame copy main_crops plaguicds, replace
		frame change plaguicds
		keep Codprod22-post preg114x1_1 ///
			preg114y1a preg114y1b preg114y1c preg114y1e preg114y1ee preg114y1f ///
			preg114z1a preg114z1b preg114z1c preg114z1e preg114z1ee preg114z1f ///
			*_1 *_2 *_3 *_4 *_5
		
		// Calcular Outliers de medidas de uso y gasto en Plaguicidas
		qui do "${ruta_utils}\outliers_pesticide_prices.do"
		use "`outc6'\\Totales_plag_en_lt_x_cultivo.dta", clear
		merge 1:1 Codprod22-post using "`outc6'\\Totales_plag_en_kg_x_cultivo.dta", nogen
		sort Codprod22-post

		// Agregar Gastos Totales
		egen gtot_plag_culp_ppc     = rowtotal(ctot_lts_plag_culp ctot_kgs_plag_culp) , m
		egen gtot_plag_wz1_culp_ppc = rowtotal(ctot_lts_plag_wz1_culp ctot_kgs_plag_wz1_culp) , m
		egen gtot_plag_wz2_culp_ppc = rowtotal(ctot_lts_plag_wz2_culp ctot_kgs_plag_wz2_culp) , m
		egen gtot_plag_mis_culp_ppc = rowtotal(ctot_lts_plag_mis_culp ctot_kgs_plag_mis_culp) , m
		drop ct*s_*

		lab var gtot_plag_culp_ppc 		"Gasto Total (en S/.) en plaguicida en el cultivo principal"
		lab var gtot_plag_wz1_culp_ppc 	"Gasto Total (en S/.) en plaguicida en el cultivo principal - capeo 1 (var en logs)"
		lab var gtot_plag_wz2_culp_ppc 	"Gasto Total (en S/.) en plaguicida en el cultivo principal - capeo 2 (var en nivs)"
		lab var gtot_plag_mis_culp_ppc	"Gasto Total (en S/.) en plaguicida en el cultivo principal - outliers a missings"

		// Deflactado on-the-way (en frame plaguicds; main_crops hereda vía frget)
		foreach var in gtot_plag_culp_ppc gtot_plag_wz1_culp_ppc ///
		               gtot_plag_wz2_culp_ppc gtot_plag_mis_culp_ppc {
			local lbl : var lab `var'
			gen double `var'_def = `var'                      if post == 0
			replace    `var'_def = `var' / scalar(factor_def) if post == 1
			lab var `var'_def "`lbl' (S/. constantes 2021)"
			order `var'_def, a(`var')
		}

		compress

		// Volver al frame principal y unir
		frame change main_crops
		frlink 1:1 Codprod22 preg101a preg114b1 post, frame(plaguicds)
		frget _all, from(plaguicds)
		drop codprod preg114o1-preg114v preg114x2a_1-preg114x4_5 plaguicds
	}

	//--------------------------------------------------------------------------
	// Indicadores de Uso y Volúmenes (Químicos y Orgánicos)
	//--------------------------------------------------------------------------
	{
		// Dummies de Uso
		gen usa_plag_culp_ppc:sino = (preg114x1_1==1) 
		gen usa_aboo_culp_ppc:sino = (preg114y1a==1) 
		gen usa_aboq_culp_ppc:sino = (preg114z1a==1) 

		lab var usa_plag_culp_ppc  "Usa plaguicida (fungui., herbi., insecti. o nemati.) en el cultivo principal"
		lab var usa_aboo_culp_ppc  "Usa abono orgánico/natural en el cultivo principal"
		lab var usa_aboq_culp_ppc  "Usa abono químico en el cultivo principal"
		drop preg114x1_* 
		
		// Ajuste de Ceros en Plaguicidas
		order kg_plag_culp_ppc lt_plag_culp_ppc gtot_plag_*, a(usa_plag_culp_ppc)
		replace kg_plag_culp_ppc 	= 0 if usa_plag_culp_ppc==0
		replace lt_plag_culp_ppc 	= 0 if usa_plag_culp_ppc==0	
		replace gtot_plag_culp_ppc 	= 0 if usa_plag_culp_ppc==0
		replace gtot_plag_wz1_culp_ppc 	= 0 if usa_plag_culp_ppc==0
		replace gtot_plag_wz2_culp_ppc 	= 0 if usa_plag_culp_ppc==0
		replace gtot_plag_mis_culp_ppc 	= 0 if usa_plag_culp_ppc==0

		// Abono Orgánico (Kilos, Litros, Gasto)
		destring preg114y1e, replace 
		gen 	kg_aboo_culp_ppc = preg114y1b 	if preg114y1c==1
		replace kg_aboo_culp_ppc = preg114y1e 	if mi(kg_aboo_culp_ppc) & preg114y1ee==1
		replace kg_aboo_culp_ppc = 0 	 	 	if usa_aboo_culp_ppc==0
		
		gen 	lt_aboo_culp_ppc = preg114y1b 	if preg114y1c==2
		replace lt_aboo_culp_ppc = preg114y1e 	if mi(lt_aboo_culp_ppc) & preg114y1ee==2
		replace lt_aboo_culp_ppc = 0 	 	 	if usa_aboo_culp_ppc==0
		replace lt_aboo_culp_ppc = .	 	 	if lt_aboo_culp_ppc==50000 // reemplazo manual por outlier extremo (ver como incluir luego en script de outliers)

		gen 	gtot_aboo_culp_ppc = preg114y1f
		replace gtot_aboo_culp_ppc = 0	 	 	if usa_aboo_culp_ppc==0
		
		lab var kg_aboo_culp_ppc 	"Kilos de abono orgánico/natural empleados en el cultivo principal"
		lab var lt_aboo_culp_ppc 	"Litros de abono orgánico/natural empleados en el cultivo principal"
		lab var gtot_aboo_culp_ppc 	"Gasto Total (en S/.) en abono orgánico/natural en el cultivo principal"

		order kg_aboo_culp_ppc-gtot_aboo_culp_ppc, a(usa_aboo_culp_ppc)
		drop preg114y*

		// Deflactado on-the-way (gasto en abono orgánico)
		local lbl : var lab gtot_aboo_culp_ppc
		gen double gtot_aboo_culp_ppc_def = gtot_aboo_culp_ppc                      if post == 0
		replace    gtot_aboo_culp_ppc_def = gtot_aboo_culp_ppc / scalar(factor_def) if post == 1
		lab var gtot_aboo_culp_ppc_def "`lbl' (S/. constantes 2021)"
		order gtot_aboo_culp_ppc_def, a(gtot_aboo_culp_ppc)
		
		// Abono Químico (Kilos, Litros, Gasto)
		destring preg114z1e, replace 
		gen 	kg_aboq_culp_ppc = preg114z1b if preg114z1c==1
		replace kg_aboq_culp_ppc = preg114z1e if mi(kg_aboq_culp_ppc) & preg114z1ee==1
		replace kg_aboq_culp_ppc = 0 	 	  if usa_aboq_culp_ppc==0
		
		gen 	lt_aboq_culp_ppc = preg114z1b if preg114z1c==2
		replace lt_aboq_culp_ppc = preg114z1e if mi(lt_aboq_culp_ppc) & preg114z1ee==2
		replace lt_aboq_culp_ppc = 0 	 	  if usa_aboq_culp_ppc==0
		
		gen 	gtot_aboq_culp_ppc = preg114z1f
		replace gtot_aboq_culp_ppc = 0 		  if usa_aboq_culp_ppc==0
		
		lab var kg_aboq_culp_ppc 	"Kilos de abono químico empleados en el cultivo principal"
		lab var lt_aboq_culp_ppc 	"Litros de abono químico empleados en el cultivo principal"
		lab var gtot_aboq_culp_ppc 	"Gasto Total (en S/.) en abono químico en el cultivo principal"

		order kg_aboq_culp_ppc-gtot_aboq_culp_ppc, a(usa_aboq_culp_ppc)
		drop preg114z*

		// Deflactado on-the-way (gasto en abono químico)
		local lbl : var lab gtot_aboq_culp_ppc
		gen double gtot_aboq_culp_ppc_def = gtot_aboq_culp_ppc                      if post == 0
		replace    gtot_aboq_culp_ppc_def = gtot_aboq_culp_ppc / scalar(factor_def) if post == 1
		lab var gtot_aboq_culp_ppc_def "`lbl' (S/. constantes 2021)"
		order gtot_aboq_culp_ppc_def, a(gtot_aboq_culp_ppc)
	}

	//--------------------------------------------------------------------------
	// Ratios de Intensidad (Por Hectárea)
	//--------------------------------------------------------------------------
	{
		// Plaguicidas
		gen kgxha_plag_culp_ppc 	= kg_plag_culp_ppc/tot_has_semb_cult_ppc if tot_has_semb_cult_ppc>0 & !mi(kg_plag_culp_ppc), a(kg_plag_culp_ppc)
		replace kgxha_plag_culp_ppc = 0 if usa_plag_culp_ppc==0
		gen ltxha_plag_culp_ppc 	= lt_plag_culp_ppc/tot_has_semb_cult_ppc if tot_has_semb_cult_ppc>0 & !mi(lt_plag_culp_ppc), a(lt_plag_culp_ppc)
		replace ltxha_plag_culp_ppc = 0 if usa_plag_culp_ppc==0
		lab var kgxha_plag_culp_ppc "Kilos de plaguicida aplicados por hectárea sembrada (kg/ha)"
		lab var ltxha_plag_culp_ppc "Litros de plaguicida aplicados por hectárea sembrada (lt/ha)"

		// Abono Orgánico
		gen 	kgxha_aboo_culp_ppc = kg_aboo_culp_ppc/tot_has_semb_cult if tot_has_semb_cult>0 & !mi(kg_aboo_culp_ppc), a(kg_aboo_culp_ppc)
		replace kgxha_aboo_culp_ppc = 0	if usa_aboo_culp_ppc==0
		gen 	ltxha_aboo_culp_ppc = lt_aboo_culp_ppc/tot_has_semb_cult if tot_has_semb_cult>0 & !mi(lt_aboo_culp_ppc), a(lt_aboo_culp_ppc)
		replace ltxha_aboo_culp_ppc = 0	if usa_aboo_culp_ppc==0
		lab var kgxha_aboo_culp_ppc "Kilos de abono orgánico aplicados por hectárea sembrada (kg/ha)"
		lab var ltxha_aboo_culp_ppc "Litros de abono orgánico aplicados por hectárea sembrada (lt/ha)"

		// Abono Químico
		gen 	kgxha_aboq_culp_ppc = kg_aboq_culp_ppc/tot_has_semb_cult if tot_has_semb_cult>0 & !mi(kg_aboq_culp_ppc), a(kg_aboq_culp_ppc)
		replace kgxha_aboq_culp_ppc = 0	if usa_aboq_culp_ppc==0
		gen 	ltxha_aboq_culp_ppc = lt_aboq_culp_ppc/tot_has_semb_cult if tot_has_semb_cult>0 & !mi(lt_aboq_culp_ppc), a(lt_aboq_culp_ppc)
		replace ltxha_aboq_culp_ppc = 0	if usa_aboq_culp_ppc==0	
		lab var kgxha_aboq_culp_ppc "Kilos de abono químico aplicados por hectárea sembrada (kg/ha)"
		lab var ltxha_aboq_culp_ppc "Litros de abono químico aplicados por hectárea sembrada (lt/ha)"
	}
}

//==============================================================================
// Step 9 (Cultivo Principal): Margen sobre Insumos (Ing x Ventas - Gasto en ins.
// /Bruto y x Has. Cultivada)
//==============================================================================
if `GenMgnIns'{
	egen rtot_gasto_ins = rowtotal(gtot_plag_culp_ppc gtot_aboo_culp_ppc gtot_aboq_culp_ppc)
	egen rtot_gasto_wz1 = rowtotal(gtot_plag_wz1_culp_ppc gtot_aboo_culp_ppc gtot_aboq_culp_ppc)
	egen rtot_gasto_wz2 = rowtotal(gtot_plag_wz2_culp_ppc gtot_aboo_culp_ppc gtot_aboq_culp_ppc)
	egen rtot_gasto_mis = rowtotal(gtot_plag_mis_culp_ppc gtot_aboo_culp_ppc gtot_aboq_culp_ppc)
	
	gen double mgn_ins_culp_ppc = itot_ppc - rtot_gasto_ins
	gen double mgn_ins_wz1_culp_ppc = itot_ppc_wz1 - rtot_gasto_wz1
	gen double mgn_ins_wz2_culp_ppc = itot_ppc_wz2 - rtot_gasto_wz2
	gen double mgn_ins_mis_culp_ppc = itot_ppc_mis - rtot_gasto_mis if !mi(itot_ppc_mis,gtot_plag_mis_culp_ppc)

	gen double mgn_ins_ha_culp_ppc = (itot_ppc - rtot_gasto_ins)/tot_has_semb_cult_ppc
	gen double mgn_ins_ha_wz1_culp_ppc = (itot_ppc_wz1 - rtot_gasto_wz1)/tot_has_semb_cult_ppc	
	gen double mgn_ins_ha_wz2_culp_ppc = (itot_ppc_wz2 - rtot_gasto_wz2)/tot_has_semb_cult_ppc
	gen double mgn_ins_ha_mis_culp_ppc = (itot_ppc_mis - rtot_gasto_mis)/tot_has_semb_cult_ppc if !mi(itot_ppc_mis,gtot_plag_mis_culp_ppc)
	drop rtot_*
	
	lab var mgn_ins_culp_ppc 		"Margen sobre gasto en insumos (S/.) - solo cultivo principal"
	lab var mgn_ins_wz1_culp_ppc 	"Margen sobre gasto en insumos (S/.) - capeo 1 (vars log)"
	lab var mgn_ins_wz2_culp_ppc 	"Margen sobre gasto en insumos (S/.) - capeo 2 (vars nivel)"
	lab var mgn_ins_mis_culp_ppc 	"Margen sobre gasto en insumos (S/.) - outliers a missing"

	lab var mgn_ins_ha_culp_ppc 	"Margen sobre gasto en insumos por Ha (S/./ha) - solo cultivo principal"
	lab var mgn_ins_ha_wz1_culp_ppc "Margen sobre gasto en insumos por Ha (S/./ha) - capeo 1 (vars log)"
	lab var mgn_ins_ha_wz2_culp_ppc "Margen sobre gasto en insumos por Ha (S/./ha) - capeo 2 (vars nivel)"
	lab var mgn_ins_ha_mis_culp_ppc "Margen sobre gasto en insumos por Ha (S/./ha) - outliers a missing"

	// Deflactado on-the-way (márgenes total y por hectárea)
	foreach var in mgn_ins_culp_ppc mgn_ins_wz1_culp_ppc ///
	               mgn_ins_wz2_culp_ppc mgn_ins_mis_culp_ppc ///
	               mgn_ins_ha_culp_ppc mgn_ins_ha_wz1_culp_ppc ///
	               mgn_ins_ha_wz2_culp_ppc mgn_ins_ha_mis_culp_ppc {
		local lbl : var lab `var'
		gen double `var'_def = `var'                      if post == 0
		replace    `var'_def = `var' / scalar(factor_def) if post == 1
		lab var `var'_def "`lbl' (S/. constantes 2021)"
		order `var'_def, a(`var')
	}
}

//==============================================================================
// Step 10 (Cultivo Principal): Limpieza final del frame main_crops
//==============================================================================
// Propósito: dejar main_crops como una base estricta a nivel de cultivo
// principal (una obs. por productor × predio × periodo, filtrada en Step 6):
//   (1) Elimina variables agregadas a nivel de predio (no aplican aquí).
//   (2) Renombra sufijos _ppc → _culp para reflejar el nivel de análisis.
//       - *_culp_ppc       → *_culp        (vars generadas en Steps 6-8)
//       - *_culp_ppc_def   → *_culp_def    (sus deflactadas)
//       - *_ppc[_suf]      → *_culp[_suf]  (vars heredadas de all_crops)
//   (3) Actualiza etiquetas: "cultivo" → "cultivo principal" (solo si la
//       etiqueta aún no contiene "cultivo principal").
//==============================================================================
if `CleanMainCrops'{
	frame change main_crops

	//--------------------------------------------------------------------------
	// (1) Drop de variables agregadas a nivel predio
	//--------------------------------------------------------------------------
	cap drop vtot_cose_pp

	//--------------------------------------------------------------------------
	// (2) Rename _ppc → _culp
	//--------------------------------------------------------------------------
	// (2a) Variables que ya tenían _culp (solo hay que quitar el _ppc final)
	cap rename *_culp_ppc_def *_culp_def
	cap rename *_culp_ppc     *_culp

	// (2b) Variables heredadas de all_crops con sufijos compuestos
	foreach suf in wz1_def wz2_def mis_def wz1 wz2 mis def {
		cap rename *_ppc_`suf' *_culp_`suf'
	}

	// (2c) Variables heredadas de all_crops terminadas en _ppc puro
	cap rename *_ppc *_culp

	//--------------------------------------------------------------------------
	// (3) Relabel: "cultivo" → "cultivo principal"
	//--------------------------------------------------------------------------
	qui ds
	foreach v of varlist `r(varlist)' {
		local lbl : var lab `v'
		if strpos("`lbl'", "cultivo")>0 & strpos("`lbl'", "cultivo principal")==0 {
			local newlbl = subinstr("`lbl'", "cultivo", "cultivo principal", 1)
			lab var `v' "`newlbl'"
		}
	}
}

//==============================================================================
// Step 11: Order, Notes & Label Data
//==============================================================================
if `OrderNotesLabelData'{
	//--------------------------------------------------------------------------
	// Base 1: Todos los Cultivos (all_crops)
	//--------------------------------------------------------------------------
	frame change all_crops
	order ///
	/* B1. Identificadores y clasificadores */ ///
	Codprod22 codprod pp_id ppc_id ///
	preg101a nomb_prod preg114b1 nomb_tipo_cult ///
	nomb_prod_obj prod_ECA_eval post ///
	stayer_line tipo_predio ///
	/* B2. Insumos */ ///
	tot_has_semb_cult_ppc ///
	tot_ud_plnts_ppc tot_ud_plnts_eprod_ppc pct_plnts_eprod_ppc ///
	tot_kg_sem_ppc ///
	/* B3. Producción cosechada (kg) por destino */ ///
	tot_kg_prod_cose_ppc ///
	tot_kg_prod_vend_ppc ///
	tot_kg_prod_vend_MN_ppc tot_kg_prod_vend_MN_ML_ppc tot_kg_prod_vend_MI_ppc ///
	tot_kg_prod_autoc_ppc ///
	/* B4. Producción cosechada (%) por destino — espejo de B3 */ ///
	pct_prod_cose_vend_ppc ///
	pct_prod_vend_MN_ppc pct_prod_vend_MN_ML_ppc pct_prod_vend_MI_ppc ///
	pct_prod_cose_autoc_ppc ///
	/* B5. Rendimientos (base, capeo1, capeo2, mis) */ ///
	kgxha_semb_ppc  kgxha_semb_ppc_wz1  kgxha_semb_ppc_wz2  kgxha_semb_ppc_mis ///
	kgx1p_eprod_ppc kgx1p_eprod_ppc_wz1 kgx1p_eprod_ppc_wz2 kgx1p_eprod_ppc_mis ///
	kgxkg_sem_ppc   kgxkg_sem_ppc_wz1   kgxkg_sem_ppc_wz2   kgxkg_sem_ppc_mis ///
	/* B6. Precio por kg (nominal y deflactado) */ ///
	ixkg_ppc  ixkg_ppc_def ///
	ixkg_ppc_wz1 ixkg_ppc_wz1_def ixkg_ppc_wz2 ixkg_ppc_wz2_def ///
	ixkg_ppc_mis ixkg_ppc_mis_def ///
	/* B7. Ingreso total (mismo patrón que B6) */ ///
	itot_ppc  itot_ppc_def ///
	itot_ppc_wz1 itot_ppc_wz1_def itot_ppc_wz2 itot_ppc_wz2_def ///
	itot_ppc_mis itot_ppc_mis_def ///
	/* B8. Ingreso bruto por hectárea (mismo patrón que B6) */ ///
	ixha_ppc  ixha_ppc_def ///
	ixha_ppc_wz1 ixha_ppc_wz1_def ixha_ppc_wz2 ixha_ppc_wz2_def ///
	ixha_ppc_mis ixha_ppc_mis_def ///
	/* B9. Valor total a nivel predio */ ///
	vtot_cose_ppc vtot_cose_pp
	
	label data "Base cultivo-predio (ppc): producción, rendimientos, precios e ingresos | 9 bloques temáticos | últ. ord.: $S_DATE"
	
	* Limpia notas previas para evitar duplicados al re-correr el do-file
	capture notes drop _dta

	note: ESTRUCTURA: 9 bloques siguiendo el flujo productivo agrícola (insumos -> cosecha -> destino -> rendimientos -> precios -> ingresos -> valor predio).
	note: UNIDAD DE ANÁLISIS: línea cultivo-predio (ppc_id). Predio = pp_id. Producto = codprod / Codprod22.
	note: SUFIJOS DE VERSIONES — _def: S/. constantes 2021 | _wz1: capeo en logs (capeo 1) | _wz2: capeo en niveles (capeo 2) | _mis: outliers convertidos a missing.

	note: B1 — IDENTIFICADORES Y CLASIFICADORES (Codprod22 ... tipo_predio).
	note: B2 — INSUMOS: hectáreas sembradas, plantas instaladas/productivas y semilla utilizada.
	note: B3 — PRODUCCIÓN COSECHADA EN KG por destino: total -> vendida -> MN -> MN-local -> MI -> autoconsumo.
	note: B4 — PRODUCCIÓN COSECHADA EN % por destino (espejo de B3).
	note: B5 — RENDIMIENTOS: kg/ha sembrada, kg/planta productiva, kg/kg de semilla. 4 versiones c/u (base, wz1, wz2, mis).
	note: B6 — PRECIO POR KG (ixkg_ppc): nominal y deflactado, con las 4 versiones de capeo.
	note: B7 — INGRESO TOTAL (itot_ppc): mismo patrón de versiones que B6.
	note: B8 — INGRESO BRUTO POR HECTÁREA (ixha_ppc): mismo patrón de versiones que B6.
	note: B9 — VALOR TOTAL: vtot_cose_ppc (por cultivo del predio) y vtot_cose_pp (agregado a nivel predio: suma sobre cultivos). Aunque vtot_cose_pp opera a unidad mayor que el resto de la base (predio vs. línea cultivo-predio), se mantiene en B9 por afinidad temática (insumo del cálculo de alquiler como % de producción en E5_build_farm.do); el valor se repite en todas las filas del mismo predio.
	
	note Codprod22             : ">>> INICIO B1: Identificadores y clasificadores"
	note tot_has_semb_cult_ppc : ">>> INICIO B2: Insumos (tierra, plantas, semilla)"
	note tot_kg_prod_cose_ppc  : ">>> INICIO B3: Producción cosechada en kg por destino"
	note pct_prod_cose_vend_ppc: ">>> INICIO B4: Producción cosechada en % por destino"
	note kgxha_semb_ppc        : ">>> INICIO B5: Rendimientos (3 familias x 4 versiones)"
	note ixkg_ppc              : ">>> INICIO B6: Precio por kg (nominal y deflactado)"
	note itot_ppc              : ">>> INICIO B7: Ingreso total (nominal y deflactado)"
	note ixha_ppc              : ">>> INICIO B8: Ingreso bruto por hectárea"
	note vtot_cose_ppc         : ">>> INICIO B9: Valor total a nivel predio"
	
	//--------------------------------------------------------------------------
	// Base 2: Cultivo Principal (main_crops)
	//--------------------------------------------------------------------------
	frame change main_crops
	order ///
	/* B1. Identificadores y clasificadores */ ///
	Codprod22 preg101a nomb_prod preg114b1 nomb_tipo_cult ///
	post nomb_prod_obj prod_ECA_eval ///
	pp_id ppc_id stayer_line tipo_predio ///
	/* B2. Insumos básicos: tierra, plantas y semilla */ ///
	tot_has_semb_cult_culp ///
	tot_ud_plnts_culp tot_ud_plnts_eprod_culp pct_plnts_eprod_culp ///
	tot_kg_sem_culp ///
	/* B3. Producción cosechada (kg) por destino */ ///
	tot_kg_prod_cose_culp ///
	tot_kg_prod_vend_culp ///
	tot_kg_prod_vend_MN_culp tot_kg_prod_vend_MN_ML_culp tot_kg_prod_vend_MI_culp ///
	tot_kg_prod_autoc_culp ///
	/* B4. Producción cosechada (%) por destino — espejo de B3 */ ///
	pct_prod_cose_vend_culp ///
	pct_prod_vend_MN_culp pct_prod_vend_MN_ML_culp pct_prod_vend_MI_culp ///
	pct_prod_cose_autoc_culp ///
	/* B5. Rendimientos (base, capeo1, capeo2, mis) */ ///
	kgxha_semb_culp  kgxha_semb_culp_wz1  kgxha_semb_culp_wz2  kgxha_semb_culp_mis ///
	kgx1p_eprod_culp kgx1p_eprod_culp_wz1 kgx1p_eprod_culp_wz2 kgx1p_eprod_culp_mis ///
	kgxkg_sem_culp   kgxkg_sem_culp_wz1   kgxkg_sem_culp_wz2   kgxkg_sem_culp_mis ///
	/* B6. Precio por kg */ ///
	ixkg_culp  ixkg_culp_def ///
	ixkg_culp_wz1 ixkg_culp_wz1_def ixkg_culp_wz2 ixkg_culp_wz2_def ///
	ixkg_culp_mis ixkg_culp_mis_def ///
	/* B7. Ingreso total */ ///
	itot_culp  itot_culp_def ///
	itot_culp_wz1 itot_culp_wz1_def itot_culp_wz2 itot_culp_wz2_def ///
	itot_culp_mis itot_culp_mis_def ///
	/* B8. Ingreso bruto por hectárea */ ///
	ixha_culp  ixha_culp_def ///
	ixha_culp_wz1 ixha_culp_wz1_def ixha_culp_wz2 ixha_culp_wz2_def ///
	ixha_culp_mis ixha_culp_mis_def ///
	/* B9. Valor total cosechado (incluye autoconsumo) */ ///
	vtot_cose_culp ///
	/* B10. Choques: plagas y eventos inesperados */ ///
	afct_plga_culp tot_plgas_culp ///
	afct_evi_culp  tot_evi_culp ///
	/* B11. Plaguicidas: uso, cantidad y gasto */ ///
	usa_plag_culp ///
	kg_plag_culp kgxha_plag_culp lt_plag_culp ltxha_plag_culp ///
	gtot_plag_culp gtot_plag_culp_def ///
	gtot_plag_wz1_culp gtot_plag_wz1_culp_def ///
	gtot_plag_wz2_culp gtot_plag_wz2_culp_def ///
	gtot_plag_mis_culp gtot_plag_mis_culp_def ///
	/* B12. Abono orgánico/natural */ ///
	usa_aboo_culp ///
	kg_aboo_culp kgxha_aboo_culp lt_aboo_culp ltxha_aboo_culp ///
	gtot_aboo_culp gtot_aboo_culp_def ///
	/* B13. Abono químico */ ///
	usa_aboq_culp ///
	kg_aboq_culp kgxha_aboq_culp lt_aboq_culp ltxha_aboq_culp ///
	gtot_aboq_culp gtot_aboq_culp_def ///
	/* B14. Margen sobre gasto en insumos (total y por ha) */ ///
	mgn_ins_culp     mgn_ins_culp_def ///
	mgn_ins_wz1_culp mgn_ins_wz1_culp_def ///
	mgn_ins_wz2_culp mgn_ins_wz2_culp_def ///
	mgn_ins_mis_culp mgn_ins_mis_culp_def ///
	mgn_ins_ha_culp     mgn_ins_ha_culp_def ///
	mgn_ins_ha_wz1_culp mgn_ins_ha_wz1_culp_def ///
	mgn_ins_ha_wz2_culp mgn_ins_ha_wz2_culp_def ///
	mgn_ins_ha_mis_culp mgn_ins_ha_mis_culp_def
	
	label data "Base cultivo principal (_culp): producción, ingresos, choques, costos de insumos y margen | 14 bloques temáticos | últ. ord.: $S_DATE"
	
	capture notes drop _dta
	note: ESTRUCTURA: 14 bloques. Flujo: identidad -> insumos basicos -> cosecha -> rendimientos -> precios -> ingresos -> valor total -> choques -> costos por insumo -> margen.
	note: UNIDAD DE ANÁLISIS: línea cultivo-predio (ppc_id), restringido al cultivo principal del predio. Predio = pp_id.
	note: SUFIJOS DE VERSIONES — _def: S/. constantes 2021 | _wz1: capeo en logs (capeo 1) | _wz2: capeo en niveles (capeo 2) | _mis: outliers a missing.
	note: SUFIJO DE BASE — _culp identifica todas las variables del cultivo principal (vs. _ppc en la base general).

	note: B1 — IDENTIFICADORES Y CLASIFICADORES (Codprod22 ... tipo_predio).
	note: B2 — INSUMOS BÁSICOS: hectáreas sembradas, plantas instaladas/productivas y semilla.
	note: B3 — PRODUCCIÓN COSECHADA EN KG por destino: total -> vendida -> MN -> MN-local -> MI -> autoconsumo.
	note: B4 — PRODUCCIÓN COSECHADA EN % por destino (espejo de B3).
	note: B5 — RENDIMIENTOS: kg/ha sembrada, kg/planta productiva, kg/kg de semilla. 4 versiones c/u (base, wz1, wz2, mis).
	note: B6 — PRECIO POR KG (ixkg_culp): nominal y deflactado, con las 4 versiones de capeo.
	note: B7 — INGRESO TOTAL (itot_culp): mismo patrón de versiones que B6.
	note: B8 — INGRESO BRUTO POR HECTÁREA (ixha_culp): mismo patrón que B6.
	note: B9 — VALOR TOTAL COSECHADO (vtot_cose_culp): incluye autoconsumo, no solo lo vendido.
	note: B10 — CHOQUES: plagas (afct_plga, tot_plgas) y eventos inesperados (afct_evi, tot_evi).
	note: B11 — PLAGUICIDAS: uso (sí/no), cantidades (kg, kg/ha, lt, lt/ha) y gasto total (con 4 versiones nominal/deflactado).
	note: B12 — ABONO ORGÁNICO: uso, cantidades y gasto total (solo nominal y deflactado, sin capeos).
	note: B13 — ABONO QUÍMICO: uso, cantidades y gasto total (solo nominal y deflactado, sin capeos).
	note: B14 — MARGEN SOBRE INSUMOS: total (mgn_ins) y por hectárea (mgn_ins_ha), c/u con 4 versiones nominal/deflactado.
	
	note Codprod22              : ">>> INICIO B1: Identificadores y clasificadores"
	note tot_has_semb_cult_culp : ">>> INICIO B2: Insumos básicos (tierra, plantas, semilla)"
	note tot_kg_prod_cose_culp  : ">>> INICIO B3: Producción cosechada en kg por destino"
	note pct_prod_cose_vend_culp: ">>> INICIO B4: Producción cosechada en % por destino"
	note kgxha_semb_culp        : ">>> INICIO B5: Rendimientos (3 familias x 4 versiones)"
	note ixkg_culp              : ">>> INICIO B6: Precio por kg"
	note itot_culp              : ">>> INICIO B7: Ingreso total"
	note ixha_culp              : ">>> INICIO B8: Ingreso bruto por hectárea"
	note vtot_cose_culp         : ">>> INICIO B9: Valor total cosechado (incluye autoconsumo)"
	note afct_plga_culp         : ">>> INICIO B10: Choques (plagas y eventos)"
	note usa_plag_culp          : ">>> INICIO B11: Plaguicidas (uso, cantidad, gasto)"
	note usa_aboo_culp          : ">>> INICIO B12: Abono orgánico/natural"
	note usa_aboq_culp          : ">>> INICIO B13: Abono químico"
	note mgn_ins_culp           : ">>> INICIO B14: Margen sobre gasto en insumos"	
}

//==============================================================================
// Step 12: Save Final Data
//==============================================================================
if `SaveAndClean'{
	frame change main_crops
	sort ppc_id post
	compress
	save "`outc5'\\Cultivo_Pcpal_LByLS", replace

	frame change all_crops
	preserve
		keep Codprod22 preg101a post pp_id vtot_cose_pp
		bys pp_id post: keep if _n==1
		sort Codprod22 preg101a post
		compress
		save "`outc5'\\Valor_Produccion_Predio_LByLS.dta", replace
	restore

	frame change all_crops
	sort ppc_id post
	drop preg114o1-preg114z2c
	compress
	save "`outc5'\\Cultivos_LByLS.dta", replace
	frame drop plaguicds default
}

log close
