param(
    [string]$Executable,
    [string]$OutputDirectory = 'artifacts/presentation-checks'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
if (!$Executable) {
    & dotnet run --project (Join-Path $taskRoot 'tests/AchievementLabs.Presentation.Tests') -c Release
    if ($LASTEXITCODE -ne 0) { throw 'Presentation logic checks failed.' }
    exit 0
}
$taskExe = (Resolve-Path -LiteralPath $Executable).Path
$taskOutput = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $taskOutput) { throw 'Use a fresh presentation output directory.' }
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskArguments = "--visual-preview --scroll-regression --preview-output `"$taskOutput`" --exit-after-visual-checks"
$taskProcess = Start-Process -FilePath $taskExe -ArgumentList $taskArguments -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $taskOutput 'stderr.txt')
if (!$taskProcess.WaitForExit(120000)) {
    $taskProcess.Kill()
    throw 'Offline presentation checks timed out.'
}
$taskProcess.Refresh()
if ($taskProcess.ExitCode -ne 0 -or !(Test-Path (Join-Path $taskOutput 'visual-checks-passed.txt'))) {
    Get-Content (Join-Path $taskOutput 'stderr.txt')
    throw 'Packaged presentation checks failed.'
}
Get-Content (Join-Path $taskOutput '*check*.txt')
