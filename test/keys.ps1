# Key script: boot, create fighter A (spending up to 18 bonus points), add
# him to the party, enter the maze, leave camp, decline the stairs.
# -Scale shrinks every gap (e.g. 0.75).  Returns @{ Keys; Stairs }, the
# frames unscaled when -Raw (demo.ps1 scales the whole list itself).
param([double]$Scale = 1.0, [switch]$Raw)
$k = @('500:0C','1300:2A','1900:2D','2700:3F','3000:0C','3400:2B','4100:3F','4500:3F')
$f = 5100
function Add($code, $step = 60) { $script:k += "${script:f}:$code"; $script:f += $step }
1..3 | ForEach-Object { Add '06' }        # STRENGTH +3 -> 11 (fighter)
Add '0C'; Add '0C'; Add '0C'               # -> VITALITY
1..6 | ForEach-Object { Add '06' }
Add '0C'                                   # -> AGILITY
1..6 | ForEach-Object { Add '06' }
Add '0C'                                   # -> LUCK
1..6 | ForEach-Object { Add '06' }
Add '1C' 600                               # ESC
Add '3F' 500                               # A) FIGHTER
Add '2B' 600                               # keep: Y
Add '0C' 600                               # RETURN: castle
Add '3D' 500                               # G)ilgamesh
Add '3F' 600                               # A)dd
Add '3F' 200                               # name A
Add '0C' 600                               # RETURN
Add '0C' 600                               # RETURN: leave tavern
Add '2A' 600                               # E)dge of town
Add '25' 1400                              # M)aze
Add '00' 700                               # L)eave camp
Add '23' 0                                 # N: don't take the stairs
if (-not $Raw) {
    $k = $k | ForEach-Object { $a, $c = $_.Split(':'); "$([int]([int]$a * $Scale)):$c" }
    $f = [int]($f * $Scale)
}
@{ Keys = $k; Stairs = $f }
