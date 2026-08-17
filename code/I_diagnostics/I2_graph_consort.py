# -----------------------------------------------------------------------------
# File           : I2_graph_consort.py
# Author         : Carlos Marena
# Email          : carlosmarena1995@gmail.com
# Last Mod. Date : 17/08/2026
# Description    : Genera el diagrama CONSORT del cluster-RCT — variante con
#                  atritos paralelos. Lee los conteos producidos por
#                  I1_summary_consort.do (xlsx en formato long) y dibuja:
#                    Fila 1: Aleatorización (caja central)
#                    Fila 2: Tratamiento y Control (cabezas) + Atritos sin BL
#                            (cajas laterales con borde discontinuo)
#                    Fila 3: Cumplidores y No cumplidores por brazo (4 cajas)
#                            con sub-líneas internas para sub-grupos (desv.
#                            temporal en T-cumpl; derrame en T-no-cumpl; ECA
#                            temprana y caso gris en C-no-cumpl)
#                    Fila 4: Muestra analítica T y C (cajas terminales)
#                  Identidad visual BID estricta: Azul #004e70, Cian #009ade,
#                  Gris oscuro #3c3b3b, Verde oscuro #308144 (cumplidores),
#                  Amarillo #ffda00 (no cumplidores). Exporta PNG (300 dpi)
#                  y PDF.
# Input          : Tablas/0_Diseño_y_Diagnóstico/Cuerpo/D1_Tabla_CONSORT.xlsx
#                  (formato long: columnas etapa, padre, brazo, nivel, n)
# Output         : Imágenes/Gráfico_Consort/D1_Grafico_CONSORT.png
#                  Imágenes/Gráfico_Consort/D1_Grafico_CONSORT.pdf
#                  El centinela que reciba como argv[1], si se le pasa uno.
# -----------------------------------------------------------------------------

import os
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

# -----------------------------------------------------------------------------
# Rutas
# -----------------------------------------------------------------------------
# La raíz sale de ${ECAS} si está definida —la única entrada de configuración
# del pipeline, ver A_setup/config.do— y si no, de la ubicación de este propio
# archivo, que vive en <raíz>/2_Scripts/I_diagnostics/. Antes estaba hardcodeada
# a la máquina del autor, de modo que este script no corría en ninguna otra.
RUTA_PROY = Path(os.environ.get("ECAS") or Path(__file__).resolve().parents[2])
RUTA_TAB  = RUTA_PROY / "5_Entregables" / "Reporte Final_VPaper" / "Tablas" / "0_Diseño_y_Diagnóstico" / "Cuerpo"
RUTA_IMG  = RUTA_PROY / "5_Entregables" / "Reporte Final_VPaper" / "Imágenes" / "Gráfico_Consort"
RUTA_IMG.mkdir(parents=True, exist_ok=True)

XLSX_IN   = RUTA_TAB / "D1_Tabla_CONSORT.xlsx"

# Conviene decir exactamente qué no se encontró: run_all.do detecta el fallo
# por el centinela del final, pero el motivo solo se ve en esta salida.
if not XLSX_IN.exists():
    sys.exit(
        f"I2: no encuentro el insumo del CONSORT.\n"
        f"    Esperaba: {XLSX_IN}\n"
        f"    Lo genera I1_summary_consort.do; corré la fase `diagnostics` antes."
    )
PNG_OUT   = RUTA_IMG / "D1_Grafico_CONSORT.png"
PDF_OUT   = RUTA_IMG / "D1_Grafico_CONSORT.pdf"

# -----------------------------------------------------------------------------
# Paleta BID
# -----------------------------------------------------------------------------
COL_AZUL     = "#004e70"  # Azul BID primario
COL_CIAN     = "#009ade"  # Cian BID
COL_GRIS     = "#3c3b3b"  # Gris oscuro BID
COL_GRISC    = "#d3d2d1"  # Gris claro BID (tonalidad primaria)
COL_VERDE    = "#308144"  # Verde oscuro BID (secundario)
COL_AMARILLO = "#ffda00"  # Amarillo BID (secundario)
COL_BLANC    = "#ffffff"

# -----------------------------------------------------------------------------
# Cargar datos (formato long) y pivotear a wide
# -----------------------------------------------------------------------------
df_long = pd.read_excel(XLSX_IN, sheet_name="CONSORT")
df_long.columns = [c.strip() for c in df_long.columns]

# Pivot: índice = etapa; columnas = (brazo, nivel); valores = n
df = df_long.pivot_table(
    index="etapa", columns=["brazo", "nivel"], values="n", aggfunc="first"
)


def n(etapa: str, brazo: str, nivel: str):
    """Devuelve el conteo (int) o None si no aplica."""
    try:
        v = df.loc[etapa, (brazo, nivel)]
    except (KeyError, IndexError):
        return None
    if pd.isna(v):
        return None
    return int(v)


def fmt(x):
    """Formatea entero con separador de miles (espacio); '—' si None."""
    if x is None:
        return "—"
    return f"{int(x):,}".replace(",", " ")


# Lectura de todos los conteos (con None-safe access)
n_alea_T            = n("alea",            "T",   "clu")
n_alea_C            = n("alea",            "C",   "clu")
n_alea_Tot          = n("alea",            "Tot", "clu")
n_atrito_T          = n("atrito",          "T",   "clu")
n_atrito_C          = n("atrito",          "C",   "clu")
n_bl_clu_T          = n("bl",              "T",   "clu")
n_bl_clu_C          = n("bl",              "C",   "clu")
n_bl_ind_T          = n("bl",              "T",   "ind")
n_bl_ind_C          = n("bl",              "C",   "ind")
n_cumpl_clu_T       = n("cumpl",           "T",   "clu")
n_cumpl_clu_C       = n("cumpl",           "C",   "clu")
n_cumpl_ind_T       = n("cumpl",           "T",   "ind")
n_cumpl_ind_C       = n("cumpl",           "C",   "ind")
n_cumpl_desv_clu_T  = n("cumpl_desv",      "T",   "clu")
n_cumpl_desv_ind_T  = n("cumpl_desv",      "T",   "ind")
n_nocumpl_clu_T     = n("nocumpl",         "T",   "clu")
n_nocumpl_clu_C     = n("nocumpl",         "C",   "clu")
n_nocumpl_ind_T     = n("nocumpl",         "T",   "ind")
n_nocumpl_ind_C     = n("nocumpl",         "C",   "ind")
n_nocumpl_drr_clu_T = n("nocumpl_derrame", "T",   "clu")
n_nocumpl_drr_ind_T = n("nocumpl_derrame", "T",   "ind")
n_nocumpl_etmp_clu_C= n("nocumpl_ecatemp", "C",   "clu")
n_nocumpl_etmp_ind_C= n("nocumpl_ecatemp", "C",   "ind")
n_nocumpl_gris_clu_C= n("nocumpl_gris",    "C",   "clu")
n_nocumpl_gris_ind_C= n("nocumpl_gris",    "C",   "ind")
n_analit_clu_T      = n("analitica",       "T",   "clu")
n_analit_clu_C      = n("analitica",       "C",   "clu")
n_analit_ind_T      = n("analitica",       "T",   "ind")
n_analit_ind_C      = n("analitica",       "C",   "ind")

# -----------------------------------------------------------------------------
# Helpers de dibujo
# -----------------------------------------------------------------------------
BOX_PAD = 0.5
FAMILY  = "DejaVu Sans"


def caja_bg(ax, x, y, w, h, fc, ec, dashed=False):
    """Solo el rectángulo redondeado. El texto se agrega aparte."""
    box = FancyBboxPatch(
        (x - w / 2, y - h / 2),
        w, h,
        boxstyle=f"round,pad={BOX_PAD},rounding_size=0.9",
        linewidth=1.0,
        facecolor=fc,
        edgecolor=ec,
    )
    if dashed:
        box.set_linestyle((0, (4, 2)))
    ax.add_patch(box)


def texto(ax, x, y, s, fontsize=9, color=COL_GRIS, bold=False, va="center"):
    ax.text(
        x, y, s,
        ha="center", va=va,
        fontsize=fontsize, color=color,
        weight="bold" if bold else "normal",
        family=FAMILY,
    )


def separador(ax, x, y, w, color=COL_GRIS, alpha=0.5):
    """Línea horizontal interna a una caja, para separar título/cuerpo de sub-grupo."""
    ax.plot(
        [x - w / 2 + 1.2, x + w / 2 - 1.2], [y, y],
        color=color, linewidth=0.5, alpha=alpha,
    )


def box_top(y, h):
    return y + h / 2 + BOX_PAD


def box_bottom(y, h):
    return y - h / 2 - BOX_PAD


def flecha(ax, x1, y1, x2, y2, color=COL_GRIS):
    ar = FancyArrowPatch(
        (x1, y1), (x2, y2),
        arrowstyle="-|>", mutation_scale=11,
        linewidth=1.0, color=color,
    )
    ax.add_patch(ar)


def linea(ax, x1, y1, x2, y2, color=COL_GRIS):
    """Segmento sin punta (para los codos del flujo)."""
    ax.plot([x1, x2], [y1, y2], color=color, linewidth=1.0)


# -----------------------------------------------------------------------------
# Figura
# -----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(13, 12))
ax.set_xlim(0, 100)
ax.set_ylim(0, 100)
ax.set_aspect("equal")
ax.axis("off")

# -----------------------------------------------------------------------------
# Coordenadas y dimensiones (eje vertical descendente)
# -----------------------------------------------------------------------------
# Fila 1: Aleatorización (centro)
x_alea, y_alea, w_alea, h_alea = 50, 88, 46, 7.5

# Fila 2: Cabezas T/C + Atritos laterales
y_arm  = 72
h_arm  = 7.5     # T/C
h_atr  = 11.5    # atritos
x_atrT, w_atrT = 8,  14
x_T,    w_T    = 32, 22
x_C,    w_C    = 68, 22
x_atrC, w_atrC = 92, 14

# Fila 3: Cumplidores / No cumplidores (4 cajas)
y_cmp = 47
h_cmp = 20
w_cmp = 18
x_cT, x_nT, x_cC, x_nC = 15, 37, 63, 85

# Fila 4: Muestra analítica T y C
y_ms = 18
h_ms = 10
w_ms = 30
x_msT, x_msC = 30, 70

# -----------------------------------------------------------------------------
# Fila 1 — Aleatorización
# -----------------------------------------------------------------------------
caja_bg(ax, x_alea, y_alea, w_alea, h_alea, fc=COL_AZUL, ec=COL_AZUL)
texto(ax, x_alea, y_alea + 1.4, "Aleatorización",
      fontsize=11, color=COL_BLANC, bold=True)
texto(ax, x_alea, y_alea - 1.4,
      f"{fmt(n_alea_Tot)} centros poblados   ·   estratos región × producto",
      fontsize=9.5, color=COL_BLANC)

# -----------------------------------------------------------------------------
# Fila 2 — Cabezas T y C
# -----------------------------------------------------------------------------
# Tratamiento (Cian BID, texto blanco)
caja_bg(ax, x_T, y_arm, w_T, h_arm, fc=COL_CIAN, ec=COL_CIAN)
texto(ax, x_T, y_arm + 1.3, "Tratamiento", fontsize=10.5, color=COL_BLANC, bold=True)
texto(ax, x_T, y_arm - 1.3, f"{fmt(n_alea_T)} centros poblados", fontsize=9.5, color=COL_BLANC)

# Control (Gris claro, texto gris oscuro)
caja_bg(ax, x_C, y_arm, w_C, h_arm, fc=COL_GRISC, ec=COL_GRIS)
texto(ax, x_C, y_arm + 1.3, "Control", fontsize=10.5, color=COL_GRIS, bold=True)
texto(ax, x_C, y_arm - 1.3, f"{fmt(n_alea_C)} centros poblados", fontsize=9.5, color=COL_GRIS)

# -----------------------------------------------------------------------------
# Fila 2 (laterales) — Atritos T y Atritos C (borde discontinuo)
# -----------------------------------------------------------------------------
caja_bg(ax, x_atrT, y_arm, w_atrT, h_atr, fc=COL_BLANC, ec=COL_GRIS, dashed=True)
texto(ax, x_atrT, y_arm + 3.5, "Atritos T", fontsize=9.5, color=COL_GRIS, bold=True)
texto(ax, x_atrT, y_arm + 1,   f"{fmt(n_atrito_T)} c. sin BL", fontsize=8.5, color=COL_GRIS)
texto(ax, x_atrT, y_arm - 1.3, "no cumple", fontsize=8.5, color=COL_GRIS)
texto(ax, x_atrT, y_arm - 3.5, "no analizable", fontsize=8.5, color=COL_GRIS)

caja_bg(ax, x_atrC, y_arm, w_atrC, h_atr, fc=COL_BLANC, ec=COL_GRIS, dashed=True)
texto(ax, x_atrC, y_arm + 3.5, "Atritos C", fontsize=9.5, color=COL_GRIS, bold=True)
texto(ax, x_atrC, y_arm + 1,   f"{fmt(n_atrito_C)} c. sin BL", fontsize=8.5, color=COL_GRIS)
texto(ax, x_atrC, y_arm - 1.3, "cumple", fontsize=8.5, color=COL_GRIS)
texto(ax, x_atrC, y_arm - 3.5, "no analizable", fontsize=8.5, color=COL_GRIS)

# Flechas Aleatorización → T y C (split central con codo)
y_split = (box_bottom(y_alea, h_alea) + box_top(y_arm, h_arm)) / 2
linea(ax, x_alea, box_bottom(y_alea, h_alea), x_alea, y_split)
linea(ax, x_T,    y_split, x_C,    y_split)
flecha(ax, x_T, y_split, x_T, box_top(y_arm, h_arm))
flecha(ax, x_C, y_split, x_C, box_top(y_arm, h_arm))

# Flechas T → Atritos T (lateral horizontal) y C → Atritos C
flecha(ax, x_T - w_T / 2 - BOX_PAD, y_arm, x_atrT + w_atrT / 2 + BOX_PAD, y_arm)
flecha(ax, x_C + w_C / 2 + BOX_PAD, y_arm, x_atrC - w_atrC / 2 - BOX_PAD, y_arm)

# -----------------------------------------------------------------------------
# Fila 3 — Cumplidores / No cumplidores
# -----------------------------------------------------------------------------
# CumplT (verde, con desv. temporal)
caja_bg(ax, x_cT, y_cmp, w_cmp, h_cmp, fc=COL_BLANC, ec=COL_VERDE)
texto(ax, x_cT, y_cmp + 7.0,  "Cumplidores T",       fontsize=10, color=COL_VERDE, bold=True)
texto(ax, x_cT, y_cmp + 4.0,  f"{fmt(n_cumpl_clu_T)} clusters", fontsize=9, color=COL_GRIS)
texto(ax, x_cT, y_cmp + 1.7,  f"{fmt(n_cumpl_ind_T)} productores", fontsize=9, color=COL_GRIS)
separador(ax, x_cT, y_cmp - 0.6, w_cmp)
texto(ax, x_cT, y_cmp - 3.0,  "Desv. temporal", fontsize=9, color=COL_GRIS, bold=True)
texto(ax, x_cT, y_cmp - 5.3,  f"{fmt(n_cumpl_desv_clu_T)} c. · {fmt(n_cumpl_desv_ind_T)} prod.", fontsize=8.5, color=COL_GRIS)
texto(ax, x_cT, y_cmp - 7.3,  "(timing temprano)", fontsize=8, color=COL_GRIS)

# NoCumplT (amarillo, con derrame)
caja_bg(ax, x_nT, y_cmp, w_cmp, h_cmp, fc=COL_BLANC, ec=COL_AMARILLO)
texto(ax, x_nT, y_cmp + 7.0,  "No cumplidores T",      fontsize=10, color=COL_GRIS, bold=True)
texto(ax, x_nT, y_cmp + 4.0,  f"{fmt(n_nocumpl_clu_T)} clusters", fontsize=9, color=COL_GRIS)
texto(ax, x_nT, y_cmp + 1.7,  f"{fmt(n_nocumpl_ind_T)} productores", fontsize=9, color=COL_GRIS)
separador(ax, x_nT, y_cmp - 0.6, w_cmp)
texto(ax, x_nT, y_cmp - 3.0,  "Derrame", fontsize=9, color=COL_GRIS, bold=True)
texto(ax, x_nT, y_cmp - 5.3,  f"{fmt(n_nocumpl_drr_clu_T)} c. · {fmt(n_nocumpl_drr_ind_T)} prod.", fontsize=8.5, color=COL_GRIS)
texto(ax, x_nT, y_cmp - 7.3,  "(asistió otra ECA estudio)", fontsize=8, color=COL_GRIS)

# CumplC (verde, sin sub-grupos)
caja_bg(ax, x_cC, y_cmp, w_cmp, h_cmp, fc=COL_BLANC, ec=COL_VERDE)
texto(ax, x_cC, y_cmp + 7.0,  "Cumplidores C",      fontsize=10, color=COL_VERDE, bold=True)
texto(ax, x_cC, y_cmp + 4.0,  f"{fmt(n_cumpl_clu_C)} clusters", fontsize=9, color=COL_GRIS)
texto(ax, x_cC, y_cmp + 1.7,  f"{fmt(n_cumpl_ind_C)} productores", fontsize=9, color=COL_GRIS)

# NoCumplC (amarillo, con ECA temprana + caso gris)
caja_bg(ax, x_nC, y_cmp, w_cmp, h_cmp, fc=COL_BLANC, ec=COL_AMARILLO)
texto(ax, x_nC, y_cmp + 7.0,  "No cumplidores C", fontsize=10, color=COL_GRIS, bold=True)
texto(ax, x_nC, y_cmp + 4.0,  f"{fmt(n_nocumpl_clu_C)} clusters", fontsize=9, color=COL_GRIS)
texto(ax, x_nC, y_cmp + 1.7,  f"{fmt(n_nocumpl_ind_C)} productores", fontsize=9, color=COL_GRIS)
separador(ax, x_nC, y_cmp - 0.6, w_cmp)
texto(ax, x_nC, y_cmp - 2.7,  "ECA temprana",       fontsize=9, color=COL_GRIS, bold=True)
texto(ax, x_nC, y_cmp - 4.8,  f"{fmt(n_nocumpl_etmp_clu_C)} c. · {fmt(n_nocumpl_etmp_ind_C)} prod.", fontsize=8.5, color=COL_GRIS)
texto(ax, x_nC, y_cmp - 6.7,  "Caso gris", fontsize=9, color=COL_GRIS, bold=True)
texto(ax, x_nC, y_cmp - 8.7,  f"{fmt(n_nocumpl_gris_clu_C)} c. · {fmt(n_nocumpl_gris_ind_C)} prod.", fontsize=8.5, color=COL_GRIS)

# Flechas T → CumplT y NoCumplT (split desde la cabeza T)
y_split_T = (box_bottom(y_arm, h_arm) + box_top(y_cmp, h_cmp)) / 2
linea(ax, x_T,  box_bottom(y_arm, h_arm), x_T,  y_split_T)
linea(ax, x_cT, y_split_T, x_nT, y_split_T)
flecha(ax, x_cT, y_split_T, x_cT, box_top(y_cmp, h_cmp))
flecha(ax, x_nT, y_split_T, x_nT, box_top(y_cmp, h_cmp))

# Flechas C → CumplC y NoCumplC
y_split_C = y_split_T
linea(ax, x_C,  box_bottom(y_arm, h_arm), x_C,  y_split_C)
linea(ax, x_cC, y_split_C, x_nC, y_split_C)
flecha(ax, x_cC, y_split_C, x_cC, box_top(y_cmp, h_cmp))
flecha(ax, x_nC, y_split_C, x_nC, box_top(y_cmp, h_cmp))

# -----------------------------------------------------------------------------
# Fila 4 — Muestra analítica T y C
# -----------------------------------------------------------------------------
caja_bg(ax, x_msT, y_ms, w_ms, h_ms, fc=COL_AZUL, ec=COL_AZUL)
texto(ax, x_msT, y_ms + 2.7, "Muestra analítica — Tratamiento", fontsize=10, color=COL_BLANC, bold=True)
texto(ax, x_msT, y_ms + 0.3, f"{fmt(n_analit_clu_T)} clusters   ·   {fmt(n_analit_ind_T)} productores", fontsize=9, color=COL_BLANC)
texto(ax, x_msT, y_ms - 2.2, f"{fmt(n_cumpl_clu_T)} cumplidores + {fmt(n_nocumpl_clu_T)} no cumplidores", fontsize=8.5, color=COL_BLANC)

caja_bg(ax, x_msC, y_ms, w_ms, h_ms, fc=COL_AZUL, ec=COL_AZUL)
texto(ax, x_msC, y_ms + 2.7, "Muestra analítica — Control", fontsize=10, color=COL_BLANC, bold=True)
texto(ax, x_msC, y_ms + 0.3, f"{fmt(n_analit_clu_C)} clusters   ·   {fmt(n_analit_ind_C)} productores", fontsize=9, color=COL_BLANC)
texto(ax, x_msC, y_ms - 2.2, f"{fmt(n_cumpl_clu_C)} cumplidores + {fmt(n_nocumpl_clu_C)} no cumplidores", fontsize=8.5, color=COL_BLANC)

# Flechas: convergencia CumplT + NoCumplT → MuestraT
y_split_ms_T = (box_bottom(y_cmp, h_cmp) + box_top(y_ms, h_ms)) / 2
linea(ax, x_cT, box_bottom(y_cmp, h_cmp), x_cT, y_split_ms_T)
linea(ax, x_nT, box_bottom(y_cmp, h_cmp), x_nT, y_split_ms_T)
linea(ax, x_cT, y_split_ms_T, x_nT, y_split_ms_T)
flecha(ax, x_msT, y_split_ms_T, x_msT, box_top(y_ms, h_ms))

# Flechas: convergencia CumplC + NoCumplC → MuestraC
y_split_ms_C = y_split_ms_T
linea(ax, x_cC, box_bottom(y_cmp, h_cmp), x_cC, y_split_ms_C)
linea(ax, x_nC, box_bottom(y_cmp, h_cmp), x_nC, y_split_ms_C)
linea(ax, x_cC, y_split_ms_C, x_nC, y_split_ms_C)
flecha(ax, x_msC, y_split_ms_C, x_msC, box_top(y_ms, h_ms))

plt.tight_layout()
fig.savefig(PNG_OUT, dpi=300, bbox_inches="tight", facecolor="white")
fig.savefig(PDF_OUT, bbox_inches="tight", facecolor="white")
plt.close(fig)

print(f"OK: {PNG_OUT}")
print(f"OK: {PDF_OUT}")

# Centinela con la lógica invertida: el archivo se crea SOLO si llegamos hasta
# acá. `shell` de Stata no propaga códigos de salida —devuelve 0 incluso ante un
# comando inexistente—, así que el llamador no puede preguntar si esto falló;
# solo puede exigir que el centinela exista. Una excepción, un intérprete
# ausente o un insumo faltante dejan el archivo sin crear y delatan el fallo.
if len(sys.argv) > 1:
    Path(sys.argv[1]).write_text("ok\n", encoding="utf-8")
