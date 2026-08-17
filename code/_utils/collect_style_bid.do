//------------------------------------------------------------------------------
// File           : _utils/collect_style_bid.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 14/08/2026
// Description    : Aplica el estilo visual del BID a la colección de `collect'
//                  que esté activa. Lo usan los scripts de diagnóstico (I*)
//                  que arman sus tablas con el framework `collect'.
//
//                  Cubre SOLO lo que es estilo de casa y es idéntico en todas
//                  las tablas: tipografía Roboto, encabezado blanco sobre azul
//                  BID, bordes, alineación y tamaños. Antes estas once líneas
//                  estaban repetidas en doce bloques de nueve scripts, con
//                  divergencias menores entre copias.
//
//                  NO cubre nada que dependa del contenido de la tabla: los
//                  `nformat' por columna, el `collect layout', el título, las
//                  notas y el `collect export' se quedan en cada script,
//                  DESPUÉS de invocar este archivo (lo que se declare después
//                  se superpone a lo de aquí).
//
//                  El azul es 0 78 112 = #004e70, el primario del manual de
//                  marca del BID.
//
// Sintaxis:
//   do "${ruta_utils}\collect_style_bid.do" [tamaño_base]
//     tamaño_base : cuerpo en puntos. Por defecto 10; las notas van a
//                   tamaño_base − 1, como en el resto del reporte.
//
// Depends        : (ninguno)
// Input          : (ninguno — opera sobre la colección activa de `collect')
// Output         : (ninguno — solo fija estilos)
//------------------------------------------------------------------------------

version 19.0

local base "`1'"
if "`base'" == "" local base 10
local size_m "`base'pt"
local size_n "`=`base' - 1'pt"

// Celdas: sin borde derecho, sin márgenes internos.
collect style cell, border(right, pattern(nil)) margin(all, width(0pt))

// Columna de etiquetas de fila (cmdset) y columnas de resultados.
// `nobold noitalic' es defensivo: evita heredar énfasis de un estilo previo.
collect style cell cmdset, font(Roboto, size(`size_m') nobold noitalic) ///
	halign(left) valign(center)
collect style cell result, font(Roboto, size(`size_m') nobold noitalic) ///
	halign(center)
collect style cell cell_type[item], font(Roboto, size(`size_m') nobold noitalic)

// Encabezados: blanco en negrita sobre azul BID.
collect style cell cell_type[corner column-header], ///
	shading(background(0 78 112)) ///
	font(Roboto, size(`size_m') color(white) bold noitalic)

// Estructura: sin repetir etiquetas duplicadas, encabezados por etiqueta.
collect style column, dups(center)
collect style header cmdset, level(label)
collect style header result, level(label)
collect style row stack, nobinder

// Título en negrita al cuerpo; notas en itálica un punto menor (estilo APA-AEA).
collect style title, font(Roboto, size(`size_m') bold)
collect style notes, font(Roboto, size(`size_n') italic)
