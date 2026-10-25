# Combat-spell setup: play party2.ps1 (fighter A + mage B) to a forced
# encounter (CHSTALRM := 1 after the stairs) and save the state at frame
# -SaveFrame, which should be the first combat menu, as out\spell.atstate2
# (with -Priest, priest C as well: out\spell3.atstate2).  -Enemy N forces
# enemy N (ENEMYINX, poked as CINIT loads): out\enemyN.atstate2.
# Drive spells from it with fromstate.ps1.
param([int]$SaveFrame = 0, [switch]$Priest, [int]$Enemy = -1)
$o = "$PSScriptRoot\out"
$k = & "$PSScriptRoot\party2.ps1" -Priest:$Priest
$n = if ($Enemy -ge 0) { "enemy$Enemy" } elseif ($Priest) { 'spell3' } else { 'spell' }
$alarm = $k.Stairs + 400
if (-not $SaveFrame) { $SaveFrame = $alarm + 1600 }
$keys = $k.Keys + "$($alarm + 100):3A"           # R: the turn checks the alarm
$pre = @(
    "bx -n `"pc={HOOK} and @frame>$alarm`" `"e 9012 01; bc {N}`"",
    "bx -n `"pc={HOOK} and @frame>$SaveFrame`" `".savestate $o\$n.atstate2; bc {N}`"")
if ($Enemy -ge 0) {
    $runovl = & "$PSScriptRoot\hook.ps1" RUNOVL wizres
    $pre += "bx -n `"pc=$runovl and a=`$08 and @frame>$alarm`" `"e 901c $('{0:X2}' -f $Enemy) 00; bc {N}`""
}
& "$PSScriptRoot\altrun.ps1" -Out "$o\$n\$n.png" -Keys $keys -Hook auto -Pre $pre -DumpFrame ($SaveFrame + 10) -Timeout 600
