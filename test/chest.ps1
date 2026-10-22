# Run A of the chest tests: play to the forced encounter (demo.ps1 keys),
# then as CUTIL first starts kill every enemy (XSTATUS := DEAD) and clear
# CHSTALRM (an alarm encounter never gives a chest), so the fight ends at
# once and REWARDS offers the room reward's chest.  Saves the state at
# frame -SaveFrame as out\chest.atstate2 and dumps the screen.
param([int]$SaveFrame = 16200)
$o = "$PSScriptRoot\out"
# no maze walk: with a real RNG a walk can meet a random encounter first
$k = & "$PSScriptRoot\keys.ps1"
$r = @{ Alarm = $k.Stairs + 400 }
$keys = $k.Keys + "$($r.Alarm + 100):3A"         # R: the turn checks the alarm
$runovl = & "$PSScriptRoot\hook.ps1" RUNOVL wizres
$t04 = 0x8BDD                                   # COMBATG A_T04BLK: TTEMP04[ 0..44], 13 bytes
$kill = @()
foreach ($g in 1..4) { foreach ($j in 0..8) { $kill += 'e {0:X4} 05' -f ($t04 + ($g * 9 + $j) * 13 + 12) } }
$kill += 'e 9012 00'                            # GLOBALS CHSTALRM
$pre = @(
    "bx -n `"pc={HOOK} and @frame>$($r.Alarm)`" `"e 9012 01; bc {N}`"",
    "bx -n `"pc=$runovl and a=`$0A and @frame>$($r.Alarm)`" `"$($kill -join '; '); bc {N}`"",
    "bx -n `"pc={HOOK} and @frame>$SaveFrame`" `".savestate $o\chest.atstate2; bc {N}`"")
& "$PSScriptRoot\altrun.ps1" -Out "$o\chest.png" -Keys $keys -Hook auto -Pre $pre -DumpFrame ($SaveFrame + 10) -Timeout 600
