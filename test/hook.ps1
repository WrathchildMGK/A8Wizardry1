# Address of a procedure in the current build, read from its listing, as
# '$XXXX' (addresses move whenever the code changes).  Default: WIZHI's VBI
# handler NMIH, which runs once per frame.
#   .\hook.ps1                       -> NMIH in wizhi.lst
#   .\hook.ps1 RUNOVL wizres         -> RUNOVL in wizres.lst
param([string]$Name = 'NMIH', [string]$Bin = 'wizhi')
$Lst = "$PSScriptRoot\..\build\$Bin.lst"
$m = Select-String -Path $Lst -Pattern "^\s*\d+\s+([0-9A-F]{4})\s+\.local\s+$Name\b" | Select-Object -First 1
if (-not $m) { throw "$Name not found in $Lst" }
'$' + $m.Matches[0].Groups[1].Value
