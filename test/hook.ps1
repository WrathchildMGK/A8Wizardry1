# Address of WIZHI's VBI handler (NMIH), read from the current build's
# listing, as '$XXXX'.  It moves whenever WIZHI changes.
param([string]$Lst = 'C:\cc65-new\Wizardry\atari\build\wizhi.lst')
$m = Select-String -Path $Lst -Pattern '^\s*\d+\s+([0-9A-F]{4})\s+\.local\s+NMIH\b' | Select-Object -First 1
if (-not $m) { throw "NMIH not found in $Lst" }
'$' + $m.Matches[0].Groups[1].Value
