#Requires -Version 5.1
# Back-compat name from the downloaded draft. Prefer: .\check-hardware.ps1
& (Join-Path $PSScriptRoot "check-hardware.ps1") @args
exit $LASTEXITCODE
