//------------------------------------------------------------------------------
// File             : B1_ingest_copy_files.do
// Author           : Carlos Marena
// Email            : carlosmarena1995@gmail.com
// Last Mod. Date   : 10/04/2026
// Description      : Copia archivos fuente (encuestas LB y LS,
// bases de CCPPs e insumos de la consultoria M.A.) desde las
// carpetas de documentacion del proyecto hacia la estructura
// Raw/ del directorio de datos.
//
// Depends          : (ninguno)
// Input            : Archivos .dta y .xlsx descubiertos
//                    dinamicamente en:
//                    ${ruta_docum}\Base SENASA\Bases Linea de base\,
//                    ${ruta_docum}\Base SENASA\Bases seguimiento\,
//                    ${ruta_docum}\Identificacion_tratados\Archivos_ccpp\,
//                    Entregable_2_Inocuidad_SENASA.zip
// Output           : Copias en Raw\1_Encu Linea Base\,
//                    Raw\2_Encu Linea Segui\,
//                    Raw\3_Centros Poblados y su Estatus de Tratamiento\
//------------------------------------------------------------------------------

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\B1_ingest_copy_files.log"
log using "${ruta_logs}\B1_ingest_copy_files.log", replace text

//==============================================================================
// Step 1: Create input directory structure
//==============================================================================
cap mkdir "${ruta_data}\Raw\1_Encu Linea Base"
cap mkdir "${ruta_data}\Raw\2_Encu Linea Segui"
cap mkdir "${ruta_data}\Raw\3_Centros Poblados y su Estatus de Tratamiento"
cap mkdir "${ruta_data}\Raw\3_Centros Poblados y su Estatus de Tratamiento\Insumos Consultoría M.A"
cap mkdir "${ruta_data}\Raw\3_Centros Poblados y su Estatus de Tratamiento\Insumos Consultoría M.A\Entregable 2"

//==============================================================================
// Step 2: Copy source files to Raw
//==============================================================================
// Insumos de linea base
local path_from "${ruta_docum}\Base SENASA\Bases Linea de base"
local path_to	"${ruta_data}\Raw\1_Encu Linea Base"	 
local files: dir "`path_from'" files "*.dta", respectcase	// stata files
local files: dir "`path_from'" files "*.xlsx", respectcase  // excel files

foreach f of local files{
	copy "`path_from'\\`f'" "`path_to'\\`f'", replace
} 

// Insumos de linea de seguimiento
local path_from "${ruta_docum}\Base SENASA\Bases seguimiento"
local path_to	"${ruta_data}\Raw\2_Encu Linea Segui"
local files: dir "`path_from'" files "*.dta", respectcase	// stata files
local files: dir "`path_from'" files "*.xlsx", respectcase 	// excel files

foreach f of local files{
	copy "`path_from'\\`f'" "`path_to'\\`f'", replace
} 

// NOTA: Explorar de donde provienen los archivos:
//   - Cultivo_modif.dta y
//   - NuevosIntegrantesHogar_modf.dta
// Ambos parecen hacer modificaciones leves a los
// archivos en la carpeta de insumos.

// Insumos de CCPPs con asignacion inicial y estatus de tratamiento
local path_from "${ruta_docum}\Identificacion_tratados\Archivos_ccpp"
local path_to	"${ruta_data}\Raw\3_Centros Poblados y su Estatus de Tratamiento"
local files: dir "`path_from'" files "*.xlsx", respectcase

foreach f of local files{
	copy "`path_from'\\`f'" "`path_to'\\`f'", replace
} 

// Ruta insumo Marcos Agurto
local path_from "${ruta_docum}\Identificacion_tratados\Acompañamiento_linea_base_marcos"
cd "${ruta_data}\Raw\3_Centros Poblados y su Estatus de Tratamiento\Insumos Consultoría M.A\Entregable 2"
unzipfile "`path_from'\Entregable_2_Inocuidad_SENASA.zip", replace 

// NOTA: En que difieren ccpp_intervencion.xlsx y
// ccpp_senasa_validado_final_12.02.xlsx?

log close
