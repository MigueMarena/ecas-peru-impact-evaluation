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
// Correcciones en el original: 0 de DNI, 131 de nombre/apellido.
// Este archivo NO es ejecutable en su forma redactada.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// File           : fix_producer_names.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Correcciones manuales a nombres y apellidos de productores
//                  y miembros del hogar en la base de Personas.
//------------------------------------------------------------------------------

version 19.0
// APELLIDOS
replace preg001a="<NOMBRE_REDACTADO>"		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>"

replace preg001a="<NOMBRE_REDACTADO>" if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 		if preg001b=="<NOMBRE_REDACTADO>" // & preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"  if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>" & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>" & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"		if preg001a=="<NOMBRE_REDACTADO>" & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"    if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>" & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 			if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"			if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>" & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>" // & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 			if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 			if preg001a=="<NOMBRE_REDACTADO>" & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 			if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 	if preg001a=="<NOMBRE_REDACTADO>" & preg001b=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"	if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>" 		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"		if preg001a=="<NOMBRE_REDACTADO>"
replace preg001a="<NOMBRE_REDACTADO>"			if preg001a=="<NOMBRE_REDACTADO>"

// NOMBRES
replace preg001b="<NOMBRE_REDACTADO>" if preg001b=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 		if preg001b=="<NOMBRE_REDACTADO>" 	& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 			if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>"			if preg001b=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 			if preg001b=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 	  	if preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 			if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"  
replace preg001b="<NOMBRE_REDACTADO>" 	if preg001b=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 			if preg001b=="<NOMBRE_REDACTADO>" & preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>"			if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>"		if preg001b=="<NOMBRE_REDACTADO>"	    & preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 			if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 		if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 			if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" if preg001b=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>"		if preg001b=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>"			if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 	if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 		if preg001b=="<NOMBRE_REDACTADO>" 		& preg001a=="<NOMBRE_REDACTADO>"
replace preg001b="<NOMBRE_REDACTADO>" 	if preg001b=="<NOMBRE_REDACTADO>"