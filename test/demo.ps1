# Demo key script: keys.ps1 (create fighter, party, maze, decline stairs),
# then walk, an encounter (CHSTALRM := 1 at frame Alarm, checked on the next
# turn), Rounds rounds of F)ight + RETURN, the rewards, and a walk.
# With fixed key frames a run is deterministic: the same fight every time.
# -Scale shrinks every gap.  Returns @{ Keys; Alarm; End }.
param([int]$Rounds = 2, [int]$RoundFrames = 420, [double]$Scale = 1.0)
$r = & "$PSScriptRoot\keys.ps1" -Raw
$k = $r.Keys
$f = $r.Stairs + 500
foreach ($c in '3A', '38', '38', '3F', '38', '3F') {   # R, F, F, L, F, L
    $k += "${f}:$c"; $f += 300
}
$alarm = $f
$f += 100
$k += "${f}:3A"                                        # R: the turn checks the alarm
$f += 900                                              # CINIT, CUTIL, CACT load
for ($i = 0; $i -lt $Rounds; $i++) {
    $k += "${f}:38"                                    # F)ight
    $k += "$($f + 80):0C"                              # RETURN: fight
    $f += $RoundFrames
}
$f += 900                                              # rewards, back to the maze
foreach ($c in '3F', '3F', '38', '38', '3A', '38') {   # L, L, F, F, R, F
    $k += "${f}:$c"; $f += 300
}
$k = $k | ForEach-Object { $a, $c = $_.Split(':'); "$([int]([int]$a * $Scale)):$c" }
@{ Keys = $k; Alarm = [int]($alarm * $Scale); End = [int]($f * $Scale) }
