//------------------------------------------------------------------------------
// File           : config.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 14/08/2026
// Description    : Configuración del entorno del proyecto. Resuelve ${ECAS}
//                  (la raíz del repositorio), define las rutas globales por
//                  fase, crea la estructura de carpetas para datos crudos
//                  (Raw/) y procesados (Out/), y establece macros locales
//                  para referenciar bases de datos clave.
//                  Solo entorno — no procesa datos, por eso es seguro de
//                  `include` desde cualquier script sin disparar nada.
//                  El orden de ejecución del pipeline vive en run_all.do.
// Depends        : (ninguno)
// Input          : (ninguno — no lee datos)
// Output         : (ninguno — crea la estructura de carpetas; no escribe datos)
//------------------------------------------------------------------------------

version 19.0

//==============================================================================
// Step 1: Resolver la raíz del proyecto
//==============================================================================
// ${ECAS} es la ÚNICA entrada de configuración del pipeline: la ruta a la raíz
// del repositorio. Todo lo demás se deriva de ella, así que ninguna ruta de
// máquina vive dentro del repositorio.
//
// Se resuelve en este orden:
//   1. ${ECAS} ya definido. Es el caso normal: se fija una sola vez por
//      máquina, FUERA del repositorio (por ejemplo en el profile.do personal
//      de Stata, junto a las demás globals de proyecto).
//   2. El directorio de trabajo, si contiene el centinela
//      2_Scripts/A_setup/config.do
//      — el caso de quien hace `cd` a la raíz antes de correr.
//   3. config_local.do en el directorio de trabajo: un archivo que solo define
//      ${ECAS}, escrito a mano para una máquina donde el repositorio no está
//      donde las dos opciones anteriores lo buscan. No se versiona.

if "${ECAS}" == "" {
	capture confirm file "2_Scripts/A_setup/config.do"
	if !_rc global ECAS "`c(pwd)'"
}
if "${ECAS}" == "" {
	capture confirm file "config_local.do"
	if !_rc qui include "config_local.do"
}
if "${ECAS}" == "" {
	di as error "No pude ubicar la raíz del proyecto."
	di as error "Define la global ECAS con la ruta al repositorio, por ejemplo:"
	di as error `"    global ECAS "D:/ruta/al/repositorio""'
	di as error "o ejecuta Stata desde esa raíz."
	exit 601
}
capture confirm file "${ECAS}/2_Scripts/A_setup/config.do"
if _rc {
	di as error "La global ECAS no apunta a la raíz del proyecto:"
	di as error "    ${ECAS}"
	di as error "Se esperaba encontrar ahí 2_Scripts/A_setup/config.do."
	exit 601
}

//==============================================================================
// Step 2: Set up absolute and relative paths
//==============================================================================
// Ruta absoluta del proyecto.
// Se normalizan los separadores a "\": Stata acepta "/" y "\" indistintamente en
// Windows, pero las herramientas externas que el pipeline invoca no. Word por COM
// (update_fields_export_pdf.ps1, verify_compiled_docx.ps1) rechaza una ruta con
// separadores mezclados —"D:/ruta/al/repo\5_Entregables\..."— con un
// "no encontramos el archivo" que no dice nada del separador. Como ${ECAS} la
// escribe el usuario, puede venir de cualquier forma; aquí se unifica una vez.
local ecas_norm = subinstr("${ECAS}", "/", "\", .)
global ruta_abs "`ecas_norm'"

// Rutas relativas
global ruta_share   "${ruta_abs}\\0_1 Compartidos"
global ruta_data	"${ruta_abs}\\1_Data"	
global ruta_scripts "${ruta_abs}\\2_Scripts"
global ruta_logs	"${ruta_abs}\\3_Logs"
global ruta_trash   "${ruta_abs}\\4_Trash"
global ruta_deliv   "${ruta_abs}\\5_Entregables"

global ruta_images  "${ruta_deliv}\\Reporte Final_VPaper\\Imágenes"
global ruta_tablas  "${ruta_deliv}\\Reporte Final_VPaper\\Tablas"
global ruta_seccio  "${ruta_deliv}\\Reporte Final_VPaper\\Secciones"
global ruta_report  "${ruta_deliv}\\Reporte Final_VPaper\\Versiones"

global ruta_docum   "${ruta_share}\\01-CSD-RND\\CSD-RND_ECAs_documentacion"

// Subcarpetas por fase. Cada global lleva el mismo nombre que su carpeta, para
// que run_all.do resuelva la ruta con ${ruta_`fase'} sin tabla de traducción.
global ruta_setup  		"${ruta_scripts}\\A_setup"
global ruta_ingest 		"${ruta_scripts}\\B_ingest"
global ruta_treatment  	"${ruta_scripts}\\C_treatment"
global ruta_merge  		"${ruta_scripts}\\D_merge"
global ruta_build  		"${ruta_scripts}\\E_build"
global ruta_estimation  "${ruta_scripts}\\G_estimation"
global ruta_reporting  	"${ruta_scripts}\\H_reporting"
global ruta_diagnostics "${ruta_scripts}\\I_diagnostics"

// Programas y utilidades reusables (invocados desde los scripts de fase)
global ruta_utils  "${ruta_scripts}\\_utils"

//==============================================================================
// Step 3: Create directory structure and define path references
//==============================================================================
local raw 	"${ruta_data}\\Raw"
local out	"${ruta_data}\\Out"

// Carpetas en Raw
cap mkdir "`raw'\\1_Encu Linea Base"
cap mkdir "`raw'\\2_Encu Linea Segui"
cap mkdir "`raw'\\3_Centros Poblados y su Estatus de Tratamiento"

// Carpetas en Out
cap mkdir "`out'\\1_Encu Linea Base"
cap mkdir "`out'\\2_Encu Linea Segui"
cap mkdir "`out'\\3_Centros Poblados y su Estatus de Tratamiento"
cap mkdir "`out'\\4_BDs Fusionadas"
cap mkdir "`out'\\5_BDs por grupos de vars"
cap mkdir "`out'\\6_Temporales"

// Referencias locales a subcarpetas
local c1 	"1_Encu Linea Base"
local c2 	"2_Encu Linea Segui"
local c3    "3_Centros Poblados y su Estatus de Tratamiento"
local c4 	"4_BDs Fusionadas"
local c5 	"5_BDs por grupos de vars"
local c6	"6_Temporales"
local rawc1 "`raw'\\`c1'"
local outc1 "`out'\\`c1'"
local rawc2 "`raw'\\`c2'"
local outc2 "`out'\\`c2'"
local rawc3 "`raw'\\`c3'"
local outc3 "`out'\\`c3'"
local outc4 "`out'\\`c4'"
local outc5 "`out'\\`c5'"
local outc6 "`out'\\`c6'"

local outc3prod "`outc3'\\Productor"
local outc3ccpp "`outc3'\\CCPP"

// Subcarpetas especificas dentro de Out
cap mkdir "`outc3'\\Productor"
cap mkdir "`outc3'\\CCPP"

// Carpetas del Reporte Final. `mkdir' no crea padres intermedios, así que hay
// que ir nivel por nivel: sin esto, en un árbol limpio los `cap mkdir' de las
// categorías fallan en silencio y la fase de estimación aborta con r(198)
// ("Exception creating output stream") al intentar guardar la primera tabla.
cap mkdir "${ruta_deliv}"
cap mkdir "${ruta_deliv}\\Reporte Final_VPaper"
cap mkdir "${ruta_tablas}"
cap mkdir "${ruta_images}"
cap mkdir "${ruta_seccio}"
cap mkdir "${ruta_report}"

// Tablas: el tema manda y dentro se separa Cuerpo de Anexo, de modo que una
// tabla del cuerpo y su robustez viven juntas.
local tab_cats `" "0_Diseño_y_Diagnóstico" "1_Conocimiento_Agronómico" "2_Prácticas_Agronómicas" "3_Registros_e_Inocuidad_Alimentaria" "4_Indicadores_Compuestos_BPAs" "5_Resultados_Productivos_y_Económicos" "'

foreach cat of local tab_cats {
	cap mkdir "${ruta_tablas}\\`cat'"
	cap mkdir "${ruta_tablas}\\`cat'\\Cuerpo"
	cap mkdir "${ruta_tablas}\\`cat'\\Anexo"
}

// Carpetas de Imágenes
cap mkdir "${ruta_images}\\Gráfico_Consort"
cap mkdir "${ruta_images}\\Gráfico_Loveplot"

// Bases para fusionar en 4_BDs Fusionadas
local basesInicio	""`outc1'\pcl_Inicio_LB"   	"`outc2'\pcl_Inicio_LS""
local basesPersonas ""`outc1'\pcl_Personas_LB" 	"`outc2'\pcl_NuevosIntegrantes_LS""
local basesParcela  ""`outc1'\pcl_Parcela_LB" 	"`outc2'\pcl_Parcela_LS""
local basesCultivo  ""`outc1'\pcl_Cultivo_LB" 	"`outc2'\pcl_Cultivo_LS""