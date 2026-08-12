//------------------------------------------------------------------------------
// File           : H1_report_compile.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 10/08/2026
// Description    : Compila el reporte final en DOS documentos independientes,
//                  concatenando las secciones .docx COMPLETAS —con sus tablas,
//                  figuras y notas ya embebidas—. No reconstruye ninguna tabla.
//
//                  (1) Cuerpo : carátula + portadilla de índices + §1 a §12
//                  (2) Anexos : portadilla de índices + Anexo A y Anexo B
//
//                  Las portadillas traen campos TOC reales. Los índices de
//                  tablas y de figuras se arman por ESTILO —los captions llevan
//                  `Titulotabla` y `Titulofigura`, propios del reporte—, y el
//                  par "estilo;nivel" del switch \t va con punto y coma, que es
//                  el separador de lista declarado en el documento.
//
//                  El circuito tiene una validación a la entrada y otra a la
//                  salida, porque los defectos de este pipeline son invisibles
//                  en el archivo suelto y caros de atribuir en el consolidado:
//
//                    Step 2  valida las secciones y ABORTA si hay bloqueantes
//                    Step 3  y 4: el append propiamente dicho
//                    Step 5  sanea lo que el append deja mal (ver allí)
//                    Step 6  resuelve los índices en Word y exporta el PDF
//                    Step 7  comprueba que el resultado abre sin reparación
//
//                  La explicación de cada defecto, con su origen y su historia,
//                  está en Reporte Final_VPaper/Planes_Ejecucion/
//                  52_E_Apoyo_Compilacion_explicada.md
//
// Input          : ${ruta_seccio}\_Indices_Cuerpo.docx
//                  ${ruta_seccio}\_Indices_Anexos.docx
//                  ${ruta_seccio}\0_Carátula.docx
//                  ${ruta_seccio}\1_Introducción.docx  … 12_Referencias.docx
//                  ${ruta_seccio}\Anexos.docx
// Helpers        : ${ruta_utils}\check_sections.py           (Step 2)
//                  ${ruta_utils}\fix_compiled_docx.py        (Step 5)
//                  ${ruta_utils}\update_fields_export_pdf.ps1 (Step 6)
//                  ${ruta_utils}\verify_compiled_docx.ps1    (Step 7)
// Output         : ${ruta_report}\{fecha}_Reporte_EI_Final.docx  (+ .pdf)
//                  ${ruta_report}\{fecha}_Anexos_EI.docx         (+ .pdf)
//------------------------------------------------------------------------------

version 19.0

cls

//==============================================================================
// Step 1: Entorno y log
//==============================================================================
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
if "${ruta_data}" == "" {
	capture qui include "${ECAS}/2_Scripts/A_setup/A_master.do"
	if _rc capture qui include "2_Scripts/A_setup/A_master.do"
	if "${ruta_data}" == "" {
		di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
		di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
		exit 601
	}
}

cap log close
cap erase "${ruta_scripts}\\H1_report_compile.log"
log using "${ruta_logs}\\H1_report_compile.log", replace text

local Date : display %tdCCYY-NN-DD date("$S_DATE", "DMY")

//==============================================================================
// Step 2: Validación previa de las secciones
//==============================================================================
// Compilar un fuente defectuoso cuesta caro: el defecto no se ve en el archivo
// suelto, se manifiesta en el consolidado y ahí es mucho más difícil de
// atribuir. `check_sections.py` revisa las catorce secciones y detiene la
// compilación si encuentra algo que la rompería —prefijos mc:Ignorable sin
// declarar, marcas de párrafo ocultas, notas al pie huérfanas, o un campo TOC
// con el separador equivocado—. Los defectos meramente cosméticos los reporta
// como avisos y deja seguir.
//
// El script crea el archivo centinela SOLO si no hay bloqueantes, de modo que
// cualquier fallo suyo —incluso una excepción o que no encuentre Python—
// también detiene la compilación en lugar de dejarla pasar en silencio.
local ok_check "${ruta_logs}\\_check_sections.OK"
cap erase "`ok_check'"

di as text _n "{hline 70}"
di as text "Validación de las secciones"
di as text "{hline 70}"
shell python "${ruta_utils}\\check_sections.py" "${ruta_seccio}" "`ok_check'"

cap confirm file "`ok_check'"
if _rc {
	di as error _n "{hline 70}"
	di as error "COMPILACIÓN DETENIDA: las secciones no pasaron la validación."
	di as error "Revisá los BLOQUEANTES listados arriba y volvé a correr H1."
	di as error "El detalle de cada chequeo está en Planes_Ejecucion/52_E_Apoyo_Compilacion_explicada.md"
	di as error "{hline 70}"
	log close
	exit 459
}
cap erase "`ok_check'"

//==============================================================================
// Step 3: Documento 1 — Cuerpo (carátula → referencias)
//==============================================================================
// El orden de esta lista ES el orden del documento final. Los encabezados
// `Ttulo1` se numeran solos, de modo que insertar o quitar una sección
// renumera las siguientes sin editar su texto.
local cuerpo   `""0_Carátula.docx""'
local cuerpo `"`cuerpo' "_Indices_Cuerpo.docx""'
local cuerpo `"`cuerpo' "1_Introducción.docx""'
local cuerpo `"`cuerpo' "2_Literatura.docx""'
local cuerpo `"`cuerpo' "3_Contexto_Descr_Interv_ECAs.docx""'
local cuerpo `"`cuerpo' "4_Dis_Exp-Protocolo_Aleatorización_Desv_y_Selección_Muestra.docx""'
local cuerpo `"`cuerpo' "5_Datos.docx""'
local cuerpo `"`cuerpo' "6_Balance_Atrición_Cumplimiento.docx""'
local cuerpo `"`cuerpo' "7_Estrategia_Econométrica.docx""'
local cuerpo `"`cuerpo' "8_Resultados.docx""'
local cuerpo `"`cuerpo' "9_Limitaciones_Siguientes_Pasos.docx""'
local cuerpo `"`cuerpo' "10_Conclusiones.docx""'
local cuerpo `"`cuerpo' "11_Lecciones_Aprendidas_Recomendaciones.docx""'
local cuerpo `"`cuerpo' "12_Referencias.docx""'

// Verificación previa: que exista cada insumo antes de intentar el append.
local faltan ""
foreach f of local cuerpo {
	cap confirm file "${ruta_seccio}\\`f'"
	if _rc local faltan `"`faltan' "`f'""'
}
if `"`faltan'"' != "" {
	di as error "FALTAN insumos del cuerpo:"
	foreach f of local faltan {
		di as error "    `f'"
	}
	exit 601
}

local rutas ""
foreach f of local cuerpo {
	local rutas `"`rutas' "${ruta_seccio}\\`f'""'
}

putdocx clear
putdocx append `rutas', ///
	saving("${ruta_report}\\`Date'_Reporte_EI_Final.docx", replace)

di as text _n "{hline 70}"
di as text "Documento 1 — Cuerpo"
di as text "{hline 70}"
di as text "  Secciones concatenadas: " as result `: word count `cuerpo''
di as text "  Salida: " as result "`Date'_Reporte_EI_Final.docx"

//==============================================================================
// Step 4: Documento 2 — Anexos
//==============================================================================
// `Anexos.docx` ya contiene el Anexo A (marco de resultados potenciales) y el
// Anexo B (72 tablas embebidas en cinco subsecciones). No se reconstruye nada.
local anexos `""_Indices_Anexos.docx" "Anexos.docx""'

local faltan ""
foreach f of local anexos {
	cap confirm file "${ruta_seccio}\\`f'"
	if _rc local faltan `"`faltan' "`f'""'
}
if `"`faltan'"' != "" {
	di as error "FALTAN insumos de los anexos:"
	foreach f of local faltan {
		di as error "    `f'"
	}
	exit 601
}

local rutas ""
foreach f of local anexos {
	local rutas `"`rutas' "${ruta_seccio}\\`f'""'
}

putdocx clear
putdocx append `rutas', ///
	saving("${ruta_report}\\`Date'_Anexos_EI.docx", replace)

di as text _n "{hline 70}"
di as text "Documento 2 — Anexos"
di as text "{hline 70}"
di as text "  Salida: " as result "`Date'_Anexos_EI.docx"

//==============================================================================
// Step 5: Saneamiento del paquete OOXML
//==============================================================================
// `putdocx append` construye el paquete mezclando las partes de las secciones,
// y en esa mezcla deja dos defectos que no se ven hasta abrir el archivo:
//
//   (1) ACUMULA los prefijos mc:Ignorable de todas las secciones de la lista
//       —no solo del primero— pero declara siempre su propio juego fijo de 71
//       namespaces. Basta con que UNA sección se haya guardado con un Word
//       reciente y aporte un prefijo de fuera de ese juego (w16du, w16sdtfl)
//       para que queden prefijos sin declarar. La norma exige que todo prefijo
//       de mc:Ignorable resuelva a un namespace declarado; al no hacerlo, Word
//       rechaza el archivo con "contenido no legible" y lo abre como documento
//       recuperado, sin ruta. Verificado que ni el orden de la lista ni la
//       opción stylesrc() cambian este comportamiento.
//
//   (2) Hereda w:trackRevisions —once de las catorce secciones lo traen
//       activado—, así que el consolidado abre con el control de cambios
//       encendido y toda edición del destinatario queda marcada. Se limpia
//       solo aquí: en las secciones el control de cambios es la forma de
//       trabajo y no se toca.
//
// El Step 2 ya habría detenido la compilación si (1) estuviera presente; este
// paso es la segunda línea de defensa y el único responsable de (2).
// El helper es idempotente: correrlo dos veces no cambia nada la segunda.
local salidas `""`Date'_Reporte_EI_Final.docx" "`Date'_Anexos_EI.docx""'

di as text _n "{hline 70}"
di as text "Saneamiento del paquete"
di as text "{hline 70}"
foreach f of local salidas {
	shell python "${ruta_utils}\\fix_compiled_docx.py" "${ruta_report}\\`f'"
}

//==============================================================================
// Step 6: Resolución de índices y exportación a PDF
//==============================================================================
// Equivale a abrir en Word, Ctrl+E y F9, guardar y exportar. Se hace aquí y no
// en la máquina que reciba el archivo porque el switch \t delimita el par
// "estilo;nivel" con el separador de lista del documento: resueltos los campos,
// los índices ya no dependen de la configuración regional de quien lo abra.
//
// Si Word no está disponible el helper informa y devuelve 2 sin abortar: los
// .docx quedan escritos y los campos se pueden actualizar a mano.
di as text _n "{hline 70}"
di as text "Índices y PDF"
di as text "{hline 70}"
foreach f of local salidas {
	shell powershell -NoProfile -ExecutionPolicy Bypass ///
		-File "${ruta_utils}/update_fields_export_pdf.ps1" "${ruta_report}\\`f'"
}

//==============================================================================
// Step 7: Sonda de integridad sobre el resultado
//==============================================================================
// El único juez fiable de si un .docx abre en Word es Word: un paquete puede
// tener todos sus XML bien formados y aun así ser inválido. La sonda pide
// abrirlo SIN permitir reparación y comprueba, además, que ningún índice haya
// quedado vacío. Si algo falla, la compilación termina con error en lugar de
// dejar un entregable roto con aspecto de terminado.
local ok_verify "${ruta_logs}\\_verify_compiled.OK"
cap erase "`ok_verify'"

local rutas ""
foreach f of local salidas {
	local rutas `"`rutas' "${ruta_report}\\`f'""'
}

di as text _n "{hline 70}"
di as text "Verificación del resultado"
di as text "{hline 70}"
shell powershell -NoProfile -ExecutionPolicy Bypass ///
	-File "${ruta_utils}/verify_compiled_docx.ps1" "`ok_verify'" `rutas'

cap confirm file "`ok_verify'"
if _rc {
	di as error _n "{hline 70}"
	di as error "EL CONSOLIDADO NO PASÓ LA VERIFICACIÓN. No lo entregues así."
	di as error "Revisá el detalle de arriba y Planes_Ejecucion/52_E_Apoyo_Compilacion_explicada.md"
	di as error "{hline 70}"
	log close
	exit 459
}
cap erase "`ok_verify'"

di as text _n "{hline 70}"
di as text "Compilación terminada. En ${ruta_report}:"
foreach f of local salidas {
	di as text "  " as result "`f'"
}
di as text "  " as result "(y el .pdf de cada uno)"
di as text "{hline 70}" _n

log close
