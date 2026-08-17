//------------------------------------------------------------------------------
// File           : merge_ccpp_status.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Asigna a cada CCPP su estado de asignacion al tratamiento
//                  y su estado final de tratamiento mediante cruce por strings
//                  (region, provincia, distrito, centro poblado).
//------------------------------------------------------------------------------

version 19.0
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
// la única entrada de configuración del pipeline (ver config.do).
// config.do se incluye SIEMPRE, sin guardarlo tras un `if' sobre alguna
// global: define locales (`outc1', `rawc1', …) y `do' abre un scope nuevo,
// así que los locales del llamador NO llegan hasta aquí. Saltarse el include
// porque las globals ya existan deja al script sin rutas y falla con r(601).
// `include' es idempotente: solo redefine rutas y crea carpetas con `cap'.
capture qui include "${ECAS}/2_Scripts/A_setup/config.do"
if _rc capture qui include "2_Scripts/A_setup/config.do"
if "${ruta_data}" == "" {
	di as error "No encuentro config.do. Define la global ECAS con la ruta"
	di as error "a la raíz del repositorio, o ejecuta Stata desde esa raíz."
	exit 601
}

// Rutas derivadas del global ${ruta_data}. Este helper se invoca con `do', que
// abre un scope nuevo: los locales `outc*' que define config.do NO llegan
// hasta aquí. Mismo patrón que prg_load_panel.do.
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