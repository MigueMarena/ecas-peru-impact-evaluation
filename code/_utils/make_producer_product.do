//----------------------------------------------------------------------
// File           : make_producer_product.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Crea base auxiliar Productor-Producto.dta con la identificacion
//                  de cada productor por periodo y producto a evaluar.
// Input          : Out/4_.../Panel_Inicio.dta
// Output         : Out/6_.../Productor-Producto.dta
//----------------------------------------------------------------------
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
// A_master.do se incluye SIEMPRE, sin guardarlo tras un `if' sobre alguna
// global: define locales (`outc1', `rawc1', …) y `do' abre un scope nuevo,
// así que los locales del llamador NO llegan hasta acá. Saltarse el include
// porque las globals ya existan deja al script sin rutas y falla con r(601).
// `include' es idempotente: solo redefine rutas y crea carpetas con `cap'.
capture qui include "${ECAS}/2_Scripts/A_setup/A_master.do"
if _rc capture qui include "2_Scripts/A_setup/A_master.do"
if "${ruta_data}" == "" {
	di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
	di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
	exit 601
}

// Rutas derivadas del global ${ruta_data}. Este helper se invoca con `do', que
// abre un scope nuevo: los locales `outc*' que define A_master.do NO llegan
// hasta acá. Mismo patrón que prg_load_panel.do.
local outc4 "${ruta_data}/Out/4_BDs Fusionadas"
local outc6 "${ruta_data}/Out/6_Temporales"

use "`outc4'\\Panel_Inicio.dta", clear

// Quedar solo con variables de identificación de productor por periodo y producto a evaluar
keep codprod Codprod22 post prod_ECA_eval
sort Codprod22 post
compress 

save "`outc6'\\Productor-Producto.dta", replace