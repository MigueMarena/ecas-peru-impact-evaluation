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
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
if "${ruta_data}" == "" {
	capture qui include "${ECAS}/2_Scripts/A_master.do"
	if _rc capture qui include "2_Scripts/A_master.do"
	if "${ruta_data}" == "" {
		di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
		di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
		exit 601
	}
}

// Rutas derivadas del global ${ruta_data}. Este helper se invoca con `do', que
// abre un scope nuevo: los locales `outc*' que define A_master.do NO llegan
// hasta acá. Mismo patrón que prg_load_panel.do.
local outc3ccpp "${ruta_data}/Out/3_Centros Poblados y su Estatus de Tratamiento/CCPP"

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