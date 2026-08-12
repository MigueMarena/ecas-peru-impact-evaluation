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
// Bootstrap robusto en batch fresh (fix bug ${ruta_scripts}; ver script 30).
if "${CONSULT}" == "" qui do "C:\\Users\\carlo\\ado\\personal\\profile.do"
include "${CONSULT}\\BID\\HRC0052956\\2_Scripts\\00_master.do"
use "`outc4'\\Panel_Inicio.dta", clear

// Quedar solo con variables de identificación de productor por periodo y producto a evaluar
keep codprod Codprod22 post prod_ECA_eval
sort Codprod22 post
compress 

save "`outc6'\\Productor-Producto.dta", replace