# Key script: boot, create fighter A and mage B (IQ raised to 11 for the
# class), and with -Priest priest C (PIETY 5 -> 11), add them to the
# party, enter the maze, leave camp, decline the stairs.  Same shape and
# return value as keys.ps1: @{ Keys; Stairs }.
param([double]$Scale = 1.0, [switch]$Raw, [switch]$Priest)
$k = @('500:0C','1300:2A','1900:2D')        # castle: E)dge, T)raining
$f = 2700
function Add($code, $step = 60) { $script:k += "${script:f}:$code"; $script:f += $step }
function Make($name, $class, $first) {
    Add $name 300; Add '0C' 400               # name, RETURN
    Add '2B' 700                              # create: Y
    Add '3F' 400                              # A) HUMAN
    Add '3F' 600                              # A) GOOD
    & $first                                  # raise the class attribute
    1..6 | ForEach-Object { Add '06' }        # then the rest, as keys.ps1
    Add '0C'
    1..6 | ForEach-Object { Add '06' }
    Add '0C'
    1..6 | ForEach-Object { Add '06' }
    Add '1C' 600                              # ESC
    Add $class 500                            # class letter
    Add '2B' 600                              # keep: Y
}
Make '3F' '3F' { 1..3 | ForEach-Object { Add '06' }; Add '0C'; Add '0C'; Add '0C' }   # A: FIGHTER, STR -> VIT
Make '15' '15' { Add '0C'; 1..3 | ForEach-Object { Add '06' }; Add '0C'; Add '0C' }   # B: MAGE, IQ -> VIT
$names = @('3F', '15')
if ($Priest) {
    Make '12' '12' { Add '0C'; Add '0C'; 1..6 | ForEach-Object { Add '06' }; Add '0C' }  # C: PRIEST, PIE -> VIT
    $names += '12'
}
Add '0C' 600                               # RETURN: castle
Add '3D' 500                               # G)ilgamesh
foreach ($n in $names) {
    Add '3F' 600                           # A)dd
    Add $n 200                             # name
    Add '0C' 600                           # RETURN
}
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
