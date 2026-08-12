//----------------------------------------------------------------------
// File           : outliers_pesticide_prices.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Detecta y reemplaza outliers en precios de plaguicidas
//                  usando MAD con umbral 3.
//----------------------------------------------------------------------

// Preliminares:
// 0. Quedan variables relevantes (nombre, tipo, kg., lt. y costos asociados).
// 1. Quedan observaciones con info de plaguicidas.
// 2. Reshape de la data a nivel de plaguicida (un productor puede usar más de un
// plaguicida por cultivo).

// Rutas derivadas del global ${ruta_data}. Este helper se invoca con `do', que
// abre un scope nuevo: los locales `outc*' que define A_master.do NO llegan
// hasta acá. Mismo patrón que prg_load_panel.do.
local outc6 "${ruta_data}/Out/6_Temporales"

foreach m in lt kg{
	preserve 
	keep Codprod22-post nomb_plag_* tipo_plag_* `m'_plag_* cx`m'_plag_*
	drop if mi(nomb_plag_culp_ppc_1) 
	reshape long nomb_plag_culp_ppc_ tipo_plag_culp_ppc_ `m'_plag_culp_ppc_ ///
			cx`m'_plag_culp_ppc_, i(Codprod22 preg101a preg114b1 post) j(n_plag)
	ren (nomb_plag_culp_ppc tipo_plag_culp_ppc `m'_plag_culp_ppc cx`m'_plag_culp_ppc) ///
		(nomb_plag tipo_plag `m'_plag cx`m'_plag)
	sort Codprod22-post n_plag
	drop if mi(nomb_plag)
	drop if mi(`m'_plag,cx`m'_plag)
	sort nomb_plag post cx`m'_plag
	
	// 1. Generar una variable que cuente el número de obs por plaguicida con precios
	by nomb_plag post: egen counter = count(cx`m'_plag) if nomb_plag!="No Especifica"
	order counter, a(n_plag)

	// 2. Generar variable en logaritmos
	gen ln_cx`m'_plag = ln(cx`m'_plag) if nomb_plag!="No Especifica", a(cx`m'_plag)
	
	// 3. Calcular estadísticos robustos dentro de cada plaguicida
	** 3.1. Mediana 
	by nomb_plag post: egen med_1 = median(ln_cx`m'_plag) if nomb_plag!="No Especifica"
	by nomb_plag post: egen med_2 = median(cx`m'_plag) 	  if nomb_plag!="No Especifica"
	
	** 3.2. MAD (Median Absolute Deviation)
	gen double abs_dev_1 = abs(ln_cx`m'_plag 	- med_1) if nomb_plag!="No Especifica"
	gen double abs_dev_2 = abs(cx`m'_plag 	- med_2) if nomb_plag!="No Especifica"
	by nomb_plag post: egen mad_1 = median(abs_dev_1) if nomb_plag!="No Especifica"
	by nomb_plag post: egen mad_2 = median(abs_dev_2) if nomb_plag!="No Especifica"
	drop abs_dev_*

	// 4. Generar los Z-SCORE modificados y límites sup. e inf. para capear
	gen double zmod_1 = .
	gen double zmod_2 = .
	replace zmod_1 =  0.6745*(ln_cx`m'_plag - med_1)/mad_1 if mad_1>0 & !mi(ln_cx`m'_plag,med_1,mad_1) & nomb_plag!="No Especifica"
	replace zmod_2 =  0.6745*(cx`m'_plag - med_2)/mad_2 	 if mad_2>0 & !mi(cx`m'_plag,med_2,mad_2)    & nomb_plag!="No Especifica"	
	gen double ln_hi = med_1 + (3.5/0.6745)*mad_1 	if !mi(med_1,mad_1) & nomb_plag!="No Especifica"
	gen double ln_lo = med_1 - (3.5/0.6745)*mad_1 	if !mi(med_1,mad_1) & nomb_plag!="No Especifica"
	gen double hi 	 = med_2 + (3.5/0.6745)*mad_2	if !mi(med_2,mad_2) & nomb_plag!="No Especifica"
	gen double lo 	 = med_2 - (3.5/0.6745)*mad_2	if !mi(med_2,mad_2) & nomb_plag!="No Especifica"
	// Nota: 0.6745 normaliza el MAD para que sea comparable con la desvest bajo 
	// normalidad (pero sin requerir que los datos sean normales)
	
	// 5. "Flaggear" outliers mayores/menores a criterio robusto (z-modificado de 3.5)
	gen flag_out1_35 	= 0 
	gen flag_out2_35 	= 0 	
	replace flag_out1_35 = 1 if abs(zmod_1)>3.5 & !mi(zmod_1)
	replace flag_out2_35 = 1 if abs(zmod_2)>3.5 & !mi(zmod_2)
	
	// 6. Crear precios winsorizosados e imputando con missings a outliers
	// Winsorización 1 y 2:
	// Capar en el umbral robusto (mediana ± (3.5/0.6745)*MAD) retransformado en niveles para wz1,
	// y en niveles para wz2, si > 10 obs del plaguicida.
	// Imputar mediana a outliers de var. en logs (1) y en niveles (2) si <= 10 obs en el cultivo
	gen double cx`m'_plag_wz1 = . , a(ln_cx`m'_plag)
	gen double cx`m'_plag_wz2 = . , a(cx`m'_plag_wz1)
	gen double cx`m'_plag_mis = . , a(cx`m'_plag_wz2)

	// Capar en el umbral robusto si hay más de 10 obs.
	replace cx`m'_plag_wz1 = exp(ln_lo)  	if flag_out1_35==1 & zmod_1<0 & counter>10 & mad_1>0
	replace cx`m'_plag_wz2 = lo  			if flag_out2_35==1 & zmod_2<0 & counter>10 & mad_2>0
	replace cx`m'_plag_wz1 = exp(ln_hi)  	if flag_out1_35==1 & zmod_1>0 & counter>10 & mad_1>0
	replace cx`m'_plag_wz2 = hi  			if flag_out2_35==1 & zmod_2>0 & counter>10 & mad_2>0
		
	// Imputar mediana si hay 10 o menos obs
	replace cx`m'_plag_wz1 = med_2 	if flag_out1_35==1 & counter<=10
	replace cx`m'_plag_wz2 = med_2 	if flag_out2_35==1 & counter<=10
	
	// Reemplazar los demás casos con la variable original
	replace cx`m'_plag_wz1 = cx`m'_plag if mi(cx`m'_plag_wz1)
	replace cx`m'_plag_wz2 = cx`m'_plag if mi(cx`m'_plag_wz2)
	
	// Imputar missing cuando se detecta como outlier con la var en logs o niveles
	replace cx`m'_plag_mis = cx`m'_plag if flag_out1_35==0 & flag_out2_35==0
	
	// 7. Eliminar las variables que no usaremos y quedar con relevantes
	drop counter ln_* hi lo med_* mad_* zmod_* flag_*
	keep Codprod22-post n_plag nomb_plag tipo_plag `m'_plag cx`m'_plag cx`m'_plag_*
	
	// Llevar a nivel de cultivo
	ren (nomb_plag tipo_plag `m'_plag cx`m'_plag cx`m'_plag_wz1 cx`m'_plag_wz2 cx`m'_plag_mis) ///
		(nomb_plag_ tipo_plag_ `m'_plag_ cx`m'_plag_ cx`m'_plag_wz1_ cx`m'_plag_wz2_ cx`m'_plag_mis_)
		
	reshape wide nomb_plag_ tipo_plag_ `m'_plag_ cx`m'_plag_ cx`m'_plag_wz1_ cx`m'_plag_wz2_ cx`m'_plag_mis_, i(Codprod22-post) j(n_plag)
	sort Codprod22-post 
	
	// 8. Generar costos totales por cada plaguicida
	forval i = 1/5{
		gen double ctot_`m's_plag_`i' 	= `m'_plag_`i' * cx`m'_plag_`i' 
		gen double ctot_`m's_plag_wz1_`i' = `m'_plag_`i' * cx`m'_plag_wz1_`i' 
		gen double ctot_`m's_plag_wz2_`i' = `m'_plag_`i' * cx`m'_plag_wz2_`i'
		gen double ctot_`m's_plag_mis_`i' = `m'_plag_`i' * cx`m'_plag_mis_`i'
	}
	
	// 9. Generar costos totales por todos los plaguicidas usados en el cultivo para cada tipo de variable
	egen double ctot_`m's_plag_culp = rowtotal(ctot_`m's_plag_1 ctot_`m's_plag_2 ctot_`m's_plag_3 ctot_`m's_plag_4 ctot_`m's_plag_5) , m
	egen double ctot_`m's_plag_wz1_culp = rowtotal(ctot_`m's_plag_wz1_1 ctot_`m's_plag_wz1_2 ctot_`m's_plag_wz1_3 ctot_`m's_plag_wz1_4 ctot_`m's_plag_wz1_5) , m
	egen double ctot_`m's_plag_wz2_culp = rowtotal(ctot_`m's_plag_wz2_1 ctot_`m's_plag_wz2_2 ctot_`m's_plag_wz2_3 ctot_`m's_plag_wz2_4 ctot_`m's_plag_wz2_5) , m
	egen double ctot_`m's_plag_mis_culp = rowtotal(ctot_`m's_plag_mis_1 ctot_`m's_plag_mis_2 ctot_`m's_plag_mis_3 ctot_`m's_plag_mis_4 ctot_`m's_plag_mis_5) , m
	
	// 10. Generar Litros/Kilos de plaguicida empleados en el cultivo principal
	egen `m'_plag_culp_ppc = rowtotal(`m'_plag_1 `m'_plag_2 `m'_plag_3 `m'_plag_4 `m'_plag_5), m
	
	// 11. Etiquetas
	if "`m'"=="lt"{
		local ud "Litros"
	}
	else{
		local ud "Kilos"
	}
	lab var `m'_plag_culp_ppc 		"`ud' de plaguicida empleados en el cultivo principal"
	lab var ctot_`m's_plag_culp		"Costo Total (en S/.) por los `=strlower("`ud'")' en plaguicida en el cultivo principal"
	lab var ctot_`m's_plag_wz1_culp "Costo Total (en S/.) por los `=strlower("`ud'")' en plaguicida en el cultivo principal - capeo 1 (var en logs)"
	lab var ctot_`m's_plag_wz2_culp "Costo Total (en S/.) por los `=strlower("`ud'")' en plaguicida en el cultivo principal - capeo 2 (var en nivs)"
	lab var ctot_`m's_plag_mis_culp "Costo Total (en S/.) por los `=strlower("`ud'")' en plaguicida en el cultivo principal - outliers a missings"

	keep Codprod22-post *_culp *_ppc
	sort Codprod22-post
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
	save "`outc6'\\Totales_plag_en_`m'_x_cultivo.dta", replace
	restore 
}