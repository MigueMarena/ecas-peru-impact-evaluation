//------------------------------------------------------------------------------
// File           : _utils/install_ado.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 12/08/2026
// Description    : Instala los comandos de terceros que usa el pipeline.
//                  Se corre UNA VEZ por máquina, a mano:
//
//                      do 2_Scripts/_utils/install_ado.do
//
//                  No lo invoca ningún script del pipeline: instalar paquetes
//                  es un efecto sobre la máquina, no un paso del análisis, y no
//                  debe ocurrir en medio de una corrida.
//
//                  Las estimaciones principales usan comandos NATIVOS de Stata
//                  (areg, ivregress 2sls) y las tablas usan putdocx y collect,
//                  también nativos. Lo de abajo es todo lo externo que hace
//                  falta, y es corto a propósito.
//
// Input            : (ninguno)
// Output           : comandos instalados en PERSONAL/PLUS
//------------------------------------------------------------------------------

version 19.0

//==============================================================================
// Comandos de SSC
//==============================================================================
// reclink2   -> E2_build_producer_sociodem.do, _utils/merge_ccpp_status.do
//               Vinculación aproximada de nombres de productor y de CCPP.
// labutil    -> E1_build_obs_chars.do
// xframeappend -> E2_build_producer_sociodem.do

local paquetes reclink2 labutil xframeappend

foreach p of local paquetes {
	capture which `p'
	if _rc {
		di as text "Instalando `p'..."
		capture noisily ssc install `p', replace
		if _rc di as error "  No se pudo instalar `p' (r(" _rc "))."
	}
	else di as text "`p' ya está instalado."
}

//==============================================================================
// Verificación
//==============================================================================
di as text _n "{hline 60}"
local faltan ""
foreach p of local paquetes {
	capture which `p'
	if _rc local faltan `faltan' `p'
}
if "`faltan'" == "" {
	di as result "Todos los comandos externos están disponibles."
}
else {
	di as error "Faltan: `faltan'"
	di as error "Instalalos a mano antes de correr el pipeline."
}
di as text "{hline 60}"
