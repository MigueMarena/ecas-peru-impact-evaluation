//------------------------------------------------------------------------------
// File           : _utils/lab_sino.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 14/08/2026
// Description    : Define la etiqueta de valores `sino', usada en todo el
//                  pipeline para variables binarias 0/1.
//
//                  Hay que invocarlo DESPUÉS de cada `use'. Una etiqueta de
//                  valores es propiedad del dataset, no de la sesión: `use'
//                  reemplaza las que haya en memoria por las del archivo que
//                  carga, así que no existe forma de definirla una sola vez
//                  para toda la corrida, como sí ocurre con una global.
//
//                  Lo que este archivo centraliza es el TEXTO de la etiqueta.
//                  Antes se repetía en 11 sitios y no todos coincidían: B2
//                  escribía "Si" sin tilde y el resto "Sí", de modo que el
//                  mismo 1 se leía distinto según la base.
//
//                  El `cap lab drop' previo no es decorativo: `lab def' aborta
//                  con r(110) si la etiqueta ya existe, aunque el contenido
//                  sea idéntico. Sin él, el script falla en cuanto la base
//                  cargada ya traiga `sino' definida.
// Depends        : (ninguno)
// Input          : (ninguno — opera sobre los datos en memoria)
// Output         : (ninguno — define la etiqueta de valores `sino')
//------------------------------------------------------------------------------

cap lab drop sino
lab def sino 0 "No" 1 "Sí"
