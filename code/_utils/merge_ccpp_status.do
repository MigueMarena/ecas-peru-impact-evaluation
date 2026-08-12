//----------------------------------------------------------------------
// File           : merge_ccpp_status.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Asigna a cada CCPP su estado de asignacion al tratamiento
//                  y su estado final de tratamiento mediante cruce por strings
//                  (region, provincia, distrito, centro poblado).
//----------------------------------------------------------------------
// Do-file de cruce 1: Asigna a cada CCPP su estado de asignación y su estado
// final de tratamiento.

// CRUCE ENTRE BDs CON STRINGS
// LLAVES: 
// 	- Nombre de región.
// 	- Nombre de provincia.
// 	- Nombre de distrito.
// 	- Nombre de centro poblado.
// 	Base using es CCPPALEAy1AECA_ESTAT_CUMPL.dta.

// --- Llamar do-file con rutas ---
// Bootstrap robusto en batch fresh (fix bug ${ruta_scripts}; ver script 30).
if "${CONSULT}" == "" qui do "C:\\Users\\carlo\\ado\\personal\\profile.do"
include "${CONSULT}\\BID\\HRC0052956\\2_Scripts\\A_master.do"

// --- Cruce ---
# delimit ;	
reclink2 nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp 
	using "`outc3ccpp'\CCPPALEAy1AECA_ESTAT_CUMPL.dta", 
	idm(idm) idu(idu) gen(score) wm(15 15 15 8) _m(_m) uprefix(u_) npairs(1);
#delimit cr 
  	
order 	nomb_rgn 	u_nomb_rgn 		///
		nomb_prvnc 	u_nomb_prvnc 	///
		nomb_dstrt 	u_nomb_dstrt 	///
		nomb_ccpp 	u_nomb_ccpp 	///
		asig_ccpp 	, a(codeca)
order asig_ccpp prod_ECA_eval, b(producto)
order prod_1aECA, a(producto)
order fch_ini_1aECA tiempo_d_1aECA per_* astn_1aECA_ccpp-cumpl_flx_ccpp, a(prod_1aECA)

// --- Cambios menores
drop  nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp score idm idu nomb_ccpp_* año_ini_* _m 
ren u_* *