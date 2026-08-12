//----------------------------------------------------------------------
// File           : std_strings.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Estandariza variables string: remueve espacios extra,
//                  acentos, umlauts, circunflejos y otros caracteres especiales.
//----------------------------------------------------------------------

// 0. List string variables and capture it in global macros
ds, has(type string)
local list_of_strings `r(varlist)'
gl varstoremaccent 	`list_of_strings'
gl varstoremumlaut 	`list_of_strings'
gl varstoremcircumf `list_of_strings'
gl varstoremother 	`list_of_strings'

 // 1. Upper and drop blank spaces
if $remspaces == 1{
	dis "Remover espacios en blanco y pasar a mayúsculas"
	ds, has(type string)
		foreach s in `r(varlist)'{
		replace `s' = ustrupper(ustrtrim(itrim(`s')))
	}
	dis _newline
}

// 2. Remove Accents
if $remaccents == 1{
	dis "Remover acentos"
	local accented   = "Á À É È Í Ì Ó Ò Ú Ù Ý"
	local noaccented = "A A E E I I O O U U Y"
	
	local n = wordcount("`accented'")
	forvalues i = 1/`n' {
		local acc = word("`accented'",	`i')
		local noa = word("`noaccented'",`i')
		foreach v of global varstoremaccent{
			replace `v' = subinstr(`v', "`acc'", "`noa'", .)
		}
	}
	dis _newline
}

// 3. Remove Umlaut
if $remumlaut == 1{
	dis "Remover diéresis"
	local umlaut    = "Ä Ë Ï Ö Ü"
	local noumlaut  = "A E I O U"

	local n = wordcount("`umlaut'")
	forvalues i = 1/`n' {
		local uml = word("`umlaut'",	`i')
		local nou = word("`noumlaut'",	`i')
		foreach v of global varstoremumlaut{ 
			replace `v' = subinstr(`v', "`uml'", "`nou'", .)
		}
	}
	dis _newline
}

// 4. Remove circumflex
if $remcircum == 1{
	dis "Remover circunflejos"
	local circumf	= "Â Ê Î Ô Û"
	local nocircumf = "A E I O U"

	local n = wordcount("`circumf'")
	forvalues i = 1/`n' {
		local cir = word("`circumf'",	`i')
		local noc = word("`nocircumf'", `i')    
		foreach v of global varstoremcircumf{
			replace `v' = subinstr(`v', "`cir'", "`noc'", .)
		}
	}
}

// 5. Remove other special vowels
if $remother == 1{
	dis "Remover otros caracteres especiales"
	local other		= "Ã Å Õ Ů Ð"
	local noother 	= "A A O U Ñ"

	local n = wordcount("`other'")
	forvalues i = 1/`n' {
		local oth = word("`other'",	`i')
		local noo = word("`noother'", `i')    
		foreach v of global varstoremother{
			replace `v' = subinstr(`v', "`oth'", "`noo'", .)
		}
	}
	dis _newline
}

// 6. Creates dummies and extracts words with "�" in string variables
if $gen_extract_invl == 1{
	ds, has(type string)
	foreach s in `r(varlist)'{
		gen dum_invl_`s' = 1 if strpos(`s', "�") > 0, a(`s')
		sum dum_invl_`s'
		return list
		if `r(sum)'!=0{
			gen extra_invl_`s'		= "" , a(dum_invl_`s')
			replace extra_invl_`s' 	= regexs(0) if regexm(`s', "\b\w*�\w*\b")
		}
		else{
			drop dum_invl_`s'
		}
	}
}

// 6. Reset globals
gl remspaces
gl remaccents
gl remumlaut
gl remcircum
gl remother
gl gen_extract_invl