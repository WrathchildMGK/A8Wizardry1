# Play the demo (demo.ps1) in its own visible Altirra, for recording.  It has
# its own settings file (test\out), so it never touches your own Altirra.
# It starts paused in the debugger:
#   1. File > Record Video... (pick a file), then
#   2. press F5 (Debug > Run): the game plays itself.  Don't press keys in it.
# Close that Altirra when the demo ends.
param([string]$Atr = "$PSScriptRoot\..\build\wizardry.atr", [int]$Rounds = 2, [double]$Scale = 1.0)
$Out = "$PSScriptRoot\out"
New-Item -ItemType Directory -Force $Out | Out-Null
$Ini = "$Out\alt_130xe.ini"
if (-not (Test-Path $Ini)) { Copy-Item "$PSScriptRoot\altirra.template.ini" $Ini }
$bat = "$Out\demo.txt"
$r = & "$PSScriptRoot\demo.ps1" -Rounds $Rounds -Scale $Scale
$hook = & "$PSScriptRoot\hook.ps1"      # WIZHI's VBI handler: runs once per frame
$lines = @()
$n = 0
foreach ($k in $r.Keys) {
    $f, $c = $k.Split(':')
    $lines += "bx -n `"pc=$hook and @frame>$f`" `"e 2fc $c; bc $n`""
    $n++
}
$lines += "bx -n `"pc=$hook and @frame>$($r.Alarm)`" `"e 9012 01; bc $n`""   # GLOBALS CHSTALRM
Set-Content -Encoding ascii $bat $lines
$Atr = (Resolve-Path $Atr).Path
$argv = "/portablealt:$Ini /hardware:130xe /memsize:128K /nobasic /siopatch /nosingleinstance /debug /debugcmd:`".batch $bat`" `"$Atr`""
Start-Process -FilePath 'D:\altirra\altirra64.exe' -ArgumentList $argv
"Demo Altirra started (about $([int]($r.End / 60)) s of play).  Record Video, then F5."
