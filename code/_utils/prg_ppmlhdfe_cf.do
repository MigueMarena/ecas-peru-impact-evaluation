//----------------------------------------------------------------------
// File           : prg_ppmlhdfe_cf.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Define el programa boot_ppml_cf para estimacion Poisson PML
//                  con efectos fijos multiples y funcion de control para
//                  variables endogenas (2 etapas).
//----------------------------------------------------------------------
// Define program for bootstrap
capture program drop boot_ppml_cf
program boot_ppml_cf, eclass
    syntax varlist [if] [in], fe(string)
    tokenize `varlist'
    local y `1'
    local D `2'
    local Z `3'
    macro shift 3
    local x `*'
    tempvar u_hat_boot
    
    // Stage 1: Control Function Residuals
    qui reghdfe `D' `Z' `x' `if' `in', a(`fe') residuals(`u_hat_boot')
    
    // Stage 2: PPML
    qui ppmlhdfe `y' `D' `x' `u_hat_boot' `if' `in', a(`fe')
end