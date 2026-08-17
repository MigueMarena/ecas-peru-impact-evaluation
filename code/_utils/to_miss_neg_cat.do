//------------------------------------------------------------------------------
// File           : to_miss_neg_cat.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Programa que recodifica categorias negativas (NS/NC, NA)
//                  a missing y limpia las etiquetas de valor correspondientes.
//------------------------------------------------------------------------------
program define to_miss_neg_cat
	version 19.0
	syntax varname
	
	// 1. Obtener el nombre del label de la variable
    local label_name : value label `varlist'
	
	// 2. Guardar las etiquetas
	local labels_list
    qui levelsof `varlist', local(valores)
	local counter = 0
	foreach val in `valores' {
		if `val' < 0{
			local etiqueta : label (`label_name') `val'
			dis as text "Categoría de `varlist': `val' (`etiqueta') a missing"
			// Volvemos missings a categoría con valores < 0
			replace `varlist' = . if `varlist'==`val' 
		}
	}
end