//----------------------------------------------------------------------
// File           : clean_pesticide_names.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Limpia y estandariza nombres de plaguicidas (preg114x2*).
//                  Anula no-plaguicidas, crea variables de nombre, tipo, cantidad
//                  y costo, y homogeniza cientos de nombres comerciales.
//----------------------------------------------------------------------
# delimit ;	
local noplagui 
	" 
	"ABONO FOLIAR" "ACEITE VEGETAL" "BIOL" "BIO CIME" "CAMARON DEL GUSANO" 
	"COLOR EXCEL" "CUROHUAÑUCHIQ" "EXTRAFOLLAJE" "FOLIAJE" "FOLLAJE" "FOLLAJES"
	"FOSFATO DIAMONICO, POTASIO, NPK" "GOMA" "GOMA AGRICOLA" "LECHE DE HORMIGA" 
	"MACHETIADORA" "MELASA" "MELASA DE CAÑA" "NICOVITA" "UTILIZO INICIO" "SAL"
	"TRAMPERAS PARA MOSCA" "TRAMPAS PARA MOSCA" "3" "88" 
	";
# delimit cr

// Modificar valores de variables de productos que se identifican no plaguicidas
foreach npl of local noplagui{
	forval i = 1/5{
		replace preg114x1_`i' = 0 if preg114x2a_`i'=="`npl'"
		foreach v of varlist preg114x2b_`i'-preg114x2h_`i'{
			cap confirm numeric var `v'
			if !_rc{
				replace `v' = .  if preg114x2a_`i'=="`npl'" 
			}
			else{
				replace `v' = "" if preg114x2a_`i'=="`npl'"
			}
		}
		replace preg114x2a_`i'=""  if preg114x2a_`i'=="`npl'"
	}
}

// Crear variables (nombre, tipo, kilos, litros y costo por kg/lt de plaguicida)
forval i=1/5{
	gen nomb_plag_culp_ppc_`i' = "" , a(preg114x2a_`i')
	gen tipo_plag_culp_ppc_`i' = .  , a(nomb_plag_culp_ppc_`i')
	gen kg_plag_culp_ppc_`i'   = .  , a(tipo_plag_culp_ppc_`i')
	gen lt_plag_culp_ppc_`i'   = .  , a(kg_plag_culp_ppc_`i')
	gen cxkg_plag_culp_ppc_`i' = .  , a(lt_plag_culp_ppc_`i')
	gen cxlt_plag_culp_ppc_`i' = .  , a(cxkg_plag_culp_ppc_`i')
}

// Reemplazar por valores nuevos (agrupa catorías, corrige, etc.)
forval i = 1/5{
	// Agrupar en una categoría productos que no especifican una marca
	replace nomb_plag_culp_ppc_`i' = "No Especifica" if ///
		preg114x2a_`i'=="." |  	///
		preg114x2a_`i'=="NO"| 	///
		preg114x2a_`i'=="NR"| 	///
		preg114x2a_`i'=="PLAGUICIDA ECUATORIANO"	|	///
		preg114x2a_`i'=="PLAGUICIDA ECUATORIANA" 	| 	///
		preg114x2a_`i'=="SE OLVIDO" | ///
		preg114x2a_`i'=="UN PREPARADO" | ///
		regexm(preg114x2a_`i', "(NO|MONSE)( | SE | TE )?(RECUER|ACUER|ACORD|SABE|SERECU)") 
	
	// Productos que involucran más de una marca
	replace nomb_plag_culp_ppc_`i' = "Affly y Carbofurano" 		if preg114x2a_`i'=="AFFLY CON CARBUFURAN"
	replace nomb_plag_culp_ppc_`i' = "Antracol y Attack" 		if preg114x2a_`i'=="ANTRACOL, ATAX"
	replace nomb_plag_culp_ppc_`i' = "Attack y Force" 			if preg114x2a_`i'=="ATAX,FORCE"
	replace nomb_plag_culp_ppc_`i' = "Attack y Campal" 			if preg114x2a_`i'=="ATAX, CAMPAL"
	replace nomb_plag_culp_ppc_`i' = "Attack y Ciperklin" 		if preg114x2a_`i'=="ATAX, CIPERCLIN"
	replace nomb_plag_culp_ppc_`i' = "Attack y Curtine - V" 	if preg114x2a_`i'=="ATAX, CORTINE"
	replace nomb_plag_culp_ppc_`i' = "Attack y Furadan" 		if preg114x2a_`i'=="ATACCK, FURADAN"
	replace nomb_plag_culp_ppc_`i' = "Arriba y K-ñon"			if preg114x2a_`i'=="ARRIBA; CAÑON"	
	replace nomb_plag_culp_ppc_`i' = "Beta Baytroide y Ciperklin" if preg114x2a_`i'=="BETA BAYTROIDE,CYPERKLIN 25"
	replace nomb_plag_culp_ppc_`i' = "Beta Baytroide y Kañon" 	if preg114x2a_`i'=="BETREBATROIN ,CAÑON"
	replace nomb_plag_culp_ppc_`i' = "Caldo Bordeles y Azufre" 	if preg114x2a_`i'=="CALDO BOLDELEZ Y AZUFRE"
	replace nomb_plag_culp_ppc_`i' = "Carbo-for y K-ñon"		if preg114x2a_`i'=="CARBOFOR,CAÑON"
	replace nomb_plag_culp_ppc_`i' = "Ciperklin y Campal"		if preg114x2a_`i'=="CIPERCLIN, CAMPAL"
	replace nomb_plag_culp_ppc_`i' = "Furadan y Regent SC"  	if preg114x2a_`i'=="JURADAN, RIGIN"
	replace nomb_plag_culp_ppc_`i' = "Melaza, Fuego y Tifon" 	if preg114x2a_`i'=="MELAZA. FUEGO, TIFON"
	replace nomb_plag_culp_ppc_`i' = "Mol, Agrostemin y Tiger" 	if preg114x2a_`i'=="MOL,AGROSTIMIL,TIGER"
	replace nomb_plag_culp_ppc_`i' = "Obramass y Galben 73"		if preg114x2a_`i'=="OBRAMAX + GALVEN"
	replace nomb_plag_culp_ppc_`i' = "Octano y Batalla"			if preg114x2a_`i'=="OCTANO, BATALLA"
	replace nomb_plag_culp_ppc_`i' = "Rango y Sanamina"			if preg114x2a_`i'=="RANGO,SANAMINA"
	replace nomb_plag_culp_ppc_`i' = "Regiment y Fibronil"		if preg114x2a_`i'=="REGIN, FIBRONIL"
	
	// Productos individuales
	replace nomb_plag_culp_ppc_`i' = "Abamectina" 		if regexm(preg114x2a_`i', "^ABA(M|N)EC") | inlist(preg114x2a_`i',"AMECTINA","AGUAMITINA")
	replace nomb_plag_culp_ppc_`i' = "Abamex" 			if inlist(preg114x2a_`i',"ABAMEX","ADENEX")
	replace nomb_plag_culp_ppc_`i' = "Abertiicc" 		if preg114x2a_`i'=="ABERTIC" 
	replace nomb_plag_culp_ppc_`i' = "Acaricida"		if regexm(preg114x2a_`i',"^ACARI(C|S)IDA")
	replace nomb_plag_culp_ppc_`i' = "Acarisil"			if inlist(preg114x2a_`i',"ACARICIL","ACARISIL")
	replace nomb_plag_culp_ppc_`i' = "Aceite Agricola o Mineral" if inlist(preg114x2a_`i',"ACEITE AGRICOLA","CIL CON ACEITE AGRICOLA","ACEITE MINERAL")
	replace nomb_plag_culp_ppc_`i' = "Actellic" 		if preg114x2a_`i'=="ACTELLIC"
	replace nomb_plag_culp_ppc_`i' = "Affly"		    if inlist(preg114x2a_`i',"AFLE","AFLIM","AFFLY","AFLY")
	replace nomb_plag_culp_ppc_`i' = "Akron" 			if inlist(preg114x2a_`i',"AKRON","AKROM","ACROM","AKROWN","ACROWN")
	replace nomb_plag_culp_ppc_`i' = "Aldrin"			if preg114x2a_`i'=="ALDRIN"
	replace nomb_plag_culp_ppc_`i' = "Alfacipermetrina" if regexm(preg114x2a_`i',"^ALFA\s?(CIPER|SIPER|CIORE)")
	replace nomb_plag_culp_ppc_`i' = "Alfakling"		if regexm(preg114x2a_`i',"^ALFA\s?(KLIN(G)?|CLIN|CLEAN)") | preg114x2a_`i'=="AFAKLIN"
	replace nomb_plag_culp_ppc_`i' = "Aliette"			if regexm(preg114x2a_`i',"^A(L|LL)IET")
	replace nomb_plag_culp_ppc_`i' = "Aminacrys"		if inlist(preg114x2a_`i',"AMINAGRIS","AMINCRIS","AMINA","AMINACRIS","AMNACRIS")
	replace nomb_plag_culp_ppc_`i' = "Antracol"			if inlist(preg114x2a_`i',"ANTRACOL","ANDRACOL","ANTROCOL","ATRACOL","ANTRACON")
	replace nomb_plag_culp_ppc_`i' = "Apichi"			if preg114x2a_`i'=="PICHI"
	replace nomb_plag_culp_ppc_`i' = "Arado" 			if preg114x2a_`i'=="ARADO"
	replace nomb_plag_culp_ppc_`i' = "Armadura"			if preg114x2a_`i'=="ARMADURA"
	replace nomb_plag_culp_ppc_`i' = "Arriba 10 CE" 	if inlist(preg114x2a_`i',"ARRIBA","ARRIBA BUMISPAL") 
	replace nomb_plag_culp_ppc_`i' = "Attack"			if regexm(preg114x2a_`i',"^AT(T)?A(C|K|X|CK|KE)$")
	replace nomb_plag_culp_ppc_`i' = "Atrayente" 		if preg114x2a_`i'=="ATRAYENTE"
	replace nomb_plag_culp_ppc_`i' = "Avermectina" 		if inlist(preg114x2a_`i',"ABECMETICA", "ABEMECTINA", "ABERMECTINA", "ABMECTINA","ABECTINA","ABEMETINA")
	replace nomb_plag_culp_ppc_`i' = "Azufre/Azufre y Cal" if regexm(preg114x2a_`i',"A(Z|S)UFRE")
	replace nomb_plag_culp_ppc_`i' = "Bala"            	if inlist(preg114x2a_`i',"BALAN","BALA")
	replace nomb_plag_culp_ppc_`i' = "Bamectin" 		if inlist(preg114x2a_`i',"PACMETIN","BAMECTIN") 
	replace nomb_plag_culp_ppc_`i' = "Barbasco" 		if preg114x2a_`i'=="BARBASCO"
	replace nomb_plag_culp_ppc_`i' = "Bazuka" 			if regexm(preg114x2a_`i',"^(BAZU|BASU)") | inlist(preg114x2a_`i',"BASUCAR","VASUCA")
	replace nomb_plag_culp_ppc_`i' = "Beauveria" 		if preg114x2a_`i'=="BAUBERIO"
	replace nomb_plag_culp_ppc_`i' = "Benlate"			if inlist(preg114x2a_`i',"VENLATE","BENLATE")
	replace nomb_plag_culp_ppc_`i' = "Beta Baytroide" 	if regexm(preg114x2a_`i',"^BETA.*(OIDE|OIDES|TROY)$") | ///
												   inlist(preg114x2a_`i',"BAYTROIDE","VITAIBATRODI","B BAYTRIDE","BAYTOSIRI")
	replace nomb_plag_culp_ppc_`i' = "Beretta" 			if preg114x2a_`i'=="BERETA"
	replace nomb_plag_culp_ppc_`i' = "Bermectine" 		if inlist(preg114x2a_`i',"BERMECTIN","BERMENTINA") 
	replace nomb_plag_culp_ppc_`i' = "Bethamax Ultra" 	if preg114x2a_`i'=="BETAMAX"
	replace nomb_plag_culp_ppc_`i' = "Biocida"			if inlist(preg114x2a_`i',"BIOCIDA","BIOSEDA")
	replace nomb_plag_culp_ppc_`i' = "Bio Follaje"		if inlist(preg114x2a_`i',"BIOFOLLAJES")
	replace nomb_plag_culp_ppc_`i' = "Bolero" 			if preg114x2a_`i'=="BOLERO"
	replace nomb_plag_culp_ppc_`i' = "Bolfo" 			if preg114x2a_`i'=="BOLFO"
	replace nomb_plag_culp_ppc_`i' = "Bomba"			if inlist(preg114x2a_`i',"BOMBAX","BOMBA") 
	replace nomb_plag_culp_ppc_`i' = "Boyka"			if preg114x2a_`i'=="BOYKA"
	replace nomb_plag_culp_ppc_`i' = "Bumistar" 		if preg114x2a_`i'=="BUMISTAR"
	replace nomb_plag_culp_ppc_`i' = "Bumper Top"		if preg114x2a_`i'=="BUMPER" | preg114x2a_`i'=="BOMPER" 
	replace nomb_plag_culp_ppc_`i' = "Buprofezin"		if preg114x2a_`i'=="BUPROFECIN"
	replace nomb_plag_culp_ppc_`i' = "Butox"			if preg114x2a_`i'=="BUTOCXS"
	replace nomb_plag_culp_ppc_`i' = "Cal o Cal Agrícola" if regexm(preg114x2a_`i',"^CAL(\sAGRICOLA)?$")
	replace nomb_plag_culp_ppc_`i' = "Caldo Boldelez" 	if preg114x2a_`i'=="CALDO BOLDELEZ"
	replace nomb_plag_culp_ppc_`i' = "Campal"			if inlist(preg114x2a_`i',"CAMPAL","CAMPAL CON LA MELASA","CAMPAL PLUS","CAMPLA")
	replace nomb_plag_culp_ppc_`i' = "Campex"			if preg114x2a_`i'=="CAMPAX"
	replace nomb_plag_culp_ppc_`i' = "Campotin" 		if preg114x2a_`i'=="CAMPOTIN"
	replace nomb_plag_culp_ppc_`i' = "Caporal" 			if preg114x2a_`i'=="CAPORAL"
	replace nomb_plag_culp_ppc_`i' = "Carbedazim" 		if inlist(preg114x2a_`i',"CARMEDASIN","CARBEDACIN") 
	replace nomb_plag_culp_ppc_`i' = "Carbofurano"		if inlist(preg114x2a_`i',"CARBO FURAN","CARBOFODAN")
	replace nomb_plag_culp_ppc_`i' = "Carbo-for"		if preg114x2a_`i'=="CARBOFOR" | preg114x2a_`i'=="CARBO FOR"
	replace nomb_plag_culp_ppc_`i' = "Carfuran"			if preg114x2a_`i'=="CARBURAN" 
	replace nomb_plag_culp_ppc_`i' = "Ceniza" 			if regexm(preg114x2a_`i',"CENIZA")
	replace nomb_plag_culp_ppc_`i' = "Cepex" 			if preg114x2a_`i'=="CEPEX"
	replace nomb_plag_culp_ppc_`i' = "Ciclon" 			if preg114x2a_`i'=="CICLON"
	replace nomb_plag_culp_ppc_`i' = "Cimetrin 200"		if preg114x2a_`i'=="CIMETRIN"
	replace nomb_plag_culp_ppc_`i' = "Ciromazina"		if preg114x2a_`i'=="CIROMACINA"
	replace nomb_plag_culp_ppc_`i' = "Cleto"			if preg114x2a_`i'=="CLITO"
	replace nomb_plag_culp_ppc_`i' = "Clorfox" 			if preg114x2a_`i'=="CLORFOX"
	replace nomb_plag_culp_ppc_`i' = "Cokifin" 			if preg114x2a_`i'=="COKIFIN"
	replace nomb_plag_culp_ppc_`i' = "Combate"			if preg114x2a_`i'=="COMBATE"
	replace nomb_plag_culp_ppc_`i' = "Confidor" 		if preg114x2a_`i'=="CONFIDOR"
	replace nomb_plag_culp_ppc_`i' = "Contacto" 		if preg114x2a_`i'=="CONTACTO"
	replace nomb_plag_culp_ppc_`i' = "Coronel" 			if preg114x2a_`i'=="CORONEL"
	replace nomb_plag_culp_ppc_`i' = "Ciperclean" 		if regexm(preg114x2a_`i',"^(C|S)IPERCLE")
	replace nomb_plag_culp_ppc_`i' = "Ciperklin"  		if regexm(preg114x2a_`i',"C(I|Y)PER(C|K)L(I)?N") | inlist(preg114x2a_`i',"CEPRICLIM","CEPRICLIN","SIPERCLIN (PIQUI PIQUI)")
	replace nomb_plag_culp_ppc_`i' = "Cipermetrina"		if inlist(preg114x2a_`i',"CIPERMETRINA","CIPEMETRINA","SEPERMETINA","SIPERMERCRIMA","SIPERVENTRINA, GRINA GRINA","CYPERMETRINA","SUPERMETRINA")
	replace nomb_plag_culp_ppc_`i' = "Cipermex" 		if regexm(preg114x2a_`i',"^(C|S)?IPERMEX$") | inlist(preg114x2a_`i',"SIPREMEX","CIPWRMEX")
	replace nomb_plag_culp_ppc_`i' = "Clorpirifos"		if regexm(preg114x2a_`i',"^CL(O|I)R\w+OS$")
	replace nomb_plag_culp_ppc_`i' = "Coadyuvante" 		if inlist(preg114x2a_`i',"PEGAMENTO","PEGASOL")
	replace nomb_plag_culp_ppc_`i' = "Contacto"			if preg114x2a_`i'=="HERBICIDAS DE CONTACTO"
	replace nomb_plag_culp_ppc_`i' = "Coraza"			if regexm(preg114x2a_`i',"^C(O|U)RR?A(S|Z)A$")
	replace nomb_plag_culp_ppc_`i' = "Corbat"			if preg114x2a_`i'=="CORBATE"
	replace nomb_plag_culp_ppc_`i' = "Cosavet" 			if preg114x2a_`i'=="COSAVET"
	replace nomb_plag_culp_ppc_`i' = "Cupravit"			if regexm(preg114x2a_`i',"^C(O|U)PR\w+I(T|D)$")
	replace nomb_plag_culp_ppc_`i' = "Cortina" 			if preg114x2a_`i'=="CORTINA"
	replace nomb_plag_culp_ppc_`i' = "Curtine - V" 		if regexm(preg114x2a_`i',"^CURTIN(E|I)")
	replace nomb_plag_culp_ppc_`i' = "Curzate"        	if regexm(preg114x2a_`i',"^(C|K)UR\w+TE")
	replace nomb_plag_culp_ppc_`i' = "Cymonaxil" 		if inlist(preg114x2a_`i',"CIMOXANIL","CYMOXANIL","SOMOZANIL")
	replace nomb_plag_culp_ppc_`i' = "Cypercor" 		if preg114x2a_`i'=="CYPERCOR"
	replace nomb_plag_culp_ppc_`i' = "Cypermate" 		if inlist(preg114x2a_`i',"CIPERMATE")
	replace nomb_plag_culp_ppc_`i' = "Cyromacina" 		if preg114x2a_`i'=="CYROMACINA"
	replace nomb_plag_culp_ppc_`i' = "DECIS" 			if regexm(preg114x2a_`i',"^DE(C|S)IS$")
	replace nomb_plag_culp_ppc_`i' = "Deferon" 			if preg114x2a_`i'=="DEFERON"
	replace nomb_plag_culp_ppc_`i' = "Deffol" 			if preg114x2a_`i'=="DEFFOL"
	replace nomb_plag_culp_ppc_`i' = "Derribe" 			if preg114x2a_`i'=="DERRIBE"
	replace nomb_plag_culp_ppc_`i' = "DK-Tina" 			if preg114x2a_`i'=="DK TINA"
	replace nomb_plag_culp_ppc_`i' = "Deltaplus" 		if preg114x2a_`i'=="DETALPLU"	
	replace nomb_plag_culp_ppc_`i' = "Destructor" 		if preg114x2a_`i'=="DESTRUCTOR"
	replace nomb_plag_culp_ppc_`i' = "Dethomil 90 PS" 	if preg114x2a_`i'=="DETHOMIL"
	replace nomb_plag_culp_ppc_`i' = "Difenconazol" 	if preg114x2a_`i'=="IFECONASOL"
	replace nomb_plag_culp_ppc_`i' = "Diuron" 			if preg114x2a_`i'=="DIURON"
	replace nomb_plag_culp_ppc_`i' = "Divino" 			if preg114x2a_`i'=="DIVINO"
	replace nomb_plag_culp_ppc_`i' = "Dominex"         	if inlist(preg114x2a_`i',"DOMINEC","DOMINEX")
	replace nomb_plag_culp_ppc_`i' = "Dorsan"         	if inlist(preg114x2a_`i',"DORZAN","DORSAN")
	replace nomb_plag_culp_ppc_`i' = "Ebuconazole/Ebuconazol" if inlist(preg114x2a_`i',"EBUCIBAZOLE","EUCANASOL")
	replace nomb_plag_culp_ppc_`i' = "EM-Compost"     	if preg114x2a_`i'=="M COMPOST"
	replace nomb_plag_culp_ppc_`i' = "Embate"     		if regexm(preg114x2a_`i',"^H?EMBATE$")
	replace nomb_plag_culp_ppc_`i' = "Erraser"     		if regexm(preg114x2a_`i',"^H?ERR?(I|A)SER$")
	replace nomb_plag_culp_ppc_`i' = "Ese que Mata"    	if regexm(preg114x2a_`i',"^ESE.*ATA$")
	replace nomb_plag_culp_ppc_`i' = "Espolon" 			if preg114x2a_`i'=="ESPOLON"
	replace nomb_plag_culp_ppc_`i' = "Ethrel" 			if preg114x2a_`i'=="ETRHEL"
	replace nomb_plag_culp_ppc_`i' = "Evito-T"     		if preg114x2a_`i'=="PAITO"
	replace nomb_plag_culp_ppc_`i' = "Exito" 			if preg114x2a_`i'=="EXITO"
	replace nomb_plag_culp_ppc_`i' = "Extermin" 		if preg114x2a_`i'=="EXTERMIN"
	replace nomb_plag_culp_ppc_`i' = "Farmagro" 		if preg114x2a_`i'=="FARMAGRO"
	replace nomb_plag_culp_ppc_`i' = "Famoss" 			if inlist(preg114x2a_`i',"FAMOSS","FAMOUS")
	replace nomb_plag_culp_ppc_`i' = "Fastac" 			if preg114x2a_`i'=="FASTAC"
	replace nomb_plag_culp_ppc_`i' = "Fipronil" 		if preg114x2a_`i'=="FIPRONIL"
	replace nomb_plag_culp_ppc_`i' = "Farmadan"			if regexm(preg114x2a_`i',"^(F|P)AR\w+(D|L|R)AN$")
	replace nomb_plag_culp_ppc_`i' = "Fenkil" 			if preg114x2a_`i'=="FENKIL"
	replace nomb_plag_culp_ppc_`i' = "Fitoclin"			if preg114x2a_`i'=="FITUCLIN"
	replace nomb_plag_culp_ppc_`i' = "Fitoraz"			if regexm(preg114x2a_`i',"^FITORA(X|S|Z)$")
	replace nomb_plag_culp_ppc_`i' = "Floricur"			if regexm(preg114x2a_`i',"^FLO(R|L)ICL?(O|U)R$")
	replace nomb_plag_culp_ppc_`i' = "Foliar" 			if inlist(preg114x2a_`i',"FOLIAR","FULIAR")
	replace nomb_plag_culp_ppc_`i' = "Foliares" 		if preg114x2a_`i'=="FOLIARES"
	replace nomb_plag_culp_ppc_`i' = "Folicur"			if inlist(preg114x2a_`i',"FOLICOR","PULICUR","FOLICUR","FULICUR")
	replace nomb_plag_culp_ppc_`i' = "Folidol" 			if preg114x2a_`i'=="FOLIDOL"
	replace nomb_plag_culp_ppc_`i' = "Forte" 			if preg114x2a_`i'=="FORTE"
	replace nomb_plag_culp_ppc_`i' = "Friponil"			if regexm(preg114x2a_`i',"^FRI(T|P)ONIL$")
	replace nomb_plag_culp_ppc_`i' = "Fuego"			if regexm(preg114x2a_`i',"^FUEGO( DE CONTACTO)?") | preg114x2a_`i'=="FUGO"
	replace nomb_plag_culp_ppc_`i' = "Fulminate" 		if preg114x2a_`i'=="FULMINATE"
	replace nomb_plag_culp_ppc_`i' = "Furadan"			if regexm(preg114x2a_`i',"^(C|F|J)(U|O|A)R(A|O)(D|S)A(N|B|M)") | ///
													preg114x2a_`i'=="FURADSJ" | ///
													preg114x2a_`i'=="FURALAN" | ///
													preg114x2a_`i'=="FURARAN" | ///
													preg114x2a_`i'=="FURDAN"  | ///
													preg114x2a_`i'=="JURANDAN"
	replace nomb_plag_culp_ppc_`i' = "Furia" 			if preg114x2a_`i'=="FURIA"												
	replace nomb_plag_culp_ppc_`i' = "Galben 73"  		if regexm(preg114x2a_`i',"^GAL(B|V)EN")
	replace nomb_plag_culp_ppc_`i' = "Galgotrin"  		if regexm(preg114x2a_`i',"^GAL(B|G)(A|O)TRIN$")
	replace nomb_plag_culp_ppc_`i' = "GF-120"  			if inlist(preg114x2a_`i',"GF-120","GF 120","FG120","GF120","JEFE","TF120")
	replace nomb_plag_culp_ppc_`i' = "Glifoklin"  		if inlist(preg114x2a_`i',"GLIFOCLIN","GLIFOKLIN")
	replace nomb_plag_culp_ppc_`i' = "Glifoagrin"  		if preg114x2a_`i'=="GRIFOCRIN"
	replace nomb_plag_culp_ppc_`i' = "Glifopac" 		if preg114x2a_`i'=="GLIFOPAC"
	replace nomb_plag_culp_ppc_`i' = "Glifosato"  		if regexm(preg114x2a_`i',"^(B|G|D|C)L?IFO(S|Z)ATO$") | preg114x2a_`i'=="LIFOSATO" 
	replace nomb_plag_culp_ppc_`i' = "Glitec" 			if preg114x2a_`i'=="GLITEC"
	replace nomb_plag_culp_ppc_`i' = "Glyfos"  			if regexm(preg114x2a_`i',"^GLYFOS?$")
	replace nomb_plag_culp_ppc_`i' = "Golfin"		    if preg114x2a_`i'=="GOLFIN"
	replace nomb_plag_culp_ppc_`i' = "Gusadrin"			if preg114x2a_`i'=="GUSADRIL"
	replace nomb_plag_culp_ppc_`i' = "Gusaran"			if preg114x2a_`i'=="GUTARAN"
	replace nomb_plag_culp_ppc_`i' = "Granulado"  		if inlist(preg114x2a_`i',"GRANULADA","GRANULADO")
	replace nomb_plag_culp_ppc_`i' = "Halizan"			if regexm(preg114x2a_`i',"^(H)?ALI(S|Z)A(N|M)?")
	replace nomb_plag_culp_ppc_`i' = "Hedonal"         	if preg114x2a_`i'=="EDONAL"
	replace nomb_plag_culp_ppc_`i' = "Herbosato"		if regexm(preg114x2a_`i',"^HER(B|H)O\s?(S|Z)ATO$")
	replace nomb_plag_culp_ppc_`i' = "Hieloxil Mix 72" 	if preg114x2a_`i'=="HIELOXIL"
	replace nomb_plag_culp_ppc_`i' = "Hojancha"  		if preg114x2a_`i'=="HOJA ANCHA"
	replace nomb_plag_culp_ppc_`i' = "Hormix"			if regexm(preg114x2a_`i',"^H?ORMIX?")
	replace nomb_plag_culp_ppc_`i' = "Huella" 			if preg114x2a_`i'=="HUELLA"
	replace nomb_plag_culp_ppc_`i' = "Iguana"			if regexm(preg114x2a_`i',"^H?IGUANA$")
	replace nomb_plag_culp_ppc_`i' = "Imidacloprid"		if regexm(preg114x2a_`i',"^(IMA|IMI).*$")
	replace nomb_plag_culp_ppc_`i' = "Insecticida Biológico" if preg114x2a_`i'=="ISARIA FUMOSOROSEA"
	replace nomb_plag_culp_ppc_`i' = "Ivermectina"		if inlist(preg114x2a_`i',"IVAMECTINA","VERMECTINA") 
	replace nomb_plag_culp_ppc_`i' = "Itasato" 			if preg114x2a_`i'=="ITASATO"
	replace nomb_plag_culp_ppc_`i' = "Itaxan" 			if inlist(preg114x2a_`i',"ITAXAN","ITAXSAN")
	replace nomb_plag_culp_ppc_`i' = "Kalizon"			if preg114x2a_`i'=="CALISON"
	replace nomb_plag_culp_ppc_`i' = "Kañon"			if preg114x2a_`i'=="CAÑON"
	replace nomb_plag_culp_ppc_`i' = "K-ñon"			if regexm(preg114x2a_`i',"^K(\s|\-)ÑON")
	replace nomb_plag_culp_ppc_`i' = "Kahuna" 			if preg114x2a_`i'=="KAHUNA"
	replace nomb_plag_culp_ppc_`i' = "Karate"			if regexm(preg114x2a_`i',"^(C|K)ARATE")
	replace nomb_plag_culp_ppc_`i' = "Kayzer"			if regexm(preg114x2a_`i',"^KA(Y|I)ZER$")
	replace nomb_plag_culp_ppc_`i' = "Kieto"			if preg114x2a_`i'=="QUIETO"
	replace nomb_plag_culp_ppc_`i' = "Kasumin" 			if preg114x2a_`i'=="KASUMIN"
	replace nomb_plag_culp_ppc_`i' = "Kumulus" 			if preg114x2a_`i'=="KUMULUS"
	replace nomb_plag_culp_ppc_`i' = "Lancer" 			if preg114x2a_`i'=="LANCER"
	replace nomb_plag_culp_ppc_`i' = "Lannate"			if regexm(preg114x2a_`i',"^LA(C|G)?NAT(E|A)$") | preg114x2a_`i'=="LANNATE"
	replace nomb_plag_culp_ppc_`i' = "Laser" 			if preg114x2a_`i'=="LASER"
	replace nomb_plag_culp_ppc_`i' = "Lorsban"			if regexm(preg114x2a_`i',"LORVAN") | preg114x2a_`i'=="LORBAN"
	replace nomb_plag_culp_ppc_`i' = "Luna" 			if preg114x2a_`i'=="LUNA"
	replace nomb_plag_culp_ppc_`i' = "Luna Tranquility" if preg114x2a_`i'=="LUNA TRANQUILY"
	replace nomb_plag_culp_ppc_`i' = "Machazo"			if regexm(preg114x2a_`i',"^MACHA(Z|S)(O|A)$")
	replace nomb_plag_culp_ppc_`i' = "Malik"			if preg114x2a_`i'=="MALPIK"
	replace nomb_plag_culp_ppc_`i' = "Mancozeb"			if regexm(preg114x2a_`i',"^MAN(C|G)O(C|S|Z)E(B|C|T|N)?$") | preg114x2a_`i'=="MANGOSED"
	replace nomb_plag_culp_ppc_`i' = "Manganeb Plus" 	if preg114x2a_`i'=="MANGANE PLUS"
	replace nomb_plag_culp_ppc_`i' = "Matador" 			if preg114x2a_`i'=="MATADOR"
	replace nomb_plag_culp_ppc_`i' = "Matrix" 			if preg114x2a_`i'=="MATRIX"
	replace nomb_plag_culp_ppc_`i' = "Marfil Top" 		if preg114x2a_`i'=="MARFIL"
	replace nomb_plag_culp_ppc_`i' = "Melaza de Caña"  	if preg114x2a_`i'=="MILASA DE CAÑA"
	replace nomb_plag_culp_ppc_`i' = "Metomil"   		if inlist(preg114x2a_`i',"MITOMIL","METHOMIL")
	replace nomb_plag_culp_ppc_`i' = "Milbeknock"		if preg114x2a_`i'=="MILBECKBOCH"
	replace nomb_plag_culp_ppc_`i' = "Milagro"			if regexm(preg114x2a_`i',"^MILAGROS?$")
	replace nomb_plag_culp_ppc_`i' = "Minecto" 			if preg114x2a_`i'=="MINECTO"
	replace nomb_plag_culp_ppc_`i' = "Minecto Duo" 		if regexm(preg114x2a_`i',"^MINE(C|B)TO DUO$")
	replace nomb_plag_culp_ppc_`i' = "Miraprin"   		if preg114x2a_`i'=="MIRAVIN"
	replace nomb_plag_culp_ppc_`i' = "Mirex"   			if preg114x2a_`i'=="MIRIX"
	replace nomb_plag_culp_ppc_`i' = "Movento"   		if regexm(preg114x2a_`i',"^M(O|E)VENTO")
	replace nomb_plag_culp_ppc_`i' = "Monitor" 			if preg114x2a_`i'=="MONITOR"
	replace nomb_plag_culp_ppc_`i' = "Mortero" 			if preg114x2a_`i'=="MORTERO"
	replace nomb_plag_culp_ppc_`i' = "Nala-T" 			if preg114x2a_`i'=="NALA_T"
	replace nomb_plag_culp_ppc_`i' = "Nemathor" 		if preg114x2a_`i'=="NEMATHOR"
	replace nomb_plag_culp_ppc_`i' = "Oberts" 			if preg114x2a_`i'=="OBERT"
	replace nomb_plag_culp_ppc_`i' = "Obramass" 		if preg114x2a_`i'=="OBRAMAS"
	replace nomb_plag_culp_ppc_`i' = "Ocaren" 			if preg114x2a_`i'=="OCAREN"
	replace nomb_plag_culp_ppc_`i' = "Octano" 			if preg114x2a_`i'=="OJTANO"
	replace nomb_plag_culp_ppc_`i' = "Olympus" 			if preg114x2a_`i'=="OLIMPOS"
	replace nomb_plag_culp_ppc_`i' = "Olympik" 			if preg114x2a_`i'=="OLYMPIK"
	replace nomb_plag_culp_ppc_`i' = "Omi-88" 			if preg114x2a_`i'=="88" & preg114x2b_`i'==2
	replace nomb_plag_culp_ppc_`i' = "Oncol" 			if regexm(preg114x2a_`i',"^(C|H)?ONCO(L|M|R)$") | ///
												preg114x2a_`i'=="OKOL" 		| ///
												preg114x2a_`i'=="OCOOL" 	| ///
												preg114x2a_`i'=="ONCOOL" 	| ///
												preg114x2a_`i'=="ONCOO" 	| ///
												preg114x2a_`i'=="PONCOL"	| ///
												preg114x2a_`i'=="UNCOL" 	| ///
												preg114x2a_`i'=="UNKOL"		
	replace nomb_plag_culp_ppc_`i' = "Orchestra" 		if regexm(preg114x2a_`i',"OLCHESTRA")					   
	replace nomb_plag_culp_ppc_`i' = "Opera" 			if preg114x2a_`i'=="OPERA"
	replace nomb_plag_culp_ppc_`i' = "Overall" 			if preg114x2a_`i'=="OVEROL"
	replace nomb_plag_culp_ppc_`i' = "Oxamyl"			if inlist(preg114x2a_`i',"OXAMYL","OXAMIL","OXAMILO")
	replace nomb_plag_culp_ppc_`i' = "Paladin" 			if preg114x2a_`i'=="PALADIN"
	replace nomb_plag_culp_ppc_`i' = "Pantera" 			if preg114x2a_`i'=="PANTERA"
	replace nomb_plag_culp_ppc_`i' = "Paration" 		if preg114x2a_`i'=="PARATION"
	replace nomb_plag_culp_ppc_`i' = "Paraquat" 		if regexm(preg114x2a_`i',"PARACUAT")
	replace nomb_plag_culp_ppc_`i' = "Patton" 			if preg114x2a_`i'=="PATON" 
	replace nomb_plag_culp_ppc_`i' = "Perfekthion" 		if regexm(preg114x2a_`i',"PERFECCION")
	replace nomb_plag_culp_ppc_`i' = "Phyton 27"       	if inlist(preg114x2a_`i',"PHYTON","PHYTON 27","FAITON") 
	replace nomb_plag_culp_ppc_`i' = "Piton" 			if preg114x2a_`i'=="PIJON"
	replace nomb_plag_culp_ppc_`i' = "Pounce"			if regexm(preg114x2a_`i',"^PON(C|S)E$")
	replace nomb_plag_culp_ppc_`i' = "Precision" 		if preg114x2a_`i'=="PRECISION"
	replace nomb_plag_culp_ppc_`i' = "Proclain" 		if preg114x2a_`i'=="PROCLAIN"
	replace nomb_plag_culp_ppc_`i' = "Preza"			if regexm(preg114x2a_`i',"^(P|F)RE(Z|S)A$")
	replace nomb_plag_culp_ppc_`i' = "Procloraz"		if inlist(preg114x2a_`i',"PLOCORAX","PROCLORAZ","PROCLORAS","PROCLORRAZ","PROCORRAS","PROCORRAZ")
	replace nomb_plag_culp_ppc_`i' = "Prodefens" 		if inlist(preg114x2a_`i',"PRODEFENSE","PRODEFENS","PRODFENSE")
	replace nomb_plag_culp_ppc_`i' = "Pronilex" 		if preg114x2a_`i'=="PRONILEX"
	replace nomb_plag_culp_ppc_`i' = "Propoleo"			if inlist(preg114x2a_`i',"PROPOLIPOS")
	replace nomb_plag_culp_ppc_`i' = "Protexin" 		if preg114x2a_`i'=="PROTEXI"
	replace nomb_plag_culp_ppc_`i' = "Proton" 			if preg114x2a_`i'=="PROTON" 
	replace nomb_plag_culp_ppc_`i' = "Proxin"			if preg114x2a_`i'=="POXIN"
	replace nomb_plag_culp_ppc_`i' = "Quimfol"			if preg114x2a_`i'=="QUIMIFOL EXTRA"
	replace nomb_plag_culp_ppc_`i' = "Quemador Biológico" if regexm(preg114x2a_`i',"QUEMADOR")
	replace nomb_plag_culp_ppc_`i' = "Quemafoll"		if preg114x2a_`i'=="QUEMAJOL"
	replace nomb_plag_culp_ppc_`i' = "Quemax"			if preg114x2a_`i'=="QUEMA" 	| preg114x2a_`i'=="QUEMAMAX" | preg114x2a_`i'=="QUEMAX"
	replace nomb_plag_culp_ppc_`i' = "Rey Quemante"		if preg114x2a_`i'=="QUEMANTE"
	replace nomb_plag_culp_ppc_`i' = "Racer"			if inlist(preg114x2a_`i',"RACEL","RACER","RAZER","REACER")
	replace nomb_plag_culp_ppc_`i' = "Raicer"			if preg114x2a_`i'=="RAISER" 
	replace nomb_plag_culp_ppc_`i' = "Ranger" 			if preg114x2a_`i'=="RANGER"
	replace nomb_plag_culp_ppc_`i' = "Rango"			if preg114x2a_`i'=="RANDO" | preg114x2a_`i'=="RANGO" | preg114x2a_`i'=="RA GO"
	replace nomb_plag_culp_ppc_`i' = "Rankill" 			if preg114x2a_`i'=="RANKILL"
	replace nomb_plag_culp_ppc_`i' = "Rapaz"			if regexm(preg114x2a_`i',"^RAPA(S|Z)$")
	replace nomb_plag_culp_ppc_`i' = "Rastrero"			if preg114x2a_`i'=="RASERO"
	replace nomb_plag_culp_ppc_`i' = "Rayo" 			if preg114x2a_`i'=="RAYO"
	replace nomb_plag_culp_ppc_`i' = "Ridomil"			if regexm(preg114x2a_`i',"^R(A|E|O)D(A|O|U)MIL$") 
	replace nomb_plag_culp_ppc_`i' = "Regent"			if regexm(preg114x2a_`i',"^REGU?ENT?$") | inlist(preg114x2a_`i',"REJE","REJEN","RIGEN","RIGIEN")    
	replace nomb_plag_culp_ppc_`i' = "Regiment"			if regexm(preg114x2a_`i',"^REGI(M|MEN|N|M,)?$") | preg114x2a_`i'=="REJEMEN"
	replace nomb_plag_culp_ppc_`i' = "Rescate" 			if preg114x2a_`i'=="RESCATE"
	replace nomb_plag_culp_ppc_`i' = "Ridomil" 			if preg114x2a_`i'=="RIDOMIL"
	replace nomb_plag_culp_ppc_`i' = "Rotenona"			if preg114x2a_`i'=="RETENOMA"
	replace nomb_plag_culp_ppc_`i' = "Rudo"				if preg114x2a_`i'=="RUDO"
	replace nomb_plag_culp_ppc_`i' = "Sanamina" 		if preg114x2a_`i'=="SANAMINA"
	replace nomb_plag_culp_ppc_`i' = "Santimec"			if inlist(preg114x2a_`i',"SANTINEC")
	replace nomb_plag_culp_ppc_`i' = "Scoba"         	if regexm(preg114x2a_`i',"^E?SCOBA")
	replace nomb_plag_culp_ppc_`i' = "Score" 			if preg114x2a_`i'=="ESCORE ENDURA"
	replace nomb_plag_culp_ppc_`i' = "Secamas" 			if preg114x2a_`i'=="SECAMAS"
	replace nomb_plag_culp_ppc_`i' = "Sekador" 			if preg114x2a_`i'=="SEKADOR"
	replace nomb_plag_culp_ppc_`i' = "Sencor" 			if preg114x2a_`i'=="SENCOR"
	replace nomb_plag_culp_ppc_`i' = "Shell" 			if preg114x2a_`i'=="SHELL"
	replace nomb_plag_culp_ppc_`i' = "Sherpa" 			if preg114x2a_`i'=="SHERPA"
	replace nomb_plag_culp_ppc_`i' = "Sico" 			if preg114x2a_`i'=="ZICO"
	replace nomb_plag_culp_ppc_`i' = "Simba" 			if preg114x2a_`i'=="SIMBAS"
	replace nomb_plag_culp_ppc_`i' = "Sistemin" 		if preg114x2a_`i'=="SISTERMIN"
	replace nomb_plag_culp_ppc_`i' = "Stermin" 			if regexm(preg114x2a_`i',"^E?STERMI?N$")
	replace nomb_plag_culp_ppc_`i' = "Suko" 			if preg114x2a_`i'=="SIKO"
	replace nomb_plag_culp_ppc_`i' = "Sulfa 80" 		if inlist(preg114x2a_`i',"SULFA 80","SULFO 80","SULFE 80")
	replace nomb_plag_culp_ppc_`i' = "Sulfato de Cobre" if regexm(preg114x2a_`i',"SULFATO( DE COBRE)?")
	replace nomb_plag_culp_ppc_`i' = "Sultan" 			if preg114x2a_`i'=="SULTAN"
	replace nomb_plag_culp_ppc_`i' = "Super Clean" 		if inlist(preg114x2a_`i',"SUPER KLIN","SUPERKLYN")
	replace nomb_plag_culp_ppc_`i' = "Super-A" 			if inlist(preg114x2a_`i',"SUPERAT","SUPERA")
	replace nomb_plag_culp_ppc_`i' = "Tamaron" 			if inlist(preg114x2a_`i',"AMARON","TOMARON","TAMARON")
	replace nomb_plag_culp_ppc_`i' = "Tebuconazole" 	if regexm(preg114x2a_`i',"^TEBUCONA") | inlist(preg114x2a_`i',"TENOKENASOLES","TEBUQUENASOLE")
	replace nomb_plag_culp_ppc_`i' = "Tenaz" 			if preg114x2a_`i'=="TENAZ"
	replace nomb_plag_culp_ppc_`i' = "Trigard" 			if preg114x2a_`i'=="TRIGAR"
	replace nomb_plag_culp_ppc_`i' = "Triunfo" 			if preg114x2a_`i'=="TRIUNFO"
	replace nomb_plag_culp_ppc_`i' = "Troya" 			if preg114x2a_`i'=="TROYA"
	replace nomb_plag_culp_ppc_`i' = "Thor"				if inlist(preg114x2a_`i',"THOR","TORH")
	replace nomb_plag_culp_ppc_`i' = "Thunder" 			if regexm(preg114x2a_`i',"^TH?UNDER")
	replace nomb_plag_culp_ppc_`i' = "Tifon" 			if regexm(preg114x2a_`i',"^T(IF|EF|IJ|UF|EJ)O(N|M)")
	replace nomb_plag_culp_ppc_`i' = "Tilt" 			if regexm(preg114x2a_`i',"^TILT?$")
	replace nomb_plag_culp_ppc_`i' = "Topas" 			if regexm(preg114x2a_`i',"^TOPA(Z|S)")
	replace nomb_plag_culp_ppc_`i' = "Trichoderma" 		if preg114x2a_`i'=="TRICHODERMA"
	replace nomb_plag_culp_ppc_`i' = "Vertical"			if preg114x2a_`i'=="VERTICAL"
	replace nomb_plag_culp_ppc_`i' = "Vydate" 			if inlist(preg114x2a_`i',"VIDATE","VYDATE")
	replace nomb_plag_culp_ppc_`i' = "Vivoral" 			if preg114x2a_`i'=="VIVORAL"
	replace nomb_plag_culp_ppc_`i' = "Wentum" 			if preg114x2a_`i'=="WENTUM"
	replace nomb_plag_culp_ppc_`i' = "Zeus"				if preg114x2a_`i'=="SEUZ"
	replace nomb_plag_culp_ppc_`i' = "20-20" 			if inlist(preg114x2a_`i',"VEINTE VEINTE","20 20")
	replace nomb_plag_culp_ppc_`i' = "2,4 D Sal Amina"  if preg114x2a_`i'=="SALAMINA 24D"
}

// Reemplazar por valores sin cambios (i.e valores de la variable correctos)
forval i=1/5{
	replace nomb_plag_culp_ppc_`i' = strproper(preg114x2a_`i') if mi(nomb_plag_culp_ppc_`i') & !mi(preg114x2a_`i')
}

// Modificar el tipo de plaguicida según lo que se reporta en internet
forval i=1/5{
	replace tipo_plag_culp_ppc_`i' = 5 if nomb_plag_culp_ppc_`i'=="Acaricida"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Bamectin"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Bazuka" & preg114x2b_`i'==5
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Benlate"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Bumper"
	replace tipo_plag_culp_ppc_`i' = 1 if nomb_plag_culp_ppc_`i'=="Cokifin"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Cortina"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Coraza"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Corbat"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Galben 73"
	replace tipo_plag_culp_ppc_`i' = 1 if nomb_plag_culp_ppc_`i'=="Hedonal"
	replace tipo_plag_culp_ppc_`i' = 1 if nomb_plag_culp_ppc_`i'=="Huella"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Itaxan"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Kasumin"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Luna"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Mirex"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Mortero"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Oncol"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Paration"
	replace tipo_plag_culp_ppc_`i' = 5 if nomb_plag_culp_ppc_`i'=="Quemador Biológico"
	replace tipo_plag_culp_ppc_`i' = 1 if nomb_plag_culp_ppc_`i'=="Sanamina"
	replace tipo_plag_culp_ppc_`i' = 1 if nomb_plag_culp_ppc_`i'=="Sencor"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Sulfato de Cobre"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Tenaz"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Tilt"
	replace tipo_plag_culp_ppc_`i' = 3 if nomb_plag_culp_ppc_`i'=="Trichoderma"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Triunfo"
	replace tipo_plag_culp_ppc_`i' = 2 if nomb_plag_culp_ppc_`i'=="Vivoral"
}

// Reemplazar por valores sin cambios del tipo de plaguicida (i.e valores correctos)
forval i=1/5{
	replace tipo_plag_culp_ppc_`i' = preg114x2b_`i' if mi(tipo_plag_culp_ppc_`i') & !mi(preg114x2b_`i')
}
lab def tipplag 1 "Herbicida" 2 "Insecticida" 3 "Fungicida" 4 "Nematicida" 5 "Otro"
lab val tipo_plag_* tipplag
 
// Corregir cantidades
forval i=1/4{
	dis "Variable: preg114x2g_`i'"
	tab preg114x2g_`i' if regexm(preg114x2g_`i',"[A-Z]")
}

forval i=1/4{
	replace preg114x2g_`i' = "" 	if inlist(preg114x2g_`i',"NOSABE")
	replace preg114x2g_`i' = "2" 	if preg114x2g_`i'=="NO 2"
	replace preg114x2g_`i' = "0" 	if preg114x2g_`i'=="0."
	replace preg114x2g_`i' = "0.5" 	if preg114x2g_`i'=="O.5"
}

// Convertir cantidades corregidas de string a número
forval i=1/4{
	destring preg114x2g_`i', replace
}

// Conversión de mililitros/gramos a litros
forval i=1/4{
	replace preg114x2g_`i' = preg114x2d_`i'/1000 if inlist(preg114x2f_`i',"MILILITROS","MILITRO","ML","ML\G")
}

// Reemplazar valores en variables de kgs. o lts. usados en plaguicidas
forval i=1/5{
	replace kg_plag_culp_ppc_`i' = preg114x2d_`i' if preg114x2e_`i'==1
	replace kg_plag_culp_ppc_`i' = preg114x2g_`i' if preg114x2g_`i'`i'==1 & mi(kg_plag_culp_ppc_`i')
	replace lt_plag_culp_ppc_`i' = preg114x2d_`i' if preg114x2e_`i'==2
	replace lt_plag_culp_ppc_`i' = preg114x2g_`i' if preg114x2g_`i'`i'==2 & mi(lt_plag_culp_ppc_`i')
}

// Reemplazar valores en variables de costo por kg. o lt. de plaguicida usado
forval i=1/5{
	replace cxkg_plag_culp_ppc_`i' = preg114x2h_`i'/kg_plag_culp_ppc_`i' if kg_plag_culp_ppc_`i'>0 & !mi(preg114x2h_`i')
	replace cxlt_plag_culp_ppc_`i' = preg114x2h_`i'/lt_plag_culp_ppc_`i' if lt_plag_culp_ppc_`i'>0 & !mi(preg114x2h_`i')
}

// Dudas sobre los siguientes nombres:
	// - ACARIBTIN					-> ?
	// - ACAYENTE					-> ?
	// - ALTERNARIA				-> ?
	// - AMENAPLIX 				-> ?
	// - AMET 						-> THIMET o AMEX? AMET es un antibacteriano-antinflamatorio para ganado bovino/porcino.
	// - AVENEX 					-> ?
	// - BATION 					-> ?
	// - BAZOOKA					-> ?
	// - BETAZOIN 					-> ?
	// - BERTIMIX					->
	// - BIOSIMIL					-> BIOMISIL?
	// - BOIREX 					-> MIREX?
	// - BOMECTI 					-> ?
	// - BONENAN 					-> BUMERAN?
	// - CALISAN 					-> HALIZAN o KALIZON?
	// - CAMARON DEL GUSANO 		-> ?
	// - CARDAMICINA 				-> CARDAZINA o CARBEDAZIM?
	// - CEPRECIM 					-> CYPERKLIN? CIPERCEM?
	// - CEQUIL  					-> SUCKILL?
	// - CITERICIN 				-> ?
	// - CLEOCLIN 					-> ?
	// - CLOFINAPIL 				-> ?
	// - CODIRAIZ					-> ?
	// - COLIFOX 					-> ?
 	// - COLPRORAS 				-> ?
	// - COPRI						-> ?
	// - CORAJE					-> ?
	// - CREZO						-> ?
	// - CULISTOC					-> ?
	// - CURATAN 					-> FUARADAN o CURATHANE (ES FUNGICIDA)?
	// - CURAZAO PARA RANCHA		-> ?
	// - DITAME 					-> DITHANE o DIAME?
	// - ECUMULIS					-> ?
	// - EL VERDE 					-> ?
	// - ELEISET					-> ?
	// - EXTERMIX					-> ?
	// - FITORRIN 					-> ?
	// - FONCOT					-> ?
	// - FORDACIL					-> ?
	// - FUNGIMAC					-> ?
	// - GARBADIL 					-> ?
	// - GUSANIN 					-> ?
	// - HFG 						-> ?
	// - LACMAR					-> ?
	// - LACTRIN					-> ?
	// - LENFOSATO					-> ?
	// - LEYBASIL 					-> ?
	// - MAGANEX 					-> SIGANEX?
	// - MAGNATE, JURADAN			-> ?
	// - MANGANEC					-> MANGANEB PLUS?
	// - MEDACOPRIT				-> ?
	// - METICAR 					-> ?
	// - MICOSEN 					-> ?
	// - MITACOPRIL				-> ?
	// - NOTIL						-> ?
	// - OLAGNATE 					-> ?
	// - PARRAX					-> ?
	// - PIOMISIL 					-> ?
	// - PIREMEX					-> PYRINEX?
	// - PONST 					-> ?
	// - PUMISTAL 					-> ?
	// - QUILKEX 					-> ?
	// - QUINO LASER 				-> ? XXX
	// - RADOMIL					-> ?
	// - RANCHA					-> ?
	// - RATECSIN					-> ?
	// - ROYA 						-> ?
	// - SAMILA 					-> ?
	// - SANTIMEX					-> SANTIMEC?
	// - SPIDER					-> ?
	// - SUCCIO					-> ?
	// - SUNCON					-> ?
	// - SUSIPRI					-> ?
	// - SUPERGLIN + CARATE 		-> ?
	// - TIBIA						-> ?
	// - TINAFOL 					-> ?
	// - TOMETCU 					-> ?
	// - VECTOMIL					-> ?
	// - VICTIRIC VOMINAL 			-> ?
	// OTROS GENÉRICOS
	// - FUNGICIDA					-> ?
	// - HERBICIDA					-> ?
	// - GOMA 						-> ?
	// - GOMA AGRICOLA				-> ?
	// - LA HORMIGA				-> ?
	// - LECHE DE HORMIGA			-> ?
	// - MACHETIADORA 				-> ?
	// - MANGANESO					-> ?
	// - RIO 						-> ?
	// - SAL						-> ?
	// - SULFATO					-> ?
