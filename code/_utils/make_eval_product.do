//----------------------------------------------------------------------
// File           : make_eval_product.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Genera la variable prod_ECA_eval (producto sujeto a evaluacion)
//                  para cada centro poblado aleatorizado.
//----------------------------------------------------------------------

gen prod_ECA_eval:prodECAe = . , a(tipo_ECA)
# delimit ;
replace prod_ECA_eval = 19 if 
	(nomb_dstrt=="ARAMANGO" & nomb_ccpp=="ARAMANGO") 			| 
	(nomb_dstrt=="ARAMANGO" & nomb_ccpp=="VALENCIA") 			| 
	(nomb_dstrt=="COPALLIN" & nomb_ccpp=="SANTA CRUZ DE MOROCHAL") |
	(nomb_dstrt=="EL PARCO" & nomb_ccpp=="TOLOPAMPA") 			|
	(nomb_dstrt=="IMAZA" 	& nomb_ccpp=="EPEMIMU") 			|
	(nomb_dstrt=="LA PECA" 	& nomb_ccpp=="EL ALMENDRAL") 		|
	(nomb_dstrt=="LA PECA" 	& nomb_ccpp=="LA PECA") 			|
	(nomb_dstrt=="CHURUJA" 	& nomb_ccpp=="CHURUJA") 			|
	(nomb_dstrt=="YAMBRASBAMBA" & nomb_ccpp=="BUENOS AIRES") 	|
	(nomb_dstrt=="NIEVA" 	& nomb_ccpp=="PARCELACION MONTERRICO") |
	(nomb_dstrt=="NIEVA" 	& nomb_ccpp=="TUNANTS") 			|
	(nomb_dstrt=="CHIRIMOTO" & nomb_ccpp=="SAN ANTONIO") 		|
	(nomb_dstrt=="CAJARURO" & nomb_ccpp=="SEDA FLOR") 			|
	(nomb_dstrt=="LONYA GRANDE" & nomb_ccpp=="ORTIZ ARRIETA") 	|
	(nomb_dstrt=="PERENE" 	& nomb_ccpp=="ALTO TOTERANI") 		|
	(nomb_dstrt=="PERENE" 	& (nomb_ccpp=="CC.NN INCHATINGARI" 	| nomb_ccpp=="INCHATINGARI")) |
	(nomb_dstrt=="PICHANAQUI" & (nomb_ccpp=="CC.NN BAJO KIMIRIKI" | nomb_ccpp=="BAJO KIMIRIKI")) |
	(nomb_dstrt=="SAN LUIS DE SHUARO" & nomb_ccpp=="ZONA 08") 	|
	(nomb_dstrt=="SAN RAMON" & nomb_ccpp=="LA AUVERNIA") 		|
	(nomb_dstrt=="LLAYLLA" 	& nomb_ccpp=="BELEN") 				|
	(nomb_dstrt=="LLAYLLA" 	& nomb_ccpp=="HERMOSA PAMPA") 		|
	(nomb_dstrt=="PANGOA" 	& nomb_ccpp=="CIUDAD DE DIOS") 		|
	(nomb_dstrt=="RIO NEGRO" & nomb_ccpp=="ALTO HUAHUARI") 		|
	(nomb_dstrt=="RIO TAMBO" & nomb_ccpp=="ALTO SHIMA") 		|
	(nomb_dstrt=="SATIPO" & nomb_ccpp=="BAJO MARANQUIARI") 		|
	(nomb_dstrt=="CHONTABAMBA"	& nomb_ccpp=="PALMERAS") 		|
	(nomb_dstrt=="CHONTABAMBA"	& nomb_ccpp=="PUSAPNO") 		|
	(nomb_dstrt=="CONSTITUCION" & nomb_ccpp=="FLOR DE UN DIA") 	|
	(nomb_dstrt=="CONSTITUCION" & nomb_ccpp=="NUEVO PORVENIR") 	|
	(nomb_dstrt=="OXAPAMPA" 	& nomb_ccpp=="PURRAYO") 		|
	(nomb_dstrt=="PUERTO BERMUDEZ" & nomb_ccpp=="SANTA ROSA DE CHIVIS") |
	(nomb_dstrt=="PISCOYACU" 	& nomb_ccpp=="PISCOYACU") 		|
	(nomb_dstrt=="YANTALO"		& nomb_ccpp=="YANTALO") 		|
	(nomb_dstrt=="TRES UNIDOS" 	& nomb_ccpp=="TRES UNIDOS") 	|
	(nomb_dstrt=="RIOJA" 		& nomb_ccpp=="RIOJA") 			|
	(nomb_dstrt=="JUAN GUERRA" 	& nomb_ccpp=="JUAN GUERRA") 	|
	(nomb_dstrt=="SAUCE" 		& nomb_ccpp=="SAUCE") 			|
	(nomb_dstrt=="NUEVO PROGRESO" & nomb_ccpp=="SANTA CRUZ") 	|
	(nomb_dstrt=="POLVORA" 		& nomb_ccpp=="PUERTO RICO") 	|
	(nomb_dstrt=="SHUNTE" 		& (nomb_ccpp=="SAN FRANCISCO" | nomb_ccpp=="SHUNTE")) | /* ojo */
	(nomb_dstrt=="UCHIZA"		& nomb_ccpp=="CHONTAYAQUILLO") 	|
	(nomb_dstrt=="SAN JACINTO" 	& nomb_ccpp=="CASA BLANQUEADA") |
	(nomb_dstrt=="SAN JACINTO" 	& nomb_ccpp=="PLATEROS") 		|
	(nomb_dstrt=="AGUAS VERDES" & nomb_ccpp=="POCITOS") 		|
	(nomb_dstrt=="PAPAYAL"		& nomb_ccpp=="UÑA DE GATO") ;
	
replace prod_ECA_eval = 26 if 
	(nomb_dstrt=="LLOCHEGUA" & nomb_ccpp=="BUENOS AIRES") |
	(nomb_dstrt=="SIVIA" & nomb_ccpp=="CCECCA") 	|
	(nomb_dstrt=="SIVIA" & nomb_ccpp=="NARANJAL") 	|
	(nomb_dstrt=="SIVIA" & nomb_ccpp=="PALMAPAMPA") |
	(nomb_dstrt=="SIVIA" & nomb_ccpp=="RAMOS PAMPA") |
	(nomb_dstrt=="SIVIA" & nomb_ccpp=="TRIBOLINE") |
	(nomb_dstrt=="SIVIA" & nomb_ccpp=="VILLA RICA") |
	(nomb_dstrt=="SIVIA" & nomb_ccpp=="VISTA ALEGRE") |
	(nomb_dstrt=="QUEROCOTO" & nomb_ccpp=="EL NARANJO") |
	(nomb_dstrt=="COLASAY" & nomb_ccpp=="BOLIVAR") |
	(nomb_dstrt=="JAEN" & nomb_ccpp=="LAS DELICIAS") |
	(nomb_dstrt=="HUARANGO" & nomb_ccpp=="NARANJO CHACAS") |
	(nomb_dstrt=="SAN IGNACIO" & nomb_ccpp=="FLOR DE LA FRONTERA") |
	(nomb_dstrt=="SAN JOSE DE LOURDES" & nomb_ccpp=="NUEVO SAN LORENZO") | /* ojo */
	(nomb_dstrt=="YANATILE" & nomb_ccpp=="COLCA") |
	(nomb_dstrt=="KIMBIRI" & nomb_ccpp=="MANITEA ALTA") |
	(nomb_dstrt=="KIMBIRI" & (nomb_ccpp=="QORICHAYOC" | nomb_ccpp=="CCORICHAYOC")) |
	(nomb_dstrt=="MARANURA" & nomb_ccpp=="MANDOR") |
	(nomb_dstrt=="PICHARI" & nomb_ccpp=="NATIVIDAD") |
	(nomb_dstrt=="PICHARI" & nomb_ccpp=="OTARI SAN MARTIN") |
	(nomb_dstrt=="PICHARI" & nomb_ccpp=="QUISTO CENTRAL") |
	(nomb_dstrt=="QUELLOUNO" & nomb_ccpp=="CHANCAMAYO") |
	(nomb_dstrt=="PERENE" & nomb_ccpp=="GRAN PLAYA SUR") |
	(nomb_dstrt=="PERENE" & nomb_ccpp=="PICHIROKI") |
	(nomb_dstrt=="PERENE" & nomb_ccpp=="PUERTO VICTORIA") |
	(nomb_dstrt=="PERENE" & nomb_ccpp=="SAN FERNANDO DE KIVINAKI") |
	(nomb_dstrt=="SAN LUIS DE SHUARO" & nomb_ccpp=="PUENTE CAPELO") |
	(nomb_dstrt=="SAN LUIS DE SHUARO" & nomb_ccpp=="RIO SECO") |
	(nomb_dstrt=="SAN RAMON" & (nomb_ccpp=="ANEXO 14 IVITA" | nomb_ccpp=="14 IVITA")) |
	(nomb_dstrt=="PANGOA" & nomb_ccpp=="BARRIO NARANJAL") |
	(nomb_dstrt=="PANGOA" & nomb_ccpp=="LOBERA") |
	(nomb_dstrt=="RIO NEGRO" & nomb_ccpp=="UNION CAPIRI") |
	(nomb_dstrt=="SATIPO" & nomb_ccpp=="TZANCUVATZIARI") |
	(nomb_dstrt=="HUARAL" & nomb_ccpp=="RETES") |
	(nomb_dstrt=="SAYAN" & nomb_ccpp=="LA CAPULLANA") |
	(nomb_dstrt=="SAYAN" & (nomb_ccpp=="SANTA ROSA" | nomb_ccpp=="LA ENSENADA")) | /* ojo */
	(nomb_dstrt=="CATAHUASI" & (nomb_ccpp=="CATAHUASI" | nomb_ccpp=="SAN GERONIMO")) | 
	(nomb_dstrt=="SAN JOSE DE SISA" & nomb_ccpp=="SAN JOSE DE SISA") |
	(nomb_dstrt=="SANTA ROSA" & nomb_ccpp=="SANTA ROSA") |
	(nomb_dstrt=="EL ESLABON" & nomb_ccpp=="EL ESLABON") |
	(nomb_dstrt=="SAPOSOA" & nomb_ccpp=="SAPOSOA") |
	(nomb_dstrt=="TABALOSOS" & nomb_ccpp=="TABALOSOS") |
	(nomb_dstrt=="CAMPANILLA" & nomb_ccpp=="BELLAVISTA")|
	(nomb_dstrt=="PACHIZA" & nomb_ccpp=="PACHIZA") |
	(nomb_dstrt=="TOCACHE" & nomb_ccpp=="ISHANGA") ;

replace prod_ECA_eval = 16 if 
	(nomb_dstrt=="CHACAS" 				& nomb_ccpp=="CHACAS") 		| 	
	(nomb_dstrt=="YAUYA" 				& nomb_ccpp=="YAUYA") 		|
	(nomb_dstrt=="HUARAZ" 				& nomb_ccpp=="HUAMARIN") 	|
	(nomb_dstrt=="SAN MARCOS" 			& nomb_ccpp=="CARHUAYOC") 	|
	(nomb_dstrt=="HUATA" 				& nomb_ccpp=="RACRACALLAN") |
	(nomb_dstrt=="CASCA" 				& nomb_ccpp=="VILCABAMBA") 	|
	(nomb_dstrt=="LLAMA" 				& nomb_ccpp=="PAMPAMARCA") 	|
	(nomb_dstrt=="PARARIN"				& nomb_ccpp=="PARARIN") 	|
	(nomb_dstrt=="RAGASH" 				& nomb_ccpp=="LACHOJ") 		|
	(nomb_dstrt=="SAN JUAN"  			& nomb_ccpp=="AHIJADERO") 	|
	(nomb_dstrt=="ABANCAY" 				& nomb_ccpp=="LLAÑUCANCHA") |
	(nomb_dstrt=="CIRCA" 				& nomb_ccpp=="TAMBURQUI") 	|
	(nomb_dstrt=="LAMBRAMA"				& nomb_ccpp=="LAMBRAMA") 	|
	(nomb_dstrt=="HUANCARAMA" 			& nomb_ccpp=="PICHIUPATA") 	|
	(nomb_dstrt=="TALAVERA" 			& nomb_ccpp=="CHACCAMARCA") |
	(nomb_dstrt=="COTARUSE" 			& nomb_ccpp=="PROMESA") 	|
	(nomb_dstrt=="SANTA ISABEL DE SIGUAS" & nomb_ccpp=="TIN TIN")	|
	(nomb_dstrt=="ACARI" 				& nomb_ccpp=="CHOCAVENTO") 	|
	(nomb_dstrt=="BELLA UNION" 			& nomb_ccpp=="HACIENDA PLATINO") |
	(nomb_dstrt=="CHILCAYMARCA" 		& nomb_ccpp=="CHILCAYMARCA")|
	(nomb_dstrt=="VIRACO" 				& nomb_ccpp=="VIRACO") 		|
	(nomb_dstrt=="CABANACONDE" 			& nomb_ccpp=="PINCHOLLO") 	|
	(nomb_dstrt=="LARI" 				& nomb_ccpp=="LARI") 		|
	(nomb_dstrt=="CHICHAS" 				& nomb_ccpp=="CHICHAS") 	|
	(nomb_dstrt=="ALCA" 				& nomb_ccpp=="AYAHUASI") 	|
	(nomb_dstrt=="LAMAY" 				& nomb_ccpp=="HUANCCO PILLPINTO") |
	(nomb_dstrt=="LAMAY" 				& nomb_ccpp=="ZAPACTO") 	|
	(nomb_dstrt=="LARES" 				& nomb_ccpp=="ROSASPATA") 	|
	(nomb_dstrt=="PITUMARCA" 			& nomb_ccpp=="CHILLCA") 	|
	(nomb_dstrt=="PICHIGUA"  			& nomb_ccpp=="NUEVA ESPERANZA") 	|
	(nomb_dstrt=="PACCARITAMBO" 		& nomb_ccpp=="MOLLEBAMBA")	|
	(nomb_dstrt=="HUAYLLABAMBA" 		& nomb_ccpp=="URQUILLOS") 	|
	(nomb_dstrt=="URUBAMBA" 			& nomb_ccpp=="RUMICHACA BAJA") 	|
	(nomb_dstrt=="PAUCARA" 				& nomb_ccpp=="CHECCO CRUZ") |
	(nomb_dstrt=="CONGALLA" 			& nomb_ccpp=="CONGALLA") 	|
	(nomb_dstrt=="SANTO TOMAS DE PATA" 	& nomb_ccpp=="CUTICCSA")	|
	(nomb_dstrt=="CAPILLAS" 			& nomb_ccpp=="CAPILLAS") 	|
	(nomb_dstrt=="CHUPAMARCA"		 	& nomb_ccpp=="CHUPAMARCA") 	|
	(nomb_dstrt=="HUAMATAMBO" 			& nomb_ccpp=="HUAMATAMBO") 	|
	(nomb_dstrt=="SANTA ANA"  			& nomb_ccpp=="SANTA ANA") 	|
	(nomb_dstrt=="COSME"				& nomb_ccpp=="SANTA ROSA DE LLACUA") |
	(nomb_dstrt=="YAULI" 				& nomb_ccpp=="MATIPACCANA") |
	(nomb_dstrt=="HUAYACUNDO ARMA" 		& nomb_ccpp=="CARMEN ALTO") |
	(nomb_dstrt=="SAN ANTONIO DE CUSICANCHA" & nomb_ccpp=="RUMICHACA") |
	(nomb_dstrt=="DANIEL HERNANDEZ" 	& nomb_ccpp=="MARCOPATA") ; 
# delimit cr
lab var prod_ECA_eval "Producto a Evaluar (determinado por SENASA)"
