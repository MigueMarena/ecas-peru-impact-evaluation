//------------------------------------------------------------------------------
// File           : spec.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 14/08/2026
// Description    : Parámetros sustantivos del análisis, en un solo lugar para
//                  que se los pueda auditar sin leer los scripts. Dos bloques:
//
//                    Construcción (E_build/): los índices de precios con que
//                      se deflacta la línea de seguimiento.
//                    Estimación (G_estimation/): el set de controles, la
//                      variable de efectos fijos, la de agrupamiento de errores
//                      estándar y los umbrales de significancia.
//
//                  Son decisiones metodológicas, no mecánica: qué IPC, qué
//                  meses, qué covariables, a qué nivel se agrupa. Enterradas
//                  en medio de un script nadie las revisa.
//
//                  No se incluye desde config.do: config.do define entorno y
//                  nada más, para seguir siendo seguro de `include` desde
//                  cualquier fase. Lo incluye explícitamente quien lo necesita
//                  — hoy E4 y los 7 scripts G*.
//
// Depends        : (ninguno)
// Input          : (ninguno)
// Output         : (ninguno — define globals)
//------------------------------------------------------------------------------

version 19.0

//==============================================================================
// CONSTRUCCIÓN — Deflación (IPC Perú, fuente: INEI)
//==============================================================================
// LB: campaña 2020-2021, encuestada aprox. en 2021 → IPC promedio jul-dic 2021.
// LS: campaña 2021-2022, encuestada aprox. en 2022 → IPC promedio jul-dic 2022.
// Para expresar la LS en precios de LB se divide por $factor_def (≈ 1.0847).
//
// Los usa E4_build_crops.do. Valores idénticos a los de
// do_calculo_indicadores_PCR.do, que vive fuera de este repositorio: si alguna
// vez se corrigen, hay que corregirlos en los dos lados.
//
// Van como `scalar' y no como global, a diferencia del resto de este archivo.
// Un global es texto: `global x = a/b' evalúa y guarda el resultado como
// string, y ahí se pierde el último bit del double (2.2e-16 en este cociente).
// Da igual para el valor en soles, pero cambia los bytes de la base guardada y
// rompe la reproducción exacta de las tablas. Los parámetros de estimación de
// más abajo sí son globals porque se sustituyen como texto en los comandos.
scalar ipc_lb     = 98.5399356    // IPC promedio jul-dic 2021 (base)
scalar ipc_ls     = 106.8904127   // IPC promedio jul-dic 2022
scalar factor_def = ipc_ls / ipc_lb

//==============================================================================
// ESTIMACIÓN — Set de controles de línea base
//==============================================================================
// Único para las 8 llamadas a helpers de tabla en los 7 scripts G* (incluida
// la de efectos heterogéneos en G5Aa/G5Ac). Prefijos c./i. explícitos: areg e
// ivregress los aceptan nativo, y prg_table_3way_het los reusa directamente
// para saturar como `tok'#ibn.`het_var'.
global ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

//==============================================================================
// ESTIMACIÓN — Efectos fijos y agrupamiento de errores estándar
//==============================================================================
// cod_rgn_PE: estrato región × producto a evaluar (el nivel al que se
// aleatorizó el diseño). cod_cpb: centro poblado (la unidad de asignación al
// tratamiento) — los errores estándar se agrupan ahí en todas las
// estimaciones del reporte.
global fe_estrato cod_rgn_PE
global cl_ccpp    cod_cpb

//==============================================================================
// ESTIMACIÓN — Umbrales de significancia (estrellas)
//==============================================================================
// Mismos tres valores usados por prg_table_2panels.do, prg_table_3panels.do y
// prg_table_4panels.do para asignar */**/***. prg_table_3way_het.do no tiene
// copia propia: reusa _fmt_b de prg_table_3panels.do (ver su cabecera).
global star_p10 0.10
global star_p05 0.05
global star_p01 0.01
