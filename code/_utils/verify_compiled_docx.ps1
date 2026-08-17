# ------------------------------------------------------------------------------
# File           : verify_compiled_docx.ps1
# Author         : Carlos Marena
# Description    : Comprobación final del consolidado. Le pide a Word que abra
#                  el archivo SIN permitirle repararlo y, si abre, informa qué
#                  encontró dentro.
#
#                  POR QUÉ HACE FALTA. Un .docx puede estar perfectamente bien
#                  formado como XML y aun así ser inválido para Word, que
#                  entonces se niega a abrirlo y ofrece "recuperar el
#                  contenido". Lo que abre en ese caso NO es el archivo: es una
#                  reconstrucción, y por eso aparece como "Documento1" sin
#                  ruta. Ninguna validación de XML detecta eso; el único
#                  juez fiable de si un .docx abre en Word es Word.
#
#                  Ese fue exactamente el estado en que estuvo el consolidado
#                  del cuerpo durante seis commits de E.13, sin que ninguna
#                  verificación por XML lo delatara. Esta sonda cierra ese
#                  hueco: si vuelve a pasar, la compilación lo dice en el acto
#                  y no tres días después.
#
#                  CÓMO DISTINGUE. Abre con OpenAndRepair desactivado:
#                    · si el paquete es válido, el documento abre y su
#                      propiedad Path apunta a la carpeta real;
#                    · si no lo es, Word lanza "El archivo parece estar
#                      corrompido", o bien abre una recuperación cuyo Path
#                      está VACÍO. Ambos casos se tratan como fallo.
#
#                  Además informa tablas, párrafos, campos y cuántas entradas
#                  quedó teniendo cada índice: un índice con 0 entradas no
#                  corrompe el archivo, pero es un entregable roto.
#
# Uso            : powershell -NoProfile -ExecutionPolicy Bypass `
#                      -File verify_compiled_docx.ps1 "<sentinel>" "a.docx" ["b.docx" ...]
#                  Crea <sentinel> SOLO si todos los archivos pasan. H1 exige
#                  ese archivo, de modo que cualquier fallo —incluido que Word
#                  no arranque— deja constancia.
# ------------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$Sentinel,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Files
)

$ErrorActionPreference = "Continue"
if (Test-Path $Sentinel) { Remove-Item $Sentinel -Force }

# Una corrida anterior que murió con documentos abiertos deja a Word en un
# estado en que New-Object falla con CO_E_SERVER_EXEC_FAILURE.
Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

$word = $null
for ($i = 0; $i -lt 5 -and $null -eq $word; $i++) {
    try { $word = New-Object -ComObject Word.Application } catch { Start-Sleep -Seconds 2 }
}
if ($null -eq $word) {
    Write-Output "  [verify] ERROR: no se pudo iniciar Word; el consolidado queda SIN verificar."
    exit 1
}

$word.Visible = $false
$word.DisplayAlerts = 0
$M = [System.Type]::Missing
$fallos = 0

foreach ($f in $Files) {
    $nombre = Split-Path $f -Leaf
    if (-not (Test-Path $f)) {
        Write-Output "  [verify] FALLA $nombre :: el archivo no existe"
        $fallos++; continue
    }
    try {
        $d = $word.Documents.Open($f, $false, $true, $false, $M, $M, $M, $M, $M, $M, $M, $false, $false)
        if ($d.Path -eq "") {
            Write-Output "  [verify] FALLA $nombre :: Word lo abrió como documento recuperado (paquete inválido)"
            $fallos++
        }
        else {
            $indices = @()
            foreach ($toc in $d.TablesOfContents) {
                $n = ($toc.Range.Text -split "`r" | Where-Object { $_.Trim() -ne "" }).Count
                $indices += $n
                if ($n -le 1) { $fallos++ }
            }
            Write-Output ("  [verify] OK    {0} :: tablas={1} párrafos={2} campos={3} índices=[{4}]" -f `
                          $nombre, $d.Tables.Count, $d.Paragraphs.Count, $d.Fields.Count, ($indices -join ', '))
            if ($indices -contains 0 -or $indices -contains 1) {
                Write-Output "  [verify]        AVISO: algún índice quedó vacío (revisa el switch \t y el separador de lista)"
            }
        }
        $d.Close([ref]0)
    }
    catch {
        Write-Output ("  [verify] FALLA {0} :: {1}" -f $nombre, $_.Exception.Message.Trim())
        foreach ($od in @($word.Documents)) { try { $od.Close([ref]0) } catch { } }
        $fallos++
    }
}

try { $word.Quit([ref]0) } catch { }
Start-Sleep -Milliseconds 500
Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force

if ($fallos -eq 0) {
    "ok" | Out-File -FilePath $Sentinel -Encoding ascii
    Write-Output "  [verify] los consolidados abren en Word sin reparación y con los índices poblados."
    exit 0
}
Write-Output "  [verify] $fallos comprobación(es) fallaron."
exit 1
