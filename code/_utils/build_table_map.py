#!/usr/bin/env python3
"""
build_table_map.py — genera docs/table_map.csv desde las cabeceras de los .do

    python 2_Scripts/_utils/build_table_map.py

Mapa de evidencia: qué script produce cada tabla y cada figura del reporte.
La fuente es el campo `Output` de la cabecera de cada script, que es donde el
pipeline ya declara lo que escribe. Generarlo en vez de mantenerlo a mano evita
que se desincronice, que es lo que le pasa siempre a los mapas escritos a mano.

Además **verifica cada salida declarada contra el disco**. Una declaración que
no corresponde a ningún archivo es una señal, no ruido: así fue como se detectó
que F1_test_balance.do prometía una tabla que ya no existía.

Cubre tablas y figuras (.docx .xlsx .png .pdf). Las bases intermedias (.dta)
son flujo de datos, no evidencia: van en docs/pipeline.md.

Se corre a mano cuando cambian las salidas; no forma parte del pipeline.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "2_Scripts"
SALIDA = ROOT / "docs" / "table_map.csv"
ENTREGABLE = ROOT / "5_Entregables" / "Reporte Final_VPaper"

EXT_EVIDENCIA = (".docx", ".xlsx", ".png", ".pdf")

RE_CAMPO = r"^// Output\s*:(.*?)(?=^// [A-Z][a-z]|^//-{4,}|^//={4,})"

# La fase se deriva de la SUBCARPETA, no del nombre del archivo: desde la
# migración del 2026-08-12 cada fase vive en la suya.
FASES = {"F_validation": "Validación", "G_estimation": "Estimación",
         "H_reporting": "Reporte", "I_diagnostics": "Diagnóstico"}

CATEGORIAS = {
    "1_Conocimiento": "Conocimiento agronómico",
    "4_Indicadores": "Indicadores compuestos BPA",
    "0_Diseño": "Diseño y diagnóstico",
    "Diagnóstico_del_Diseño": "Diseño y diagnóstico",
    "Prácticas_Agronómicas": "Prácticas agronómicas",
    "Registros_e_Inocuidad": "Registros e inocuidad",
    "Indicadores_Compuestos": "Indicadores compuestos BPA",
    "Imágenes": "Figuras",
}


def lineas_output(texto: str) -> list[str]:
    m = re.search(RE_CAMPO, texto, re.M | re.S)
    if not m:
        return []
    out = []
    for ln in (m.group(1) + "\n").splitlines():
        ln = re.sub(r"^//\s*", "", ln).strip()
        # Descarta comentarios explicativos entre paréntesis y notas sueltas.
        if not ln or ln.startswith("(") or ln.startswith("riego omitido"):
            continue
        out.append(ln)
    return out


def clasificar(ruta: str) -> tuple[str, str]:
    ubic = ("Anexo" if "Anexos" in ruta else
            "Cuerpo" if "Tablas" in ruta else
            "Figura" if ("Imágenes" in ruta or "Imagenes" in ruta) else
            "Versiones" if "ruta_report" in ruta or "Versiones" in ruta else "")
    cat = next((v for k, v in CATEGORIAS.items() if k in ruta), "")
    return ubic, cat


def verificar(ruta: str) -> str:
    """¿Existe en disco? Los patrones con comodines se cuentan por carpeta."""
    limpia = re.sub(r"\$\{[a-z_]+\}", "", ruta).replace("\\", "/").strip("/ ")
    limpia = re.sub(r"^(Tablas|Anexos|Imágenes|Imagenes)/", r"\1/", limpia)
    base = ENTREGABLE / limpia
    if "<" in limpia or "*" in limpia or "{" in limpia:
        carpeta = base.parent
        if not carpeta.is_dir():
            return "carpeta ausente"
        n = len([p for p in carpeta.iterdir() if p.suffix.lower() in EXT_EVIDENCIA])
        return f"{n} archivos"
    return "sí" if base.exists() else "NO"


def main() -> int:
    filas = []
    for p in sorted(SCRIPTS.glob("*/*.do")):
        if "Trash" in str(p):
            continue
        fase = FASES.get(p.parent.name)
        if not fase:                      # solo fases que producen evidencia
            continue
        for ln in lineas_output(p.read_text(encoding="utf-8")[:6000]):
            if not any(e in ln.lower() for e in EXT_EVIDENCIA):
                continue
            ruta = ln.split(" (")[0].strip()
            ubic, cat = clasificar(ruta)
            filas.append({
                "script": p.name,
                "fase": fase,
                "salida": ruta,
                "ubicacion": ubic,
                "categoria": cat,
                "existe": verificar(ruta),
            })

    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    with SALIDA.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(filas[0]))
        w.writeheader()
        w.writerows(filas)

    print(f"{SALIDA.relative_to(ROOT)}: {len(filas)} salidas de "
          f"{len({f['script'] for f in filas})} scripts")
    faltan = [f for f in filas if f["existe"] in ("NO", "carpeta ausente")]
    if faltan:
        print(f"\n  {len(faltan)} declaración(es) sin archivo en disco:")
        for f in faltan:
            print(f"    {f['script']:<38} {f['salida'][:60]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
