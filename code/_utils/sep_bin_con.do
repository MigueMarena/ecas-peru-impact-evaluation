//----------------------------------------------------------------------
// File           : sep_bin_con.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Evalua variables de un modulo y las separa en binarias
//                  (binvars) y continuas (convars) generando dos macros locales.
//----------------------------------------------------------------------
local confifbin "0 1"
global binvars
global convars
foreach v of varlist $varstoeval{
	qui levelsof `v', local(values)
	local size: list sizeof values
	if `size'==2{
		local isok: list confifbin == values
		if `isok'==1{
			local binvars `binvars' `v'
		}
		else{
			local convars `convars' `v'
		}
	}
	else{
		local convars `convars' `v'
	}
}