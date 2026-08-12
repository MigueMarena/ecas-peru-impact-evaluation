//------------------------------------------------------------------------------
// File           : F1_test_balance.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Realiza un analisis de balance (test de ortogonalidad) para
//                  verificar la aleatorizacion. Estima regresiones de la
//                  asignacion sobre caracteristicas de linea base a nivel de
//                  productor y parcela.
// Input          : Out/5_.../Vars_Caract_Obs.dta
//                  Out/5_.../Vars_ProdJH_Scdm_LB.dta
//                  Out/5_.../Viv_Act_SEA_LB.dta
//                  Out/5_.../Demog_Ing_Hog_LB.dta
//                  Out/5_.../Predio_LByLS.dta
// Output         : Tablas/6.1-1_Tabla_Balance.stcol
//------------------------------------------------------------------------------

cls
local vlist1 Codprod22 post cod_rgn_PE cod_cpb asig_ccpp
local sociodem edad sexo educ castell
local hogar ilogsact icondvid tot_miem_1564 tot_miem_depen
local predio tot_has_prod años_tenen_prod riego_tec_prod
local Z asig_ccpp
local FE cod_rgn_PE
local clvar cod_cpb

//==============================================================================
// Step 1: Load Data and Merge Data Sources
//==============================================================================
// Bootstrap robusto en batch fresh (fix bug ${ruta_scripts}; ver script 30).
if "${CONSULT}" == "" qui do "C:\\Users\\carlo\\ado\\personal\\profile.do"
qui include "${CONSULT}\\BID\\HRC0052956\\2_Scripts\\A_master.do"

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\F1_test_balance.log"
log using "${ruta_logs}\F1_test_balance.log", replace text

cd "`outc5'"

use `vlist1' using Vars_Caract_Obs, clear
keep if post==0

merge 1:1 Codprod22 using Vars_ProdJH_Scdm_LB, keepus(`sociodem') keep(3) nogen
merge 1:1 Codprod22 using Viv_Act_SEA_LB, keepus(ilogsact icondvid) keep(3) nogen
merge 1:1 Codprod22 using Demog_Ing_Hog_LB, keepus(tot_miem_1564 tot_miem_depen) keep(3) nogen
merge 1:m Codprod22 post using Productor_Predio_LB, keepus(`predio') keep(3) nogen

//==============================================================================
// Step 2: Label Preparation
//==============================================================================
local balance_vars `sociodem' `hogar' `predio'
local lblsdv ""
foreach dv of local balance_vars {
    local lbl : var lab `dv'
    local lblsdv `"`lblsdv' "`lbl'""'
}
local lblsdv : list retokenize lblsdv
local sec = 6
local subsec = 1
local numtbl = 1
 
//==============================================================================
// Step 3: Generate Tables with collect framework
//==============================================================================
collect clear
collect create Tabla_Balance, replace 

local i = 1

//------------------------------------------------------------------------------
// Producer Level Analysis
//------------------------------------------------------------------------------
preserve
    // !CRUCIAL!: Quedarse con una sola observación por productor
    duplicates drop Codprod22, force
    foreach dv in `sociodem' `hogar' {
        // Calcular Media del Grupo de Control
        qui: summ `dv' if `Z'==0
        qui: collect get Mean=r(mean), tags(cmdset[`i']) name(Tabla_Balance)
        
        // Modelo OLS (Balance Test)
        qui: areg `dv' `Z', a(`FE') cl(`clvar')
        qui: collect get _r_b _r_se, tags(cmdset[`i'] model[OLS]) name(Tabla_Balance)
    
        local ++i
    }
restore

//------------------------------------------------------------------------------
// Predio Level Analysis
//------------------------------------------------------------------------------
// La base original en memoria ya está a nivel de predio (merge 1:m)
foreach dv in `predio'{
    // Calcular Media del Grupo de Control
    qui: summ `dv' if `Z'==0
    qui: collect get Mean=r(mean), tags(cmdset[`i']) name(Tabla_Balance)
    
    // Modelo OLS (Balance Test)
    qui: areg `dv' `Z', a(`FE') cl(`clvar')
    qui: collect get _r_b _r_se, tags(cmdset[`i'] model[OLS]) name(Tabla_Balance)

    local ++i
}

//------------------------------------------------------------------------------
// Process Data and Levels from Dimensions
//------------------------------------------------------------------------------
collect set Tabla_Balance

// Etiquetar los niveles de 'cmdset' con las etiquetas reales de las variables
collect levelsof cmdset
numlist "`s(levels)'", sort
local levels `r(numlist)'
foreach l of numlist `levels' {
    gettoken lbl lblsdv: lblsdv
    collect label levels cmdset `l' "`lbl'", modify
}

// Etiquetas de Encabezados
collect label levels model OLS "Estimación", modify
collect label levels result Mean "Media (Control)" _r_b "Diferencia (T-C)" _r_se "Error Est.", modify

//------------------------------------------------------------------------------
// Customization 
//------------------------------------------------------------------------------
// A. Estrellas de Significancia (Standard: * 0.1, ** 0.05, *** 0.01)
collect stars _r_p 0.01 "***" 0.05 "**" 0.1 "*", attach(_r_b)

// B. Formatos a números y a strings
collect style cell result[Mean], font(Roboto, size(10pt)) nformat(%9.3f)
collect style cell result[_r_b], font(Roboto, size(10pt)) nformat(%9.4f)
collect style cell result[_r_se], font(Roboto, size(10pt)) nformat(%9.4f) sformat("(%s)")

// C. Encabezados, alineación y bordes
collect style column, dups(center)
collect style cell, halign(center) valign(center) // Todo centrado
collect style cell cmdset, font(Roboto, size(10pt)) halign(left) // Excepto los nombres de variables (izquierda)
collect style cell cell_type[item], halign(center) valign(center)
collect style cell cell_type[column-header], halign(center) valign(center)

// D. Estilo limpio sin bordes
collect style cell, border(right, pattern(nil)) 
collect style cell, border(left, pattern(nil))

// E. Limpieza de Títulos de Columna
collect style header colname, level(hide)
collect style header result, level(label)

// F. Agregar Título y Notas
local titulo "Tabla `sec'.`subsec'-`numtbl': Verificación de la Aleatorización"
local nota1 "Notas: La variable dependiente se indica en cada fila. La columna 'Media (Control)' es el promedio de la variable para el grupo de control."
local nota2 "La columna 'Diferencia (T-C)' reporta el coeficiente de la regresión de la variable sobre la asignación al tratamiento."
local nota3 "La columna 'Error Est.' reporta el error estándar robusto clusterizado."
local nota4 "Las variables sociodemográficas y del hogar se estiman a nivel de productor, mientras que las del predio a nivel de parcela."
local nota5 "Todas las regresiones incluyen efectos fijos de estrato y errores estándar clusterizados a nivel de centro poblado."
local nota6 "Niveles de significancia: *** p<0.01, ** p<0.05, * p<0.1."

collect title "`titulo'"
collect notes "`nota1' `nota2' `nota3' `nota4' `nota5' `nota6'"
collect style title, font(Roboto, size(10pt) italic)
collect style notes, font(Roboto,size(9pt))

//==============================================================================
// Final Layout
//==============================================================================
collect layout (cmdset) (result[Mean] model[OLS]#colname[`Z']#result[_r_b _r_se])

//==============================================================================
// Export Table to Word
//==============================================================================
mat widths = (67, 11, 11, 11)
collect style putdocx, name(Tabla_Balance) width(100%) width(widths)
collect export "${ruta_tablas}\\`sec'.`subsec'-`numtbl'_Tabla_Balance.docx", as(docx) replace

log close
