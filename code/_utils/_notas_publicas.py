# -*- coding: utf-8 -*-
"""
Constantes y utilidades compartidas entre el diccionario interno y el catálogo
público para policy makers.

Incluye:
- GROUP_COLORS: paleta de 13 colores pastel para las filas del Excel, uno por
  grupo temático (consistente entre ambos archivos).
- BID_BLUE: color institucional del BID para las cabeceras.
- NOTAS_REWRITE: diccionario que asigna a cada variable una versión de su
  campo 'notas' libre de jerga Stata y con acrónimos expandidos.
- clean_notas(): aplica la reescritura (o, en su defecto, una limpieza genérica
  que expande acrónimos aislados).

Importado por:
- _build_diccionario.py
- _build_catalogo_policymakers.py
"""

# Color institucional del BID para cabeceras
BID_BLUE = "004E70"

# Color por grupo temático (tonos pastel). Paleta de 13 colores.
GROUP_COLORS = {
    "Características de la Observación":       "DDEBF7",  # azul muy claro
    "Sociodemográficas del Productor":         "FCE4D6",  # durazno claro
    "Hogar - Activos y Condiciones de Vida":   "E2EFDA",  # verde muy claro
    "Hogar - Composición Demográfica":         "FFF2CC",  # amarillo muy claro
    "Hogar - Servicios de Extensión Agraria":  "EDEDED",  # gris muy claro
    "Predio y Parcelas":                       "D9E1F2",  # azul gris claro
    "Económicos - Cultivo Principal":          "FFE699",  # amarillo dorado claro
    "Conocimiento Agronómico":                 "C6E0B4",  # verde claro
    "BPA - Prácticas Agronómicas":             "BDD7EE",  # azul medio claro
    "Registros y Almacenamiento":              "F4CCCC",  # rosado claro
    "Inocuidad Alimentaria":                   "FFD1B3",  # naranja claro
    "Compuesto Propio BPA":                    "D9D2E9",  # lila claro
    "Compuesto ENA":                           "EAD1DC",  # rosa lila claro
}

# Plantilla estándar para agregaciones gtot_*_prod con patrón Stata
GTOT_PROD_TEMPLATE = (
    "Gasto total del productor en este concepto, obtenido sumando el gasto "
    "reportado en cada una de sus parcelas durante la campaña agrícola."
)

# Nota compartida por las prácticas BPA principales bpa_1 ... bpa_14
BPA_PRINCIPAL_NOTE = (
    "Las prácticas bpa_10 a bpa_14 (uso de fertilizantes, abono orgánico, plaguicidas, "
    "control biológico y manejo integrado de plagas) también actúan como condicionantes "
    "para el cálculo de sus sub-prácticas: éstas solo se evalúan cuando el productor "
    "efectivamente declara usar el insumo correspondiente."
)

# Notas para sub-prácticas bpa_10_*, bpa_11_*, ...
SUBBPA_NOTES = {
    "bpa_10_": "Esta sub-práctica solo se calcula para productores que usan fertilizantes (bpa_10 = 1).",
    "bpa_11_": "Esta sub-práctica solo se calcula para productores que usan abono orgánico (bpa_11 = 1).",
    "bpa_12_": "Esta sub-práctica solo se calcula para productores que usan plaguicidas (bpa_12 = 1).",
    "bpa_13_": "Esta sub-práctica solo se calcula para productores que usan plaguicidas (bpa_13 evalúa control biológico como alternativa o complemento).",
    "bpa_14_": "Esta sub-práctica solo se calcula para productores que usan plaguicidas (bpa_14 evalúa Manejo Integrado de Plagas como alternativa o complemento).",
}

# ---------------------------------------------------------------------------
# Reescrituras explícitas: variable_creada -> nota pública
# ---------------------------------------------------------------------------
NOTAS_REWRITE = {
    # --- script 06 ---
    "cod_rgn_PE": (
        "Se usa como efecto fijo en todas las regresiones ITT (Intent-to-Treat, "
        "intención de tratar) y LATE (Local Average Treatment Effect, efecto local "
        "promedio del tratamiento) para absorber diferencias estructurales entre "
        "estratos de aleatorización."
    ),
    "cod_cpb": (
        "Se utiliza para agrupar a los productores del mismo centro poblado al "
        "calcular la incertidumbre estadística de los efectos estimados "
        "(clusterización de errores estándar)."
    ),
    "mes_enc": (
        "Se incluye como control en las regresiones para absorber estacionalidad "
        "ligada al momento del año en que se tomó la encuesta."
    ),
    "dias_iniLB_iniECA": (
        "Sirve como variable principal del test de falsificación: verifica que en "
        "línea base (antes de la intervención) no haya diferencias sistemáticas "
        "entre centros poblados asignados a tratamiento y control que pudieran "
        "explicar resultados posteriores. Cuando no se registra fecha de inicio "
        "de la ECA (Escuela de Campo Agrícola), se imputa un valor de cero días."
    ),

    # --- script 07 ---
    "edad": (
        "Cuando el productor no aparece en el roster de miembros del hogar se "
        "imputa su edad desde el jefe de hogar, usando un emparejamiento "
        "aproximado por nombres y apellidos (puntaje de similitud ≥ 0.82)."
    ),
    "edadsq": (
        "Captura no-linealidades en el efecto de la edad sobre los resultados "
        "estudiados."
    ),
    "educ": (
        "Se construye mapeando el nivel educativo declarado (por ejemplo: "
        "primaria, secundaria, superior) y el grado alcanzado a un equivalente "
        "en años de escolaridad. Incluye ajustes manuales para casos especiales "
        "(por ejemplo, docentes o profesores cuya ocupación implica un nivel "
        "superior no declarado explícitamente)."
    ),
    "nivedmax": (
        "Categoriza el nivel educativo más alto completado por el productor o "
        "jefe de hogar: sin estudios, inicial, primaria, secundaria, superior "
        "no universitaria, superior universitaria."
    ),
    "leng_mat": (
        "Categoriza la primera lengua aprendida del productor o jefe de hogar: "
        "castellano, quechua, otras lenguas nativas/originarias, u otras "
        "lenguas (extranjeras, no sabe/no contesta)."
    ),
    "iden_etn": (
        "Recoge la autoidentificación étnica del productor o jefe de hogar: "
        "mestizo, quechua, otro indígena/originario, otro grupo (afrodescendiente "
        "o blanco), o no sabe/no contesta."
    ),

    # --- script 08 hogar ---
    "ilogsact": (
        "Índice sintético de logros del hogar construido a partir de características "
        "de la vivienda (materiales, acceso a servicios básicos) y tenencia de "
        "activos durables. Refleja nivel socioeconómico estructural."
    ),
    "icondvid": (
        "Índice sintético de condiciones de vida del hogar, complementario al "
        "índice de logros. Combina acceso a servicios, calidad de vivienda y "
        "hacinamiento."
    ),
    "imen_per_cap": (
        "Cociente entre el ingreso mensual del hogar y el número total de miembros del "
        "hogar. Mide el ingreso monetario promedio por persona."
    ),

    # --- script 10 (agregaciones al productor) ---
    "tot_has_prod": (
        "Superficie total manejada por el productor, obtenida sumando las "
        "hectáreas trabajadas en cada una de sus parcelas durante la campaña "
        "agrícola."
    ),
    "gtot_oper_2_pp": (
        "Suma de 12 componentes de gasto operativo, excluyendo el gasto en plaguicidas, "
        "abonos y fertilizantes químicos y abono orgánico (que se analizan por separado "
        "como insumos del cultivo principal)."
    ),

    # --- script 09 cultivo principal ---
    "tot_has_semb_cult_culp": (
        "Superficie sembrada del cultivo principal. Se homogenizan unidades de "
        "superficie declaradas por el productor (hectáreas, metros cuadrados u "
        "otras unidades locales) a hectáreas."
    ),
    "tot_ud_plnts_eprod_culp": (
        "Se imputa un valor de cero cuando el productor declara tener plantas "
        "pero no reporta cuántas están en edad productiva."
    ),
    "tot_kg_sem_culp": (
        "Cantidad de semilla usada, homogenizada a kilogramos. Se convierten "
        "toneladas y otras unidades locales a kilogramos."
    ),
    "tot_kg_prod_cose_culp": (
        "Producción cosechada, homogenizada a kilogramos. Cuando el productor "
        "reporta la producción en toneladas u otras unidades locales, se aplica "
        "un factor de conversión específico por tipo de cultivo y unidad "
        "declarada (la moda de equivalencias reportadas)."
    ),
    "tot_kg_prod_vend_culp": (
        "Producción vendida, homogenizada a kilogramos con el mismo "
        "procedimiento que la producción cosechada."
    ),
    "tot_kg_prod_vend_MN_culp": (
        "Producción vendida al mercado nacional, homogenizada a kilogramos con "
        "el mismo procedimiento que la producción cosechada."
    ),
    "tot_kg_prod_vend_MI_culp": (
        "Producción vendida al mercado internacional, homogenizada a kilogramos "
        "con el mismo procedimiento que la producción cosechada."
    ),
    "usa_plag_culp": (
        "Cuando el productor declara no usar plaguicida, las cantidades en kg, "
        "litros y el gasto en plaguicida se imputan a cero."
    ),
    "kg_plag_culp": (
        "Suma de los kilogramos de plaguicidas sólidos usados por el productor, "
        "considerando hasta cinco productos distintos. Se imputa a cero cuando el "
        "productor declara no usar plaguicidas."
    ),
    "lt_plag_culp": (
        "Suma de los litros de plaguicidas líquidos usados por el productor, "
        "considerando hasta cinco productos distintos. Se imputa a cero cuando el "
        "productor declara no usar plaguicidas."
    ),
    "kgxha_plag_culp": (
        "Kilogramos de plaguicida aplicados por hectárea sembrada. Se calcula solo "
        "cuando la superficie sembrada es positiva; se imputa a cero cuando el "
        "productor declara no usar plaguicidas."
    ),
    "ltxha_plag_culp": (
        "Litros de plaguicida aplicados por hectárea sembrada. Se calcula solo "
        "cuando la superficie sembrada es positiva; se imputa a cero cuando el "
        "productor declara no usar plaguicidas."
    ),
    "kg_aboo_culp": (
        "Se imputa a cero cuando el productor declara no usar abono orgánico."
    ),
    "lt_aboo_culp": (
        "Un valor extremo aislado de 50,000 litros fue reemplazado por valor "
        "faltante durante la limpieza. Se imputa a cero cuando el productor "
        "declara no usar abono orgánico."
    ),
    "gtot_plag_culp": (
        "Monto del gasto en plaguicidas expresado en soles corrientes. Existe también "
        "una versión deflactada a soles constantes de 2021 para comparar entre línea "
        "base y línea de seguimiento."
    ),
    "mgn_ins_culp": (
        "Se construye como el ingreso total del cultivo menos los tres gastos directos "
        "en insumos (plaguicidas, abono orgánico y abono químico)."
    ),

    # --- script 11 conocimiento ---
    "ptj_CQre": (
        "Puntaje reescalado en la dimensión 'Conocimientos Generales': cada pregunta "
        "se pondera por su dificultad empírica (inversa de la tasa de acierto) y el "
        "resultado se normaliza al rango 0-17 para que sea comparable con el puntaje "
        "bruto."
    ),
    "ptj_BPA_CQ": (
        "Subconjunto de preguntas de la dimensión 'Conocimientos Generales' que están "
        "directamente vinculadas a Buenas Prácticas Agrícolas (BPA). Escala 0-12."
    ),
    "ptj_PAQre": (
        "Puntaje reescalado en la dimensión 'Prácticas Agronómicas': cada pregunta "
        "se pondera por su dificultad empírica (inversa de la tasa de acierto) y el "
        "resultado se normaliza al rango 0-17 para que sea comparable con el puntaje "
        "bruto."
    ),
    "ptj_BPA_PAQ": (
        "Subconjunto de preguntas de la dimensión 'Prácticas Agronómicas' que están "
        "directamente vinculadas a Buenas Prácticas Agrícolas (BPA). Escala 0-12."
    ),
    "ptj_PLQre": (
        "Puntaje reescalado en la dimensión 'Plagas y Enfermedades': cada pregunta "
        "se pondera por su dificultad empírica (inversa de la tasa de acierto) y el "
        "resultado se normaliza al rango 0-17 para que sea comparable con el puntaje "
        "bruto."
    ),
    "ptj_BPA_PLQ": (
        "Subconjunto de preguntas de la dimensión 'Plagas y Enfermedades' que están "
        "directamente vinculadas a Buenas Prácticas Agrícolas (BPA). Escala 0-11."
    ),

    # --- script 15 compuestos ---
    "bpa_comp_suelo": (
        "Es uno de los cuatro pilares del indicador compuesto propio de BPA (Buenas "
        "Prácticas Agrícolas): producción, higiene, almacenamiento y distribución. "
        "Este pilar cubre las prácticas de manejo del suelo."
    ),
    "bpa_comp_riego": (
        "Pilar intermedio que alimenta el indicador compuesto propio de BPA (Buenas "
        "Prácticas Agrícolas). Cubre las prácticas de manejo del agua de riego."
    ),
    "bpa_comp_insumos": (
        "Pilar intermedio que alimenta el indicador compuesto propio de BPA (Buenas "
        "Prácticas Agrícolas). Cubre las prácticas de uso de insumos (fertilización, "
        "control de plagas, abono orgánico)."
    ),
    "bpa_comp_prod": (
        "Pilar intermedio que alimenta el indicador compuesto propio de BPA (Buenas "
        "Prácticas Agrícolas). Resume las prácticas de producción (suelo, riego, insumos)."
    ),
    "bpa_comp_higiene_vO": (
        "Versión 'Original ENA' del pilar de higiene, que es la adoptada por el "
        "indicador compuesto propio de BPA (Buenas Prácticas Agrícolas). Sigue la "
        "definición de higiene del catálogo oficial de la Encuesta Nacional "
        "Agropecuaria del INEI."
    ),
    "bpa_comp_alm_vO": (
        "Versión 'Original ENA' del pilar de almacenamiento, que es la adoptada por el "
        "indicador compuesto propio de BPA (Buenas Prácticas Agrícolas). Sigue la "
        "definición de almacenamiento del catálogo oficial de la Encuesta Nacional "
        "Agropecuaria del INEI."
    ),
}

# Aplicar nota común a prácticas BPA principales (bpa_1 ... bpa_14)
for _i in range(1, 15):
    NOTAS_REWRITE.setdefault(f"bpa_{_i}", BPA_PRINCIPAL_NOTE)

# Aplicar notas a sub-prácticas bpa_X_Y
for _prefix, _note in SUBBPA_NOTES.items():
    for _j in range(1, 8):
        NOTAS_REWRITE.setdefault(f"{_prefix}{_j}", _note)

# Sub-sub-prácticas bpa_12_q_* (condicionales al uso de plaguicida químico)
_BPA12Q_COND_CHEM = (
    "Esta sub-práctica solo se calcula para productores que usan plaguicida químico "
    "(bpa_12_4 = 1)."
)
_BPA12Q_COND_LABEL = (
    "Esta sub-práctica solo se calcula para productores que usan plaguicida químico con "
    "etiqueta en el envase (bpa_12_q_1 = 1), pues requiere leer o seguir la información "
    "impresa en dicha etiqueta."
)
_BPA12Q_COND_ENVASE = (
    "Esta sub-práctica se calcula para los productores que reportaron cómo disponen de "
    "los envases vacíos del plaguicida. El productor se considera con buena gestión si "
    "usa exclusivamente métodos adecuados y no emplea ningún método inadecuado."
)
for _suf in ("1", "5", "6", "7"):
    NOTAS_REWRITE.setdefault(f"bpa_12_q_{_suf}", _BPA12Q_COND_CHEM)
for _suf in ("2", "3", "4"):
    NOTAS_REWRITE.setdefault(f"bpa_12_q_{_suf}", _BPA12Q_COND_LABEL)
NOTAS_REWRITE.setdefault("bpa_12_q_71", _BPA12Q_COND_ENVASE)


def clean_notas(var_name: str, notas: str) -> str:
    """Devuelve una versión pública del campo notas.

    1. Si la variable tiene una reescritura explícita en NOTAS_REWRITE, la usa.
    2. Si el texto contiene un patrón Stata típico de gtot_*_prod, lo reemplaza.
    3. En cualquier otro caso, expande acrónimos aislados (ECA, ENA, BPA, etc.).
    """
    if not notas:
        return ""
    if var_name in NOTAS_REWRITE:
        return NOTAS_REWRITE[var_name]
    if "bys Codprod22 post: egen total" in notas:
        return GTOT_PROD_TEMPLATE

    n = notas
    replacements = [
        (" ECA ",   " ECA (Escuela de Campo Agrícola) "),
        (" ECAs ",  " ECAs (Escuelas de Campo Agrícolas) "),
        ("ECA082",  "ECA082 (código de Escuela de Campo Agrícola)"),
        (" ENA ",   " ENA (Encuesta Nacional Agropecuaria del INEI) "),
        (" BPA ",   " BPA (Buenas Prácticas Agrícolas) "),
        (" BPM ",   " BPM (Buenas Prácticas de Manufactura) "),
        (" MIP ",   " MIP (Manejo Integrado de Plagas) "),
        (" ITT ",   " ITT (Intent-to-Treat, intención de tratar) "),
        (" LATE ",  " LATE (Local Average Treatment Effect, efecto local promedio del tratamiento) "),
        (" IPC ",   " IPC (Índice de Precios al Consumidor) "),
        (" INEI ",  " INEI (Instituto Nacional de Estadística e Informática) "),
    ]
    for old, new in replacements:
        if old in (" " + n + " ") and new.strip().split("(")[0].strip() not in n:
            n = n.replace(old.strip(), new.strip(), 1)
    return n
