#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ImagePath)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]
function Await-Operation($Operation, [type]$ResultType) {
    $awaitMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    $awaitTask = $awaitMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    try { $awaitTask.Wait() } catch { throw $awaitTask.Exception.InnerException }
    return $awaitTask.Result
}
$resolvedImage = (Resolve-Path -LiteralPath $ImagePath).ProviderPath
$imageFile = Await-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($resolvedImage)) ([Windows.Storage.StorageFile])
$imageStream = Await-Operation ($imageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
try {
    $decoder = Await-Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($imageStream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await-Operation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    try {
        $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
        if (-not $engine) { throw 'Windows OCR language unavailable.' }
        $result = Await-Operation ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
        $cleanText = [regex]::Replace($result.Text, '[\x00-\x1F]', ' ')
        $cleanLines = @($result.Lines | ForEach-Object { [regex]::Replace($_.Text, '[\x00-\x1F]', ' ') })
        [pscustomobject]@{ Text=$cleanText; Lines=$cleanLines; Image=$resolvedImage } | ConvertTo-Json -Depth 4
    } finally { $bitmap.Dispose() }
} finally { $imageStream.Dispose() }
