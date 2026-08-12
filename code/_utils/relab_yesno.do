//----------------------------------------------------------------------
// File           : relab_yesno.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Reetiqueta variables con respuestas si/no a formato estandar.
//----------------------------------------------------------------------

ds , has(vallab)
foreach var in `r(varlist)'{
	local lblname : val lab `var'
	qui levelsof `var', local(lvlsvar)
	foreach val in `lvlsvar'{
		local lblval: label `lblname' `val'
		if "`lblval'"=="Si" | "`lblval'"=="No" | "`lblval'"=="88" {
			replace `var' = 0 if `var'==2
			replace `var' = . if `var'==88
			lab def `lblname' 0 "No" 1 "Si", modify
		}
	}
}
 