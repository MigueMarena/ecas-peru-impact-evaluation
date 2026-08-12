# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# File           : check_sections.py
# Author         : Carlos Marena
# Description    : Valida las secciones .docx ANTES de compilarlas. Existe
#                  porque casi todos los defectos que costaron caro en el
#                  bloque E.13 eran invisibles en el archivo suelto y solo se
#                  manifestaban al consolidar —o peor, al abrir el consolidado
#                  en otra máquina—. Cada chequeo de aquí corresponde a un
#                  problema que ya ocurrió al menos una vez.
#
#                  La explicación completa de cada defecto, con su historia,
#                  está en:
#                     Reporte Final_VPaper/Planes_Ejecucion/
#                     52_E_Apoyo_Compilacion_explicada.md
#
#                  BLOQUEANTES (impiden compilar; producen un consolidado roto
#                  o inservible):
#
#                   B1 · Paquete ilegible — el .docx no abre como ZIP o alguno
#                        de sus XML no está bien formado.
#                   B2 · Prefijos mc:Ignorable sin declarar — la norma
#                        (ISO/IEC 29500-3 §10.1.1) exige que todo prefijo
#                        listado como ignorable esté declarado como namespace.
#                        `putdocx append` ACUMULA los prefijos de todas las
#                        secciones y declara su propio juego fijo de 71: basta
#                        con que UNA sección aporte uno de fuera para que el
#                        consolidado nazca corrupto y Word se niegue a abrirlo.
#                        Es el defecto que costó seis commits de E.13.
#                   B3 · Marca de párrafo oculta (w:vanish / w:specVanish en
#                        w:pPr/w:rPr) — un párrafo cuya marca de fin está
#                        oculta deja de terminar: Word lo funde con el
#                        siguiente al maquetar, y el segundo pierde su
#                        numeración. Así se fundían los títulos de §6 y 6.1.
#                        Delatador: el índice se ve bien y el cuerpo no.
#                   B4 · Notas al pie huérfanas — el cuerpo referencia una nota
#                        que no existe en footnotes.xml. Pasó al aceptar
#                        borrados que englobaban la referencia (E.1).
#                   B5 · Portadilla con el separador equivocado en un campo
#                        TOC. El switch \t delimita "estilo;nivel" con el
#                        separador de lista del documento, que aquí es ';'.
#                        Con coma, Word busca un estilo llamado literalmente
#                        "Titulo de tabla,1" y el índice sale VACÍO.
#
#                  AVISOS (no impiden compilar, pero se ven en el resultado):
#
#                   A1 · Marcas de control de cambios vivas (w:ins / w:del) —
#                        el consolidado las arrastra tal cual.
#                   A2 · Comentarios vivos — viajan al documento de entrega.
#                   A3 · Párrafo vacío con estilo de encabezado o de caption —
#                        residuo de edición. Word lo omite del índice, pero
#                        conviene limpiarlo antes de entregar.
#                   A4 · Encabezado con numeración propia (numPr con numId
#                        distinto de 0) — se numera por su cuenta, fuera de la
#                        secuencia que da el estilo. numId="0" no se reporta:
#                        es la forma canónica de suprimir la numeración y está
#                        puesto a propósito desde E.4 en "Anexos", "Anexo A/B"
#                        y las portadillas.
#                   A5 · Caption con campos SEQ/STYLEREF residuales — estampan
#                        un número extra pegado al rótulo ("Tabla 3.2-1 3.21").
#
# Uso            : python check_sections.py "<carpeta Secciones>" "<sentinel>"
#                  Escribe el informe por pantalla. Si NO hay bloqueantes crea
#                  el archivo <sentinel>; si los hay, se asegura de que no
#                  exista. H1 exige el sentinel para seguir, de modo que
#                  cualquier fallo del script —incluso una excepción— también
#                  detiene la compilación.
# ------------------------------------------------------------------------------
import glob
import os
import re
import sys
import zipfile

from lxml import etree

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
def q(t): return '{%s}%s' % (W, t)

ESTILOS_ENCABEZADO = ('Ttulo1', 'Ttulo2', 'Ttulo3', 'Ttulo4')
ESTILOS_CAPTION    = ('Titulotabla', 'Titulodetabla', 'Titulofigura',
                      'Titulodefigura', 'Descripcin', 'Descripcinfigura')

bloqueantes, avisos = [], []
def bloqueante(arch, msg): bloqueantes.append((arch, msg))
def aviso(arch, msg):      avisos.append((arch, msg))


def revisa(ruta):
    arch = os.path.basename(ruta)
    es_portadilla = arch.startswith('_Indices')

    # ---- B1: el paquete abre y sus XML están bien formados -------------
    try:
        z = zipfile.ZipFile(ruta)
        if z.testzip() is not None:
            bloqueante(arch, 'B1 · el ZIP tiene una entrada dañada')
            return
        partes = {}
        for n in z.namelist():
            if n.endswith('.xml') or n.endswith('.rels'):
                partes[n] = etree.fromstring(z.read(n))
    except Exception as e:
        bloqueante(arch, 'B1 · paquete ilegible: %s' % e)
        return

    doc = partes.get('word/document.xml')
    if doc is None:
        bloqueante(arch, 'B1 · falta word/document.xml')
        return

    # ---- B2: prefijos mc:Ignorable declarados ---------------------------
    for nombre in ('word/document.xml', 'word/footnotes.xml', 'word/endnotes.xml',
                   'word/styles.xml', 'word/settings.xml', 'word/numbering.xml'):
        if nombre not in z.namelist():
            continue
        raw = z.read(nombre).decode('utf-8', 'replace')
        m = re.search(r'<\w+:\w+\b[^>]*\bmc:Ignorable\s*=\s*"[^"]*"[^>]*>', raw)
        if not m:
            continue
        raiz = m.group(0)
        declarados = set(re.findall(r'xmlns:([\w\d]+)\s*=', raiz))
        prefijos = re.search(r'mc:Ignorable\s*=\s*"([^"]*)"', raiz).group(1).split()
        huerfanos = [p for p in prefijos if p not in declarados]
        if huerfanos:
            bloqueante(arch, 'B2 · %s declara ignorables sin namespace: %s '
                             '(corromperá el consolidado)'
                             % (nombre.split('/')[-1], ', '.join(huerfanos)))

    # ---- recorrido de párrafos: B3, A3, A4 ------------------------------
    for nombre in ('word/document.xml', 'word/footnotes.xml', 'word/endnotes.xml'):
        arbol = partes.get(nombre)
        if arbol is None:
            continue
        etiqueta = nombre.split('/')[-1].replace('.xml', '')
        for i, p in enumerate(arbol.iter(q('p'))):
            pPr = p.find(q('pPr'))
            ps = p.find('%s/%s' % (q('pPr'), q('pStyle')))
            estilo = ps.get(q('val')) if ps is not None else None
            texto = ''.join(t.text or '' for t in p.iter(q('t'))).strip()

            if pPr is not None:
                rPr = pPr.find(q('rPr'))
                if rPr is not None:
                    for tag in ('vanish', 'specVanish'):
                        if rPr.find(q(tag)) is not None:
                            bloqueante(arch, 'B3 · %s ¶%d (%s) tiene la MARCA DE PÁRRAFO oculta '
                                             '(w:%s): se fundirá con el párrafo siguiente — %r'
                                             % (etiqueta, i, estilo or 'sin estilo', tag, texto[:40]))
                # A4: numeración propia en un encabezado.
                # numId="0" NO cuenta: es la forma canónica de decir "este
                # encabezado no se numera", y está puesto a propósito en
                # "Anexos", "Anexo A/B" y las portadillas desde E.4. Solo
                # molesta un numId real, que saca al encabezado de la
                # secuencia del estilo y lo numera por su cuenta.
                numPr = pPr.find(q('numPr'))
                if estilo in ESTILOS_ENCABEZADO and numPr is not None:
                    nid = numPr.find(q('numId'))
                    val = nid.get(q('val')) if nid is not None else None
                    if val not in (None, '0'):
                        aviso(arch, 'A4 · %s ¶%d (%s) lleva numeración propia (numId=%s); se '
                                    'numerará fuera de la secuencia del estilo — %r'
                                    % (etiqueta, i, estilo, val, texto[:40]))

            # A3: párrafos vacíos con estilo estructural. Word los omite del
            # índice, así que no rompen nada; son residuos de edición que
            # conviene limpiar antes de entregar.
            if not texto and estilo in ESTILOS_ENCABEZADO + ESTILOS_CAPTION:
                aviso(arch, 'A3 · %s ¶%d vacío con estilo %s (residuo de edición)'
                            % (etiqueta, i, estilo))

    # ---- A1 y A2: marcas de revisión y comentarios ----------------------
    ins = sum(len(partes[n].findall('.//' + q('ins'))) for n in
              ('word/document.xml', 'word/footnotes.xml', 'word/endnotes.xml') if n in partes)
    dele = sum(len(partes[n].findall('.//' + q('del'))) for n in
               ('word/document.xml', 'word/footnotes.xml', 'word/endnotes.xml') if n in partes)
    if ins or dele:
        aviso(arch, 'A1 · %d inserciones y %d eliminaciones sin aceptar; el consolidado las arrastra'
                    % (ins, dele))
    coment = len(doc.findall('.//' + q('commentReference')))
    if coment:
        aviso(arch, 'A2 · %d comentario(s) vivo(s); viajan al documento de entrega' % coment)

    # ---- B4: notas al pie huérfanas -------------------------------------
    if 'word/footnotes.xml' in partes:
        definidas = {n.get(q('id')) for n in partes['word/footnotes.xml'].findall(q('footnote'))}
        usadas = {r.get(q('id')) for r in doc.iter(q('footnoteReference'))}
        faltan = sorted(u for u in usadas if u not in definidas)
        if faltan:
            bloqueante(arch, 'B4 · el cuerpo referencia notas al pie inexistentes: %s' % faltan)

    # ---- A5: campos residuales en captions ------------------------------
    residuales = 0
    for p in doc.iter(q('p')):
        ps = p.find('%s/%s' % (q('pPr'), q('pStyle')))
        if ps is None or ps.get(q('val')) not in ESTILOS_CAPTION:
            continue
        for it in p.iter(q('instrText')):
            if re.search(r'\b(SEQ|STYLEREF)\b', it.text or ''):
                residuales += 1
    if residuales:
        aviso(arch, 'A5 · %d caption(s) con campos SEQ/STYLEREF residuales: estampan un número '
                    'extra al final del rótulo' % residuales)

    # ---- B5: separador de lista en los campos TOC de las portadillas ----
    if es_portadilla:
        raw = z.read('word/document.xml').decode('utf-8', 'replace')
        sep = ';'
        se = partes.get('word/settings.xml')
        if se is not None:
            ls = se.find(q('listSeparator'))
            if ls is not None:
                sep = ls.get(q('val')) or ';'
        for instr in re.findall(r'<w:instrText[^>]*>([^<]*TOC[^<]*)</w:instrText>', raw):
            for arg in re.findall(r'\\t\s+"([^"]*)"', instr):
                if sep not in arg:
                    bloqueante(arch, 'B5 · campo TOC con el separador equivocado: %r. El documento '
                                     'declara %r como separador de lista, así que el par debe '
                                     'escribirse "estilo%snivel" o el índice saldrá VACÍO'
                                     % (arg, sep, sep))


def main():
    if len(sys.argv) < 2:
        sys.stderr.write('Uso: python check_sections.py "<carpeta>" ["<sentinel>"]\n')
        return 2
    carpeta = sys.argv[1]
    sentinel = sys.argv[2] if len(sys.argv) > 2 else None

    if sentinel and os.path.exists(sentinel):
        os.remove(sentinel)

    archivos = [f for f in sorted(glob.glob(os.path.join(carpeta, '*.docx')))
                if not os.path.basename(f).startswith('~$')]
    if not archivos:
        print('  [check_sections] ERROR: no hay .docx en %s' % carpeta)
        return 1

    for f in archivos:
        revisa(f)

    print('  [check_sections] %d secciones revisadas' % len(archivos))
    if avisos:
        print('  --- avisos (%d) ---' % len(avisos))
        for a, m in avisos:
            print('      %-52s %s' % (a[:52], m))
    if bloqueantes:
        print('  --- BLOQUEANTES (%d) ---' % len(bloqueantes))
        for a, m in bloqueantes:
            print('      %-52s %s' % (a[:52], m))
        print('  [check_sections] compilación DETENIDA: corregí los bloqueantes y volvé a correr.')
        return 1

    print('  [check_sections] sin bloqueantes: se puede compilar.')
    if sentinel:
        with open(sentinel, 'w', encoding='utf-8') as fh:
            fh.write('ok\n')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:                       # sin sentinel => H1 se detiene
        sys.stderr.write('  [check_sections] ERROR inesperado: %s\n' % exc)
        sys.exit(1)
