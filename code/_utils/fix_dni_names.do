//------------------------------------------------------------------------------
// NOTA DE PUBLICACIÓN — este archivo fue REDACTADO automáticamente.
//
// El original aplica correcciones manuales sobre identificadores nominales de
// productores (DNI, nombres, apellidos). Esos valores son datos personales y no
// pueden publicarse, así que fueron reemplazados por marcadores.
//
// Se publica igual, y no se omite, porque la existencia de estas correcciones
// es información metodológica: las bases fueron parchadas a mano antes de los
// cruces, y un lector que audite el pipeline necesita saberlo. Lo que no puede
// ver son los valores.
//
// Correcciones en el original: 86 de DNI, 122 de nombre/apellido.
// Este archivo NO es ejecutable en su forma redactada.
//------------------------------------------------------------------------------

//----------------------------------------------------------------------
// File           : fix_dni_names.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Correcciones manuales a numeros de DNI y nombres de
//                  productores en las bases donde el DNI es identificador
//                  para cruce.
//----------------------------------------------------------------------
// CORRECCION DE DNIs
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 		& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>" // NO ES EL dni_prod CORRECTO
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 		& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 		& apell_prod=="<NOMBRE_REDACTADO>"
replace nomb_prod = "<NOMBRE_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace apell_prod = "<NOMBRE_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>"  	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>" // NO ES EL dni_prod CORRECTO
replace apell_prod = "<NOMBRE_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 		& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if nomb_prod=="<NOMBRE_REDACTADO>" 	& apell_prod=="<NOMBRE_REDACTADO>"
replace dni_prod = "<DNI_REDACTADO>" if dni_prod=="<DNI_REDACTADO>" 		& nomb_prod=="<NOMBRE_REDACTADO>"

// NOMBRES
replace nomb_prod="<NOMBRE_REDACTADO>" 	if nomb_prod=="<NOMBRE_REDACTADO>" & dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 			if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 			if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 			if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>"  if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 		if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 	if nomb_prod=="<NOMBRE_REDACTADO>" & apell_prod=="<NOMBRE_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 		if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>"			if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>"  	if dni_prod=="<DNI_REDACTADO>" 
replace nomb_prod="<NOMBRE_REDACTADO>" if dni_prod == "<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 			if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>"			if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace nomb_prod="<NOMBRE_REDACTADO>"	if dni_prod=="<DNI_REDACTADO>"

// APELLIDOS
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"   	if dni_prod == "<DNI_REDACTADO>" 
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"  	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"    	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"  	if dni_prod=="<DNI_REDACTADO>" 
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"  	if dni_prod=="<DNI_REDACTADO>" 
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"     if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"  	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"		if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>"    if dni_prod=="<DNI_REDACTADO>"
replace apell_prod="<NOMBRE_REDACTADO>" 	if dni_prod=="<DNI_REDACTADO>"
