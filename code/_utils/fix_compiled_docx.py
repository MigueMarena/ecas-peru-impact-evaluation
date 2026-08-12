# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# File           : fix_compiled_docx.py
# Author         : Carlos Marena
# Description    : Sanea el .docx que produce `putdocx append`. Dos defectos
#                  del ensamblado, ambos invisibles hasta que Word abre el
#                  archivo. La explicación larga, con la evidencia de cada
#                  experimento, está en:
#                     Reporte Final_VPaper/Planes_Ejecucion/
#                     52_E_Apoyo_Compilacion_explicada.md
#
#                  (1) mc:Ignorable CON PREFIJOS NO DECLARADOS.
#
#                      El primer renglón de document.xml declara una lista de
#                      "prefijos ignorables": dialectos recientes de Word que
#                      un lector antiguo puede saltarse en vez de fallar.
#                      ISO/IEC 29500-3 §10.1.1 exige que CADA prefijo de esa
#                      lista esté declarado como namespace en el mismo
#                      elemento o en un ancestro. Si falta alguno, el paquete
#                      es inválido y el consumidor DEBE rechazarlo. Word lo
#                      hace: "Word encontró contenido no legible", y lo que
#                      abre después no es el archivo sino una reconstrucción
#                      —de ahí que aparezca como "Documento1", sin ruta.
#
#                      Qué hace putdocx exactamente (medido, no supuesto):
#                      ACUMULA los prefijos de TODAS las secciones de la lista
#                      y declara siempre su propio juego fijo de 71 namespaces.
#                      Comprobado que da igual el orden de los archivos y que
#                      la opción stylesrc() no lo altera. Basta con que UNA
#                      sección se haya guardado con un Word suficientemente
#                      nuevo y aporte un prefijo de fuera de ese juego —w16du
#                      (2023) o w16sdtfl (2024)— para que el consolidado nazca
#                      corrupto. No es, por tanto, un problema "de la
#                      carátula": es de cualquier sección.
#
#                      Retirar los prefijos huérfanos es seguro por
#                      construcción: si un prefijo no está declarado, no puede
#                      existir contenido etiquetado con él (sería XML
#                      inválido), así que la lista pierde una entrada que no
#                      apuntaba a nada.
#
#                      Nota: `check_sections.py` detecta esto en los fuentes
#                      antes de compilar. Este helper es la segunda línea de
#                      defensa, y la única si alguien corre el append a mano.
#
#                  (2) w:trackRevisions HEREDADO.
#
#                      No lo inventa putdocx: once de las catorce secciones lo
#                      traen activado en su settings.xml, consecuencia natural
#                      de haber trabajado el reporte con control de cambios. El
#                      append conserva el ajuste y el consolidado abre con la
#                      revisión ENCENDIDA, de modo que cualquier corrección de
#                      quien lo reciba queda marcada en rojo.
#
#                      Se limpia SOLO en el consolidado. En las secciones el
#                      control de cambios es la forma de trabajo y no se toca.
#
#                  El script es idempotente y no toca nada más del paquete:
#                  reempaqueta las partes en su orden original, byte a byte,
#                  salvo las dos que modifica.
#
# Uso            : python fix_compiled_docx.py "ruta\al\consolidado.docx"
# Salida         : código 0 si el archivo queda sano; 1 si no pudo procesarse.
# ------------------------------------------------------------------------------
import os
import re
import shutil
import sys
import zipfile

# Partes del paquete cuyo elemento raíz puede llevar mc:Ignorable.
PARTES_MCE = (
    'word/document.xml', 'word/footnotes.xml', 'word/endnotes.xml',
    'word/styles.xml', 'word/settings.xml', 'word/numbering.xml',
    'word/fontTable.xml', 'word/webSettings.xml',
)


def sanea_mce(texto):
    """Retira de mc:Ignorable los prefijos sin declaración xmlns visible.

    Devuelve (texto_nuevo, lista_de_prefijos_retirados)."""
    m = re.search(r'<\w+:\w+\b[^>]*\bmc:Ignorable\s*=\s*"[^"]*"[^>]*>', texto)
    if not m:
        return texto, []
    raiz = m.group(0)
    declarados = set(re.findall(r'xmlns:([\w\d]+)\s*=', raiz))
    ig = re.search(r'mc:Ignorable\s*=\s*"([^"]*)"', raiz).group(1)
    prefijos = ig.split()
    huerfanos = [p for p in prefijos if p not in declarados]
    if not huerfanos:
        return texto, []
    vivos = ' '.join(p for p in prefijos if p in declarados)
    raiz_nueva = re.sub(r'mc:Ignorable\s*=\s*"[^"]*"',
                        'mc:Ignorable="%s"' % vivos, raiz)
    return texto.replace(raiz, raiz_nueva, 1), huerfanos


def quita_track_revisions(texto):
    """Retira <w:trackRevisions/> del settings.xml. Devuelve (texto, n)."""
    nuevo, n = re.subn(r'<w:trackRevisions\s*/>|<w:trackRevisions\b[^>]*>\s*</w:trackRevisions>',
                       '', texto)
    return nuevo, n


def main(ruta):
    if not os.path.isfile(ruta):
        sys.stderr.write('ERROR: archivo no encontrado: %s\n' % ruta)
        return 1

    with zipfile.ZipFile(ruta) as z:
        orden = [i.filename for i in z.infolist()]
        partes = {n: z.read(n) for n in orden}

    cambios = []

    for nombre in PARTES_MCE:
        if nombre not in partes:
            continue
        texto = partes[nombre].decode('utf-8')
        texto, huerfanos = sanea_mce(texto)
        if huerfanos:
            partes[nombre] = texto.encode('utf-8')
            cambios.append('%s: mc:Ignorable sin declarar -> retirados %s'
                           % (nombre, ', '.join(huerfanos)))

    if 'word/settings.xml' in partes:
        texto = partes['word/settings.xml'].decode('utf-8')
        texto, n = quita_track_revisions(texto)
        if n:
            partes['word/settings.xml'] = texto.encode('utf-8')
            cambios.append('word/settings.xml: retirado w:trackRevisions')

    if not cambios:
        print('  [fix_compiled_docx] sin cambios: %s' % os.path.basename(ruta))
        return 0

    tmp = ruta + '.tmp'
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as zo:
        for nombre in orden:
            zo.writestr(nombre, partes[nombre])
    shutil.move(tmp, ruta)

    print('  [fix_compiled_docx] %s' % os.path.basename(ruta))
    for c in cambios:
        print('      %s' % c)
    return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.stderr.write('Uso: python fix_compiled_docx.py "ruta\\al\\archivo.docx"\n')
        sys.exit(1)
    sys.exit(max(main(a) for a in sys.argv[1:]))
