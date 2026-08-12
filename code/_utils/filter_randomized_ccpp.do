//----------------------------------------------------------------------
// File           : filter_randomized_ccpp.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Filtra la data quedando solo con centros poblados aleatorizados.
//----------------------------------------------------------------------
# delimit ;
keep if	(nomb_dstrt=="ARAMANGO" 	& nomb_ccpp=="ARAMANGO") 		| // 1 
		(nomb_dstrt=="ARAMANGO" 	& nomb_ccpp=="VALENCIA")		| // 2
		(nomb_dstrt=="COPALLIN" 	& nomb_ccpp=="SANTA CRUZ DE MOROCHAL") | // 3
		(nomb_dstrt=="EL PARCO" 	& (nomb_ccpp=="EL PARCO" | nomb_ccpp=="TOLOPAMPA")) | // 4
		(nomb_dstrt=="IMAZA" 		& (nomb_ccpp=="CHIRIACO"  | nomb_ccpp=="EPEMIMU")) 	| // 5
		(nomb_dstrt=="LA PECA" 		& nomb_ccpp=="EL ALMENDRAL") 	| // 6
		(nomb_dstrt=="LA PECA" 		& nomb_ccpp=="LA PECA") 		| // 7
		(nomb_dstrt=="CHURUJA" 		& nomb_ccpp=="CHURUJA") 		| // 8
		(nomb_dstrt=="YAMBRASBAMBA" & (nomb_ccpp=="YAMBRASBAMBA" | nomb_ccpp=="BUENOS AIRES")) 	| // 9
		(nomb_dstrt=="NIEVA" 		& nomb_ccpp=="PARCELACION MONTERRICO") 					| // 10
		(nomb_dstrt=="NIEVA"		& (nomb_ccpp=="URAKUSA" | nomb_ccpp=="TUNANTS")) 		| // 11
		(nomb_dstrt=="CHIRIMOTO" 	& (nomb_ccpp=="CHIRIMOTO" | nomb_ccpp=="SAN ANTONIO")) 	| // 12
		(nomb_dstrt=="CAJARURO" 	& nomb_ccpp=="SEDA FLOR") 		| // 13
		(nomb_dstrt=="LONYA GRANDE" & (nomb_ccpp=="LONYA GRANDE" | nomb_ccpp=="ORTIZ ARRIETA")) | // 14
		(nomb_dstrt=="CHACAS" 	 	& nomb_ccpp=="CHACAS") 			| // 15
		(nomb_dstrt=="YAUYA" 		& nomb_ccpp=="YAUYA") 			| // 16
		(nomb_dstrt=="HUARAZ" 		& nomb_ccpp=="HUAMARIN") 		| // 17
		(nomb_dstrt=="SAN MARCOS" 	& nomb_ccpp=="CARHUAYOC") 		| // 18
		(nomb_dstrt=="HUATA" 		& (nomb_ccpp=="HUATA" | nomb_ccpp=="RACRACALLAN")) | // 19
		(nomb_dstrt=="CASCA" 		& nomb_ccpp=="VILCABAMBA") 		| // 20
		(nomb_dstrt=="LLAMA" 		& nomb_ccpp=="PAMPAMARCA") 		| // 21
		(nomb_dstrt=="PARARIN" 		& nomb_ccpp=="PARARIN") 		| // 22
		(nomb_dstrt=="RAGASH" 		& (nomb_ccpp=="LACHOG"|nomb_ccpp=="LACHOJ")) | // 23
		(nomb_dstrt=="SAN JUAN" 	& nomb_ccpp=="AHIJADERO")	| // 24
		(nomb_dstrt=="ABANCAY" 		& nomb_ccpp=="LLAÑUCANCHA") | // 25
		(nomb_dstrt=="CIRCA" 		& nomb_ccpp=="TAMBURQUI") 		| // 26
		(nomb_dstrt=="LAMBRAMA" 	& nomb_ccpp=="LAMBRAMA")		| // 27
		(nomb_dstrt=="HUANCARAMA" 	& nomb_ccpp=="PICHIUPATA") 		| // 28
		(nomb_dstrt=="TALAVERA" 	& nomb_ccpp=="CHACCAMARCA") 	| // 29
		(nomb_dstrt=="COTARUSE" 	& nomb_ccpp=="PROMESA")			| // 30
		(nomb_dstrt=="SANTA ISABEL DE SIGUAS" & nomb_ccpp=="TIN TIN")	| // 31
		(nomb_dstrt=="ACARI" 		& nomb_ccpp=="CHOCAVENTO") 			| // 32
		(nomb_dstrt=="BELLA UNION"  & nomb_ccpp=="HACIENDA PLATINO")	| // 33 
		(nomb_dstrt=="CHILCAYMARCA" & nomb_ccpp=="CHILCAYMARCA")		| // 34
		(nomb_dstrt=="VIRACO" 		& nomb_ccpp=="VIRACO") 				| // 35
		(nomb_dstrt=="CABANACONDE" 	& nomb_ccpp=="PINCHOLLO")			| // 36  
		(nomb_dstrt=="LARI" 		& nomb_ccpp=="LARI")				| // 37
		(nomb_dstrt=="CHICHAS" 	    & nomb_ccpp=="CHICHAS") 			| // 38
		(nomb_dstrt=="ALCA" 		& nomb_ccpp=="AYAHUASI") 			| // 39
		(nomb_dstrt=="LLOCHEGUA" 	& nomb_ccpp=="BUENOS AIRES")		| // 40
		(nomb_dstrt=="SIVIA" 		& nomb_ccpp=="CCECCA") 				| // 41
		(nomb_dstrt=="SIVIA" 		& nomb_ccpp=="NARANJAL") 			| // 42
		(nomb_dstrt=="SIVIA" 		& nomb_ccpp=="PALMAPAMPA") 			| // 43
		(nomb_dstrt=="SIVIA" 		& nomb_ccpp=="RAMOS PAMPA") 		| // 44
		(nomb_dstrt=="SIVIA" 		& nomb_ccpp=="TRIBOLINE")			| // 45
		(nomb_dstrt=="SIVIA" 		& nomb_ccpp=="VILLA RICA") 			| // 46
		(nomb_dstrt=="SIVIA" 		& nomb_ccpp=="VISTA ALEGRE")		| // 47
		(nomb_dstrt=="QUEROCOTO" 	& nomb_ccpp=="EL NARANJO") 			| // 48
		(nomb_dstrt=="COLASAY" 		& nomb_ccpp=="BOLIVAR") 			| // 49
		(nomb_dstrt=="JAEN" 		& nomb_ccpp=="LAS DELICIAS") 		| // 50
		(nomb_dstrt=="HUARANGO" 	& nomb_ccpp=="NARANJO CHACAS")		| // 51
		(nomb_dstrt=="SAN IGNACIO" 	& (nomb_ccpp=="FLOR DE LA FRONTERA" | nomb_ccpp=="QUIRACAS")) | // 52
		(nomb_dstrt=="SAN JOSE DE LOURDES" & (nomb_ccpp=="NUEVO SAN LORENZO" | nomb_ccpp=="LA CATAGUA")) | // 53
		(nomb_dstrt=="LAMAY"		& nomb_ccpp=="HUANCCO PILLPINTO")	| // 54
		(nomb_dstrt=="LAMAY" 		& (nomb_ccpp=="POQUES PATA" | nomb_ccpp=="POQUES" | nomb_ccpp=="ZAPACTO")) | // 55
		(nomb_dstrt=="LARES" 		& nomb_ccpp=="ROSASPATA")			| // 56
		(nomb_dstrt=="YANATILE" 	& nomb_ccpp=="COLCA") 				| // 57
		(nomb_dstrt=="PITUMARCA" 	& nomb_ccpp=="CHILLCA") 			| // 58
		(nomb_dstrt=="PICHIGUA" 	& (nomb_ccpp=="NUEVA ESPERANZA" | nomb_ccpp=="MOROCCO")) | // 59
		(nomb_dstrt=="KIMBIRI" 		& nomb_ccpp=="MANITEA ALTA") 		| // 60
		(nomb_dstrt=="KIMBIRI" 		& (nomb_ccpp=="QORICHAYOC" | nomb_ccpp=="CCORICHAYOC")) | // 61
		(nomb_dstrt=="MARANURA" 	& nomb_ccpp=="MANDOR") 				| // 62
		(nomb_dstrt=="PICHARI" 		& nomb_ccpp=="NATIVIDAD") 			| // 63
		(nomb_dstrt=="PICHARI" 		& nomb_ccpp=="OTARI SAN MARTIN")	| // 64
		(nomb_dstrt=="PICHARI"		& nomb_ccpp=="QUISTO CENTRAL") 		| // 65
		(nomb_dstrt=="QUELLOUNO" 	& nomb_ccpp=="CHANCAMAYO") 			| // 66
		(nomb_dstrt=="PACCARITAMBO" & nomb_ccpp=="MOLLEBAMBA")			| // 67
		(nomb_dstrt=="HUAYLLABAMBA" & nomb_ccpp=="URQUILLOS") 			| // 68
		(nomb_dstrt=="URUBAMBA" 	& nomb_ccpp=="RUMICHACA BAJA")		| // 69
		(nomb_dstrt=="PAUCARA" 		& nomb_ccpp=="CHECCO CRUZ") 		| // 70
		(nomb_dstrt=="CONGALLA" 	& nomb_ccpp=="CONGALLA") 			| // 71
		(nomb_dstrt=="SANTO TOMAS DE PATA" & nomb_ccpp=="CUTICCSA")		| // 72
		(nomb_dstrt=="CAPILLAS" 	& nomb_ccpp=="CAPILLAS") 			| // 73 
		(nomb_dstrt=="CHUPAMARCA" 	& nomb_ccpp=="CHUPAMARCA")			| // 74
		(nomb_dstrt=="HUAMATAMBO" 	& nomb_ccpp=="HUAMATAMBO")			| // 75
		(nomb_dstrt=="SANTA ANA" 	& (nomb_ccpp=="SANTA ANA" | nomb_ccpp=="SANTA ROSA")) | // 76
		(nomb_dstrt=="COSME" 		& nomb_ccpp=="SANTA ROSA DE LLACUA") | // 77
		(nomb_dstrt=="YAULI" 		& nomb_ccpp=="MATIPACCANA") 		| // 78
		(nomb_dstrt=="HUAYACUNDO ARMA" & nomb_ccpp=="CARMEN ALTO")		| // 79
		(nomb_dstrt=="SAN ANTONIO DE CUSICANCHA" & nomb_ccpp=="RUMICHACA") | // 80
		(nomb_dstrt=="DANIEL HERNANDEZ" & nomb_ccpp=="MARCOPATA")  		| // 81
		(nomb_dstrt=="PERENE" 		& nomb_ccpp=="ALTO TOTERANI") 		| // 82
		(nomb_dstrt=="PERENE" 		& nomb_ccpp=="INCHATINGARI") 		| // 83
		(nomb_dstrt=="PERENE" 		& nomb_ccpp=="GRAN PLAYA SUR") 		| // 84
		(nomb_dstrt=="PERENE" 		& nomb_ccpp=="PICHIROKI")			| // 85
		(nomb_dstrt=="PERENE" 		& nomb_ccpp=="PUERTO VICTORIA")		| // 86
		(nomb_dstrt=="PERENE" 		& nomb_ccpp=="SAN FERNANDO DE KIVINAKI") | // 87
		(nomb_dstrt=="PICHANAQUI" 	& nomb_ccpp=="BAJO KIMIRIKI")		| // 88
		(nomb_dstrt=="SAN LUIS DE SHUARO" & nomb_ccpp=="PUENTE CAPELO") | // 89
		(nomb_dstrt=="SAN LUIS DE SHUARO" & nomb_ccpp=="RIO SECO")		| // 90 
		(nomb_dstrt=="SAN LUIS DE SHUARO" & nomb_ccpp=="ZONA 08") | // 91
		(nomb_dstrt=="SAN RAMON" 	& nomb_ccpp=="ANEXO 14 IVITA") | // 92 
		(nomb_dstrt=="SAN RAMON" 	& nomb_ccpp=="LA AUVERNIA") 		| // 93
		(nomb_dstrt=="LLAYLLA" 		& nomb_ccpp=="BELEN")				| // 94
		(nomb_dstrt=="LLAYLLA" 		& nomb_ccpp=="HERMOSA PAMPA")		| // 95
		(nomb_dstrt=="PANGOA" 		& (nomb_ccpp=="NARANJAL"|nomb_ccpp=="BARRIO NARANJAL")) | // 96
		(nomb_dstrt=="PANGOA" 		& nomb_ccpp=="CIUDAD DE DIOS") 		| // 97
		(nomb_dstrt=="PANGOA"		& nomb_ccpp=="LOBERA") 				| // 98
		(nomb_dstrt=="RIO NEGRO" 	& nomb_ccpp=="ALTO HUAHUARI")		| // 99
		(nomb_dstrt=="RIO NEGRO" 	& nomb_ccpp=="UNION CAPIRI")		| // 100
		(nomb_dstrt=="RIO TAMBO" 	& nomb_ccpp=="ALTO SHIMA")			| // 101
		(nomb_dstrt=="SATIPO" 		& nomb_ccpp=="BAJO MARANQUIARI")	| // 102 
		(nomb_dstrt=="SATIPO" 		& nomb_ccpp=="TZANCUVATZIARI")		| // 103
		(nomb_dstrt=="HUARAL" 		& nomb_ccpp=="RETES")				| // 104
		(nomb_dstrt=="SAYAN" 		& nomb_ccpp=="LA CAPULLANA")		| // 105
		(nomb_dstrt=="SAYAN" 		& (nomb_ccpp=="LA ENSENADA" | nomb_ccpp=="SANTA ROSA" | nomb_ccpp=="IRRIGACION SANTA ROSA")) | // 106
		(nomb_dstrt=="CATAHUASI" 	& (nomb_ccpp=="CATAHUASI" | nomb_ccpp=="SAN GERONIMO")) | // 107
		(nomb_dstrt=="CHONTABAMBA" 	& nomb_ccpp=="PALMERAS") | // 108
		(nomb_dstrt=="CHONTABAMBA" 	& nomb_ccpp=="PUSAPNO")	 | // 109
		(nomb_dstrt=="CONSTITUCION" & (nomb_ccpp=="NUEVO PORVENIR"|nomb_ccpp=="PORVENIR")) | // 110
		(nomb_dstrt=="CONSTITUCION" & nomb_ccpp=="FLOR DE UN DIA") 		| // 111
		(nomb_dstrt=="OXAPAMPA" 	& nomb_ccpp=="PURRAYO")				| // 112
		(nomb_dstrt=="PUERTO BERMUDEZ" 	& nomb_ccpp=="SANTA ROSA DE CHIVIS") | // 113
		(nomb_dstrt=="SAN JOSE DE SISA" & nomb_ccpp=="SAN JOSE DE SISA")	 | // 114
		(nomb_dstrt=="SANTA ROSA" 	& nomb_ccpp=="SANTA ROSA")			| // 115
		(nomb_dstrt=="EL ESLABON" 	& nomb_ccpp=="EL ESLABON") 			| // 116
		(nomb_dstrt=="PISCOYACU" 	& nomb_ccpp=="PISCOYACU")			| // 117
		(nomb_dstrt=="SAPOSOA" 		& nomb_ccpp=="SAPOSOA") 			| // 118
		(nomb_dstrt=="TABALOSOS" 	& nomb_ccpp=="TABALOSOS")			| // 119
		(nomb_dstrt=="CAMPANILLA" 	& (nomb_ccpp=="BELLAVISTA" | nomb_ccpp=="CAMPANILLA")) | // 120
		(nomb_dstrt=="PACHIZA" 		& nomb_ccpp=="PACHIZA")				| // 121
		(nomb_dstrt=="YANTALO" 		& nomb_ccpp=="YANTALO") 			| // 122
		(nomb_dstrt=="TRES UNIDOS"  & nomb_ccpp=="TRES UNIDOS")			| // 123
		(nomb_dstrt=="RIOJA" 		& nomb_ccpp=="RIOJA") 				| // 124
		(nomb_dstrt=="JUAN GUERRA" 	& nomb_ccpp=="JUAN GUERRA")			| // 125
		(nomb_dstrt=="SAUCE" 		& nomb_ccpp=="SAUCE")				| // 126
		(nomb_dstrt=="NUEVO PROGRESO" & (nomb_ccpp=="NUEVO PROGRESO"|nomb_ccpp=="SANTA CRUZ")) 	| // 127
		(nomb_dstrt=="POLVORA" 		& (nomb_ccpp=="POLVORA" | nomb_ccpp=="PUERTO RICO"))	   	| // 128
		(nomb_dstrt=="SHUNTE" 		& (nomb_ccpp=="SHUNTE"	 | nomb_ccpp=="SAN FRANCISCO")) 	| // 129""
		(nomb_dstrt=="TOCACHE" 		& (nomb_ccpp=="TOCACHE"	 | nomb_ccpp=="ISHANGA")) 			| // 130
		(nomb_dstrt=="UCHIZA" 		& (nomb_ccpp=="UCHIZA" 	 | nomb_ccpp=="CHONTALLAQUILLO"	 	| nomb_ccpp=="CHONTAYAQUILLO")) 	| // 131
		(nomb_dstrt=="SAN JACINTO"  & nomb_ccpp=="CASA BLANQUEADA") 	| 	// 132
		(nomb_dstrt=="SAN JACINTO" 	& nomb_ccpp=="PLATEROS")			| 	// 133
		(nomb_dstrt=="AGUAS VERDES" & nomb_ccpp=="POCITOS")				| 	// 134
		(nomb_dstrt=="PAPAYAL"  	& nomb_ccpp=="UÑA DE GATO");				// 135
# delimit cr // elimina a observaciones del ccpp EL CEDRON que están en ambas bd