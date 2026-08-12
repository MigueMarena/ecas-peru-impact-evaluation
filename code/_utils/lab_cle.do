//----------------------------------------------------------------------
// File           : lab_cle.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Programa que analiza etiquetas de valor de una variable
//                  y reporta etiquetas vacias, niveles sin uso y niveles
//                  faltantes.
//----------------------------------------------------------------------
program define lab_cle
    syntax varname 
    
    // 1. Obtener el nombre del label de la variable
    local label_name : value label `varlist'
    di as text "Análisis de la variable " as result "`varlist'"
	
    // Verificar si la variable tiene etiquetas de valor
    if "`label_name'" == "" {
        di as error "La variable `varlist' no tiene etiquetas de valor."
        exit
    }
    
    // 2. Guardar las etiquetas en una macro local
    local labels_list
    qui levelsof `varlist', local(valores) 
    
    foreach val in `valores' {
        local etiqueta : label (`label_name') `val'
        local labels_list `"`labels_list'|`etiqueta'"' // Usa `|` como separador
    }

    // Ver etiquetas obtenidas
    di as text "Etiquetas extraídas: `labels_list'"
    
    // 3. Verificar si todas las etiquetas son numéricas
    local all_numeric 1  // Macro local para verificar si todas las etiquetas son números
    foreach lbl in `labels_list' {
		local clean_lbl = subinstr("`lbl'", "|", "", .) // Elimina separadores
		if regexm("`clean_lbl'", "^[0-9]+(\.[0-9]+)?$")==0 { // Si no se puede convertir en número
			local all_numeric 0
            continue, break
		}
    }
	
    // 4. Realizar acción según el tipo de etiquetas
    if `all_numeric' == 1 {
        di as result "Todas las etiquetas son numéricas."
        // Eliminar la etiqueta y queda solo numérica
		lab drop `label_name'
		lab val `label_name'
    }
    else {
        di as result "Al menos una etiqueta no es numérica."
    }
end
