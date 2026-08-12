//------------------------------------------------------------------------------
// File             : A_master.do
// Author           : Carlos Marena
// Email            : carlosmarena1995@gmail.com
// Last Mod. Date   : 15/04/2026
// Description      : Script maestro que inicializa el entorno del
// proyecto. Define rutas de directorios globales y locales, crea la
// estructura de carpetas para datos crudos (Raw/) y procesados
// (Out/), y establece macros locales para referenciar bases de datos
// clave en las distintas etapas del procesamiento. Debe ejecutarse
// antes que cualquier otro script.
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
//      2_Scripts/A_setup/A_master.do
//      — el caso de quien hace `cd` a la raíz antes de correr.
//   3. config_local.do en el directorio de trabajo: escotilla para máquinas con
//      un layout distinto. No se versiona.

if "${ECAS}" == "" {
	capture confirm file "2_Scripts/A_setup/A_master.do"
	if !_rc global ECAS "`c(pwd)'"
}
if "${ECAS}" == "" {
	capture confirm file "config_local.do"
	if !_rc qui include "config_local.do"
}
if "${ECAS}" == "" {
	di as error "No pude ubicar la raíz del proyecto."
	di as error "Definí la global ECAS con la ruta al repositorio, por ejemplo:"
	di as error `"    global ECAS "D:/ruta/al/repositorio""'
	di as error "o ejecutá Stata desde esa raíz."
	exit 601
}
capture confirm file "${ECAS}/2_Scripts/A_setup/A_master.do"
if _rc {
	di as error "La global ECAS no apunta a la raíz del proyecto:"
	di as error "    ${ECAS}"
	di as error "Se esperaba encontrar ahí 2_Scripts/A_setup/A_master.do."
	exit 601
}

//==============================================================================
// Step 2: Set up absolute and relative paths
//==============================================================================
// Ruta absoluta del proyecto
global ruta_abs "${ECAS}"

// Rutas relativas
global ruta_share   "${ruta_abs}\\0_1 Compartidos"
global ruta_data	"${ruta_abs}\\1_Data"	
global ruta_scripts "${ruta_abs}\\2_Scripts"
global ruta_logs	"${ruta_abs}\\3_Logs"
global ruta_trash   "${ruta_abs}\\4_Trash"
global ruta_deliv   "${ruta_abs}\\5_Entregables"

global ruta_images  "${ruta_deliv}\\Reporte Final_VPaper\\Imágenes"
global ruta_tablas  "${ruta_deliv}\\Reporte Final_VPaper\\Tablas"
global ruta_anexos	"${ruta_deliv}\\Reporte Final_VPaper\\Anexos"
global ruta_seccio  "${ruta_deliv}\\Reporte Final_VPaper\\Secciones"
global ruta_report  "${ruta_deliv}\\Reporte Final_VPaper\\Versiones"

global ruta_docum   "${ruta_share}\\01-CSD-RND\\CSD-RND_ECAs_documentacion"

// Subcarpetas por fase. La estructura de 2_Scripts/ espeja la de code/ en el
// repositorio público, así que el manifiesto de publicación es 1:1 y no
// traduce nombres: lo que se ve acá es lo que se publica.
global ruta_setup  "${ruta_scripts}\\A_setup"
global ruta_ingest "${ruta_scripts}\\B_ingest"
global ruta_treatment  "${ruta_scripts}\\C_treatment"
global ruta_merge  "${ruta_scripts}\\D_merge"
global ruta_build  "${ruta_scripts}\\E_build"
global ruta_estimation  "${ruta_scripts}\\G_estimation"
global ruta_reporting  "${ruta_scripts}\\H_reporting"
global ruta_diagnostics   "${ruta_scripts}\\I_diagnostics"

// Programas y utilidades reusables (invocados desde los scripts de fase)
global ruta_utils  "${ruta_scripts}\\_utils"

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\A_master.log"
log using "${ruta_logs}\A_master.log", replace text


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

// Carpetas de Tablas (Reporte Final): una carpeta plana por categoría.
// Las tablas 3-paneles producidas por prg_table_3panels unifican F-U/DiD/LATE
// en un solo .docx; la subdivisión por estimador (antes 1_ITT/ y 2_LATE/)
// quedó obsoleta y fue removida del pipeline.
local tab_cats `" "1_Conocimiento_Agronómico" "2_Prácticas_Agronómicas" "3_Registros_e_Inocuidad_Alimentaria" "4_Indicadores_Compuestos_BPAs" "5_Resultados_Productivos_y_Económicos" "'

foreach cat of local tab_cats {
	cap mkdir "${ruta_tablas}\\`cat'"
}

// Carpetas de Anexos
cap mkdir "${ruta_anexos}\\Prácticas_Agronómicas"
cap mkdir "${ruta_anexos}\\Registros_e_Inocuidad_Alimentaria"
cap mkdir "${ruta_anexos}\\Indicadores_Compuestos_BPAs"
cap mkdir "${ruta_anexos}\\Diagnóstico_del_Diseño"

// Carpetas de Diseño y Diagnóstico (scripts 30-40)
local diag_cats `" "1_CONSORT" "2_Cluster_Descriptivos" "3_Balance" "4_Atricion" "5_Compliance" "6_Robustez_Timing" "'
cap mkdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico"
foreach cat of local diag_cats {
	cap mkdir "${ruta_tablas}\\0_Diseño_y_Diagnóstico\\`cat'"
}

// Carpetas de Imágenes para Diseño y Diagnóstico
cap mkdir "${ruta_images}\\Gráfico_Consort"
cap mkdir "${ruta_images}\\Gráfico_Loveplot"

// Bases para fusionar en 4_BDs Fusionadas
local basesInicio	""`outc1'\pcl_Inicio_LB"   	"`outc2'\pcl_Inicio_LS""
local basesPersonas ""`outc1'\pcl_Personas_LB" 	"`outc2'\pcl_NuevosIntegrantes_LS""
local basesParcela  ""`outc1'\pcl_Parcela_LB" 	"`outc2'\pcl_Parcela_LS""
local basesCultivo  ""`outc1'\pcl_Cultivo_LB" 	"`outc2'\pcl_Cultivo_LS""

//==============================================================================
// Step 4: Cierre
//==============================================================================
// El ORDEN DE EJECUCIÓN del pipeline ya no vive acá: está en run_all.do, que es
// el orquestador. Este archivo define el entorno y nada más, y por eso es
// seguro hacerle `include` desde cualquier script sin disparar nada.
//
// (Tenerlos juntos era la trampa: los 35 scripts hacen `include` de este
// archivo, así que activar aquí las llamadas del pipeline habría producido
// recursión infinita.)

log close
