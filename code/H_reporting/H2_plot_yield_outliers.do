//----------------------------------------------------------------------
// File           : H2_plot_yield_outliers.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 11/04/2026
// Description    : Genera graficos Q-Q (qplot) por tipo de cultivo para comparar
//                  la distribucion del rendimiento original vs. outliers a valores
//                  missing. Un grafico .png por cada tipo de cultivo.
// Input          : Out/5_.../Cultivo_Pcpal_LByLS.dta
// Output         : Imagenes/Rendimiento Cultivos/*.png
//----------------------------------------------------------------------

// 0. Configuración Inicial
version 19.0 // Requiere Stata 19: ivregress con absorb() (ver A_master.do)
// Bootstrap del entorno: define las globals ${ruta_*} a partir de ${ECAS},
// la única entrada de configuración del pipeline (ver A_master.do).
if "${ruta_data}" == "" {
	capture qui include "${ECAS}/2_Scripts/A_master.do"
	if _rc capture qui include "2_Scripts/A_master.do"
	if "${ruta_data}" == "" {
		di as error "No encuentro A_master.do. Definí la global ECAS con la ruta"
		di as error "a la raíz del repositorio, o corré Stata desde esa raíz."
		exit 601
	}
}

// Redirige el log de stata-batch a 3_Logs/ (limpia el log auto en 2_Scripts).
cap log close
cap erase "${ruta_scripts}\H2_plot_yield_outliers.log"
log using "${ruta_logs}\H2_plot_yield_outliers.log", replace text

set scheme stcolor
preserve

// Definir path local de ruta de gráficos
local ruta_graficos "${ruta_deliv}\Reporte Final - VPaper\Imágenes\Rendimiento Cultivos"

// 1. Preparación de Datos y Reshape
// Mantener solo variables necesarias
keep nomb_tipo_cult kgxha_semb_culp kgxha_semb_culp_mis

// Limpieza: eliminar obs sin rendimiento (0 o missing) o sin tipo de cultivo
drop if kgxha_semb_culp == 0 | kgxha_semb_culp == . | nomb_tipo_cult == ""

// Ordenar y crear un ID único DENTRO de cada tipo de cultivo para el reshape
sort nomb_tipo_cult
by nomb_tipo_cult: gen long id = _n

// Renombrar variables para el formato 'long' (stub: kgxha_semb_culp_)
ren (kgxha_semb_culp kgxha_semb_culp_mis) (kgxha_semb_culp_1 kgxha_semb_culp_2)

// Reshape de 'wide' a 'long'.
reshape long kgxha_semb_culp_@, i(id nomb_tipo_cult) j(estvar)

// Etiquetar la nueva variable 'estvar' para legibilidad en los gráficos
lab def estvarlbl 1 "Original" 2 "Outliers a MV", replace
lab val estvar estvarlbl

// Renombrar la variable de rendimiento a su nombre genérico y ordenar
ren kgxha_semb_culp_ kgxha_semb_culp
order nomb_tipo_cult estvar id kgxha_semb_culp
sort nomb_tipo_cult estvar kgxha_semb_culp

// 2. Generación de Estadísticos de Resumen
// Crear estadísticos a nivel de grupo (cultivo x estvar)
// Estos se usarán en el 'addplot()' del gráfico (p25, p50, mean, etc.)
by nomb_tipo_cult estvar: egen counter = count(kgxha_semb_culp)
by nomb_tipo_cult estvar: egen min     = min(kgxha_semb_culp)
by nomb_tipo_cult estvar: egen p25     = pctile(kgxha_semb_culp), p(25)
by nomb_tipo_cult estvar: egen p50     = pctile(kgxha_semb_culp), p(50)
by nomb_tipo_cult estvar: egen p75     = pctile(kgxha_semb_culp), p(75)
by nomb_tipo_cult estvar: egen mean    = mean(kgxha_semb_culp)
by nomb_tipo_cult estvar: egen max     = max(kgxha_semb_culp)

// Filtro: Mantener solo cultivos con al menos 10 observaciones
keep if counter >= 10 | (counter < 10 & inlist(nomb_tipo_cult,"Mashua","Platano Biscocho"))
if _N == 0 {
    di as error "No quedan observaciones después de filtrar por counter >= 10"
    exit
}

// 3. Variables Auxiliares para Gráficos
// Obtener el número MÁXIMO de dígitos (para padding de nombres de archivo)
summ counter if estvar == 1, meanonly
local maxcount = r(max)
local ndigmaxc = length("`maxcount'")

// 'where': Define la coordenada 'x' (en el eje horizontal del qplot) donde estará el boxplot superpuesto.
gen where = 3.2

// 'x': Define los puntos de inicio y fin (-2.9 a 2.9) para la línea de la media en el 'addplot'.
by nomb_tipo_cult estvar: gen x = cond(_n==1, -2.9, cond(_n == _N, 2.9, .))

// 4. Bucle de Generación de Gráficos
// Definir número de ticks para el eje Y
local itvls = 7

// Obtener lista única de cultivos que quedan
levelsof nomb_tipo_cult, local(lista_cultivos)

foreach lbl of local lista_cultivos {
    // --- A. Preparar Metadatos del Gráfico ---
    // Obtener N, min, max para este cultivo (del grupo 'Original')
    qui summ kgxha_semb_culp if nomb_tipo_cult == "`lbl'" & estvar == 1, detail
    local nobs   = r(N)
    local ln_min = ln(r(min))
    local ln_max = ln(r(max))
    local stp    = (`ln_max' - `ln_min') / `itvls'

    // --- B. Lógica de Nombres de Archivo (Robusta) ---
    // Generar padding de ceros para ordenar archivos por 'nobs'
    local nobs_fmt : display %0`ndigmaxc'.0f `nobs'
    local nombre_archivo = "`nobs_fmt'_`lbl'"

    // --- C. Lógica de Etiquetas de Eje Y (Personalizada) ---
    // Construir lista de etiquetas para el eje Y en escala logarítmica
    local ylabels ""
    forvalues i = 0/`itvls' {
        local ln_val = `ln_min' + `i' * `stp'
        local val = exp(`ln_val')
        
        // Formatear y recortar para evitar espacios extra
        local val_fmt : display %9.0f `val'
        local val_fmt = trim("`val_fmt'")  
        local ylabels "`ylabels' `val_fmt'"
    }
    // display "Debug: `lbl' | N=`nobs' | Y-Labels: `ylabels'" // Descomentar para debug

    // --- D. Generar Gráfico Q-Plot ---
    qui qplot kgxha_semb_culp if nomb_tipo_cult == "`lbl'", ///
        trscale(invnormal(@)) /// /* Transforma Y a Z-scores */
        by(estvar, note("") row(1) legend(off) ///
           title("`lbl' (N=`nobs')") ) /// /* Título dinámico por grupo */
        /// Opciones del eje Y (Rendimiento)
        yscale(log) ///
        ytitle("Rend. del cultivo (kg × ha.)") ///
        ylabel(`ylabels', angle(horizontal) grid) /// /* Etiquetas personalizadas */
        /// Opciones del eje X (Cuantiles Normales)
        xtitle("Standard normal deviate") ///
        xla(-3/3) ///
        /// Superponer Boxplot y Media (addplot)
        addplot( ///
            (rbar p25 p50 where if nomb_tipo_cult == "`lbl'", ///
                barw(0.4) lcol(black) fcolor(none)) ///
            (rbar p50 p75 where if nomb_tipo_cult == "`lbl'", ///
                barw(0.4) lcol(black) fcolor(none)) ///
            (rspike p75 max where if nomb_tipo_cult == "`lbl'", ///
                lcol(black)) ///
            (rspike p25 min where if nomb_tipo_cult == "`lbl'", ///
                lcol(black)) ///
            (line mean x if nomb_tipo_cult == "`lbl'", ///
                lcol(stc2) lpattern(dash)) ///
        )

    // --- E. Exportar Gráfico ---
    graph export "`ruta_graficos'\\`nombre_archivo'.emf", replace
}
restore

log close
