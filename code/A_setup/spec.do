//------------------------------------------------------------------------------
// File           : spec.do
// Author         : Carlos Marena
// Email          : carlosmarena1995@gmail.com
// Last Mod. Date : 14/08/2026
// Description    : Parámetros de especificación de la fase de estimación
//                  (G_estimation/): el set de controles, la variable de
//                  efectos fijos, la de agrupamiento de errores estándar, y
//                  los umbrales de significancia usados para las estrellas.
//
//                  Antes de este archivo, ctrl_set estaba definido byte a
//                  byte idéntico en local, por separado, en los 7 scripts
//                  G*; absorb(cod_rgn_PE) y cluster(cod_cpb) se repetían como
//                  literal en 17 llamadas cada uno; y los umbrales
//                  0.01/0.05/0.10 estaban hardcodeados por separado dentro
//                  de tres helpers de tabla (prg_table_2panels, 3panels,
//                  4panels). Nada impedía que se editara uno y no los otros.
//
//                  Solo lo usa la fase G. No se incluye desde A_master.do:
//                  A_master.do define entorno y nada más (para seguir siendo
//                  seguro de `include` desde cualquier fase); mezclar acá
//                  parámetros de una fase específica rompería esa separación.
//                  Cada script G* lo incluye explícitamente, igual que ya
//                  hace con los helpers de tabla.
//
// Depends        : (ninguno)
// Input          : (ninguno)
// Output         : (ninguno — define globals)
//------------------------------------------------------------------------------

version 19.0

//==============================================================================
// Set de controles de línea base
//==============================================================================
// Único para las 8 llamadas a helpers de tabla en los 7 scripts G* (incluida
// la de efectos heterogéneos en G5Aa/G5Ac). Prefijos c./i. explícitos: areg e
// ivregress los aceptan nativo, y prg_table_3way_het los reusa directamente
// para saturar como `tok'#ibn.`het_var'.
global ctrl_set c.edad c.edadsq i.sexo c.educ i.castell c.ilogsact c.icondvid ///
	c.tot_miem_1564 c.tot_miem_depen c.tot_has_prod i.riego_tec_prod ///
	c.años_tenen_prod i.mes_enc

//==============================================================================
// Efectos fijos y agrupamiento de errores estándar
//==============================================================================
// cod_rgn_PE: estrato región × producto a evaluar (el nivel al que se
// aleatorizó el diseño). cod_cpb: centro poblado (la unidad de asignación al
// tratamiento) — los errores estándar se agrupan ahí en todas las
// estimaciones del reporte.
global fe_estrato cod_rgn_PE
global cl_ccpp    cod_cpb

//==============================================================================
// Umbrales de significancia (estrellas)
//==============================================================================
// Mismos tres valores usados por prg_table_2panels.do, prg_table_3panels.do y
// prg_table_4panels.do para asignar */**/***. prg_table_3way_het.do no tiene
// copia propia: reusa _fmt_b de prg_table_3panels.do (ver su cabecera).
global star_p10 0.10
global star_p05 0.05
global star_p01 0.01
