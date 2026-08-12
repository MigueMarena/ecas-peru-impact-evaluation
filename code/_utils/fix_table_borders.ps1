# ------------------------------------------------------------------------------
# File           : fix_table_borders.ps1
# Author         : Carlos Marena
# Description    : Corrige dos límites de la API `putdocx table` sobre las
#                  tablas INDIVIDUALES, en el momento en que se generan.
#
#                  IMPORTANTE — DÓNDE ENCAJA ESTE HELPER. No tiene nada que ver
#                  con la compilación del reporte ni con `putdocx append`: lo
#                  invocan `prg_table_2panels`, `prg_table_3panels`,
#                  `prg_table_4panels` y `prg_table_3way_het` sobre el .docx de
#                  cada tabla, mucho antes de consolidar. Lo que arregla no es
#                  un defecto heredado del consolidado, sino de lo que el
#                  comando de Stata te deja pedir.
#
#                  (1) GROSOR DE LOS BORDES DOBLES. `putdocx` no expone el
#                      atributo w:sz de un borde, de modo que las dobles líneas
#                      salen con el grosor por defecto (~0.375 pt) y a esa
#                      escala las dos líneas paralelas se tocan: en pantalla se
#                      ven como UNA sola línea gruesa, y se pierde la distinción
#                      visual entre el cierre de un bloque y una separación
#                      cualquiera. Se inyecta w:sz="6" (0.75 pt).
#
#                  (2) JUSTIFICADO DE LA NOTA AL PIE. `putdocx` no admite
#                      halign(justify) en el contenido de una celda —solo en
#                      párrafos sueltos—, así que la nota, que ocupa una celda
#                      a todo el ancho y suele tener cinco oraciones, quedaba
#                      alineada a la izquierda con el margen derecho irregular.
#                      Se inyecta <w:jc w:val="both"/> en el w:pPr del párrafo
#                      que empieza con "Notas. Esta tabla".
#
#                  Ambos son retoques de presentación sobre tablas ya escritas;
#                  ninguno altera cifras ni estructura.
#
# Uso            : powershell -NoProfile -ExecutionPolicy Bypass `
#                      -File fix_table_borders.ps1 "ruta\al\archivo.docx"
# ------------------------------------------------------------------------------
param(
    [Parameter(Mandatory=$true)][string]$DocxPath
)

if (-not (Test-Path $DocxPath)) {
    Write-Error "Archivo no encontrado: $DocxPath"
    exit 1
}

# Extraer el .docx (es un .zip) a un directorio temporal único
$tmp = Join-Path $env:TEMP "fix_borders_$([guid]::NewGuid())"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($DocxPath, $tmp)

# Modificar document.xml: añadir w:sz="6" (1.5pt) a borders dobles
$xmlPath = Join-Path $tmp "word\document.xml"
$xml = Get-Content $xmlPath -Raw

$xml = $xml -replace '<w:top w:val="double" w:color="000000"/>',    '<w:top w:val="double" w:sz="6" w:color="000000"/>'
$xml = $xml -replace '<w:bottom w:val="double" w:color="000000"/>', '<w:bottom w:val="double" w:sz="6" w:color="000000"/>'
$xml = $xml -replace '<w:left w:val="double" w:color="000000"/>',   '<w:left w:val="double" w:sz="6" w:color="000000"/>'
$xml = $xml -replace '<w:right w:val="double" w:color="000000"/>',  '<w:right w:val="double" w:sz="6" w:color="000000"/>'

# ------------------------------------------------------------------------------
# Justify a la celda de notas. Stata putdocx no admite halign(justify) en cell
# content, así que se inyecta vía XML el `<w:jc w:val="both"/>` en el <w:pPr>
# del paragraph que contiene "Notas. Esta tabla". ("both" es el valor docx
# para justify-both-sides; "distribute" sería distribute alignment.)
$notesAnchor = '<w:t xml:space="preserve">Notas. Esta tabla'
$notesIdx = $xml.IndexOf($notesAnchor)
if ($notesIdx -gt 0) {
    $pprStart = $xml.LastIndexOf('<w:pPr>', $notesIdx)
    $pprEnd   = $xml.IndexOf('</w:pPr>', $pprStart)
    if ($pprStart -ge 0 -and $pprEnd -gt $pprStart) {
        $pprBlock = $xml.Substring($pprStart, $pprEnd - $pprStart + '</w:pPr>'.Length)
        if (-not $pprBlock.Contains('<w:jc ')) {
            $newPprBlock = $pprBlock -replace '</w:pPr>', '<w:jc w:val="both"/></w:pPr>'
            $xml = $xml.Substring(0, $pprStart) + $newPprBlock + $xml.Substring($pprEnd + '</w:pPr>'.Length)
        }
    }
}

[System.IO.File]::WriteAllText($xmlPath, $xml, [System.Text.Encoding]::UTF8)

# Re-empacar y reemplazar el .docx original
Remove-Item $DocxPath
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $DocxPath)
Remove-Item $tmp -Recurse -Force

Write-Host "Bordes dobles engrosados a 1.5pt en: $DocxPath"
