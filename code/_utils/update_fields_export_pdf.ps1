# ------------------------------------------------------------------------------
# File           : update_fields_export_pdf.ps1
# Author         : Carlos Marena
# Description    : Cierra el último tramo manual de la compilación: abre el
#                  consolidado en Word, actualiza los campos, guarda y exporta
#                  el PDF. Explicación larga en:
#                     Reporte Final_VPaper/Planes_Ejecucion/
#                     52_E_Apoyo_Compilacion_explicada.md
#
#                  QUÉ ES "RESOLVER LOS CAMPOS". En Word un índice no es texto:
#                  es un CAMPO, una instrucción que Word evalúa y cuyo
#                  resultado muestra. La del índice de tablas del reporte es
#
#                      TOC \h \z \t "Titulo de tabla;1"
#
#                  es decir: "armá una tabla de contenido recogiendo todos los
#                  párrafos con el estilo llamado «Titulo de tabla», al nivel
#                  1, con hipervínculos". Mientras nadie la evalúa, en su lugar
#                  no hay nada: por eso el archivo recién salido de Stata
#                  muestra los índices VACÍOS. Los campos están escritos, pero
#                  sin calcular. En Word se calculan con Ctrl+E y F9.
#
#                  Y no se pueden sustituir escribiendo el índice a mano,
#                  porque necesita NÚMEROS DE PÁGINA, y esos no existen hasta
#                  que alguien maqueta el documento. El único que sabe en qué
#                  página cae cada tabla es Word.
#
#                  QUÉ ES "POR COM". COM es el mecanismo de Windows que permite
#                  que un programa pilote a otro. Este script arranca Word sin
#                  ventana visible y le va dando las mismas órdenes que daría
#                  una persona: abre, actualiza, guarda, exporta, cierra. No es
#                  una conversión ni una reimplementación: es Word haciendo el
#                  trabajo, teledirigido. Por eso el PDF sale idéntico al que
#                  se obtendría "Guardar como PDF" a mano, y no como el de un
#                  convertidor externo, que perdería formato.
#
#                  POR QUÉ AQUÍ Y NO EN LA MÁQUINA QUE RECIBA EL ARCHIVO. El
#                  switch \t delimita el par "estilo;nivel" con el separador de
#                  lista del documento. Dejando los campos ya resueltos, los
#                  índices del entregable no dependen de la configuración
#                  regional de quien lo abra.
#
#                  Los TOC se actualizan dos veces a propósito: la primera
#                  pasada INSERTA las entradas, lo que empuja el texto y
#                  cambia la paginación; la segunda fija los números de página
#                  ya definitivos.
#
#                  Se abre SIN OpenAndRepair a propósito: si el paquete
#                  estuviera corrupto queremos que falle aquí, con un mensaje
#                  claro, y no que Word lo "recupere" en silencio y produzca un
#                  PDF a partir de una reconstrucción.
#
#                  Si Word no está disponible el script informa y devuelve 2,
#                  para que el .do siga adelante sin abortar la compilación:
#                  el .docx ya está escrito y los campos quedan actualizables
#                  a mano.
#
# Uso            : powershell -NoProfile -ExecutionPolicy Bypass `
#                      -File update_fields_export_pdf.ps1 "ruta\al\archivo.docx"
# ------------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$DocxPath
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $DocxPath)) {
    Write-Output "  [update_fields] ERROR: archivo no encontrado: $DocxPath"
    exit 1
}

$PdfPath = [System.IO.Path]::ChangeExtension($DocxPath, ".pdf")
$nombre  = Split-Path $DocxPath -Leaf

# Word queda en mal estado si una corrida anterior murió con documentos abiertos.
Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

$word = $null
for ($i = 0; $i -lt 5 -and $null -eq $word; $i++) {
    try { $word = New-Object -ComObject Word.Application } catch { Start-Sleep -Seconds 2 }
}
if ($null -eq $word) {
    Write-Output "  [update_fields] Word no disponible; $nombre queda con los campos sin resolver."
    exit 2
}

$word.Visible = $false
$word.DisplayAlerts = 0
$M = [System.Type]::Missing
$salida = 0

try {
    # Sin OpenAndRepair: si el paquete estuviera corrupto queremos que falle
    # aquí y no que Word lo "recupere" en silencio como documento sin ruta.
    $doc = $word.Documents.Open($DocxPath, $false, $false, $false, $M, $M, $M, $M, $M, $M, $M, $false, $false)

    if ($doc.Path -eq "") {
        Write-Output "  [update_fields] ERROR: Word abrió $nombre como documento recuperado."
        $doc.Close([ref]0)
        $salida = 1
    }
    else {
        $doc.Fields.Update() | Out-Null
        foreach ($toc in $doc.TablesOfContents)  { $toc.Update() }
        foreach ($tof in $doc.TablesOfFigures)   { $tof.Update() }
        foreach ($toc in $doc.TablesOfContents)  { $toc.UpdatePageNumbers() }

        $n = 0
        foreach ($toc in $doc.TablesOfContents) {
            $n++
            $entradas = ($toc.Range.Text -split "`r" | Where-Object { $_.Trim() -ne "" }).Count
            Write-Output ("  [update_fields] {0} · índice {1}: {2} entradas" -f $nombre, $n, $entradas)
        }

        $doc.Save()
        # 17 = wdExportFormatPDF, 0 = wdExportOptimizeForPrint,
        # 7 = wdExportDocumentWithMarkup->NO (wdExportDocumentContent), sin marcas.
        $doc.ExportAsFixedFormat($PdfPath, 17, $false, 0, 0, 1, 1, 0, $true, $true, 0, $true, $true, $false)
        $doc.Close([ref]0)
        Write-Output ("  [update_fields] PDF exportado: " + (Split-Path $PdfPath -Leaf))
    }
}
catch {
    Write-Output ("  [update_fields] ERROR en " + $nombre + ": " + $_.Exception.Message.Trim())
    foreach ($d in @($word.Documents)) { try { $d.Close([ref]0) } catch { } }
    $salida = 1
}

try { $word.Quit([ref]0) } catch { }
Start-Sleep -Milliseconds 500
Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
exit $salida
