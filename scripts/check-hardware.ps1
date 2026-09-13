#Requires -Version 5.1
# Wrapper so scripts\check-hardware.ps1 matches scripts\check-hardware.sh
& (Join-Path $PSScriptRoot "..\check-hardware.ps1") @args
exit $LASTEXITCODE
