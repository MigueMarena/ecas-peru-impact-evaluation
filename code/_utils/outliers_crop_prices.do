//----------------------------------------------------------------------
// File           : outliers_crop_prices.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Detecta y reemplaza outliers en precios de cultivos
//                  (ixkg_ppc) usando el metodo de Median Absolute Deviation
//                  (MAD) con umbral 3.
//----------------------------------------------------------------------

// Preliminares:
// 0. Arreglar la data en función a los valores del código del cultivo y pre-post
// 1. Generar una variable que cuente el número de obs por cultivo con precios
sort preg114b1 post
by preg114b1 post: egen counter = count(ixkg_ppc) if ixkg_ppc!=.

// 1. Generar variable en logaritmos
gen ln_ixkg_ppc = ln(ixkg_ppc)

// 2. Calcular estadísticos robustos dentro de cada cultivo
** 2.1. Mediana
by preg114b1 post: egen med_1 = median(ln_ixkg_ppc)	if !mi(ln_ixkg_ppc)
by preg114b1 post: egen med_2 = median(ixkg_ppc) 		if !mi(ixkg_ppc)

** 2.2. MAD (Median Absolute Deviation)
gen double abs_dev_1 = abs(ln_ixkg_ppc - med_1)
gen double abs_dev_2 = abs(ixkg_ppc - med_2)
by preg114b1 post: egen mad_1 = median(abs_dev_1) if !mi(ln_ixkg_ppc)
by preg114b1 post: egen mad_2 = median(abs_dev_2) if !mi(ixkg_ppc)
drop abs_dev_*

// 3. Generar los Z-SCORE modificados y límites sup. e inf. para capear
gen double zmod_1 = .
gen double zmod_2 = .
replace zmod_1 =  0.6745*(ln_ixkg_ppc - med_1)/mad_1 	if mad_1>0 & !mi(ln_ixkg_ppc,med_1,mad_1)
replace zmod_2 =  0.6745*(	 ixkg_ppc - med_2)/mad_2 	if mad_2>0 & !mi(ixkg_ppc,med_2,mad_2)
gen double ln_hi = med_1 + (3.5/0.6745)*mad_1 	if !mi(med_1,mad_1)
gen double ln_lo = med_1 - (3.5/0.6745)*mad_1 	if !mi(med_1,mad_1)
gen double hi 	 = med_2 + (3.5/0.6745)*mad_2	if !mi(med_2,mad_2)
gen double lo 	 = med_2 - (3.5/0.6745)*mad_2	if !mi(med_2,mad_2)
// Nota: 0.6745 normaliza el MAD para que sea comparable con la desvest bajo 
// normalidad (pero sin requerir que los datos sean normales)

// 4. "Flaggear" outliers mayores/menores a criterio robusto (z-modificado de 3.5)
gen flag_out1_35 	= 0 if !mi(ln_ixkg_ppc)
gen flag_out2_35 	= 0 if !mi(ixkg_ppc)
replace flag_out1_35 = 1 if abs(zmod_1)>3.5 & !mi(zmod_1)
replace flag_out2_35 = 1 if abs(zmod_2)>3.5 & !mi(zmod_2)

// 5. Crear precios winsorizosados e imputando con missings a outliers
// Winsorización 1 y 2:
// Capar en el umbral robusto (mediana ± (3.5/0.6745)*MAD) retransformado en niveles para wz1,
// y en niveles para wz2, si > 10 obs en el cultivo.
// Imputar mediana a outliers de var. en logs (1) y en niveles (2) si <= 10 obs en el cultivo
gen double ixkg_ppc_wz1 = .
gen double ixkg_ppc_wz2 = .
gen double ixkg_ppc_mis = .

// Capar en el umbral robusto si hay más de 10 obs.
replace ixkg_ppc_wz1 = exp(ln_lo)	if flag_out1_35==1 & zmod_1<0 & counter>10 & mad_1>0
replace ixkg_ppc_wz2 = lo  			if flag_out2_35==1 & zmod_2<0 & counter>10 & mad_2>0
replace ixkg_ppc_wz1 = exp(ln_hi) 	if flag_out1_35==1 & zmod_1>0 & counter>10 & mad_1>0
replace ixkg_ppc_wz2 = hi  			if flag_out2_35==1 & zmod_2>0 & counter>10 & mad_2>0

// Imputar mediana si hay 10 o menos obs
replace ixkg_ppc_wz1 = med_2 	if flag_out1_35==1 & counter<=10 
replace ixkg_ppc_wz2 = med_2 	if flag_out2_35==1 & counter<=10 

// Reemplazar los demás casos con la variable original 
replace ixkg_ppc_wz1 = ixkg_ppc if mi(ixkg_ppc_wz1)
replace ixkg_ppc_wz2 = ixkg_ppc if mi(ixkg_ppc_wz2)

// Imputar missing cuando se detecta como outlier con la var en logs o niveles 
replace ixkg_ppc_mis = ixkg_ppc if flag_out1_35!=1 & flag_out2_35!=1 

// 6. Eliminar las variables que no usaremos
drop counter ln_* hi lo med_* mad_* zmod_* flag_*
sort ppc_id post