//----------------------------------------------------------------------
// File           : prg_falsification_tests.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Define el programa FALSIFICATION_TESTS para ejecutar tests
//                  de falsificacion estimando OLS y IV sobre resultados de
//                  linea base.
//----------------------------------------------------------------------
cap program drop FALSIFICATION_TESTS
program define FALSIFICATION_TESTS
    version 19
    syntax varlist(min=1 max=1), controls(string) absorb(varlist) cluster(varname)

    local dv `varlist'
    local patt = "([0-9]+b?\.[A-Za-z0-9_]+|_cons)" 

    quietly {
        // 1. OLS Regression
        eststo `dv'_OLS, noe: areg `dv' dias_iniLB_iniECA `controls' if `cond', a(`absorb') vce(cl `cluster')
        local vars_OLS = trim(itrim(ustrregexra("`: colnames e(b)'","`patt'", "")))
        
        // 2. IV Regression
        eststo `dv'_IV, noe: ivregress 2sls `dv' (dias_iniLB_iniECA=asig_ccpp) `controls', a(`absorb') cl(`cluster')
        local vars_IV = trim(itrim(ustrregexra("`: colnames e(b)'","`patt'", "")))
        
        // Store Stats
        scalar N_obs = e(N)
        scalar N_cls = e(N_clust) 
        scalar F_FS  = e(widstat)

        local end 
        local vars `vars_OLS' `vars_IV'
        forval j = 1/`: word count `vars''{
            local end "`end' 1"
        }
        
        // Baseline stats
        summ `dv' if asig_ccpp==0 & post==0
        scalar meancgr  = r(mean)
        scalar sdcgr    = r(sd)
        
        // Append
        eststo `dv': appendmodels `dv'_OLS `dv'_IV
        
        // Matrix operations
        local   end = "("+ ustrregexra(trim("`end'"), " ", ",") + ")"
        mat     end = `end'
        mat colnames end = `vars'
        estadd matrix end: `dv'
        
        // Add scalars
        foreach astat in meancgr sdcgr N_obs N_cls F_FS {
            cap estadd scalar `astat' : `dv'
        }
    }
end