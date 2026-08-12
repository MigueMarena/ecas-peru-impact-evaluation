#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
plot_knowledge_distributions.py
================================
Genera gráficos de distribución (KDE) del puntaje del test de conocimientos
agronómicos (Total y Sección BPA) por grupo de asignación del CCPP (Z=0
control, Z=1 tratamiento). Produce cuatro figuras por cada variable:

    - **Global**       : 1 panel con la muestra pooled.
    - **Heterogéneos** : 3 paneles (Cítricos, Papa, Plátano).

Diseño:
- Identidad visual BID: paleta primaria del Manual de Marca BID.
- Principios de Kieran Healy (Data Visualization, 2018):
    * Tipografía sans-serif clara, sin chartjunk.
    * Etiquetas directas en vez de leyendas cuando es posible; si no caben,
      una franja-leyenda discreta arriba del grid.
    * Subtítulos informativos que cuentan la historia.
    * Contraste con propósito: control = amarillo BID (cálido), tratamiento =
      azul BID (frío) => complementarios cool/warm dentro de la paleta.
    * Fondo blanco minimalista, líneas delgadas.

Inputs (no se modifican):
    1_Data/Out/5_BDs por grupos de vars/Vars_Caract_Obs.dta
    1_Data/Out/5_BDs por grupos de vars/Vars_Ptjs_Test_BPAs_LS.dta

Outputs:
    6_Presentaciones/Íconos e Imágenes/dist_score_total_global.{png,pdf}
    6_Presentaciones/Íconos e Imágenes/dist_score_total_hetero.{png,pdf}
    6_Presentaciones/Íconos e Imágenes/dist_score_bpa_global.{png,pdf}
    6_Presentaciones/Íconos e Imágenes/dist_score_bpa_hetero.{png,pdf}

Variables identificadas (revisadas en 11_build_bpa_knowledge.do y 18_estimate_knowledge_scores.do):
    - Codprod22       : ID del productor (m:1 join key entre las dos bases).
    - asig_ccpp       : asignación del CCPP a tratamiento (1) vs. control (0).
    - post            : período (1 = Línea de Seguimiento, 2022).
    - prod_ECA_eval   : cultivo evaluado (codificada): 26=Cítricos, 16=Papa, 19=Plátano.
    - ptj_test        : puntaje TOTAL del test, ponderado y reescalado a 0-17 (pooled).
    - ptj_BPA         : puntaje SECCIÓN BPA (rowtotal: 0-12 cítricos/papa, 0-11 plátano).
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.lines import Line2D
from scipy import stats

# =============================================================================
# Rutas del proyecto
# =============================================================================
RUTA_PROYECTO = Path(r"E:/Consultorías/BID/HRC0052956")
RUTA_DATOS    = RUTA_PROYECTO / "1_Data" / "Out" / "5_BDs por grupos de vars"
RUTA_OUT      = RUTA_PROYECTO / "6_Presentaciones" / "Íconos e Imágenes"

DTA_CARACT    = RUTA_DATOS / "Vars_Caract_Obs.dta"
DTA_PUNTAJES  = RUTA_DATOS / "Vars_Ptjs_Test_BPAs_LS.dta"

# =============================================================================
# Paleta BID (del Manual de Marca, declarada en E:/Consultorías/BID/CLAUDE.md)
# =============================================================================
# Primarios
COLOR_AZUL_BID     = "#004e70"   # Azul BID (Pantone 3025 C)
COLOR_GRIS_OSCURO  = "#3c3b3b"   # Gris oscuro corporativo (Black 7C)
COLOR_CIAN         = "#009ade"   # Cian BID (Pantone 2925 C)
COLOR_GRIS_MEDIO   = "#aeadab"
COLOR_GRIS_CLARO   = "#d3d2d1"

# Secundarios
COLOR_AMARILLO_BID = "#ffda00"   # Amarillo BID (Pantone 108 C)

# Tonalidad cálida derivada del amarillo BID (permitida por la norma de marca:
# "tonalidades" de colores primarios/secundarios). Más legible sobre blanco que
# el amarillo puro, conservando el carácter cálido.
COLOR_AMBAR_OSCURO = "#c79100"

# Asignación semántica:
#   - Z=0 (control)      -> cálido (amarillo/ámbar): referencia, contrapunto warm.
#   - Z=1 (tratamiento)  -> azul BID (cool): dirección esperada del efecto.
COLOR_CONTROL        = COLOR_AMBAR_OSCURO
COLOR_CONTROL_FILL   = COLOR_AMARILLO_BID
COLOR_TRATAMIENTO    = COLOR_AZUL_BID
COLOR_TRATAMIENTO_FILL = COLOR_AZUL_BID

# Códigos de cultivo (de 18_estimate_knowledge_scores.do)
CROP_CODES = {
    "Cítricos": 26,
    "Papa":     16,
    "Plátano":  19,
}

# =============================================================================
# Efectos ITT a reportar en cada panel
# =============================================================================
# Tupla: (coef_en_puntos_del_test, cambio_relativo_pct_vs_control, sig_stars)
#   sig_stars: 3=***p<0.01, 2=**p<0.05, 1=*p<0.10, 0=ns.
# Fuente: Tabla 8.1-1_Tabla_Ptjes_Comb.docx, columna con controles (ITT).
# El coeficiente está ya expresado en puntos del test (coef_SD × DE_control)
# y el % relativo respecto de la media del control en t=1.
# Deja un grupo con valor None para que el panel caiga al Δ muestral.
ITT_EFFECTS: dict[str, dict[str, tuple[float, float, int] | None]] = {
    # Puntaje de la sección BPA (valores provistos por el equipo a partir
    # del slide oficial de resultados).
    "ptj_BPA": {
        "Pooled":   (0.25, 12.0, 2),
        "Cítricos": (0.57, 28.0, 2),
        "Papa":     (0.02,  1.0, 0),
        "Plátano":  (0.09,  9.0, 0),
    },
    # Puntaje total del test — pendiente de poblar con los números oficiales;
    # mientras tanto, los paneles muestran Δ muestral como referencia.
    "ptj_test": {
        "Pooled":   None,
        "Cítricos": None,
        "Papa":     None,
        "Plátano":  None,
    },
}

# =============================================================================
# Configuración tipográfica y de tema (estilo "minimal" tipo Kieran Healy)
# =============================================================================
def configurar_estilo() -> None:
    """Aplica un tema minimalista sin chartjunk. Prefiere Open Sans (tipografía
    secundaria BID); si no está disponible, cae a Arial y luego a DejaVu Sans."""
    fuentes_disponibles = {f.name for f in font_manager.fontManager.ttflist}
    if "Open Sans" in fuentes_disponibles:
        familia = ["Open Sans"]
    elif "Arial" in fuentes_disponibles:
        familia = ["Arial"]
    else:
        familia = ["DejaVu Sans"]

    mpl.rcParams.update({
        "font.family":          "sans-serif",
        "font.sans-serif":      familia,
        "font.size":            10.5,
        "axes.titlesize":       12,
        "axes.labelsize":       10,
        "xtick.labelsize":      9,
        "ytick.labelsize":      9,
        "legend.fontsize":      9,
        "figure.titlesize":     14,

        "figure.facecolor":     "white",
        "axes.facecolor":       "white",
        "savefig.facecolor":    "white",

        "axes.spines.top":      False,
        "axes.spines.right":    False,
        "axes.spines.left":     True,
        "axes.spines.bottom":   True,
        "axes.edgecolor":       COLOR_GRIS_OSCURO,
        "axes.linewidth":       0.6,
        "axes.labelcolor":      COLOR_GRIS_OSCURO,

        "xtick.color":          COLOR_GRIS_OSCURO,
        "ytick.color":          COLOR_GRIS_OSCURO,
        "xtick.major.size":     3,
        "ytick.major.size":     3,
        "xtick.direction":      "out",
        "ytick.direction":      "out",

        "axes.grid":            True,
        "axes.axisbelow":       True,
        "grid.color":           COLOR_GRIS_CLARO,
        "grid.linewidth":       0.4,
        "grid.alpha":           0.5,

        "lines.linewidth":      1.8,
        "lines.solid_capstyle": "round",

        "savefig.dpi":          300,
        "savefig.bbox":         "tight",
        "pdf.fonttype":         42,
        "ps.fonttype":          42,
    })


# =============================================================================
# Carga y preparación de datos
# =============================================================================
def cargar_datos() -> pd.DataFrame:
    """Lee las dos .dta y devuelve un DataFrame productor-nivel en LS con:
        Codprod22, asig_ccpp, prod_ECA_eval, ptj_test, ptj_BPA, cultivo (str)."""
    try:
        import pyreadstat  # noqa: F401
        caract,    _ = pyreadstat.read_dta(str(DTA_CARACT),    encoding="latin1")
        puntajes,  _ = pyreadstat.read_dta(str(DTA_PUNTAJES),  encoding="latin1")
    except ImportError:
        caract   = pd.read_stata(DTA_CARACT,   convert_categoricals=False)
        puntajes = pd.read_stata(DTA_PUNTAJES, convert_categoricals=False)

    cols_caract = ["Codprod22", "post", "asig_ccpp", "prod_ECA_eval"]
    caract = caract.loc[:, cols_caract].copy()
    caract = caract.loc[caract["post"] == 1].drop(columns="post")

    cols_punt = ["Codprod22", "ptj_test", "ptj_BPA"]
    puntajes = puntajes.loc[:, cols_punt].copy()

    df = caract.merge(puntajes, on="Codprod22", how="inner", validate="1:1")

    df["asig_ccpp"]     = df["asig_ccpp"].astype("Int64")
    df["prod_ECA_eval"] = df["prod_ECA_eval"].astype("Int64")

    map_cultivo = {v: k for k, v in CROP_CODES.items()}
    df["cultivo"] = df["prod_ECA_eval"].map(map_cultivo)

    return df


# =============================================================================
# Estadística auxiliar
# =============================================================================
@dataclass
class ResumenGrupo:
    n: int
    media: float
    de: float


def resumen(serie: pd.Series) -> ResumenGrupo:
    s = serie.dropna()
    return ResumenGrupo(n=len(s),
                        media=float(s.mean()) if len(s) else np.nan,
                        de=float(s.std(ddof=1)) if len(s) > 1 else np.nan)


def diff_means_test(t: pd.Series, c: pd.Series) -> tuple[float, float]:
    """Diferencia de medias (T - C) y p-valor de un t-test de Welch.
    NOTA: este p-valor es informativo; las regresiones del paper usan
    errores estándar clústerizados a nivel de CCPP (no se replica aquí)."""
    t = t.dropna()
    c = c.dropna()
    if len(t) < 2 or len(c) < 2:
        return (np.nan, np.nan)
    diff = float(t.mean() - c.mean())
    res  = stats.ttest_ind(t, c, equal_var=False, nan_policy="omit")
    return diff, float(res.pvalue)


def estrellas(p: float) -> str:
    if np.isnan(p):
        return ""
    if p < 0.01:
        return "***"
    if p < 0.05:
        return "**"
    if p < 0.10:
        return "*"
    return ""


# =============================================================================
# Plotting helpers
# =============================================================================
def kde_xy(serie: pd.Series, x_grid: np.ndarray) -> np.ndarray | None:
    """Devuelve y(x) de un KDE Gaussiano evaluado en x_grid, o None si no aplica."""
    s = serie.dropna().values
    if len(s) < 5 or np.std(s) == 0:
        return None
    kde = stats.gaussian_kde(s, bw_method="scott")
    return kde(x_grid)


def _dibujar_kdes(ax: plt.Axes,
                  df_grupo: pd.DataFrame,
                  var: str,
                  x_lo: float,
                  x_hi: float) -> dict:
    """Dibuja las dos KDEs (control y tratamiento) y devuelve un dict con la
    información necesaria para rotular y anotar."""
    x_grid = np.linspace(x_lo, x_hi, 500)

    serie_c = df_grupo.loc[df_grupo["asig_ccpp"] == 0, var]
    serie_t = df_grupo.loc[df_grupo["asig_ccpp"] == 1, var]

    y_c = kde_xy(serie_c, x_grid)
    y_t = kde_xy(serie_t, x_grid)

    ymax = 0.0
    if y_c is not None:
        ax.fill_between(x_grid, 0, y_c, color=COLOR_CONTROL_FILL,
                        alpha=0.28, lw=0, zorder=1)
        ax.plot(x_grid, y_c, color=COLOR_CONTROL, lw=1.8, zorder=3)
        ymax = max(ymax, float(np.nanmax(y_c)))
    if y_t is not None:
        ax.fill_between(x_grid, 0, y_t, color=COLOR_TRATAMIENTO_FILL,
                        alpha=0.18, lw=0, zorder=2)
        ax.plot(x_grid, y_t, color=COLOR_TRATAMIENTO, lw=1.8, zorder=4)
        ymax = max(ymax, float(np.nanmax(y_t)))

    res_c = resumen(serie_c)
    res_t = resumen(serie_t)
    diff, pval = diff_means_test(serie_t, serie_c)

    # Líneas verticales de medias (discretas, sin leyenda)
    if not np.isnan(res_c.media):
        ax.axvline(res_c.media, color=COLOR_CONTROL,
                   lw=1.0, ls=(0, (4, 2)), zorder=5)
    if not np.isnan(res_t.media):
        ax.axvline(res_t.media, color=COLOR_TRATAMIENTO,
                   lw=1.0, ls=(0, (4, 2)), zorder=5)

    return {
        "x_grid": x_grid,
        "y_c":    y_c,
        "y_t":    y_t,
        "ymax":   ymax,
        "res_c":  res_c,
        "res_t":  res_t,
        "diff":   diff,
        "pval":   pval,
    }


def _fmt_itt(coef: float, rel: float, sig: int) -> str:
    """Formatea '+0.25 puntos. (+12%)**' al estilo de los slides BID."""
    stars = "*" * sig
    sign_c = "+" if coef >= 0 else ""
    sign_r = "+" if rel >= 0 else ""
    unidad = "puntos" if abs(coef) >= 1 else "ptos."
    return f"{sign_c}{coef:.2f} {unidad} ({sign_r}{rel:.0f}%){stars}"


def _anotar_efecto_y_n(ax: plt.Axes, info: dict,
                       var: str, grupo: str) -> None:
    """Anota el efecto (ITT si está disponible; si no, Δ muestral) y el tamaño
    de muestra. Se colocan en las esquinas superior e inferior derechas para
    no colisionar con las etiquetas de grupo."""
    res_c, res_t = info["res_c"], info["res_t"]

    itt = ITT_EFFECTS.get(var, {}).get(grupo)
    if itt is not None:
        coef, rel, sig = itt
        texto = _fmt_itt(coef, rel, sig)
    else:
        diff, pval = info["diff"], info["pval"]
        if not np.isnan(diff):
            texto = f"$\\Delta$ = {diff:+.2f}{estrellas(pval)}"
        else:
            texto = ""

    if texto:
        ax.text(0.97, 0.93, texto,
                transform=ax.transAxes, ha="right", va="top",
                fontsize=10, color=COLOR_GRIS_OSCURO,
                bbox=dict(facecolor="white", edgecolor="none",
                          alpha=0.85, pad=2.5))

    ax.text(0.97, 0.05,
            f"$n_C$ = {res_c.n:,}    $n_T$ = {res_t.n:,}".replace(",", " "),
            transform=ax.transAxes, ha="right", va="bottom",
            fontsize=8.5, color=COLOR_GRIS_MEDIO)


def _etiquetas_directas_en_picos(ax: plt.Axes, info: dict) -> None:
    """Coloca etiquetas 'Control' y 'Tratamiento' sobre los picos de cada KDE,
    evitando superposición. Se ajusta el ylim si es necesario para hacer
    espacio arriba."""
    x_grid = info["x_grid"]
    y_c, y_t = info["y_c"], info["y_t"]
    ymax = info["ymax"]
    if ymax <= 0:
        ax.set_yticks([])
        ax.spines["left"].set_visible(False)
        return

    x_range = x_grid[-1] - x_grid[0]

    etiquetas = []  # (x_peak, y_peak, color, texto)
    if y_c is not None and np.nanmax(y_c) > 0:
        idx = int(np.nanargmax(y_c))
        etiquetas.append((x_grid[idx], y_c[idx], COLOR_CONTROL,     "Control"))
    if y_t is not None and np.nanmax(y_t) > 0:
        idx = int(np.nanargmax(y_t))
        etiquetas.append((x_grid[idx], y_t[idx], COLOR_TRATAMIENTO, "Tratamiento"))

    # Si los picos están demasiado cerca, desplazamos horizontalmente las
    # etiquetas para que no se apilen.
    offsets_x = [0.0] * len(etiquetas)
    offsets_y_mult = [1.06] * len(etiquetas)  # altura sobre el pico (× ymax)

    if len(etiquetas) == 2:
        dx_abs = abs(etiquetas[0][0] - etiquetas[1][0])
        if dx_abs < 0.12 * x_range:
            # Separar horizontalmente ±6% del rango y subir una un poco más.
            shift = 0.08 * x_range
            if etiquetas[0][0] <= etiquetas[1][0]:
                offsets_x[0] = -shift
                offsets_x[1] = +shift
            else:
                offsets_x[0] = +shift
                offsets_x[1] = -shift
            offsets_y_mult = [1.08, 1.16]

    # Ajustar ylim para asegurar espacio de las etiquetas.
    y_label_top = ymax * max(offsets_y_mult) + ymax * 0.03
    ax.set_ylim(0, max(ymax * 1.32, y_label_top))

    for (x_peak, y_peak, color, txt), ox, oy_mult in zip(
            etiquetas, offsets_x, offsets_y_mult):
        x_lbl = float(np.clip(x_peak + ox, x_grid[0] + 0.02 * x_range,
                              x_grid[-1] - 0.02 * x_range))
        y_lbl = ymax * oy_mult
        # Pequeño conector del pico a la etiqueta si se desplazó.
        if abs(ox) > 0:
            ax.plot([x_peak, x_lbl], [y_peak, y_lbl * 0.97],
                    color=color, lw=0.7, alpha=0.6, zorder=6,
                    solid_capstyle="round")
        ax.text(x_lbl, y_lbl, txt,
                color=color, fontsize=10, ha="center", va="bottom",
                fontweight="bold", zorder=7,
                bbox=dict(facecolor="white", edgecolor="none",
                          alpha=0.85, pad=1.5))

    ax.set_yticks([])
    ax.spines["left"].set_visible(False)


def _franja_leyenda(fig: plt.Figure, y: float = 0.905) -> None:
    """Franja-leyenda compacta para la figura de heterogéneos (3 paneles) en
    lugar de etiquetas directas por panel."""
    ax_leg = fig.add_axes([0.04, y, 0.92, 0.035])
    ax_leg.axis("off")
    handles = [
        Line2D([0], [0], color=COLOR_CONTROL,     lw=2.4, label="Control (Z = 0)"),
        Line2D([0], [0], color=COLOR_TRATAMIENTO, lw=2.4, label="Tratamiento (Z = 1)"),
    ]
    ax_leg.legend(handles=handles, loc="center left",
                  frameon=False, ncol=2, handlelength=2.0,
                  handletextpad=0.6, columnspacing=2.0,
                  fontsize=10)


# =============================================================================
# Figuras: global y heterogéneos
# =============================================================================
def _panel(ax: plt.Axes, df: pd.DataFrame, var: str,
           x_lo: float, x_hi: float, titulo: str, grupo: str,
           con_etiquetas: bool) -> None:
    info = _dibujar_kdes(ax, df, var, x_lo, x_hi)
    if info["ymax"] > 0:
        ax.set_ylim(0, info["ymax"] * 1.32)
    ax.set_xlim(x_lo, x_hi)
    ax.set_title(titulo, loc="left", color=COLOR_GRIS_OSCURO, pad=6)
    if con_etiquetas:
        _etiquetas_directas_en_picos(ax, info)
    _anotar_efecto_y_n(ax, info, var=var, grupo=grupo)
    ax.set_yticks([])
    ax.spines["left"].set_visible(False)


def _pie_nota(fig: plt.Figure) -> None:
    # Nota multilínea: un único string largo obligaría a `bbox_inches="tight"`
    # a ensanchar el PNG para que el texto no se corte, dejando mucho margen
    # en blanco a la derecha de los paneles.
    nota = (
        "Fuente: línea de seguimiento 2022, PRODESA–SENASA. "
        "KDE Gaussiano (Scott); líneas verticales = media por grupo.\n"
        "Anotación: ITT en puntos del test (OLS con controles) y % vs. control; "
        "si no hay ITT, $\\Delta$ muestral (t-Welch).\n"
        "* p < 0.10, ** p < 0.05, *** p < 0.01."
    )
    fig.text(0.01, -0.02, nota, ha="left", va="top",
             fontsize=8, color=COLOR_GRIS_MEDIO, linespacing=1.35)


def figura_global(df: pd.DataFrame, var: str,
                  escala: tuple[float, float],
                  titulo: str, subtitulo: str, eje_x: str,
                  archivo_base: Path) -> None:
    """Figura de 1 panel para la muestra completa (pooled)."""
    fig = plt.figure(figsize=(8.2, 4.8))
    ax = fig.add_subplot(1, 1, 1)
    x_lo, x_hi = escala

    _panel(ax, df, var, x_lo, x_hi,
           titulo="Muestra Completa", grupo="Pooled",
           con_etiquetas=True)
    ax.set_xlabel(eje_x, color=COLOR_GRIS_OSCURO)

    # Título arriba; subtítulo separado ~3.5% de la figura para dar aire.
    fig.suptitle(titulo, x=0.04, y=0.99, ha="left",
                 fontsize=15, fontweight="bold",
                 color=COLOR_AZUL_BID)
    fig.text(0.04, 0.905, subtitulo, ha="left",
             fontsize=10.5, color=COLOR_GRIS_OSCURO, style="italic")

    _pie_nota(fig)
    fig.tight_layout(rect=(0, 0, 1, 0.86))

    _guardar(fig, archivo_base)


def figura_heterogeneos(df: pd.DataFrame, var: str,
                        escala: tuple[float, float],
                        titulo: str, subtitulo: str, eje_x: str,
                        archivo_base: Path) -> None:
    """Figura de 3 paneles (Cítricos, Papa, Plátano)."""
    cultivos = list(CROP_CODES.keys())

    fig, axes = plt.subplots(
        nrows=1, ncols=len(cultivos),
        figsize=(12.5, 4.8),
        sharex=True, sharey=False,
    )

    x_lo, x_hi = escala
    for ax, cultivo in zip(axes, cultivos):
        sub = df.loc[df["cultivo"] == cultivo]
        _panel(ax, sub, var, x_lo, x_hi,
               titulo=cultivo, grupo=cultivo,
               con_etiquetas=False)
        ax.set_xlabel(eje_x, color=COLOR_GRIS_OSCURO)

    # Título arriba; subtítulo separado ~4% de la figura para dar aire.
    fig.suptitle(titulo, x=0.04, y=0.99, ha="left",
                 fontsize=15, fontweight="bold",
                 color=COLOR_AZUL_BID)
    fig.text(0.04, 0.915, subtitulo, ha="left",
             fontsize=10.5, color=COLOR_GRIS_OSCURO, style="italic")

    # Franja-leyenda entre subtítulo y paneles.
    _franja_leyenda(fig, y=0.855)

    _pie_nota(fig)
    fig.tight_layout(rect=(0, 0, 1, 0.82))

    _guardar(fig, archivo_base)


def _guardar(fig: plt.Figure, archivo_base: Path) -> None:
    RUTA_OUT.mkdir(parents=True, exist_ok=True)
    png = archivo_base.with_suffix(".png")
    pdf = archivo_base.with_suffix(".pdf")
    fig.savefig(png, dpi=300, bbox_inches="tight")
    fig.savefig(pdf,           bbox_inches="tight")
    plt.close(fig)
    print(f"  -> {png}")
    print(f"  -> {pdf}")


# =============================================================================
# Main
# =============================================================================
def main() -> int:
    configurar_estilo()
    print("Cargando datos...")
    df = cargar_datos()
    print(f"  {len(df):,} productores en LS con puntajes y asignación.".replace(",", " "))

    cultivos_obs = sorted(df["cultivo"].dropna().unique())
    print(f"  Cultivos detectados: {cultivos_obs}")
    if set(cultivos_obs) != set(CROP_CODES.keys()):
        print("  [WARN] Cultivos detectados difieren del esperado. Revisar CROP_CODES.",
              file=sys.stderr)

    bpa_max = float(np.ceil(df["ptj_BPA"].max())) if df["ptj_BPA"].notna().any() else 12.0

    specs = [
        dict(
            var      = "ptj_test",
            escala   = (0.0, 17.0),
            titulo   = "Distribución del puntaje total del test de conocimientos agronómicos",
            subtitulo_g = ("Muestra completa. CCPPs tratados (azul) vs. CCPPs de control (ámbar). "
                           "Seguimiento 2022."),
            subtitulo_h = ("Por cultivo evaluado. CCPPs tratados (azul) vs. CCPPs de control (ámbar). "
                           "Seguimiento 2022."),
            eje_x    = "Puntaje total (0 – 17, ponderado y reescalado)",
            nombre   = "dist_score_total",
        ),
        dict(
            var      = "ptj_BPA",
            escala   = (0.0, max(12.0, bpa_max)),
            titulo   = "Distribución del puntaje de la sección de BPA del test",
            subtitulo_g = ("Muestra completa. Sección BPA del test de conocimientos. "
                           "Seguimiento 2022."),
            subtitulo_h = ("Por cultivo. Sección BPA: 12 ítems en cítricos y papa, 11 en plátano. "
                           "Seguimiento 2022."),
            eje_x    = "Puntaje sección BPA (escala original)",
            nombre   = "dist_score_bpa",
        ),
    ]

    for i, s in enumerate(specs, start=1):
        print(f"\n[{i}/{len(specs)}] {s['titulo']}")

        print("  > Global")
        figura_global(
            df=df, var=s["var"], escala=s["escala"],
            titulo=s["titulo"], subtitulo=s["subtitulo_g"],
            eje_x=s["eje_x"],
            archivo_base=RUTA_OUT / f"{s['nombre']}_global",
        )

        print("  > Heterogéneos por cultivo")
        figura_heterogeneos(
            df=df, var=s["var"], escala=s["escala"],
            titulo=s["titulo"], subtitulo=s["subtitulo_h"],
            eje_x=s["eje_x"],
            archivo_base=RUTA_OUT / f"{s['nombre']}_hetero",
        )

    print("\nListo.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
