//----------------------------------------------------------------------
// File           : fix_ccpp_names.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 04/05/2026
// Description    : Correcciones manuales a nombres de centros poblados (nomb_ccpp).
// 					Se hicieron cambios a lineas 28 y 33 en función a definición
// 					explícita de cumplimiento. Las ECAs no son implementadas en 
//					esos centros exactamente.
//----------------------------------------------------------------------
replace nomb_ccpp="AHIJADERO"		if 	nomb_ccpp=="AIJADERO" | regexm(nomb_ccpp,"AHIJADERO") & nomb_dstrt=="SAN JUAN"
replace nomb_ccpp="ALTO SHIMA" 		if	nomb_ccpp=="CANAAN" & nomb_dstrt=="RIO TAMBO" /*1*/
replace nomb_ccpp="ALTO TOTERANI" 	if nomb_ccpp=="MARANKIARI BAJO (MARANQUIARI)" /*2*/
replace nomb_ccpp="BAJO MARANQUIARI" if nomb_ccpp=="BAJO MARANKIARI" & nomb_dstrt=="SATIPO"
replace nomb_ccpp="ANEXO 14 IVITA"	 if  nomb_ccpp=="14 IVITA" & nomb_dstrt=="SAN RAMON"
replace nomb_ccpp="CARMEN ALTO" 	if 	nomb_ccpp=="CARMEN ALTO (SACHIN)"
replace nomb_ccpp="CUTICCSA"		if 	nomb_ccpp=="CUTICCSA (EUTICSA GRANDE)" | nomb_ccpp=="CUTICSA"
replace nomb_ccpp="EPEMIMU"			if	nomb_ccpp=="CHIRIACO" 			/*3*/
// replace nomb_ccpp="FLOR DE LA FRONTERA" if	nomb_ccpp=="QUIRACAS"   /*4*/ -> ECA fue en QUIRACAS, hay derrame a FLOR DE LA FRONTERA.
replace nomb_ccpp="HUAMARIN"		if  regexm(nomb_ccpp, "HUAMARIN")
replace nomb_ccpp="HUANCCO PILLPINTO" if nomb_ccpp=="HUANCO PILLPINTO"
replace nomb_ccpp="LLAÑUCANCHA"		if 	nomb_ccpp=="LLANO CANCHA"
replace nomb_ccpp="LOBERA"			if 	nomb_ccpp=="SAN RAMON DE PANGOA" & nomb_dstrt=="PANGOA" /*5*/
replace nomb_ccpp="NARANJO CHACAS" 	if nomb_ccpp=="NARANJOS CHACA"
replace nomb_ccpp="PARARIN"   		if 	regexm(nomb_ccpp, "PARARIN")
replace nomb_dstrt="POLVORA"		if 	nomb_dstrt=="SANTA LUCIA" & nomb_ccpp=="LABOYACU"
replace nomb_ccpp="PUERTO RICO" 	if 	nomb_dstrt=="POLVORA" & nomb_ccpp=="LABOYACU"
replace nomb_ccpp="PURRAYO"   		if 	regexm(nomb_ccpp, "PURRAYO")
replace nomb_ccpp="RUMICHACA BAJA" 	if nomb_ccpp=="RUMICHACA" & nomb_dstrt=="URUBAMBA"
// replace nomb_ccpp="SANTA ANA"	if 	nomb_ccpp=="SANTA ROSA" & nomb_dstrt=="SANTA ANA" /*6*/ -> ECA fue en SANTA ROSA, hay derrame a SANTA ANA.
replace nomb_ccpp="TRES UNIDOS"		if  nomb_ccpp=="BELLO HORIZONTE" & nomb_dstrt=="TRES UNIDOS" /*7*/
replace nomb_ccpp="TZANCUVATZIARI" 	if nomb_ccpp=="TZANCUVATZARI"
replace nomb_ccpp="VILCABAMBA" 		if 	regexm(nomb_ccpp, "VILCABAMBA") 
replace nomb_ccpp="ZONA 08" 		if	nomb_ccpp=="SAN LUIS DE SHUARO" /*8*/
// replace nomb_ccpp="ZAPACTO" 		if 	nomb_ccpp=="POQUES" 			/*9*/ -> ECA fue en POQUES, hay derrame a ZAPACTO.
