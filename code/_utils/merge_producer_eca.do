//----------------------------------------------------------------------
// File           : merge_producer_eca.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Asigna a cada productor que asistio: producto, tipo y nombre
//                  de ECA, fechas de inicio/fin, promedio obtenido y estado de
//                  tratamiento.
//----------------------------------------------------------------------
// Do-file de cruce 2: Asigna a cada productor que asistió el producto, tipo,
// nombre de ECA, la fecha de inicio y fin de ECA, el promedio que obtuvo el
// productor en la ECA y su estatus de tratamiento (pariticipación/graduación)

// --- Llamar do-file con rutas ---
// Bootstrap robusto en batch fresh (fix bug ${ruta_scripts}; ver script 30).
if "${CONSULT}" == "" qui do "C:\\Users\\carlo\\ado\\personal\\profile.do"
qui include "${CONSULT}\\BID\\HRC0052956\\2_Scripts\\A_master.do"
des using "`outc3prod'\PRODUCTORES_2021_CCPPs_ALEA"

// --- Crear base para cruce ---
preserve
use "`outc3prod'\PRODUCTORES_2021_CCPPs_ALEA", clear
ren nomb_ccpp nomb_ccpp_ECA
gen tiempo_d_ECA = datediff(fch_ini_ECA, fch_fin_ECA, "d")
lab var nomb_ccpp_ECA 	"Nombre de Centro Poblado en que capacitó la ECA"
lab var tiempo_d_ECA	"Duración (días) de la ECA"
keep dni_prod nomb_ccpp_ECA prod_ECA fch_ini tiempo_d ssns_* *_ssns_* graduado
order dni_prod nomb_ccpp_ECA prod_ECA fch_ini tiempo_d ssns_* *_ssns_* graduado
tempfile productores2021
save `productores2021'
restore 

// --- Cruce ---
merge 1:1 dni using `productores2021', gen(_m1) force // 06/05/2026: 337 match.

// NO CORRER (SOLO PARA CORROBORAR QUE CRUCE USANDO DNIs Y NOMBRES DA MISMO RESULTADO)
// # delimit ;
// reclink2 nomb_rgn nomb_prvnc nomb_dstrt nomb_prod apell_prod using "`outc3prod'\PRODUCTORES_2021_CCPPs_ALEA",
	// idm(idm) idu(idu) gen(score) wm(15 15 15 12 12) _m(_m) uprefix(u_) npairs(1);
// #delimit cr

// --- Registros en base master o que emparejaron
keep if _m1==1 | _m1==3
drop _m1

// --- Generar variable de tratamiento a nivel de productor ---
// 	1: PARTICIPA 	(solo en ECAs de cultivo de interés o de los 3 cultivos)
//  2: PARTICIPA Y SE GRADUA (solo en ECAs de cultivo de interés o de los 3 cultivos)
lab def asst 0 "No participa" 1 "Participa"
lab def grad 0 "No graduado"  1 "Graduado"

gen ptcp_ECA_prod:asst = (graduado==0|graduado==1) & inlist(prod_ECA,12,15,16,19), a(graduado)
gen grad_ECA_prod:grad = (graduado==1) & inlist(prod_ECA,12,15,16,19), a(ptcp_ECA_prod)
drop graduado

lab var ptcp_ECA_prod "Productor participa de la ECA en alguno de los cultivos de interés"
lab var grad_ECA_prod "Productor se gradua de la ECA en alguno de los cultivos de interés"

// --- Ordenar la data
sort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp ordenprod
order nomb_ccpp_ECA-grad_ECA_prod, a(cumpl_flx_ccpp)