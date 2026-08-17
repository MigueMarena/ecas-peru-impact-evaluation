//------------------------------------------------------------------------------
// File           : prg_procesa_eca.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Define el programa procesaECA que procesa informacion a nivel
//                  de centros poblados-ECAs y genera indicadores agregados por
//                  ECA para un anio dado.
//------------------------------------------------------------------------------
capture program drop procesaECA
// ============================================================
// Programa: procesaECA
// Objetivo:
//   Procesar información a nivel de Centros Poblados – ECAs
//   y generar indicadores agregados a nivel de cada ECA.
// Argumentos:
//   1. year   = año de referencia
//   2. filein = archivo de entrada a procesar
// ============================================================

program define procesaECA
    version 19.0
    args year filein outdir
    local keysECA nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp nomb_ECA
		
	// --- 1. [Cargar base] ---
    use "`filein'", clear
	
	// --- 2. [Ordenar registros] ---
	// Si existe "fuente" se ordena por fuente; si no, se usa "graduado".
    order `keysECA'
	cap confirm v fuente 
	if _rc==0 {
		gsort `keysECA' nomb_ECA -fuente -prom_fin
	}
	else {
		gsort `keysECA' nomb_ECA -graduado -prom_fin
	}
     
	// --- 3. [Indicadores básicos a nivel de ECA] ---
	by nomb_rgn-nomb_ccpp nomb_ECA: egen astn_ECA  = count(graduado)
	by nomb_rgn-nomb_ccpp nomb_ECA: egen grad_ECA  = total(graduado)
	gen float tasa_grad_ECA  = grad_ECA/astn_ECA * 100
	
	by nomb_rgn-nomb_ccpp nomb_ECA: egen prom_nf_grad_ECA  = mean(prom_fin) if graduado==1
	by nomb_rgn-nomb_ccpp nomb_ECA: carryforward prom_nf_grad_ECA, replace
	
	by nomb_rgn-nomb_ccpp nomb_ECA: egen max_nf_grad_ECA = max(prom_fin) if graduado==1
	by nomb_rgn-nomb_ccpp nomb_ECA: carryforward max_nf_grad_ECA, replace
	
	by nomb_rgn-nomb_ccpp nomb_ECA: egen min_nf_grad_ECA = min(prom_fin) if graduado==1
	by nomb_rgn-nomb_ccpp nomb_ECA: carryforward min_nf_grad_ECA, replace
	
	// --- 4. [Indicadores condicionales] ---
	// Solo si existen variables de asistencia y fechas.
	cap confirm v ssns_as_prod fch_ini_ECA fch_fin_ECA
	if _rc==0 {
		by nomb_rgn-nomb_ccpp nomb_ECA: egen prom_ssns_as_grad_ECA = mean(ssns_as_prod) if graduado==1
		by nomb_rgn-nomb_ccpp nomb_ECA: carryforward prom_ssns_as_grad_ECA, replace	
		order ssns_ECA, b(prom_ssns_as_grad_ECA)
		
		gen float tasa_as_prom_ECA = prom_ssns_as_grad_ECA/ssns_ECA * 100
		gen tiempo_d_ECA = datediff(fch_ini_ECA, fch_fin_ECA, "d"), a(fch_fin_ECA)
	}
	
	// --- 5. [Mantener un registro por ECA] ---
	by nomb_rgn-nomb_ECA: keep if _n==1
	keep nomb_rgn-nomb_ECA *_ECA
	drop tipo_ECA
	
	// --- 6. [Ordenar dataset final] ---
	cap confirm v fch_ini_ECA
	if _rc==0 {
		gsort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp fch_ini_ECA -astn_ECA
	}
	else {
		gsort nomb_rgn nomb_prvnc nomb_dstrt nomb_ccpp -astn_ECA
	}
	
	// --- 7. [Etiquetas y guardado] ---
	lab var astn_ECA          "Asistentes (graduados y no graduados) de la ECA"
	lab var grad_ECA          "Graduados de la ECA"
	lab var tasa_grad_ECA     "Tasa de graduación de la ECA"
	lab var prom_nf_grad_ECA  "Promedio de la nota final de los graduados de la ECA"
	lab var max_nf_grad_ECA   "Máxima nota final obtenida por un graduado de la ECA"
	lab var min_nf_grad_ECA   "Mínima nota final obtenida por un graduado de la ECA"
	cap lab var prom_ast_grad_ECA 	"Promedio de sesiones asistidas por los graduados de la ECA"
	cap lab var tasa_ast_prom_ECA 	"Tasa de asistencia promedio de la ECA"
    cap lab var fch_ini_ECA       	"Fecha de inicio de la ECA"
	cap lab var tiempo_d_ECA		"Duración (días) de la ECA"
	
	compress
    save "`outdir'\\CCPP-ECAs-`year'.dta", replace
end