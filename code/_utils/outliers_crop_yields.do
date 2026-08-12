//----------------------------------------------------------------------
// File           : outliers_crop_yields.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Detecta y reemplaza outliers en rendimientos de cultivos
//                  (kgxha, kgx1p, kgxkg_sem) usando MAD con umbral 3.
//----------------------------------------------------------------------
sort preg114b1
foreach v in kgxha_semb_ppc kgx1p_eprod_ppc kgxkg_sem_ppc{
	// 1. Generar variable que cuente el número de obs por cultivo (solo con rend. > 0)
	by preg114b1: egen counter = count(`v') if `v'!=. & `v'>0

	// 2. Generar variable en logaritmos
	gen ln_`v' = ln(`v') if `v'!=. & `v'>0

	// 3. Calcular estadísticos robustos dentro de cada cultivo
	** 3.1. Mediana
	by preg114b1: egen med_1 = median(ln_`v')	if !mi(ln_`v') & `v'>0 
	by preg114b1: egen med_2 = median(`v') 		if !mi(`v')    & `v'>0 

	** 3.2. MAD (Median Absolute Deviation)
	gen double abs_dev_1 = abs(ln_`v' - med_1) 	if !mi(ln_`v') & `v'>0
	gen double abs_dev_2 = abs(`v' - med_2)		if !mi(`v')    & `v'>0
	by preg114b1: egen mad_1 = median(abs_dev_1) if !mi(ln_`v') & `v'>0
	by preg114b1: egen mad_2 = median(abs_dev_2) if !mi(`v')	   & `v'>0
	drop abs_dev_*

	// 4. Generar los Z-SCORE modificados y límites sup. e inf. para capear
	gen double zmod_1 = .
	gen double zmod_2 = .
	replace zmod_1 =  0.6745*(ln_`v' - med_1)/mad_1 	if mad_1>0 & !mi(ln_`v',med_1,mad_1)
	replace zmod_2 =  0.6745*(	 `v' - med_2)/mad_2 	if mad_2>0 & !mi(`v',med_2,mad_2)
	gen double ln_hi = med_1 + (3.5/0.6745)*mad_1 	if !mi(med_1,mad_1)
	gen double ln_lo = med_1 - (3.5/0.6745)*mad_1 	if !mi(med_1,mad_1)
	gen double hi 	 = med_2 + (3.5/0.6745)*mad_2	if !mi(med_2,mad_2)
	gen double lo 	 = med_2 - (3.5/0.6745)*mad_2	if !mi(med_2,mad_2)
	// Nota: 0.6745 normaliza el MAD para que sea comparable con la desvest bajo 
	// normalidad (pero sin requerir que los datos sean normales)

	// 5. "Flaggear" outliers mayores/menores a criterio robusto (z-modificado de 3.5)
	gen flag_out1_35 	= 0 if !mi(ln_`v') & `v'>0
	gen flag_out2_35 	= 0 if !mi(`v') & `v'>0
	replace flag_out1_35 = 1 if abs(zmod_1)>3.5 & !mi(zmod_1)
	replace flag_out2_35 = 1 if abs(zmod_2)>3.5 & !mi(zmod_2)

	// 6. Crear precios winsorizosados e imputando con missings a outliers
	// Winsorización 1 y 2:
	// Capar en el umbral robusto (mediana ± (3.5/0.6745)*MAD) retransformado en niveles para wz1,
	// y en niveles para wz2, si > 10 obs en el cultivo.
	// Imputar mediana a outliers de var. en logs (1) y en niveles (2) si <= 10 obs en el cultivo
	gen double `v'_wz1 = .
	gen double `v'_wz2 = .
	gen double `v'_mis = .

	// Capar en el umbral robusto si hay más de 10 obs.
	replace `v'_wz1 = exp(ln_lo)	if flag_out1_35==1 & zmod_1<0 & counter>10 & mad_1>0
	replace `v'_wz2 = lo  			if flag_out2_35==1 & zmod_2<0 & counter>10 & mad_2>0
	replace `v'_wz1 = exp(ln_hi) 	if flag_out1_35==1 & zmod_1>0 & counter>10 & mad_1>0
	replace `v'_wz2 = hi  			if flag_out2_35==1 & zmod_2>0 & counter>10 & mad_2>0

	// Imputar mediana si hay 10 o menos obs
	replace `v'_wz1 = med_2 	if flag_out1_35==1 & counter<=10 
	replace `v'_wz2 = med_2 	if flag_out2_35==1 & counter<=10 

	// Reemplazar los demás casos con la variable original 
	replace `v'_wz1 = `v' if mi(`v'_wz1)
	replace `v'_wz2 = `v' if mi(`v'_wz2)

	// Imputar missing cuando se detecta como outlier con la var en logs o niveles 
	replace `v'_mis = `v' if flag_out1_35!=1 & flag_out2_35!=1
	
	// 7. Eliminar las variables que no usaremos
	drop counter ln_* hi lo med_* mad_* zmod_* flag_*
	
	// 8. Ordenar las variables creadas
	order `v'_wz1, a(`v')
	order `v'_wz2, a(`v'_wz1)
	order `v'_mis, a(`v'_wz2)
}
sort ppc_id post